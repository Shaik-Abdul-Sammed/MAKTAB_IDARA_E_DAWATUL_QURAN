import 'dart:async';
import 'dart:convert';
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

class WriteRecord {
  final String path;
  final DateTime timestamp;
  final bool success;
  final Object? error;
  WriteRecord(this.path, this.timestamp, this.success, this.error);

  @override
  String toString() => '[${timestamp.toIso8601String()}] $path -> ${success ? "SUCCESS" : "FAILED: $error"}';
}

void logMaktabFingerprint(String source, String maktabId) {
  final bytes = utf8.encode(maktabId);
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  debugPrint('[MAKTAB FINGERPRINT] source=$source value="$maktabId" length=${maktabId.length} hex=$hex');
}

/// 100% Free ($0/month target) Firebase Realtime Database Granular Cloud Sync Engine.
/// Replaces external REST servers with native, granular Firebase Realtime Database listeners & updates.
/// Local SQLite (`maktab.db`) remains the zero-latency offline cache.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  CloudSyncService._init();

  final List<WriteRecord> _writeRingBuffer = [];
  void recordWrite(String path, bool success, [Object? error]) {
    if (_writeRingBuffer.length >= 20) {
      _writeRingBuffer.removeAt(0);
    }
    _writeRingBuffer.add(WriteRecord(path, DateTime.now(), success, error));
  }
  List<WriteRecord> get recentWrites => List.unmodifiable(_writeRingBuffer);

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

  static const List<String> _managerCollections = [
    'teachers',
    'batches',
    'students',
    'attendance',
    'teacher_attendance',
    'quran_progress',
    'fee_payments',
    'salary_payments',
  ];

  static const List<String> _teacherCollections = [
    'teachers',
    'batches',
    'students',
    'attendance',
    'teacher_attendance',
    'quran_progress',
  ];

  String? _currentRole;

  void setCurrentRole(String? role) {
    _currentRole = role?.trim().toLowerCase();
  }

  List<String> get _activeCollections {
    if (_currentRole == 'teacher') return _teacherCollections;
    final email = fb_auth.FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    if (_currentRole == null && email.startsWith('teacher_')) {
      return _teacherCollections;
    }
    return _managerCollections;
  }

  Future<void> _resolveUserRole() async {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final db = _db;
    if (db == null) return;
    try {
      final snap = await db.ref('users/$uid/role').get().timeout(
        const Duration(seconds: 4),
      );
      if (snap.exists && snap.value != null) {
        _currentRole = snap.value.toString().trim().toLowerCase();
        debugPrint('[CloudSyncService] Resolved user role from RTDB: $_currentRole');
      }
    } catch (e) {
      debugPrint('[CloudSyncService] Could not resolve role for $uid: $e');
    }
  }

  /// Active maktabId used by the periodic auto-sync timer
  String? _activeMaktabId;

  /// Periodic background sync every 30 seconds
  Timer? _periodicSyncTimer;

  /// Whether a periodic syncAll is already running (prevent overlap)
  bool _periodicSyncInProgress = false;

  /// Single-flight guard to prevent concurrent pulls
  Future<bool>? _activePullFuture;

  Stream<String> get onDataSynced => _syncController.stream;
  Stream<String> get dataChangeStream => _syncController.stream;

  void notifyDataChanged(String collection) {
    if (!_syncController.isClosed) {
      _syncController.add(collection);
    }
  }

  bool get isAuthValid {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<void> _runStartupPermissionProbe(String maktabId) async {
    final db = _db;
    if (db == null) return;
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    final probePaths = [
      'maktabs/$maktabId/students',
      'maktabs/$maktabId/attendance',
      if (uid != null) 'users/$uid',
    ];
    for (final path in probePaths) {
      try {
        final snap = await db.ref(path).get().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Probe $path timed out'),
        );
        int nodeCount = 0;
        if (snap.exists && snap.value is Map) {
          nodeCount = (snap.value as Map).length;
        } else if (snap.exists && snap.value is List) {
          nodeCount = (snap.value as List).length;
        }
        debugPrint('[STARTUP PROBE] path=$path exists=${snap.exists} isNull=${snap.value == null} nodeCount=$nodeCount');
      } catch (e, st) {
        debugPrint('[STARTUP PROBE ERROR] path=$path exception=$e\nstackTrace=$st');
      }
    }
  }

  // ── Always-On Auto Sync ─────────────────────────────────────────────────────

  /// Start the persistent always-on sync engine.
  /// Safe to call multiple times — deduplicated internally.
  void enableAlwaysOnSync(String maktabId) {
    _activeMaktabId = maktabId;
    if (!isAuthValid) {
      if (kDebugMode) debugPrint('[CloudSyncService] enableAlwaysOnSync deferred: No authenticated non-anonymous Firebase user.');
      return;
    }
    logMaktabFingerprint('cloud_sync', maktabId);
    _resolveUserRole().then((_) => _runStartupPermissionProbe(maktabId)).then((_) {
      _startPeriodicSync();
      // Kick-off an immediate push-before-pull
      syncAll()
          .then((_) => pullAllDataForMaktab(maktabId))
          .then((_) => printDiagnosticSummary())
          .catchError((_) => false);
    }).catchError((e) {
      debugPrint('[CloudSyncService] Startup probe execution note: $e');
      _startPeriodicSync();
      syncAll()
          .then((_) => pullAllDataForMaktab(maktabId))
          .then((_) => printDiagnosticSummary())
          .catchError((_) => false);
    });
  }

  /// Call this when the app resumes from background to force an immediate re-sync.
  void onAppResumed() {
    final mId = _activeMaktabId;
    if (mId == null || mId.isEmpty || !isAuthValid) return;
    // Restart realtime listeners in case they dropped while backgrounded
    startRealtimeSync(mId);
    // Immediately push local changes before pulling latest cloud data
    syncAll()
        .then((_) => pullAllDataForMaktab(mId))
        .then((_) => printDiagnosticSummary())
        .catchError((_) => false);
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_periodicSyncInProgress || !isAuthValid) return;
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
          } catch (e, st) {
            debugPrint('[CloudSync] getMaktabId discovery error: $e\n$st');
          }
        }
        maktabId ??= 'MAKTAB-001';
        await prefs.setString('maktab_id', maktabId);
      }
      return maktabId;
    } catch (e, st) {
      debugPrint('[CloudSync] getMaktabId error: $e\n$st');
      return 'MAKTAB-001';
    }
  }

  Future<void> setMaktabId(String maktabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('maktab_id', maktabId);
    } catch (e, st) {
      debugPrint('[CloudSync] setMaktabId error: $e\n$st');
    }
  }

  // ── Firebase Granular Realtime Listeners ─────────────────────────────────

  void startRealtimeSync(String maktabId) {
    stopRealtimeSync();
    if (!isAuthValid) {
      if (kDebugMode) debugPrint('[CloudSyncService] startRealtimeSync deferred: No authenticated non-anonymous Firebase user.');
      return;
    }
    final db = _db;
    if (db == null) return;

    final collections = _activeCollections;

    for (var col in collections) {
      final path = 'maktabs/$maktabId/$col';
      try {
        final sub = db.ref(path).onValue.listen((event) async {
          if (!event.snapshot.exists || event.snapshot.value == null) return;
          try {
            final data = _normalizeRtdbSnapshotValue(event.snapshot.value);
            await _mergeCollectionToSQLite(col, data);
          } catch (e) {
            debugPrint('Firebase Granular Sync error on $col: $e');
          }
        }, onError: (Object error) {
          debugPrint('[RTDB ERROR] path=$path uid=${fb_auth.FirebaseAuth.instance.currentUser?.uid} email=${fb_auth.FirebaseAuth.instance.currentUser?.email} error=$error');
        }, cancelOnError: false);
        _childSubscriptions.add(sub);
      } catch (e, st) {
        debugPrint('[CloudSync] startRealtimeSync subscription error on $col: $e\n$st');
      }
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
          } catch (e, st) {
            debugPrint('[CloudSync] _mergeCollectionToSQLite delete seeded students error: $e\n$st');
          }
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
        } catch (e, st) {
          debugPrint('[CloudSync] _mergeCollectionToSQLite fail-safe auto-relink error: $e\n$st');
        }
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
            item['id'] ??= int.tryParse(entry.key.toString().split('_').last);
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

  /// Retry set helper with exponential backoff (timeout up to 15s).
  Future<bool> _retrySet(DatabaseReference ref, Map<String, dynamic> map, {int maxAttempts = 3}) async {
    int delayMs = 1000;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await ref.set(map).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('RTDB set timed out on attempt $attempt for ${ref.path}'),
        );
        return true;
      } catch (e) {
        if (attempt == maxAttempts) {
          debugPrint('[CloudSyncService] _retrySet failed after $maxAttempts attempts at ${ref.path}: $e');
          return false;
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }
    return false;
  }

  Future<void> pushUser(User user) async {
    try {
      final maktabId = await getMaktabId();
      final id = user.id ?? DateTime.now().millisecondsSinceEpoch;
      await _db?.ref('maktabs/$maktabId/teachers/$id').set(user.toMap());
    } catch (e) {
      debugPrint('Firebase pushUser error: $e');
    }
  }

  Future<bool> pushBatch(Batch batch) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = batch.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = batch.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushBatch: No authenticated Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/batches/$id';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);

      // Batches write verification
      try {
        final verifySnap = await db.ref(path).get().timeout(const Duration(seconds: 4));
        debugPrint('[WRITE VERIFICATION] collection=batches path=$path exists=${verifySnap.exists} isNull=${verifySnap.value == null} matches=${verifySnap.exists && verifySnap.value != null}');
      } catch (e, st) {
        debugPrint('[WRITE VERIFICATION ERROR] collection=batches path=$path error=$e\n$st');
      }
      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        recordWrite('maktabs/$maktabId/batches/$id', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushBatch error: $e');
      return false;
    }
  }

  Future<bool> pushStudent(Student student) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = student.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = student.toMap();
      map['id'] ??= id;

      try {
        final sqliteDb = await DatabaseHelper.instance.database;
        final batchRows = await sqliteDb.query('batches', where: 'id = ?', whereArgs: [student.batchId]);
        if (batchRows.isNotEmpty) {
          map['batch_name'] = batchRows.first['name'];
        }
      } catch (e, st) {
        debugPrint('[CloudSync] pushStudent batch lookup error: $e\n$st');
      }

      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushStudent: No authenticated Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/students/$id';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);

      // Manager write verification
      try {
        final verifySnap = await db.ref(path).get().timeout(const Duration(seconds: 4));
        debugPrint('[WRITE VERIFICATION] collection=students path=$path exists=${verifySnap.exists} isNull=${verifySnap.value == null} matches=${verifySnap.exists && verifySnap.value != null}');
      } catch (e, st) {
        debugPrint('[WRITE VERIFICATION ERROR] collection=students path=$path error=$e\n$st');
      }

      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        recordWrite('maktabs/$maktabId/students/$id', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushStudent error: $e | UID: ${fb_auth.FirebaseAuth.instance.currentUser?.uid}');
      return false;
    }
  }

  Future<bool> pushAttendance(Attendance attendance) async {
    String? maktabId;
    String? key;
    try {
      maktabId = await getMaktabId();
      key = '${attendance.studentId}_${attendance.date}';
      final map = attendance.toMap();
      map['id'] ??= attendance.id ?? DateTime.now().millisecondsSinceEpoch;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushAttendance: No authenticated Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/attendance/$key';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);

      // Attendance write verification
      try {
        final verifySnap = await db.ref(path).get().timeout(const Duration(seconds: 4));
        debugPrint('[WRITE VERIFICATION] collection=attendance path=$path exists=${verifySnap.exists} isNull=${verifySnap.value == null} matches=${verifySnap.exists && verifySnap.value != null}');
      } catch (e, st) {
        debugPrint('[WRITE VERIFICATION ERROR] collection=attendance path=$path error=$e\n$st');
      }

      return true;
    } catch (e) {
      if (maktabId != null && key != null) {
        recordWrite('maktabs/$maktabId/attendance/$key', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushAttendance error: $e | Path: maktabs/$maktabId/attendance/$key | UID: ${fb_auth.FirebaseAuth.instance.currentUser?.uid}');
      return false;
    }
  }

  Future<bool> pushTeacherAttendance(TeacherAttendance ta) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = ta.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = ta.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushTeacherAttendance: No authenticated Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/teacher_attendance/$id';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);
      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        recordWrite('maktabs/$maktabId/teacher_attendance/$id', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushTeacherAttendance error: $e');
      return false;
    }
  }

  Future<bool> pushQuranProgress(QuranProgress qp) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = qp.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = qp.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushQuranProgress: No authenticated Firebase user.');
        return false;
      }

      final rtdbKey = '${qp.studentId}_${qp.date}_$id';
      final path = 'maktabs/$maktabId/quran_progress/$rtdbKey';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);
      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        final rtdbKey = '${qp.studentId}_${qp.date}_$id';
        recordWrite('maktabs/$maktabId/quran_progress/$rtdbKey', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushQuranProgress error: $e');
      return false;
    }
  }

  Future<bool> pushFeePayment(FeePayment fee) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = fee.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = fee.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (kDebugMode) debugPrint('[CloudSyncService] Gated pushFeePayment: No authenticated Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/fee_payments/$id';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);
      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        recordWrite('maktabs/$maktabId/fee_payments/$id', false, e);
      }
      if (kDebugMode) debugPrint('[CloudSyncService] pushFeePayment error: $e');
      return false;
    }
  }

  Future<bool> pushSalaryPayment(SalaryPayment sp) async {
    String? maktabId;
    int? id;
    try {
      maktabId = await getMaktabId();
      id = sp.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = sp.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('pushSalaryPayment skipped: No authenticated non-anonymous Firebase user.');
        return false;
      }

      final path = 'maktabs/$maktabId/salary_payments/$id';
      final ok = await _retrySet(db.ref(path), map);
      if (!ok) {
        recordWrite(path, false, 'Failed after retries');
        return false;
      }
      recordWrite(path, true);
      return true;
    } catch (e) {
      if (maktabId != null && id != null) {
        recordWrite('maktabs/$maktabId/salary_payments/$id', false, e);
      }
      debugPrint('Firebase pushSalaryPayment error: $e');
      return false;
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
      // Also delete /users/{uid} if we know the uid. Query RTDB for teachers, find the one with teacherId == X:
      final teacherSnap = await _db?.ref('maktabs/$maktabId/teachers').get();
      if (teacherSnap?.value is Map) {
        final map = teacherSnap!.value as Map;
        for (final entry in map.entries) {
          final node = entry.value;
          if (node is Map && (node['teacherId'] == id || entry.key == id.toString())) {
            final uid = node['uid'];
            if (uid != null) {
              await _db?.ref('users/$uid').remove();
            }
          }
        }
      }
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

  Future<void> deleteQuranProgressCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/quran_progress/$id').remove();
      final snap = await _db?.ref('maktabs/$maktabId/quran_progress').get();
      if (snap?.value is Map) {
        final map = snap!.value as Map;
        for (final entry in map.entries) {
          if (entry.key == id.toString() || entry.key.toString().endsWith('_$id')) {
            await _db?.ref('maktabs/$maktabId/quran_progress/${entry.key}').remove();
          }
        }
      }
      notifyDataChanged('quran_progress');
    } catch (e) {
      debugPrint('[CloudSync] deleteQuranProgressCloud error: $e');
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

      final unSyncedBatches = await db.query('batches', where: 'is_synced = 0');
      for (var bRow in unSyncedBatches) {
        final b = Batch.fromMap(bRow);
        final pushOk = await pushBatch(b);
        if (pushOk && b.id != null) {
          await db.update('batches', {'is_synced': 1}, where: 'id = ?', whereArgs: [b.id]);
        }
      }

      final unSyncedQuran = await db.query('quran_progress', where: 'is_synced = 0');
      for (var qRow in unSyncedQuran) {
        final qp = QuranProgress.fromMap(qRow);
        final pushOk = await pushQuranProgress(qp);
        if (pushOk && qp.id != null) {
          await db.update('quran_progress', {'is_synced': 1}, where: 'id = ?', whereArgs: [qp.id]);
        }
      }

      final unSyncedTeacherAtt = await db.query('teacher_attendance', where: 'is_synced = 0');
      for (var taRow in unSyncedTeacherAtt) {
        final ta = TeacherAttendance.fromMap(taRow);
        final pushOk = await pushTeacherAttendance(ta);
        if (pushOk && ta.id != null) {
          await db.update('teacher_attendance', {'is_synced': 1}, where: 'id = ?', whereArgs: [ta.id]);
        }
      }

      final unSyncedSalary = await db.query('salary_payments', where: 'is_synced = 0');
      for (var spRow in unSyncedSalary) {
        final sp = SalaryPayment.fromMap(spRow);
        final pushOk = await pushSalaryPayment(sp);
        if (pushOk && sp.id != null) {
          await db.update('salary_payments', {'is_synced': 1}, where: 'id = ?', whereArgs: [sp.id]);
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

  Future<bool> pullAllDataForMaktab(String maktabId) {
    return _activePullFuture ??= _doPullAllDataForMaktab(maktabId).whenComplete(() {
      _activePullFuture = null;
    });
  }

  Future<bool> _doPullAllDataForMaktab(String maktabId) async {
    try {
      final db = _db;
      if (db == null) return false;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[PULL] deferred — no auth user');
        return false;
      }
      final userSnap = await db.ref('users/${user.uid}').get().timeout(const Duration(seconds: 8));
      if (!userSnap.exists || userSnap.value == null) {
        debugPrint('[PULL] deferred — /users/${user.uid} missing');
        return false;
      }
      final rawProfile = userSnap.value;
      if (rawProfile is! Map) {
        debugPrint('[PULL] deferred — /users/${user.uid} invalid format');
        return false;
      }
      final profile = rawProfile;
      if (profile['active'] != true) {
        debugPrint('[PULL] deferred — user inactive');
        return false;
      }
      if (profile['maktabId'] != maktabId) {
        debugPrint('[PULL] deferred — maktabId mismatch: ${profile['maktabId']} vs $maktabId');
        return false;
      }
      if (_currentRole == null && profile['role'] != null) {
        setCurrentRole(profile['role'].toString());
      }

      final collections = _activeCollections;

      final pulledCollections = <String>[];
      final failedCollections = <String>[];

      for (var col in collections) {
        try {
          final snapshot = await db.ref('maktabs/$maktabId/$col').get().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('pull $col timed out'),
          );
          if (snapshot.exists && snapshot.value != null) {
            final data = _normalizeRtdbSnapshotValue(snapshot.value);
            await _mergeCollectionToSQLite(col, data);
            pulledCollections.add(col);
          }
        } catch (e) {
          failedCollections.add(col);
        }
      }

      debugPrint(
        '[PULL] maktab=$maktabId collections=${pulledCollections.join(",")} failures=${failedCollections.join(",")}',
      );

      bool anyPulled = pulledCollections.isNotEmpty;

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
        } catch (e, st) {
          debugPrint('[CloudSync] pullAllDataForMaktab fallback error: $e\n$st');
        }
      }

      return anyPulled;
    } catch (e) {
      debugPrint('CloudSyncService pullAllDataForMaktab error: $e');
      return false;
    }
  }

  Future<String> getDiagnosticSummary() async {
    final buffer = StringBuffer();
    final now = DateTime.now().toIso8601String();
    final localMaktabId = await getMaktabId();
    final bytes = utf8.encode(localMaktabId);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final user = fb_auth.FirebaseAuth.instance.currentUser;

    buffer.writeln('=== SYNC DIAGNOSTIC SUMMARY ===');
    buffer.writeln('Timestamp: $now');
    buffer.writeln('App version: 1.0.0');
    buffer.writeln('MaktabId (local): "$localMaktabId" (len=${localMaktabId.length}, hex=$hex)');
    buffer.writeln('');
    buffer.writeln('[Auth]');
    buffer.writeln('  currentUser: ${user?.uid}');
    buffer.writeln('  email: ${user?.email}');
    buffer.writeln('  isAnonymous: ${user?.isAnonymous}');
    buffer.writeln('  isEmailVerified: ${user?.emailVerified}');
    buffer.writeln('');
    buffer.writeln('[RTDB Probe]');
    final db = _db;
    if (db != null) {
      if (user?.uid != null) {
        try {
          final uSnap = await db.ref('users/${user!.uid}').get().timeout(const Duration(seconds: 4));
          buffer.writeln('  /users/${user.uid} exists: ${uSnap.exists}');
          if (uSnap.exists && uSnap.value is Map) {
            final uMap = Map<String, dynamic>.from(uSnap.value as Map);
            buffer.writeln('  /users/${user.uid}.maktabId: "${uMap['maktabId']}"');
            buffer.writeln('  /users/${user.uid}.active: ${uMap['active']} (type: ${uMap['active'].runtimeType})');
            buffer.writeln('  /users/${user.uid}.role: "${uMap['role']}"');
          }
        } catch (e) {
          buffer.writeln('  /users/${user?.uid} error: $e');
        }
      } else {
        buffer.writeln('  /users/{uid}: Not checked (currentUser is null)');
      }

      final probeCols = ['students', 'attendance', 'batches', 'teachers'];
      for (final col in probeCols) {
        try {
          final snap = await db.ref('maktabs/$localMaktabId/$col').get().timeout(const Duration(seconds: 4));
          int count = 0;
          if (snap.exists && snap.value is Map) {
            count = (snap.value as Map).length;
          } else if (snap.exists && snap.value is List) {
            count = (snap.value as List).length;
          }
          buffer.writeln('  /maktabs/$localMaktabId/$col count: $count');
        } catch (e) {
          buffer.writeln('  /maktabs/$localMaktabId/$col error: $e');
        }
      }
    } else {
      buffer.writeln('  RTDB Database instance: NULL');
    }

    buffer.writeln('');
    buffer.writeln('[Last 10 Writes]');
    final lastWrites = _writeRingBuffer.reversed.take(10).toList().reversed.toList();
    if (lastWrites.isEmpty) {
      buffer.writeln('  No writes recorded yet.');
    } else {
      for (final w in lastWrites) {
        buffer.writeln('  ${w.toString()}');
      }
    }
    buffer.writeln('=== END SUMMARY ===');
    return buffer.toString();
  }

  Future<void> printDiagnosticSummary() async {
    try {
      final summary = await getDiagnosticSummary();
      debugPrint(summary);
    } catch (e) {
      debugPrint('[CloudSyncService] printDiagnosticSummary error: $e');
    }
  }

  Future<void> rerunProbe() async {
    final maktabId = await getMaktabId();
    await _runStartupPermissionProbe(maktabId);
  }
}
