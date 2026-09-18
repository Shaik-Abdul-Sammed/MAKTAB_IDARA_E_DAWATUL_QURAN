import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/models/quran_progress.dart';
import 'package:maktab_app/models/fee_payment.dart';
import 'package:maktab_app/models/salary_payment.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;
import 'package:maktab_app/services/database_helper.dart';

/// 100% Free ($0/month target) Firebase Realtime Database Granular Cloud Sync Engine.
/// Replaces external REST servers with native, granular Firebase Realtime Database listeners & updates.
/// Local SQLite (`maktab.db`) remains the zero-latency offline cache.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  CloudSyncService._init();

  static const String _rtdbUrl = 'https://maktab-management-99001-default-rtdb.asia-southeast1.firebasedatabase.app';

  FirebaseDatabase? get _db {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      );
    } catch (_) {
      return null;
    }
  }

  final List<StreamSubscription<DatabaseEvent>> _childSubscriptions = [];
  final StreamController<String> _syncController = StreamController<String>.broadcast();

  /// Active maktabId used by the periodic auto-sync timer
  String? _activeMaktabId;

  /// Periodic background sync every 30 seconds
  Timer? _periodicSyncTimer;

  /// Whether a periodic syncAll is already running (prevent overlap)
  bool _periodicSyncInProgress = false;

  Stream<String> get onDataSynced => _syncController.stream;

  void notifyDataChanged(String collection) {
    if (!_syncController.isClosed) {
      _syncController.add(collection);
    }
  }

  // ── Always-On Auto Sync ─────────────────────────────────────────────────────

  /// Start the persistent always-on sync engine.
  /// Safe to call multiple times — deduplicated internally.
  void enableAlwaysOnSync(String maktabId) {
    _activeMaktabId = maktabId;
    _startPeriodicSync();
    // Kick-off an immediate push-before-pull
    syncAll().then((_) => pullAllDataForMaktab(maktabId)).catchError((_) => false);
  }

  /// Call this when the app resumes from background to force an immediate re-sync.
  void onAppResumed() {
    final mId = _activeMaktabId;
    if (mId == null || mId.isEmpty) return;
    // Restart realtime listeners in case they dropped while backgrounded
    startRealtimeSync(mId);
    // Immediately push local changes before pulling latest cloud data
    syncAll().then((_) => pullAllDataForMaktab(mId)).catchError((_) => false);
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_periodicSyncInProgress) return;
      final mId = _activeMaktabId;
      if (mId == null || mId.isEmpty) return;
      _periodicSyncInProgress = true;
      try {
        // Ensure realtime listeners are alive
        if (_childSubscriptions.isEmpty) {
          startRealtimeSync(mId);
        }
        // Push any local-only changes to cloud
        await syncAll();
        // Pull any remote-only changes to local
        await pullAllDataForMaktab(mId);
      } catch (e) {
        debugPrint('Auto-sync periodic error: $e');
      } finally {
        _periodicSyncInProgress = false;
      }
    });
  }

  void stopAlwaysOnSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _activeMaktabId = null;
    stopRealtimeSync();
  }

  Future<String> getMaktabId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? maktabId = prefs.getString('maktab_id');
      if (maktabId == null || maktabId.isEmpty) {
        if (Firebase.apps.isNotEmpty) {
          try {
            final user = fb_auth.FirebaseAuth.instance.currentUser;
            final db = _db;
            if (user != null && db != null) {
              final snapshot = await db.ref('users/${user.uid}/maktabId').get().timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException('maktabId query timed out'),
              );
              if (snapshot.exists && snapshot.value != null && snapshot.value.toString().isNotEmpty) {
                maktabId = snapshot.value.toString();
                await prefs.setString('maktab_id', maktabId);
                return maktabId;
              }
            }

            // Auto-discover active Maktab ID from cloud if currently missing
            if (db != null) {
              final maktabsSnap = await db.ref('maktabs').get().timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException('maktabs list query timed out'),
              );
              if (maktabsSnap.exists && maktabsSnap.value is Map) {
                final map = Map<String, dynamic>.from(maktabsSnap.value as Map);
                // First look for any maktab node that has students (including MAKTAB-001)
                for (var key in map.keys) {
                  final kStr = key.toString();
                  if (map[kStr] is Map && map[kStr]['students'] != null) {
                    maktabId = kStr;
                    await prefs.setString('maktab_id', maktabId);
                    return maktabId;
                  }
                }
                // Fallback to first available key
                if (map.keys.isNotEmpty) {
                  maktabId = map.keys.first.toString();
                  await prefs.setString('maktab_id', maktabId);
                  return maktabId;
                }
              }
            }
          } catch (_) {}
        }
        maktabId ??= 'MAKTAB-001';
        await prefs.setString('maktab_id', maktabId);
      }
      return maktabId;
    } catch (_) {
      return 'MAKTAB-001';
    }
  }

  Future<void> setMaktabId(String maktabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('maktab_id', maktabId);
    } catch (_) {}
  }

  // ── Firebase Granular Realtime Listeners ─────────────────────────────────

  void startRealtimeSync(String maktabId) {
    stopRealtimeSync();
    final db = _db;
    if (db == null) return;

    final collections = [
      'teachers',
      'batches',
      'students',
      'attendance',
      'teacher_attendance',
      'quran_progress',
      'fee_payments',
      'salary_payments',
    ];

    for (var col in collections) {
      try {
        final sub = db.ref('maktabs/$maktabId/$col').onValue.listen((event) async {
          if (!event.snapshot.exists || event.snapshot.value == null) return;
          try {
            final data = _normalizeRtdbSnapshotValue(event.snapshot.value);
            await _mergeCollectionToSQLite(col, data);
          } catch (e) {
            debugPrint('Firebase Granular Sync error on $col: $e');
          }
        }, onError: (e) {
          debugPrint('Firebase stream note for $col: $e');
        });
        _childSubscriptions.add(sub);
      } catch (_) {}
    }
    // Trigger background sync for any unpushed offline SQLite records
    syncAll().catchError((e) {
      debugPrint('Background syncAll error on startRealtimeSync: $e');
      return false;
    });
  }

  void stopRealtimeSync() {
    for (var sub in _childSubscriptions) {
      sub.cancel();
    }
    _childSubscriptions.clear();
  }

  Map<String, dynamic> _normalizeRtdbSnapshotValue(dynamic val) {
    final Map<String, dynamic> result = {};
    if (val is Map) {
      val.forEach((k, v) {
        if (v != null) result[k.toString()] = v;
      });
    } else if (val is List) {
      for (int i = 0; i < val.length; i++) {
        if (val[i] != null) {
          result[i.toString()] = val[i];
        }
      }
    }
    return result;
  }

  Map<String, dynamic> _toMap(dynamic val) {
    if (val is Map) {
      final Map<String, dynamic> result = {};
      val.forEach((k, v) {
        if (v != null) result[k.toString()] = v;
      });
      return result;
    }
    return {};
  }

  Future<void> _mergeCollectionToSQLite(String collection, Map<String, dynamic> colData) async {
    final db = await DatabaseHelper.instance.database;

    switch (collection) {
      case 'batches':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final b = Batch.fromMap(item);
            await db.insert('batches', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging batch ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'students':
        if (colData.isNotEmpty) {
          try {
            await db.delete(
              'students',
              where: 'id >= 101 AND id <= 110 AND admission_number LIKE ?',
              whereArgs: ['ADM-2026-%'],
            );
          } catch (_) {}
        }
        final localBatches = await db.query('batches');
        final batchMap = <int, int>{};
        final batchNameMap = <String, int>{};
        for (var b in localBatches) {
          final bId = b['id'] as int?;
          final bName = b['name']?.toString().toLowerCase();
          if (bId != null) {
            batchMap[bId] = bId;
            if (bName != null) batchNameMap[bName] = bId;
          }
        }

        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final s = Student.fromMap(item);
            var map = s.toMap();

            int? resolvedBatchId = map['batch_id'] as int?;
            if (resolvedBatchId != null && resolvedBatchId > 0) {
              map['batch_id'] = resolvedBatchId;
            } else if (item['batch_name'] != null || item['batch'] != null) {
              final rawName = (item['batch_name'] ?? (item['batch'] is Map ? item['batch']['name'] : item['batch']))?.toString().toLowerCase();
              if (rawName != null && batchNameMap.containsKey(rawName)) {
                map['batch_id'] = batchNameMap[rawName];
              }
            }
            if (map['batch_id'] == null || (map['batch_id'] as int) <= 0) {
              if (localBatches.isNotEmpty) {
                map['batch_id'] = localBatches.first['id'];
              } else {
                map['batch_id'] = 1;
              }
            }

            if (map['id'] != null) {
              final existingRows = await db.query('students', where: 'id = ?', whereArgs: [map['id']]);
              if (existingRows.isNotEmpty) {
                final isSynced = existingRows.first['is_synced'] as int?;
                if (isSynced == 0) {
                  continue;
                }
              }
            }

            map['is_synced'] = 1;
            await db.insert('students', map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging student ${entry.key} to SQLite: $e');
          }
        }

        // Fail-safe auto-relink: ONLY update students with missing or invalid (<= 0) batch_id
        try {
          final batchesList = await db.query('batches');
          if (batchesList.isNotEmpty) {
            final firstBatchId = batchesList.first['id'] as int?;
            if (firstBatchId != null) {
              await db.rawUpdate('''
                UPDATE students
                SET batch_id = ?
                WHERE (batch_id IS NULL OR batch_id <= 0)
              ''', [firstBatchId]);
            }
          }
        } catch (_) {}
        break;

      case 'teachers':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final u = User.fromMap(item);
            await db.insert('users', u.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging teacher ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'attendance':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final a = Attendance.fromMap(item);
            
            // Protect un-synced local edits (is_synced == 0) for the same student & date
            final existingRows = await db.query(
              'attendance',
              where: '(student_id = ? AND date = ?) OR id = ?',
              whereArgs: [a.studentId, a.date, a.id],
            );
            if (existingRows.isNotEmpty) {
              final isSynced = existingRows.first['is_synced'] as int?;
              if (isSynced == 0) {
                // Local edit is newer; do not overwrite with stale cloud data
                continue;
              }
            }

            final aMap = a.toMap();
            aMap['is_synced'] = 1;
            await db.insert('attendance', aMap, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging attendance ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'teacher_attendance':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final ta = TeacherAttendance.fromMap(item);
            await db.insert('teacher_attendance', ta.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging teacher_attendance ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'quran_progress':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final qp = QuranProgress.fromMap(item);
            await db.insert('quran_progress', qp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging quran_progress ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'fee_payments':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final f = FeePayment.fromMap(item);
            await db.insert('fee_payments', f.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging fee_payment ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'salary_payments':
        for (var entry in colData.entries) {
          try {
            final item = _toMap(entry.value);
            item['id'] ??= int.tryParse(entry.key.toString());
            final sp = SalaryPayment.fromMap(item);
            await db.insert('salary_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging salary_payment ${entry.key} to SQLite: $e');
          }
        }
        break;
    }
    notifyDataChanged(collection);
  }

  // ── Push Entity Methods ───────────────────────────────────────────────────

  Future<void> pushUser(User user) async {
    try {
      final maktabId = await getMaktabId();
      final id = user.id ?? DateTime.now().millisecondsSinceEpoch;
      await _db?.ref('maktabs/$maktabId/teachers/$id').set(user.toMap());
    } catch (e) {
      debugPrint('Firebase pushUser error: $e');
    }
  }

  Future<void> pushBatch(Batch batch) async {
    try {
      final maktabId = await getMaktabId();
      final id = batch.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = batch.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/batches/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushBatch timed out'),
      );
    } catch (e) {
      debugPrint('Firebase pushBatch error: $e');
    }
  }

  Future<bool> pushStudent(Student student) async {
    try {
      final maktabId = await getMaktabId();
      final id = student.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = student.toMap();
      map['id'] ??= id;

      try {
        final sqliteDb = await DatabaseHelper.instance.database;
        final batchRows = await sqliteDb.query('batches', where: 'id = ?', whereArgs: [student.batchId]);
        if (batchRows.isNotEmpty) {
          map['batch_name'] = batchRows.first['name'];
        }
      } catch (_) {}

      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/students/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushStudent timed out'),
      );
      return true;
    } catch (e) {
      debugPrint('Firebase pushStudent error: $e');
      return false;
    }
  }

  Future<bool> pushAttendance(Attendance attendance) async {
    try {
      final maktabId = await getMaktabId();
      final key = '${attendance.studentId}_${attendance.date}';
      final map = attendance.toMap();
      map['id'] ??= attendance.id ?? DateTime.now().millisecondsSinceEpoch;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/attendance/$key').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushAttendance timed out'),
      );
      return true;
    } catch (e) {
      debugPrint('Firebase pushAttendance error: $e');
      return false;
    }
  }

  Future<void> pushTeacherAttendance(TeacherAttendance ta) async {
    try {
      final maktabId = await getMaktabId();
      final id = ta.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = ta.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/teacher_attendance/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushTeacherAttendance timed out'),
      );
    } catch (e) {
      debugPrint('Firebase pushTeacherAttendance error: $e');
    }
  }

  Future<void> pushQuranProgress(QuranProgress qp) async {
    try {
      final maktabId = await getMaktabId();
      final id = qp.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = qp.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/quran_progress/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushQuranProgress timed out'),
      );
    } catch (e) {
      debugPrint('Firebase pushQuranProgress error: $e');
    }
  }

  Future<bool> pushFeePayment(FeePayment fee) async {
    try {
      final maktabId = await getMaktabId();
      final id = fee.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = fee.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/fee_payments/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushFeePayment timed out'),
      );
      return true;
    } catch (e) {
      debugPrint('Firebase pushFeePayment error: $e');
      return false;
    }
  }

  Future<void> pushSalaryPayment(SalaryPayment sp) async {
    try {
      final maktabId = await getMaktabId();
      final id = sp.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = sp.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/salary_payments/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushSalaryPayment timed out'),
      );
    } catch (e) {
      debugPrint('Firebase pushSalaryPayment error: $e');
    }
  }

  Future<void> deleteBatchCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/batches/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteBatchCloud error: $e');
    }
  }

  Future<void> deleteStudentCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/students/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteStudentCloud error: $e');
    }
  }

  Future<void> deleteFeePaymentCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/fee_payments/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteFeePaymentCloud error: $e');
    }
  }

  Future<void> deleteTeacherCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/teachers/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteTeacherCloud error: $e');
    }
  }

  Future<void> deleteSalaryPaymentCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/salary_payments/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteSalaryPaymentCloud error: $e');
    }
  }

  // ── Sync All Offline SQLite Records ────────────────────────────────────────

  bool _isSyncing = false;

  Future<bool> syncAll() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    try {
      final maktabId = await getMaktabId();
      final db = await DatabaseHelper.instance.database;

      final unSyncedStudents = await db.query('students', where: 'is_synced = 0');
      for (var sRow in unSyncedStudents) {
        final s = Student.fromMap(sRow);
        final pushOk = await pushStudent(s);
        if (pushOk && s.id != null) {
          await db.update('students', {'is_synced': 1}, where: 'id = ?', whereArgs: [s.id]);
        }
      }

      final unSyncedAttendance = await db.query('attendance', where: 'is_synced = 0');
      for (var aRow in unSyncedAttendance) {
        final a = Attendance.fromMap(aRow);
        final pushOk = await pushAttendance(a);
        if (pushOk && a.id != null) {
          await db.update('attendance', {'is_synced': 1}, where: 'id = ?', whereArgs: [a.id]);
        }
      }

      final unSyncedFee = await db.query('fee_payments', where: 'is_synced = 0');
      for (var fRow in unSyncedFee) {
        final f = FeePayment.fromMap(fRow);
        final pushOk = await pushFeePayment(f);
        if (pushOk && f.id != null) {
          await db.update('fee_payments', {'is_synced': 1}, where: 'id = ?', whereArgs: [f.id]);
        }
      }

      // Start granular listening for changes in this Maktab
      startRealtimeSync(maktabId);

      return true;
    } catch (e) {
      debugPrint('CloudSyncService syncAll error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> pullAllDataForMaktab(String maktabId) async {
    try {
      final db = _db;
      if (db == null) return false;

      final collections = [
        'teachers',
        'batches',
        'students',
        'attendance',
        'teacher_attendance',
        'quran_progress',
        'fee_payments',
        'salary_payments',
      ];

      bool anyPulled = false;
      for (var col in collections) {
        try {
          final snapshot = await db.ref('maktabs/$maktabId/$col').get().timeout(
            const Duration(seconds: 4),
            onTimeout: () => throw TimeoutException('pull $col timed out'),
          );
          if (snapshot.exists && snapshot.value != null) {
            final data = _normalizeRtdbSnapshotValue(snapshot.value);
            await _mergeCollectionToSQLite(col, data);
            anyPulled = true;
          }
        } catch (e) {
          debugPrint('CloudSyncService error pulling $col for maktab $maktabId: $e');
        }
      }

      // Fallback check: if primary maktabId returned no student data, search other maktab nodes in RTDB
      if (!anyPulled) {
        try {
          final maktabsSnap = await db.ref('maktabs').get().timeout(const Duration(seconds: 3));
          if (maktabsSnap.exists && maktabsSnap.value is Map) {
            final maktabsMap = Map<String, dynamic>.from(maktabsSnap.value as Map);
            for (var entry in maktabsMap.entries) {
              final otherId = entry.key.toString();
              if (otherId == maktabId) continue;
              final val = entry.value;
              if (val is Map && val['students'] != null) {
                final studentData = _normalizeRtdbSnapshotValue(val['students']);
                if (studentData.isNotEmpty) {
                  await _mergeCollectionToSQLite('students', studentData);
                  if (val['batches'] != null) {
                    await _mergeCollectionToSQLite('batches', _normalizeRtdbSnapshotValue(val['batches']));
                  }
                  anyPulled = true;
                  await setMaktabId(otherId);
                  startRealtimeSync(otherId);
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      startRealtimeSync(maktabId);
      return anyPulled;
    } catch (e) {
      debugPrint('CloudSyncService pullAllDataForMaktab error: $e');
      return false;
    }
  }
}
