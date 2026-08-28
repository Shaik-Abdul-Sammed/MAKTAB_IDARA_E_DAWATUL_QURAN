import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/services/database_helper.dart';

class DatabaseSeeder {
  static String _hashPin(String pin) {
    const salt = 'idara_maktab_sec_salt_2026';
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  static Future<void> seedDefaultData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Seed Manager Profile: K. ABDUL RAWOOF
      final managerMaps = await db.query(
        'users',
        where: 'role IN (?, ?)',
        whereArgs: ['admin', 'manager'],
      );

      if (managerMaps.isEmpty) {
        final legacyHash = sha256.convert(utf8.encode('1234')).toString();
        final manager = User(
          name: 'K. ABDUL RAWOOF',
          mobile: '9030983012',
          pinHash: legacyHash,
          role: 'admin',
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        );
        await db.insert('users', manager.toMap());
        debugPrint('Seeded Manager: K. ABDUL RAWOOF');
      } else {
        // Update manager name and mobile if existing
        await db.rawUpdate(
          'UPDATE users SET name = ?, mobile = ? WHERE role IN (?, ?)',
          ['K. ABDUL RAWOOF', '9030983012', 'admin', 'manager'],
        );
      }

      // 2. Seed Default Teachers
      final defaultTeachers = [
        User(
          id: 2018,
          name: 'SHAIK MOHAMMAD MAHABOOB SHAREEF',
          mobile: '9177024433',
          pinHash: _hashPin('123456'),
          role: 'teacher',
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
        User(
          id: 20261,
          name: 'MOULANA ABDUL WAHEED',
          mobile: '8790507120',
          pinHash: _hashPin('123456'),
          role: 'teacher',
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
        User(
          id: 20262,
          name: 'MOULANA YAQOOB BAIG',
          mobile: '6309987430',
          pinHash: _hashPin('123456'),
          role: 'teacher',
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];

      for (final t in defaultTeachers) {
        final existing = await db.query('users', where: 'id = ?', whereArgs: [t.id]);
        if (existing.isEmpty) {
          await db.insert('users', t.toMap());
        } else {
          await db.update('users', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
        }
      }

      // 3. Seed Default Sections / Batches with exact assigned teachers
      final defaultBatches = [
        {
          'id': 1,
          'name': 'SECTION G1',
          'timing': 'ASAR TO MAGRIB',
          'teacher_id': 2018,
        },
        {
          'id': 2,
          'name': 'SECTION B1',
          'timing': 'ASAR TO MAGRIB',
          'teacher_id': 20261,
        },
        {
          'id': 3,
          'name': 'SECTION B2',
          'timing': 'ASAR TO MAGRIB',
          'teacher_id': 20262,
        },
        {
          'id': 4,
          'name': 'SECTION B3',
          'timing': 'MAGRIB TO ISHA',
          'teacher_id': 20262,
        },
        {
          'id': 5,
          'name': 'BALIGAAN SECTION',
          'timing': 'AFTER ISHA 8:30 TO 9:30',
          'teacher_id': 2018,
        },
      ];

      for (final b in defaultBatches) {
        final existing = await db.query('batches', where: 'id = ?', whereArgs: [b['id']]);
        if (existing.isEmpty) {
          await db.insert('batches', b);
        } else {
          await db.update('batches', b, where: 'id = ?', whereArgs: [b['id']]);
        }
      }

      debugPrint('Database default seeding complete for IDARA E DAWATHUL QURAAN.');
    } catch (e) {
      debugPrint('Error seeding default database: $e');
    }
  }
}
