import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:maktab_app/services/secure_env_service.dart';
import '../repositories/audit_repository.dart';
import '../utils/offline/queue_manager.dart';
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('maktab.db');
    return _database!;
  }
  
  Future<String> _getPlatformDatabasesPath() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      ffi.sqfliteFfiInit();
      return await ffi.databaseFactoryFfi.getDatabasesPath();
    }
    return await getDatabasesPath();
  }

  Future<String> get databasePath async {
    final dbPath = await _getPlatformDatabasesPath();
    return join(dbPath, 'maktab.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await _getPlatformDatabasesPath();
    final path = join(dbPath, filePath);
    final key = await SecureEnvService.getDatabaseEncryptionKey();

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      // SQLCipher is not supported on Linux/Windows by default, 
      // fallback to unencrypted FFI for desktop testing.
      return await ffi.databaseFactoryFfi.openDatabase(
        path,
        options: ffi.OpenDatabaseOptions(
          version: 9,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await _createDB(db, version);
          },
          onUpgrade: _onUpgrade,
        ),
      );
    }

    await _migrateToEncryptedIfNeeded(path, key);

    return await openDatabase(
      path,
      password: key,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _migrateToEncryptedIfNeeded(String path, String key) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final db = await openDatabase(path, password: key);
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      await db.close();
      return; 
    } catch (e) {
      try {
        final dbUnencrypted = await openDatabase(path); 
        await dbUnencrypted.rawQuery('SELECT count(*) FROM sqlite_master');
        
        debugPrint('Migrating unencrypted database to SQLCipher...');
        final encryptedPath = '$path.encrypted';
        
        await dbUnencrypted.execute("ATTACH DATABASE '$encryptedPath' AS encrypted KEY '$key'");
        await dbUnencrypted.execute("SELECT sqlcipher_export('encrypted')");
        await dbUnencrypted.execute("DETACH DATABASE encrypted");
        await dbUnencrypted.close();
        
        final encryptedFile = File(encryptedPath);
        await encryptedFile.copy(path);
        await encryptedFile.delete();
        debugPrint('Database migration to SQLCipher complete.');
      } catch (e2) {
        debugPrint('Migration failed or DB is corrupted: $e2');
      }
    }
  }

  Future _createDB(dynamic db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType = 'BOOLEAN NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const integerNullable = 'INTEGER';
    
    // Users Table (Admin & Teachers)
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        pin_hash $textType,
        role $textType,
        mobile $textNullable,
        photo_path $textNullable,
        dob $textNullable,
        is_active $boolType DEFAULT 1,
        created_at $textType
      )
    ''');

    // Students Table
    await db.execute('''
      CREATE TABLE students (
        id $idType,
        admission_number $textType,
        name $textType,
        arabic_name $textNullable,
        dob $textNullable,
        gender $textNullable,
        father_name $textNullable,
        phone $textNullable,
        guardian_name $textNullable,
        guardian_phone $textNullable,
        photo_path $textNullable,
        batch_id $integerType,
        created_at $textType,
        teacher_notes $textNullable,
        fees_amount $integerNullable,
        is_deleted $integerNullable DEFAULT 0,
        deleted_at $textNullable
      )
    ''');
    await db.execute('CREATE INDEX idx_stu_batch ON students(batch_id)');


    // Batches Table
    await db.execute('''
      CREATE TABLE batches (
        id $idType,
        name $textType,
        timing $textType,
        teacher_id $integerNullable,
        FOREIGN KEY (teacher_id) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');

    // Fee Payments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fee_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        mode TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        voice_note_path TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');


    // Attendance Table
    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        student_id $integerType,
        date $textType,
        status $textType,
        remarks $textNullable,
        time $textNullable,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_att_date ON attendance(date)');
    await db.execute('CREATE INDEX idx_att_student_date ON attendance(student_id, date)');

    // Teacher Attendance Table
    await db.execute('''
      CREATE TABLE teacher_attendance (
        id $idType,
        teacher_id $integerType,
        date $textType,
        status $textType,
        remarks $textNullable,
        marked_by $integerNullable,
        time $textNullable,
        FOREIGN KEY (teacher_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_teach_att_date ON teacher_attendance(date)');
    await db.execute('CREATE INDEX idx_teach_att_teacher_date ON teacher_attendance(teacher_id, date)');

    // Quran Progress Table
    await db.execute('''
      CREATE TABLE quran_progress (
        id $idType,
        student_id $integerType,
        date $textType,
        surah $textType,
        ayah_from $integerType,
        ayah_to $integerType,
        grade $textType,
        remarks $textNullable,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_qp_student_date ON quran_progress(student_id, date)');

    // Teacher Profiles Table
    await db.execute('''
      CREATE TABLE teacher_profiles (
        id $idType,
        user_id $integerType,
        photo_path $textNullable,
        qualification $textNullable,
        experience $textNullable,
        subjects $textNullable,
        remarks $textNullable,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await AuditRepository.createTable(db);
        await db.execute('''
          CREATE TABLE behavior_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            teacher_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            incident TEXT NOT NULL,
            action_taken TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE announcements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL,
            batch_id INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE syllabus_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT NOT NULL,
            description TEXT NOT NULL,
            batch_id INTEGER NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE checklist_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            category TEXT NOT NULL,
            is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE checklist_submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            batch_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            answers_json TEXT NOT NULL,
            remarks TEXT
          )
        ''');
    await QueueManager.createTable(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id $idType,
        sender_id $integerType,
        receiver_id $integerNullable,
        content $textType,
        timestamp $textType,
        is_read $boolType DEFAULT 0,
        FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_msg_sender ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_msg_receiver ON messages(receiver_id)');

    // Password Vault Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS password_vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        username TEXT,
        password TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'General',
        url TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    try {
      await db.execute('ALTER TABLE students ADD COLUMN is_deleted INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE students ADD COLUMN deleted_at TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE attendance ADD COLUMN time TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE teacher_attendance ADD COLUMN time TEXT');
    } catch (_) {}
    // v9: password vault table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS password_vault (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label TEXT NOT NULL,
          username TEXT,
          password TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'General',
          url TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN voice_note_path TEXT');
      } catch (_) {}
    }

    // ── v6 → v7 ──────────────────────────────────────────────────────────────
    if (oldVersion < 7) {
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS fee_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          mode TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
        ''');
      } catch (_) {}
    }

    // ── v5 → v6 ──────────────────────────────────────────────────────────────
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN fees_amount INTEGER');
      } catch (_) {}
    }

    // ── v1 → v2 ──────────────────────────────────────────────────────────────
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN photo_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE students ADD COLUMN photo_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE students ADD COLUMN guardian_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE students ADD COLUMN guardian_phone TEXT');
      } catch (_) {}

      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textNullable = 'TEXT';
      const integerType = 'INTEGER NOT NULL';
      const integerNullable = 'INTEGER';
      const textType = 'TEXT NOT NULL';

      try {
        await db.execute('''
          CREATE TABLE teacher_attendance (
            id $idType,
            teacher_id $integerType,
            date $textType,
            status $textType,
            remarks $textNullable,
            marked_by $integerNullable,
            FOREIGN KEY (teacher_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_teach_att_date ON teacher_attendance(date)');
        await db.execute('CREATE INDEX idx_teach_att_teacher_date ON teacher_attendance(teacher_id, date)');
      } catch (_) {}
    }

    // ── v2 → v3: teacher_notes for private remarks ────────────────────────────
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE students ADD COLUMN teacher_notes TEXT');
      } catch (_) {}
      
      try {
        await AuditRepository.createTable(db);
        await db.execute('''
          CREATE TABLE behavior_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            teacher_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            incident TEXT NOT NULL,
            action_taken TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE announcements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL,
            batch_id INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE syllabus_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT NOT NULL,
            description TEXT NOT NULL,
            batch_id INTEGER NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE checklist_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            category TEXT NOT NULL,
            is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE checklist_submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            batch_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            answers_json TEXT NOT NULL,
            remarks TEXT
          )
        ''');
      } catch (_) {}
      
      try {
        await QueueManager.createTable(db);
      } catch (_) {}
      
      try {
        const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
        const integerType = 'INTEGER NOT NULL';
        const textNullable = 'TEXT';
        await db.execute('''
          CREATE TABLE IF NOT EXISTS teacher_profiles (
            id $idType,
            user_id $integerType,
            photo_path $textNullable,
            qualification $textNullable,
            experience $textNullable,
            subjects $textNullable,
            remarks $textNullable,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
    }

    // ── v3 → v4: messages table ──────────────────────────────────────────────
    if (oldVersion < 4) {
      try {
        const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
        const integerType = 'INTEGER NOT NULL';
        const integerNullable = 'INTEGER';
        const textType = 'TEXT NOT NULL';
        const boolType = 'BOOLEAN NOT NULL';
        
        await db.execute('''
          CREATE TABLE IF NOT EXISTS messages (
            id $idType,
            sender_id $integerType,
            receiver_id $integerNullable,
            content $textType,
            timestamp $textType,
            is_read $boolType DEFAULT 0,
            FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_sender ON messages(sender_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_receiver ON messages(receiver_id)');
      } catch (_) {}
    }
    
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN dob TEXT');
      } catch (_) {}
    }
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
  Future<void> promoteStudents(List<int> studentIds, int newBatchId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (var id in studentIds) {
        await txn.update(
          'students',
          {'batch_id': newBatchId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
