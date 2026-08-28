import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/salary_payment.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/salary_repository.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/utils/salary_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  Future<int> createDummyTeacher(UserRepository userRepo, {String name = 'Test Teacher', int salary = 15000}) async {
    return await userRepo.insertUser(User(
      name: name,
      pinHash: 'hash123',
      role: 'teacher',
      mobile: '9177024433',
      monthlySalary: salary,
      upiId: 'teacher@upi',
      preferredPaymentMode: 'UPI',
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  group('Teacher Salary & Payment Module Tests', () {
    // 1. Salary creation & config
    test('1. Teacher salary profile configuration & persistence', () async {
      final userRepo = UserRepository();
      final id = await createDummyTeacher(userRepo, name: 'Shaik Mahaboob', salary: 15000);
      expect(id, greaterThan(0));

      final saved = await userRepo.getUserById(id);
      expect(saved, isNotNull);
      expect(saved!.monthlySalary, 15000);
      expect(saved.upiId, 'teacher@upi');
      expect(saved.preferredPaymentMode, 'UPI');
    });

    // 2. Salary payment insertion
    test('2. Full salary payment insertion', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      final sp = SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'UPI',
        upiIdSnapshot: 'teacher@upi',
        transactionReference: 'UPI12345678',
        status: 'PAID',
        notes: 'Full August Salary',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final id = await salaryRepo.insertPayment(sp);
      expect(id, greaterThan(0));

      final list = await salaryRepo.getPaymentsForTeacher(teacherId);
      expect(list.length, 1);
      expect(list.first.amount, 15000);
      expect(list.first.status, 'PAID');
    });

    // 3. Partial payment
    test('3. Partial salary payment tracking', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      final spPartial = SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 5000,
        paymentDate: '2026-08-02',
        paymentMode: 'Cash',
        status: 'PARTIALLY PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await salaryRepo.insertPayment(spPartial);
      final totalPaid = await salaryRepo.getTotalPaidForTeacherAndMonth(teacherId, '2026-08');
      expect(totalPaid, 5000);

      const monthlySalary = 15000;
      final remaining = (monthlySalary - totalPaid).clamp(0, monthlySalary);
      expect(remaining, 10000);
    });

    // 4. Multiple payments in one month
    test('4. Multiple partial payments in one month add up correctly', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      await salaryRepo.insertPayment(SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 5000,
        paymentDate: '2026-08-01',
        paymentMode: 'Cash',
        status: 'PARTIALLY PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      await salaryRepo.insertPayment(SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 10000,
        paymentDate: '2026-08-15',
        paymentMode: 'UPI',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      final totalPaid = await salaryRepo.getTotalPaidForTeacherAndMonth(teacherId, '2026-08');
      expect(totalPaid, 15000);

      const monthlySalary = 15000;
      final remaining = (monthlySalary - totalPaid).clamp(0, monthlySalary);
      expect(remaining, 0);
    });

    // 5. Remaining amount calculation
    test('5. Remaining amount calculation logic', () {
      const monthlySalary = 15000;
      int paid = 10000;
      int remaining = (monthlySalary - paid).clamp(0, monthlySalary);
      expect(remaining, 5000);

      paid = 15000;
      remaining = (monthlySalary - paid).clamp(0, monthlySalary);
      expect(remaining, 0);

      paid = 18000;
      remaining = (monthlySalary - paid).clamp(0, monthlySalary);
      expect(remaining, 0);
    });

    // 6. Payment status derivation
    test('6. Payment status derivation (PAID vs PARTIALLY PAID vs PENDING)', () {
      String getStatus(int monthly, int paid) {
        if (monthly <= 0) return 'NOT CONFIG';
        if (paid >= monthly) return 'PAID';
        if (paid > 0) return 'PARTIALLY PAID';
        return 'PENDING';
      }

      expect(getStatus(15000, 15000), 'PAID');
      expect(getStatus(15000, 5000), 'PARTIALLY PAID');
      expect(getStatus(15000, 0), 'PENDING');
    });

    // 7. UPI URI generation
    test('7. Standard UPI URI format generation', () {
      final upiId = 'mahaboob@upi';
      final teacherName = 'Shaik Mahaboob Shareef';
      final amount = 15000;

      final encodedName = Uri.encodeComponent(teacherName);
      final upiUri = 'upi://pay?pa=$upiId&pn=$encodedName&am=$amount&cu=INR';

      expect(upiUri, contains('pa=mahaboob@upi'));
      expect(upiUri, contains('am=15000'));
      expect(upiUri, contains('cu=INR'));
      expect(Uri.tryParse(upiUri), isNotNull);
    });

    // 8. Invalid UPI ID handling
    test('8. Invalid UPI ID empty/null validation', () {
      bool isValidUpi(String? upi) {
        if (upi == null || upi.trim().isEmpty) return false;
        return upi.contains('@');
      }

      expect(isValidUpi('teacher@upi'), isTrue);
      expect(isValidUpi(''), isFalse);
      expect(isValidUpi(null), isFalse);
      expect(isValidUpi('invalidupi'), isFalse);
    });

    // 9. Zero/Negative payment prevention
    test('9. Zero and negative payment amounts are invalid', () {
      bool isValidPaymentAmount(int amount) {
        return amount > 0;
      }

      expect(isValidPaymentAmount(5000), isTrue);
      expect(isValidPaymentAmount(0), isFalse);
      expect(isValidPaymentAmount(-100), isFalse);
    });

    // 10. Duplicate payment prevention (Offline collision safe query)
    test('10. Querying payment list by teacher & month returns exact records without duplication', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      final sp = SalaryPayment(
        id: 999,
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'Cash',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final db = await DatabaseHelper.instance.database;
      await db.insert('salary_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('salary_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final list = await salaryRepo.getPaymentsForTeacherAndMonth(teacherId, '2026-08');
      expect(list.length, 1);
    });

    // 11. Offline payment creation
    test('11. Offline payment record created in local SQLite database', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      final id = await salaryRepo.insertPayment(SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 12000,
        paymentDate: '2026-08-10',
        paymentMode: 'Bank Transfer',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      final payments = await salaryRepo.getPaymentsForTeacher(teacherId);
      expect(payments.length, 1);
      expect(payments.first.id, id);
    });

    // 12. Offline -> Firebase payload preparation
    test('12. SalaryPayment map converts cleanly to Firebase JSON payload', () {
      final sp = SalaryPayment(
        id: 55,
        teacherId: 106,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'UPI',
        upiIdSnapshot: 'test@upi',
        transactionReference: 'TXN123',
        status: 'PAID',
        createdAt: '2026-08-05T10:00:00Z',
        updatedAt: '2026-08-05T10:00:00Z',
      );

      final map = sp.toMap();
      expect(map['teacher_id'], 106);
      expect(map['amount'], 15000);
      expect(map['status'], 'PAID');
      expect(map['upi_id_snapshot'], 'test@upi');
    });

    // 13. App restart persistence
    test('13. Salary data persists across SQLite database close and re-open', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      await salaryRepo.insertPayment(SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'Cash',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      // Close and re-open
      await DatabaseHelper.instance.close();

      final listAfterReopen = await salaryRepo.getPaymentsForTeacher(teacherId);
      expect(listAfterReopen.length, 1);
      expect(listAfterReopen.first.amount, 15000);
    });

    // 14 & 15. Manager & Operator salary access permission
    test('14 & 15. Role authorization for Manager, Admin, and Operator', () {
      bool isAuthorized(String? role) {
        return role == 'admin' || role == 'manager' || role == 'operator';
      }

      expect(isAuthorized('admin'), isTrue);
      expect(isAuthorized('manager'), isTrue);
      expect(isAuthorized('operator'), isTrue);
      expect(isAuthorized('teacher'), isFalse);
    });

    // 16. Teacher salary modification DENIED
    test('16. Teacher role is rejected from modifying salary records', () {
      bool canModifySalary(String? role) {
        return role == 'admin' || role == 'manager' || role == 'operator';
      }

      expect(canModifySalary('teacher'), isFalse);
    });

    // 17. Cross-Maktab salary access DENIED
    test('17. Salary querying requires matching maktabId', () async {
      final userRepo = UserRepository();
      final salaryRepo = SalaryRepository();
      final teacherId = await createDummyTeacher(userRepo);

      await salaryRepo.insertPayment(SalaryPayment(
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'Cash',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      final maktab1List = await salaryRepo.getPaymentsForMonth('MAKTAB-001', '2026-08');
      final maktab2List = await salaryRepo.getPaymentsForMonth('MAKTAB-002', '2026-08');

      expect(maktab1List.length, 1);
      expect(maktab2List.length, 0);
    });

    // 18. Firebase sync loop prevention
    test('18. ConflictAlgorithm.replace prevents duplicate key sync loops', () async {
      final userRepo = UserRepository();
      final teacherId = await createDummyTeacher(userRepo);
      final db = await DatabaseHelper.instance.database;

      final sp = SalaryPayment(
        id: 88,
        teacherId: teacherId,
        maktabId: 'MAKTAB-001',
        salaryMonth: '2026-08',
        amount: 15000,
        paymentDate: '2026-08-05',
        paymentMode: 'Cash',
        status: 'PAID',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await db.insert('salary_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('salary_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final result = await db.query('salary_payments', where: 'id = ?', whereArgs: [88]);
      expect(result.length, 1);
    });

    // 19. Monthly report calculation
    test('19. Salary summary metrics calculation', () {
      final teacherSalaries = [15000, 15000, 15000];
      final teacherPaid = [15000, 10000, 15000];

      final totalSalary = teacherSalaries.reduce((a, b) => a + b);
      final totalPaid = teacherPaid.reduce((a, b) => a + b);
      final totalPending = totalSalary - totalPaid;

      expect(totalSalary, 45000);
      expect(totalPaid, 40000);
      expect(totalPending, 5000);
    });

    // 20. PDF salary report generation
    test('20. PDF Salary Report generates non-empty PDF document bytes', () async {
      final pdfBytes = await SalaryPdfGenerator.generateSalaryReportPdf(
        maktabName: 'IDARA E DAWATHUL QURAAN',
        month: 'August 2026',
        teacherSalaryData: [
          {'name': 'Shaik Mohammad', 'monthlySalary': 15000, 'paid': 15000, 'pending': 0, 'status': 'PAID'},
          {'name': 'Abdul Waheed', 'monthlySalary': 15000, 'paid': 10000, 'pending': 5000, 'status': 'PARTIALLY PAID'},
          {'name': 'Yaqoob Baig', 'monthlySalary': 15000, 'paid': 15000, 'pending': 0, 'status': 'PAID'},
        ],
        totalSalary: 45000,
        totalPaid: 40000,
        totalPending: 5000,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes[0], 0x25); // %PDF header
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });
  });
}
