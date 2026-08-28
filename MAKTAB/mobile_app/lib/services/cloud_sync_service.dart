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

  Stream<String> get onDataSynced => _syncController.stream;

  void notifyDataChanged(String collection) {
    if (!_syncController.isClosed) {
      _syncController.add(collection);
    }
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
              if (snapshot.exists && snapshot.value != null) {
                maktabId = snapshot.value.toString();
                await prefs.setString('maktab_id', maktabId);
                return maktabId;
              }
            }
          } catch (_) {}
        }
        maktabId = 'MAKTAB-001';
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
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
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

  Future<void> _mergeCollectionToSQLite(String collection, Map<String, dynamic> colData) async {
    final db = await DatabaseHelper.instance.database;

    switch (collection) {
      case 'batches':
        for (var entry in colData.entries) {
          try {
            final item = Map<String, dynamic>.from(entry.value as Map);
            item['id'] ??= int.tryParse(entry.key.toString());
            final b = Batch.fromMap(item);
            await db.insert('batches', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging batch ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'students':
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
            final item = Map<String, dynamic>.from(entry.value as Map);
            item['id'] ??= int.tryParse(entry.key.toString());
            final s = Student.fromMap(item);
            var map = s.toMap();

            int? resolvedBatchId = map['batch_id'] as int?;
            if (resolvedBatchId != null && batchMap.containsKey(resolvedBatchId)) {
              map['batch_id'] = batchMap[resolvedBatchId];
            } else if (item['batch_name'] != null || item['batch'] != null) {
              final rawName = (item['batch_name'] ?? (item['batch'] is Map ? item['batch']['name'] : item['batch']))?.toString().toLowerCase();
              if (rawName != null && batchNameMap.containsKey(rawName)) {
                map['batch_id'] = batchNameMap[rawName];
              }
            }
            if (localBatches.isNotEmpty) {
              map['batch_id'] ??= localBatches.first['id'];
            }
            map['batch_id'] ??= 1;

            await db.insert('students', map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging student ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'teachers':
        for (var entry in colData.entries) {
          try {
            final item = Map<String, dynamic>.from(entry.value as Map);
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
            final item = Map<String, dynamic>.from(entry.value as Map);
            item['id'] ??= int.tryParse(entry.key.toString());
            final a = Attendance.fromMap(item);
            await db.insert('attendance', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            debugPrint('Error merging attendance ${entry.key} to SQLite: $e');
          }
        }
        break;

      case 'teacher_attendance':
        for (var entry in colData.entries) {
          try {
            final item = Map<String, dynamic>.from(entry.value as Map);
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
            final item = Map<String, dynamic>.from(entry.value as Map);
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
            final item = Map<String, dynamic>.from(entry.value as Map);
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
            final item = Map<String, dynamic>.from(entry.value as Map);
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

  Future<void> pushStudent(Student student) async {
    try {
      final maktabId = await getMaktabId();
      final id = student.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = student.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

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
    } catch (e) {
      debugPrint('Firebase pushStudent error: $e');
    }
  }

  Future<void> pushAttendance(Attendance attendance) async {
    try {
      final maktabId = await getMaktabId();
      final id = attendance.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = attendance.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      await db.ref('maktabs/$maktabId/attendance/$id').set(map).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('pushAttendance timed out'),
      );
    } catch (e) {
      debugPrint('Firebase pushAttendance error: $e');
      rethrow;
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

  Future<void> pushFeePayment(FeePayment fee) async {
    try {
      final maktabId = await getMaktabId();
      final id = fee.id ?? DateTime.now().millisecondsSinceEpoch;
      final map = fee.toMap();
      map['id'] ??= id;
      final db = _db;
      if (db == null) return;

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
    } catch (e) {
      debugPrint('Firebase pushFeePayment error: $e');
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

  Future<void> deleteSalaryPaymentCloud(int id) async {
    try {
      final maktabId = await getMaktabId();
      await _db?.ref('maktabs/$maktabId/salary_payments/$id').remove();
    } catch (e) {
      debugPrint('Firebase deleteSalaryPaymentCloud error: $e');
    }
  }

  // ── Sync All Offline SQLite Records ────────────────────────────────────────

  Future<bool> syncAll() async {
    try {
      final maktabId = await getMaktabId();
      final db = await DatabaseHelper.instance.database;

      final users = (await db.query('users')).map((e) => User.fromMap(e)).toList();
      final batches = (await db.query('batches')).map((e) => Batch.fromMap(e)).toList();
      final students = (await db.query('students')).map((e) => Student.fromMap(e)).toList();
      final attendance = (await db.query('attendance')).map((e) => Attendance.fromMap(e)).toList();
      final taList = (await db.query('teacher_attendance')).map((e) => TeacherAttendance.fromMap(e)).toList();
      final qpList = (await db.query('quran_progress')).map((e) => QuranProgress.fromMap(e)).toList();
      final feeList = (await db.query('fee_payments')).map((e) => FeePayment.fromMap(e)).toList();
      final salList = (await db.query('salary_payments')).map((e) => SalaryPayment.fromMap(e)).toList();

      for (var u in users) {
        if (u.id != null) await _db?.ref('maktabs/$maktabId/teachers/${u.id}').set(u.toMap());
      }
      for (var b in batches) {
        if (b.id != null) await _db?.ref('maktabs/$maktabId/batches/${b.id}').set(b.toMap());
      }
      for (var s in students) {
        if (s.id != null) await _db?.ref('maktabs/$maktabId/students/${s.id}').set(s.toMap());
      }
      for (var a in attendance) {
        if (a.id != null) await _db?.ref('maktabs/$maktabId/attendance/${a.id}').set(a.toMap());
      }
      for (var ta in taList) {
        if (ta.id != null) await _db?.ref('maktabs/$maktabId/teacher_attendance/${ta.id}').set(ta.toMap());
      }
      for (var qp in qpList) {
        if (qp.id != null) await _db?.ref('maktabs/$maktabId/quran_progress/${qp.id}').set(qp.toMap());
      }
      for (var f in feeList) {
        if (f.id != null) await _db?.ref('maktabs/$maktabId/fee_payments/${f.id}').set(f.toMap());
      }
      for (var sp in salList) {
        if (sp.id != null) await _db?.ref('maktabs/$maktabId/salary_payments/${sp.id}').set(sp.toMap());
      }

      // Start granular listening for changes in this Maktab
      startRealtimeSync(maktabId);

      return true;
    } catch (e) {
      debugPrint('CloudSyncService syncAll error: $e');
      return false;
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
            final data = Map<String, dynamic>.from(snapshot.value as Map);
            await _mergeCollectionToSQLite(col, data);
            anyPulled = true;
          }
        } catch (e) {
          debugPrint('CloudSyncService error pulling $col for maktab $maktabId: $e');
        }
      }

      startRealtimeSync(maktabId);
      return anyPulled;
    } catch (e) {
      debugPrint('CloudSyncService pullAllDataForMaktab error: $e');
      return false;
    }
  }
}
