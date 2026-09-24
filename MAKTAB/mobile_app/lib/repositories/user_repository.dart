import 'package:flutter/foundation.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/database_seeder.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> initializeDefaultAdmin() async {
    await DatabaseSeeder.seedDefaultData();
  }

  Future<User?> authenticateUser(String pinHash) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'pin_hash = ? AND is_active = 1',
      whereArgs: [pinHash],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertUser(User user) async {
    final db = await _dbHelper.database;
    final id = await db.insert('users', user.toMap());
    final createdUser = user.copyWith(id: id);
    await CloudSyncService.instance.pushUser(createdUser);
    CloudSyncService.instance.notifyDataChanged('teachers');
    return id;
  }

  Future<List<User>> getAllTeachers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['teacher'],
    );
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<User?> getUserById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getAdminUser() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getManager() async => getAdminUser();

  /// Updates a user's PIN hash. The [newPinHash] must already be hashed
  /// by the caller (e.g. AuthProvider._hashPin). Storing as-is prevents double-hashing.
  Future<int> updateUserPin(int userId, String newPinHash) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'users',
      {'pin_hash': newPinHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
    final user = await getUserById(userId);
    if (user != null) {
      await CloudSyncService.instance.pushUser(user);
    }
    CloudSyncService.instance.notifyDataChanged('teachers');
    return res;
  }

  /// Registers the first real admin user, replacing the default placeholder.
  /// [pin] must already be hashed by the caller (AuthProvider._hashPin).
  Future<bool> registerFirstUser({
    required String name,
    required String mobile,
    required String pin, // pre-hashed by AuthProvider
    required String dob,
  }) async {
    final db = await _dbHelper.database;
    // Remove any existing default admin first to ensure a clean state
    await db.delete('users', where: 'role = ?', whereArgs: ['admin']);

    User newAdmin = User(
      name: name,
      pinHash: pin, // already hashed — store as-is
      role: 'admin',
      mobile: mobile,
      dob: dob,
      createdAt: DateTime.now().toIso8601String(),
    );
    final id = await db.insert('users', newAdmin.toMap());
    if (id > 0) {
      final createdAdmin = newAdmin.copyWith(id: id);
      final maktabId = 'MAKTAB-$mobile';
      await CloudSyncService.instance.setMaktabId(maktabId);
      await CloudSyncService.instance.pushUser(createdAdmin);
      CloudSyncService.instance.notifyDataChanged('teachers');
      return true;
    }
    return false;
  }

  Future<bool> hasRegisteredAdmin() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ? AND mobile IS NOT NULL AND mobile != ? AND name != ?',
      whereArgs: ['admin', '9030983012', 'Super Admin'],
    );
    return maps.isNotEmpty;
  }

  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;

    // Step 1 — Orphan students in the teacher's batches (SQLite):
    await db.rawUpdate('''
      UPDATE students SET batch_id = NULL
      WHERE batch_id IN (SELECT id FROM batches WHERE teacher_id = ?)
    ''', [id]);
    debugPrint('[DELETE-TEACHER] Orphaned students from teacher $id batches');

    // Step 2 — Orphan teacher_id on the batches (SQLite):
    await db.update('batches', {'teacher_id': null}, where: 'teacher_id = ?', whereArgs: [id]);

    // Step 3 — Push the orphans to RTDB so other devices see the change:
    final orphanedStudents = await db.query('students', where: 'batch_id IS NULL AND is_synced = 1');
    for (final s in orphanedStudents) {
      await CloudSyncService.instance.pushStudent(Student.fromMap(s));
    }
    final orphanedBatches = await db.query('batches', where: 'teacher_id IS NULL AND is_synced = 1');
    for (final b in orphanedBatches) {
      await CloudSyncService.instance.pushBatch(Batch.fromMap(b));
    }

    // Step 4 — Delete the SQLite users row. (Existing behavior.)
    final res = await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Step 5 — Delete RTDB nodes:
    await CloudSyncService.instance.deleteTeacherCloud(id);

    // Step 6 — Firebase Auth account: The client SDK cannot delete another user's Auth account. Add an explicit log:
    debugPrint('[DELETE-TEACHER] Firebase Auth account for teacher $id not deleted — requires Cloud Function with Admin SDK. Account remains orphaned.');

    CloudSyncService.instance.notifyDataChanged('teachers');
    return res;
  }

  Future<int> updateUser(User user) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await CloudSyncService.instance.pushUser(user);
    CloudSyncService.instance.notifyDataChanged('teachers');
    return res;
  }
}
