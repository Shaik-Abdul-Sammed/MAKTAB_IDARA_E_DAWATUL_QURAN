import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app"

tests = {
    # ---------------- MODELS ----------------
    "test/models/user_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User serialization and deserialization', () {
      final user = User(
        id: 1,
        name: 'Test User',
        pinHash: 'hashed_pin',
        role: 'teacher',
        createdAt: '2023-10-27T10:00:00Z',
      );

      final map = user.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Test User');
      expect(map['pin_hash'], 'hashed_pin');
      expect(map['role'], 'teacher');
      expect(map['created_at'], '2023-10-27T10:00:00Z');

      final deserializedUser = User.fromMap(map);
      expect(deserializedUser.id, 1);
      expect(deserializedUser.name, 'Test User');
      expect(deserializedUser.pinHash, 'hashed_pin');
    });
  });
}
""",

    "test/models/student_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';

void main() {
  group('Student Model Tests', () {
    test('Student serialization and deserialization', () {
      final student = Student(
        id: 1,
        name: 'John Doe',
        age: 10,
        guardianName: 'Jane Doe',
        guardianPhone: '1234567890',
        address: '123 Main St',
        batchId: 2,
        enrolledAt: '2023-10-27T10:00:00Z',
      );

      final map = student.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'John Doe');
      expect(map['batch_id'], 2);

      final deserializedStudent = Student.fromMap(map);
      expect(deserializedStudent.id, 1);
      expect(deserializedStudent.name, 'John Doe');
      expect(deserializedStudent.batchId, 2);
    });
  });
}
""",

    "test/models/batch_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart';

void main() {
  group('Batch Model Tests', () {
    test('Batch serialization and deserialization', () {
      final batch = Batch(
        id: 1,
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        teacherId: 3,
      );

      final map = batch.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Morning Batch');
      expect(map['teacher_id'], 3);

      final deserializedBatch = Batch.fromMap(map);
      expect(deserializedBatch.id, 1);
      expect(deserializedBatch.name, 'Morning Batch');
      expect(deserializedBatch.teacherId, 3);
    });
  });
}
""",

    "test/models/attendance_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';

void main() {
  group('Attendance Model Tests', () {
    test('Attendance serialization and deserialization', () {
      final attendance = Attendance(
        id: 1,
        studentId: 2,
        batchId: 3,
        date: '2023-10-27',
        status: 'present',
        remarks: 'On time',
      );

      final map = attendance.toMap();
      expect(map['id'], 1);
      expect(map['student_id'], 2);
      expect(map['status'], 'present');

      final deserializedAttendance = Attendance.fromMap(map);
      expect(deserializedAttendance.id, 1);
      expect(deserializedAttendance.studentId, 2);
      expect(deserializedAttendance.status, 'present');
    });
  });
}
""",

    "test/models/syllabus_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/syllabus.dart';

void main() {
  group('Syllabus Model Tests', () {
    test('Syllabus serialization and deserialization', () {
      final syllabus = Syllabus(
        id: 1,
        title: 'Tajweed Rules',
        description: 'Learn basic tajweed',
        batchId: 2,
      );

      final map = syllabus.toMap();
      expect(map['id'], 1);
      expect(map['title'], 'Tajweed Rules');
      expect(map['batch_id'], 2);

      final deserializedSyllabus = Syllabus.fromMap(map);
      expect(deserializedSyllabus.id, 1);
      expect(deserializedSyllabus.title, 'Tajweed Rules');
      expect(deserializedSyllabus.batchId, 2);
    });
  });
}
""",

    "test/models/exam_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/exam.dart';

void main() {
  group('Exam Model Tests', () {
    test('Exam serialization and deserialization', () {
      final exam = Exam(
        id: 1,
        name: 'Midterm',
        date: '2023-11-15',
        batchId: 2,
      );

      final map = exam.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Midterm');
      expect(map['batch_id'], 2);

      final deserializedExam = Exam.fromMap(map);
      expect(deserializedExam.id, 1);
      expect(deserializedExam.name, 'Midterm');
      expect(deserializedExam.batchId, 2);
    });
  });
}
""",

    "test/models/result_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/result.dart';

