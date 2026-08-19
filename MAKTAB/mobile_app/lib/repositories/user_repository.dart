import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> initializeDefaultAdmin() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    if (maps.isEmpty) {
      // Create a default admin with PIN '1234'
      User defaultAdmin = User(
        name: 'Super Admin',
        pinHash: _hashPin('1234'), 
        role: 'admin',
        createdAt: DateTime.now().toIso8601String(),
      );
      await db.insert('users', defaultAdmin.toMap());
    }
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
      return true;
    }
    return false;
  }

  Future<bool> hasRegisteredAdmin() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ? AND mobile IS NOT NULL',
      whereArgs: ['admin'],
    );
    return maps.isNotEmpty;
  }

  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateUser(User user) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
}
