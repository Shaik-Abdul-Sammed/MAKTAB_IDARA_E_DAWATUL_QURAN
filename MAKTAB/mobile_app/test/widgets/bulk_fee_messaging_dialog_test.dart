import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/widgets/bulk_fee_messaging_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Batch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'maktab_id': 'MAKTAB-001'});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');

    final db = await DatabaseHelper.instance.database;

    // Create test batch
    await db.insert('batches', {
      'id': 1,
      'name': 'Batch A - Morning',
      'timing': 'Morning',
    });
  });

  testWidgets('BulkFeeMessagingDialog renders correctly with batches and students', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final List<Batch> testBatches = [
      Batch(id: 1, name: 'Batch A - Morning', timing: 'Morning'),
    ];

    final nowStr = DateTime.now().toIso8601String();
    final List<Student> testStudents = [
      Student(
        id: 101,
        admissionNumber: 'ADM-1001',
        name: 'Zaid Khan',
        batchId: 1,
        phone: '9876543210',
        feesAmount: 500,
        createdAt: nowStr,
      ),
      Student(
        id: 102,
        admissionNumber: 'ADM-1002',
        name: 'Bilal Ahmed',
        batchId: 1,
        phone: '9876543211',
        feesAmount: 600,
        createdAt: nowStr,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkFeeMessagingDialog(
            batches: testBatches,
            initialBatchId: 1,
            students: testStudents,
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog elements
    expect(find.text('Bulk Batch Fee Reminders'), findsOneWidget);
    expect(find.text('Class / Batch'), findsOneWidget);
    expect(find.text('Status Filter'), findsOneWidget);
    expect(find.text('Message Template'), findsOneWidget);

    // Verify target students loaded
    expect(find.text('Zaid Khan'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Device Alert'), findsOneWidget);
    expect(find.text('Share Summary'), findsOneWidget);
    expect(find.textContaining('Send WhatsApp'), findsOneWidget);
  });

  testWidgets('Deselect All clears student selections in BulkFeeMessagingDialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final List<Batch> testBatches = [
      Batch(id: 1, name: 'Batch A - Morning', timing: 'Morning'),
    ];

    final nowStr = DateTime.now().toIso8601String();
    final List<Student> testStudents = [
      Student(
        id: 101,
        admissionNumber: 'ADM-1001',
        name: 'Zaid Khan',
        batchId: 1,
        phone: '9876543210',
        feesAmount: 500,
        createdAt: nowStr,
      ),
      Student(
        id: 102,
        admissionNumber: 'ADM-1002',
        name: 'Bilal Ahmed',
        batchId: 1,
        phone: '9876543211',
        feesAmount: 600,
        createdAt: nowStr,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkFeeMessagingDialog(
            batches: testBatches,
            initialBatchId: 1,
            students: testStudents,
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Initial state: 2 students selected
    expect(find.textContaining('Selected Students (2 / 2)'), findsOneWidget);

    // Tap Deselect All
    await tester.tap(find.text('Deselect All'));
    await tester.pump();

    // Updated state: 0 students selected
    expect(find.textContaining('Selected Students (0 / 2)'), findsOneWidget);

    // Tap Select All
    await tester.tap(find.text('Select All'));
    await tester.pump();

    // Updated state: 2 students selected
    expect(find.textContaining('Selected Students (2 / 2)'), findsOneWidget);
  });
}