void main() {
  group('Result Model Tests', () {
    test('Result serialization and deserialization', () {
      final result = Result(
        id: 1,
        examId: 2,
        studentId: 3,
        marksObtained: 85,
        totalMarks: 100,
        remarks: 'Good',
      );

      final map = result.toMap();
      expect(map['id'], 1);
      expect(map['marks_obtained'], 85);
      expect(map['student_id'], 3);

      final deserializedResult = Result.fromMap(map);
      expect(deserializedResult.id, 1);
      expect(deserializedResult.marksObtained, 85);
      expect(deserializedResult.studentId, 3);
    });
  });
}
""",

    # ---------------- REPOSITORIES ----------------
    "test/repositories/user_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('User Repository Tests', () {
    test('insert and retrieve user', () async {
      final repo = UserRepository();
      final user = User(
        name: 'Test Teacher',
        pinHash: 'hash',
        role: 'teacher',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      final id = await repo.insertUser(user);
      expect(id, isPositive);
      
      final teachers = await repo.getAllTeachers();
      expect(teachers.length, 1);
      expect(teachers.first.name, 'Test Teacher');
    });
  });
}
""",

    "test/repositories/student_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Student Repository Tests', () {
    test('insert and retrieve student', () async {
      final repo = StudentRepository();
      final student = Student(
        name: 'John Doe',
        age: 10,
        guardianName: 'Jane Doe',
        guardianPhone: '1234567890',
        address: '123 Main St',
        batchId: 1,
        enrolledAt: DateTime.now().toIso8601String(),
      );
      
      final id = await repo.insertStudent(student);
      expect(id, isPositive);
      
      final students = await repo.getStudentsByBatch(1);
      expect(students.length, 1);
      expect(students.first.name, 'John Doe');
    });
  });
}
""",

    "test/repositories/batch_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart' as model;
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Batch Repository Tests', () {
    test('insert and retrieve batch', () async {
      final repo = BatchRepository();
      final batch = model.Batch(
        name: 'Morning Batch',
        timing: '08:00 AM',
      );
      
      final id = await repo.insertBatch(batch);
      expect(id, isPositive);
      
      final batches = await repo.getAllBatches();
      expect(batches.length, 1);
      expect(batches.first.name, 'Morning Batch');
    });
  });
}
""",

    "test/repositories/attendance_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Attendance Repository Tests', () {
    test('insert and retrieve attendance', () async {
      final repo = AttendanceRepository();
      final attendance = Attendance(
        studentId: 1,
        batchId: 2,
        date: '2023-10-27',
        status: 'present',
      );
      
      final id = await repo.insertAttendance(attendance);
      expect(id, isPositive);
      
      final records = await repo.getAttendanceForStudent(1);
      expect(records.length, 1);
      expect(records.first.status, 'present');
    });
  });
}
""",
    
    "test/repositories/syllabus_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/syllabus.dart';
import 'package:maktab_app/repositories/syllabus_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Syllabus Repository Tests', () {
    test('insert and retrieve syllabus', () async {
      final repo = SyllabusRepository();
      final syllabus = Syllabus(
        title: 'Tajweed',
        description: 'Rules',
        batchId: 1,
      );
      
      final id = await repo.insertSyllabus(syllabus);
      expect(id, isPositive);
      
      final records = await repo.getSyllabusByBatch(1);
      expect(records.length, 1);
      expect(records.first.title, 'Tajweed');
    });
  });
}
""",

    "test/repositories/exam_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/exam.dart';
import 'package:maktab_app/repositories/exam_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Exam Repository Tests', () {
    test('insert and retrieve exam', () async {
      final repo = ExamRepository();
      final exam = Exam(
        name: 'Midterm',
        date: '2023-11-15',
        batchId: 1,
      );
      
      final id = await repo.insertExam(exam);
      expect(id, isPositive);
      
      final records = await repo.getExamsByBatch(1);
      expect(records.length, 1);
      expect(records.first.name, 'Midterm');
    });
  });
}
""",

    "test/repositories/result_repository_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/result.dart';
import 'package:maktab_app/repositories/result_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Result Repository Tests', () {
    test('insert and retrieve result', () async {
      final repo = ResultRepository();
      final result = Result(
        examId: 1,
        studentId: 2,
        marksObtained: 80,
        totalMarks: 100,
      );
      
      final id = await repo.insertResult(result);
      expect(id, isPositive);
      
      final records = await repo.getResultsForStudent(2);
      expect(records.length, 1);
      expect(records.first.marksObtained, 80);
    });
  });
}
"""
}

for file_path, content in tests.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Updated {file_path}")
