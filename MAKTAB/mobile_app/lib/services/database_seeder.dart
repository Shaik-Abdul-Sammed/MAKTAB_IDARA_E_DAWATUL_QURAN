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

      // 4. Seed Default Students if students table is empty
      final existingStudents = await db.query('students', where: 'is_deleted IS NULL OR is_deleted = 0');
      if (existingStudents.isEmpty) {
        final defaultStudents = [
          {
            'id': 101,
            'admission_number': 'ADM-2026-001',
            'name': 'FATIMA BEGUM',
            'arabic_name': 'فاطمة بيغم',
            'father_name': 'Mohammed Ali',
            'phone': '9876543210',
            'guardian_name': 'Mohammed Ali',
            'guardian_phone': '9876543210',
            'batch_id': 1,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 102,
            'admission_number': 'ADM-2026-002',
            'name': 'AISHA SIDDIQUA',
            'arabic_name': 'عائشة صديقة',
            'father_name': 'Syed Ibrahim',
            'phone': '9876543211',
            'guardian_name': 'Syed Ibrahim',
            'guardian_phone': '9876543211',
            'batch_id': 1,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 103,
            'admission_number': 'ADM-2026-003',
            'name': 'MOHAMMED OMAR',
            'arabic_name': 'محمد عمر',
            'father_name': 'Mohammed Abdul',
            'phone': '9876543212',
            'guardian_name': 'Mohammed Abdul',
            'guardian_phone': '9876543212',
            'batch_id': 2,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 104,
            'admission_number': 'ADM-2026-004',
            'name': 'MOHAMMED ZAID',
            'arabic_name': 'محمد زيد',
            'father_name': 'Tariq Ahmed',
            'phone': '9876543213',
            'guardian_name': 'Tariq Ahmed',
            'guardian_phone': '9876543213',
            'batch_id': 2,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 105,
            'admission_number': 'ADM-2026-005',
            'name': 'SYED BILAL',
            'arabic_name': 'سيد بلال',
            'father_name': 'Syed Usman',
            'phone': '9876543214',
            'guardian_name': 'Syed Usman',
            'guardian_phone': '9876543214',
            'batch_id': 3,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 106,
            'admission_number': 'ADM-2026-006',
            'name': 'ABDUL REHMAN',
            'arabic_name': 'عبد الرحمن',
            'father_name': 'Abdul Kareem',
            'phone': '9876543215',
            'guardian_name': 'Abdul Kareem',
            'guardian_phone': '9876543215',
            'batch_id': 3,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 107,
            'admission_number': 'ADM-2026-007',
            'name': 'MOHAMMED YUSUF',
            'arabic_name': 'محمد يوسف',
            'father_name': 'Mohammed Younus',
            'phone': '9876543216',
            'guardian_name': 'Mohammed Younus',
            'guardian_phone': '9876543216',
            'batch_id': 4,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 108,
            'admission_number': 'ADM-2026-008',
            'name': 'HASSAN ALI',
            'arabic_name': 'حسن علي',
            'father_name': 'Akbar Ali',
            'phone': '9876543217',
            'guardian_name': 'Akbar Ali',
            'guardian_phone': '9876543217',
            'batch_id': 4,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 109,
            'admission_number': 'ADM-2026-009',
            'name': 'SHAHEED AHMED',
            'arabic_name': 'شهيد أحمد',
            'father_name': 'Rasheed Ahmed',
            'phone': '9876543218',
            'guardian_name': 'Rasheed Ahmed',
            'guardian_phone': '9876543218',
            'batch_id': 5,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
          {
            'id': 110,
            'admission_number': 'ADM-2026-010',
            'name': 'IBRAHIM KHALIL',
            'arabic_name': 'إبراهيم خليل',
            'father_name': 'Ismail Khalil',
            'phone': '9876543219',
            'guardian_name': 'Ismail Khalil',
            'guardian_phone': '9876543219',
            'batch_id': 5,
            'created_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          },
        ];

        for (final s in defaultStudents) {
          await db.insert('students', s);
        }
        debugPrint('Seeded 10 default students across all batches.');
      }

      debugPrint('Database default seeding complete for IDARA E DAWATHUL QURAAN.');
    } catch (e) {
      debugPrint('Error seeding default database: $e');
    }
  }
}
