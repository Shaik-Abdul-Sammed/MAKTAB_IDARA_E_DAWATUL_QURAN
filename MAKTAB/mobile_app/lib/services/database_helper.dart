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
          version: 24,
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
      version: 24,
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
        teacher_id $integerNullable,
        name $textType,
        pin_hash $textType,
        role $textType,
        mobile $textNullable,
        photo_path $textNullable,
        dob $textNullable,
        monthly_salary INTEGER DEFAULT 0,
        upi_id TEXT,
        preferred_payment_mode TEXT,
        is_active $boolType DEFAULT 1,
        created_at $textType,
        is_synced INTEGER DEFAULT 1
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
        deleted_at $textNullable,
        preferred_language TEXT DEFAULT 'en',
        is_synced INTEGER DEFAULT 1
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
        is_synced INTEGER DEFAULT 1
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
        receipt_sent INTEGER DEFAULT 0,
        receipt_sent_at TEXT,
        is_synced INTEGER DEFAULT 1
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
        time_period $textNullable,
        is_synced INTEGER DEFAULT 1
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
        time_period $textNullable,
        is_read INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_teach_att_date ON teacher_attendance(date)');
    await db.execute('CREATE INDEX idx_teach_att_teacher_date ON teacher_attendance(teacher_id, date)');

    // Quran Progress Table
    await db.execute('''
      CREATE TABLE quran_progress (
        id $idType,
        student_id $integerType,
        teacher_id $integerNullable,
        date $textType,
        surah $textType,
        ayah_from $integerType,
        ayah_to $integerType,
        grade $textType,
        recitation_type TEXT DEFAULT 'Sabaq',
        remarks $textNullable,
        is_synced INTEGER DEFAULT 1
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
        is_read $boolType DEFAULT 0
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

    // Salary Payments Table (v10)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS salary_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL,
        maktab_id TEXT NOT NULL,
        salary_month TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        upi_id_snapshot TEXT,
        transaction_reference TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        receipt_sent INTEGER DEFAULT 0,
        receipt_sent_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_teacher_month ON salary_payments(teacher_id, salary_month)');
  }

  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    if (oldVersion < 13) {
      const syncedTables = [
        'students',
        'attendance',
        'fee_payments',
        'batches',
        'users',
        'teacher_attendance',
        'quran_progress',
        'salary_payments',
      ];
      for (final table in syncedTables) {
        try {
          final columns = await db.rawQuery("PRAGMA table_info($table)");
          final hasIsSynced = columns.any((c) => c['name'] == 'is_synced');
          if (!hasIsSynced) {
            await db.execute("ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 1");
          }
        } catch (e) {
          debugPrint('Error ensuring is_synced on $table: $e');
        }
      }
    }

    if (oldVersion < 14) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const textNullable = 'TEXT';
      const integerType = 'INTEGER NOT NULL';
      const integerNullable = 'INTEGER';

      try {
        await db.execute('DROP TABLE IF EXISTS attendance_old');
        await db.execute('ALTER TABLE attendance RENAME TO attendance_old');
        await db.execute('''
          CREATE TABLE attendance (
            id $idType,
            student_id $integerType,
            date $textType,
            status $textType,
            remarks $textNullable,
            time $textNullable,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO attendance SELECT * FROM attendance_old');
        await db.execute('DROP TABLE attendance_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_att_date ON attendance(date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_att_student_date ON attendance(student_id, date)');
      } catch (e) {
        debugPrint('Error migrating attendance in v14: $e');
      }

      try {
        await db.execute('DROP TABLE IF EXISTS teacher_attendance_old');
        await db.execute('ALTER TABLE teacher_attendance RENAME TO teacher_attendance_old');
        await db.execute('''
          CREATE TABLE teacher_attendance (
            id $idType,
            teacher_id $integerType,
            date $textType,
            status $textType,
            remarks $textNullable,
            marked_by $integerNullable,
            time $textNullable,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO teacher_attendance SELECT * FROM teacher_attendance_old');
        await db.execute('DROP TABLE teacher_attendance_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_teach_att_date ON teacher_attendance(date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_teach_att_teacher_date ON teacher_attendance(teacher_id, date)');
      } catch (e) {
        debugPrint('Error migrating teacher_attendance in v14: $e');
      }

      try {
        await db.execute('DROP TABLE IF EXISTS quran_progress_old');
        await db.execute('ALTER TABLE quran_progress RENAME TO quran_progress_old');
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
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO quran_progress SELECT * FROM quran_progress_old');
        await db.execute('DROP TABLE quran_progress_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_qp_student_date ON quran_progress(student_id, date)');
      } catch (e) {
        debugPrint('Error migrating quran_progress in v14: $e');
      }

      try {
        await db.execute('DROP TABLE IF EXISTS fee_payments_old');
        await db.execute('ALTER TABLE fee_payments RENAME TO fee_payments_old');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fee_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            mode TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            notes TEXT,
            voice_note_path TEXT,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO fee_payments SELECT * FROM fee_payments_old');
        await db.execute('DROP TABLE fee_payments_old');
      } catch (e) {
        debugPrint('Error migrating fee_payments in v14: $e');
      }

      try {
        await db.execute('DROP TABLE IF EXISTS salary_payments_old');
        await db.execute('ALTER TABLE salary_payments RENAME TO salary_payments_old');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salary_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            maktab_id TEXT NOT NULL,
            salary_month TEXT NOT NULL,
            amount INTEGER NOT NULL,
            payment_date TEXT NOT NULL,
            payment_mode TEXT NOT NULL,
            upi_id_snapshot TEXT,
            transaction_reference TEXT,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO salary_payments SELECT * FROM salary_payments_old');
        await db.execute('DROP TABLE salary_payments_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_teacher_month ON salary_payments(teacher_id, salary_month)');
      } catch (e) {
        debugPrint('Error migrating salary_payments in v14: $e');
      }
    }
    try {
      await db.execute('ALTER TABLE attendance ADD COLUMN is_synced INTEGER DEFAULT 1');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] attendance.is_synced already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE students ADD COLUMN is_synced INTEGER DEFAULT 1');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] students.is_synced already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE fee_payments ADD COLUMN is_synced INTEGER DEFAULT 1');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] fee_payments.is_synced already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE users ADD COLUMN monthly_salary INTEGER DEFAULT 0');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] users.monthly_salary already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE users ADD COLUMN upi_id TEXT');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] users.upi_id already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE users ADD COLUMN preferred_payment_mode TEXT');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v14] users.preferred_payment_mode already present or failed: $e');
    }
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS salary_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          teacher_id INTEGER NOT NULL,
          maktab_id TEXT NOT NULL,
          salary_month TEXT NOT NULL,
          amount INTEGER NOT NULL,
          payment_date TEXT NOT NULL,
          payment_mode TEXT NOT NULL,
          upi_id_snapshot TEXT,
          transaction_reference TEXT,
          status TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (teacher_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_teacher_month ON salary_payments(teacher_id, salary_month)');
    } catch (e) {
      debugPrint('[MIGRATION v10] salary_payments setup failed: $e');
    }
    try {
      await db.execute('ALTER TABLE students ADD COLUMN is_deleted INTEGER DEFAULT 0');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v10] students.is_deleted already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE students ADD COLUMN deleted_at TEXT');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v10] students.deleted_at already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE attendance ADD COLUMN time TEXT');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v10] attendance.time already present or failed: $e');
    }
    try {
      await db.execute('ALTER TABLE teacher_attendance ADD COLUMN time TEXT');
    // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
    // Logs the error and continues so migration does not abort.
    } catch (e) {
      debugPrint('[MIGRATION v10] teacher_attendance.time already present or failed: $e');
    }
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
    } catch (e) {
      debugPrint('[MIGRATION v9] password_vault setup failed: $e');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN voice_note_path TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v8] fee_payments.voice_note_path already present or failed: $e');
      }
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
      } catch (e) {
        debugPrint('[MIGRATION v7] fee_payments setup failed: $e');
      }
    }

    // ── v5 → v6 ──────────────────────────────────────────────────────────────
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN fees_amount INTEGER');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v6] students.fees_amount already present or failed: $e');
      }
    }

    // ── v1 → v2 ──────────────────────────────────────────────────────────────
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN photo_path TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v2] users.photo_path already present or failed: $e');
      }
      try {
        await db.execute('ALTER TABLE students ADD COLUMN photo_path TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v2] students.photo_path already present or failed: $e');
      }
      try {
        await db.execute('ALTER TABLE students ADD COLUMN guardian_name TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v2] students.guardian_name already present or failed: $e');
      }
      try {
        await db.execute('ALTER TABLE students ADD COLUMN guardian_phone TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v2] students.guardian_phone already present or failed: $e');
      }

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
      } catch (e) {
        debugPrint('[MIGRATION v4] teacher_attendance setup failed: $e');
      }
    }

    // ── v2 → v3: teacher_notes for private remarks ────────────────────────────
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE students ADD COLUMN teacher_notes TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v3] students.teacher_notes already present or failed: $e');
      }
      
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
      } catch (e) {
        debugPrint('[MIGRATION v13] checklist_submissions setup failed: $e');
      }
      
      try {
        await QueueManager.createTable(db);
      } catch (e) {
        debugPrint('[MIGRATION v13] QueueManager setup failed: $e');
      }
      
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
      } catch (e) {
        debugPrint('[MIGRATION v12] teacher_profiles setup failed: $e');
      }
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
      } catch (e) {
        debugPrint('[MIGRATION v11] messages setup failed: $e');
      }
    }
    
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN dob TEXT');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v5] users.dob already present or failed: $e');
      }
    }

    if (oldVersion < 15) {
      // Remap teacher_attendance.teacher_id from local user id to canonical teacherId
      try {
        await db.execute('ALTER TABLE users ADD COLUMN teacher_id INTEGER');
      // Intentionally tolerant: ALTER TABLE is idempotent — column may already exist.
      // Logs the error and continues so migration does not abort.
      } catch (e) {
        debugPrint('[MIGRATION v15] users.teacher_id already present or failed: $e');
      }
      try {
        await db.execute('UPDATE users SET teacher_id = id WHERE teacher_id IS NULL');
      } catch (e, st) {
        debugPrint('[DatabaseHelper._onUpgrade] Migration v15 users.teacher_id = id failed: $e\n$st');
      }
      try {
        await db.execute('''
          UPDATE teacher_attendance
          SET teacher_id = (
            SELECT teacher_id FROM users
            WHERE users.id = teacher_attendance.teacher_id
          )
          WHERE EXISTS (
            SELECT 1 FROM users WHERE users.id = teacher_attendance.teacher_id
          )
        ''');
        debugPrint('[MIGRATION v15] Remapped teacher_attendance.teacher_id to canonical');
      } catch (e) {
        debugPrint('[MIGRATION v15 ERROR] $e');
      }

      // Fix P3a: Add teacher_id to quran_progress
      try {
        await db.execute('ALTER TABLE quran_progress ADD COLUMN teacher_id INTEGER');
        debugPrint('[MIGRATION v15] Added teacher_id column to quran_progress');
      } catch (e) {
        debugPrint('[MIGRATION v15 ERROR] $e');
      }
    }

    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE messages RENAME TO messages_old');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_id INTEGER NOT NULL,
            receiver_id INTEGER,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            is_read INTEGER DEFAULT 0
          )
        ''');
        await db.execute('INSERT INTO messages (id, sender_id, receiver_id, content, timestamp, is_read) SELECT id, sender_id, receiver_id, content, timestamp, is_read FROM messages_old');
        await db.execute('DROP TABLE messages_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_sender ON messages(sender_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_receiver ON messages(receiver_id)');
        debugPrint('[MIGRATION v16] Rebuilt messages table without FK');
      } catch (e) {
        debugPrint('[MIGRATION v16 ERROR] $e');
      }
    }

    if (oldVersion < 17) {
      try {
        final rowsWithId3or4 = await db.query('users', where: 'id IN (3, 4)');
        debugPrint('[MIGRATION v17] Local users rows with id IN (3, 4): $rowsWithId3or4');

        // Safely remove only orphaned test teacher accounts by name/pattern.
        // Legacy test record "MOULANA ABDUL WAHEED SAHB" is targeted, while
        // active teacher "MOULANA ABDUL WAHEED" (20261) is preserved.
        await db.delete(
          'users',
          where: "name LIKE '%Test%' OR name LIKE '%Demo%' OR name LIKE '%R22%' OR name = 'MOULANA ABDUL WAHEED SAHB'",
        );
        debugPrint('[MIGRATION v17] Removed test teacher accounts');
      } catch (e) {
        debugPrint('[MIGRATION v17 ERROR] $e');
      }
      try {
        await db.update(
          'users',
          {'name': 'Shaik. Abdul Rawoof'},
          where: "role IN ('manager', 'admin', 'operator') OR name LIKE '%Sammed%'",
        );
        debugPrint('[MIGRATION v17] Updated manager name in local users table');
      } catch (e) {
        debugPrint('[MIGRATION v17 ERROR] Manager name update: $e');
      }
    }

    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE batches RENAME TO batches_old');
        await db.execute('''
          CREATE TABLE batches (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            timing TEXT,
            teacher_id INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO batches (id, name, timing, teacher_id, is_synced) SELECT id, name, timing, teacher_id, is_synced FROM batches_old');
        await db.execute('DROP TABLE batches_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_batch_teacher ON batches(teacher_id)');
        debugPrint('[MIGRATION v18] Rebuilt batches table without FK');
      } catch (e) {
        debugPrint('[MIGRATION v18 ERROR] Rebuilding batches: $e');
      }

      try {
        await db.execute('ALTER TABLE teacher_attendance RENAME TO teacher_attendance_old');
        await db.execute('''
          CREATE TABLE teacher_attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            remarks TEXT,
            marked_by INTEGER,
            time TEXT,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO teacher_attendance SELECT * FROM teacher_attendance_old');
        await db.execute('DROP TABLE teacher_attendance_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_teach_att_date ON teacher_attendance(date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_teach_att_teacher_date ON teacher_attendance(teacher_id, date)');
        debugPrint('[MIGRATION v18] Rebuilt teacher_attendance table without FK');
      } catch (e) {
        debugPrint('[MIGRATION v18 ERROR] Rebuilding teacher_attendance: $e');
      }

      try {
        await db.execute('ALTER TABLE salary_payments RENAME TO salary_payments_old');
        await db.execute('''
          CREATE TABLE salary_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            maktab_id TEXT NOT NULL,
            salary_month TEXT NOT NULL,
            amount INTEGER NOT NULL,
            payment_date TEXT NOT NULL,
            payment_mode TEXT NOT NULL,
            upi_id_snapshot TEXT,
            transaction_reference TEXT,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('INSERT INTO salary_payments SELECT * FROM salary_payments_old');
        await db.execute('DROP TABLE salary_payments_old');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_teacher_month ON salary_payments(teacher_id, salary_month)');
        debugPrint('[MIGRATION v18] Rebuilt salary_payments table without FK');
      } catch (e) {
        debugPrint('[MIGRATION v18 ERROR] Rebuilding salary_payments: $e');
      }
    }

    if (oldVersion < 20) {
      try {
        await db.execute("ALTER TABLE quran_progress ADD COLUMN recitation_type TEXT DEFAULT 'Sabaq'");
        debugPrint('[MIGRATION v20] Added recitation_type column to quran_progress');
      } catch (e) {
        debugPrint('[MIGRATION v20 ERROR] Adding recitation_type: $e');
      }
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN time_period TEXT');
        debugPrint('[MIGRATION v21] Added time_period to attendance');
      } catch (e) {
        debugPrint('[MIGRATION v21 ERROR] Adding time_period to attendance: $e');
      }
      try {
        await db.execute('ALTER TABLE teacher_attendance ADD COLUMN time_period TEXT');
        debugPrint('[MIGRATION v21] Added time_period to teacher_attendance');
      } catch (e) {
        debugPrint('[MIGRATION v21 ERROR] Adding time_period to teacher_attendance: $e');
      }
    }

    if (oldVersion < 22) {
      try {
        await db.execute('ALTER TABLE teacher_attendance ADD COLUMN is_read INTEGER DEFAULT 0');
        debugPrint('[MIGRATION v22] Added is_read to teacher_attendance');
      } catch (e) {
        debugPrint('[MIGRATION v22 ERROR] Adding is_read to teacher_attendance: $e');
      }
    }

    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN receipt_sent INTEGER DEFAULT 0');
        debugPrint('[MIGRATION v23] Added receipt_sent to fee_payments');
      } catch (e) { debugPrint('[MIGRATION v23] fee_payments.receipt_sent: $e'); }
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN receipt_sent_at TEXT');
        debugPrint('[MIGRATION v23] Added receipt_sent_at to fee_payments');
      } catch (e) { debugPrint('[MIGRATION v23] fee_payments.receipt_sent_at: $e'); }
      try {
        await db.execute('ALTER TABLE salary_payments ADD COLUMN receipt_sent INTEGER DEFAULT 0');
        debugPrint('[MIGRATION v23] Added receipt_sent to salary_payments');
      } catch (e) { debugPrint('[MIGRATION v23] salary_payments.receipt_sent: $e'); }
      try {
        await db.execute('ALTER TABLE salary_payments ADD COLUMN receipt_sent_at TEXT');
        debugPrint('[MIGRATION v23] Added receipt_sent_at to salary_payments');
      } catch (e) { debugPrint('[MIGRATION v23] salary_payments.receipt_sent_at: $e'); }
    }

    if (oldVersion < 24) {
      try {
        await db.execute("ALTER TABLE students ADD COLUMN preferred_language TEXT DEFAULT 'en'");
        debugPrint('[MIGRATION v24] Added preferred_language to students');
      } catch (e) {
        debugPrint('[MIGRATION v24] students.preferred_language: $e');
      }
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
