import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/app_icons.dart';
import '../../models/batch.dart';
import '../../models/fee_payment.dart';
import '../../models/fee_handover.dart';
import '../../models/student.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/fee_handover_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../utils/reminder_formatter.dart';
import '../../utils/whatsapp_utility.dart';
import '../../utils/language_resolver.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/finance/fee_card.dart';
import '../../widgets/bulk_fee_messaging_dialog.dart';

class TeacherFeesScreen extends StatefulWidget {
  const TeacherFeesScreen({super.key});

  @override
  State<TeacherFeesScreen> createState() => _TeacherFeesScreenState();
}

class _TeacherFeesScreenState extends State<TeacherFeesScreen> {
  final FeePaymentRepository _feeRepo = FeePaymentRepository();
  final BatchRepository _batchRepo = BatchRepository();
  final FeeHandoverRepository _handoverRepo = FeeHandoverRepository();
  final UserRepository _userRepo = UserRepository();

  List<FeeStudentItem> _feeItems = [];
  List<Batch> _batches = [];
  bool _isLoading = true;
  String _filter = 'All';
  String _searchQuery = '';
  int? _selectedBatchId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  int _teacherId = 0;
  int? _alternateTeacherId;
  String _teacherName = '';
  User? _manager;

  int _totalCollected = 0;
  int _totalHandedOver = 0;
  List<Map<String, dynamic>> _myCollections = [];
  List<Map<String, dynamic>> _unattributedCollections = [];
  List<FeeHandover> _myHandovers = [];
  int _sectionASubTab = 0; // 0 = Collections History, 1 = Student Fee Dues

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _boot() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _teacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;
    _alternateTeacherId = (auth.currentUser?.id != null && auth.currentUser?.id != _teacherId) ? auth.currentUser!.id : null;
    _teacherName = auth.currentUser?.name ?? 'Teacher';
    _loadFeeRecords();
  }

  Future<void> _loadFeeRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final batches = await _batchRepo.fetchTeacherBatches(_teacherId, _alternateTeacherId);
      final batchIds = batches.map((b) => b.id).whereType<int>().toSet();

      List<Student> students = [];
      if (batchIds.isNotEmpty) {
        final placeholders = List.filled(batchIds.length, '?').join(',');
        final db = await DatabaseHelper.instance.database;
        final maps = await db.rawQuery('''
          SELECT s.* FROM students s
          WHERE (s.is_deleted IS NULL OR s.is_deleted = 0)
            AND s.batch_id IN ($placeholders)
          ORDER BY s.name ASC
        ''', batchIds.toList());
        students = maps.map((m) => Student.fromMap(m)).toList();
      }

      final studentIds = students.map((s) => s.id).whereType<int>().toSet();
      debugPrint('[TeacherFeeScope] teacherId=$_teacherId batches=${batchIds.length} students=${students.length}');

      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

      final List<FeeStudentItem> items = [];
      for (var s in students) {
        if (_selectedBatchId != null && s.batchId != _selectedBatchId) continue;

        final feeAmount = (s.feesAmount ?? 500).toDouble();
        final payments = await _feeRepo.getPaymentsForStudent(s.id!);

        // Sum all payments recorded in the current calendar month
        final paymentsThisMonth = payments
            .where((p) => p.timestamp.startsWith(currentMonthStr))
            .toList();
        final paidThisMonth = paymentsThisMonth.fold<double>(
          0.0,
          (sum, p) => sum + p.amount.toDouble(),
        );

        // True remaining balance for the month
        final remaining = (feeAmount - paidThisMonth).clamp(0.0, feeAmount);
        final isFullyPaid = remaining <= 0;

        final dueDate = DateFormat('yyyy-MM-10').format(DateTime.now());
        final isOverdue = !isFullyPaid && DateTime.now().day > 10;

        final status = isFullyPaid
            ? 'Paid'
            : (paidThisMonth > 0
                ? 'Partial'
                : (isOverdue ? 'Overdue' : 'Pending'));

        items.add(FeeStudentItem(
          student: s,
          amountDue: remaining,
          dueDate: dueDate,
          status: status,
        ));
      }

      final totalCollected = await _handoverRepo.getTotalCollectedForStudents(
        _teacherId,
        studentIds.toList(),
        _alternateTeacherId,
      );
      final totalHandedOver = await _handoverRepo.getTotalHandedOver(_teacherId, _alternateTeacherId);
      var myCollections = await _handoverRepo.getPaymentsCollectedByTeacher(_teacherId, _alternateTeacherId);
      myCollections = myCollections.where((c) => studentIds.contains(c['student_id'])).toList();
      var unattributed = await _handoverRepo.getUnattributedPayments();
      unattributed = unattributed.where((c) => studentIds.contains(c['student_id'])).toList();
      final myHandovers = await _handoverRepo.getHandoversForTeacher(_teacherId, _alternateTeacherId);
      final manager = await _userRepo.getManager();

      final outstanding = (totalCollected - totalHandedOver).clamp(0, 999999999);
      debugPrint('[FeeTotals] collected=$totalCollected handedOver=$totalHandedOver outstanding=$outstanding');

      if (mounted) {
        setState(() {
          _batches = batches;
          _feeItems = items;
          _totalCollected = totalCollected;
          _totalHandedOver = totalHandedOver;
          _myCollections = myCollections;
          _unattributedCollections = unattributed;
          _myHandovers = myHandovers;
          _manager = manager;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherFeesScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _outstandingOwed {
    final diff = _totalCollected - _totalHandedOver;
    if (diff < 0) {
      debugPrint('[TeacherFees] Warning: totalHandedOver ($_totalHandedOver) > totalCollected ($_totalCollected)');
      return 0;
    }
    return diff;
  }

  void _openBulkMessagingDialog() {
    debugPrint('[UPI-TRACE] showDialog fired from _openBulkMessagingDialog line 197');
    debugPrint('[showDialog] opening BulkFeeMessagingDialog');
    showDialog(
      context: context,
      builder: (ctx) => BulkFeeMessagingDialog(
        batches: _batches,
        initialBatchId: _selectedBatchId,
      ),
    ).then((_) => _loadFeeRecords());
  }

  Future<void> _payViaUpiThenRecord(FeeStudentItem item) async {
    debugPrint('[UPI-TRACE] handler entry, student=${item.student.id} amount=${item.amountDue}');
    if (item.amountDue <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending fee to pay.')),
      );
      return;
    }

    final amount = item.amountDue;
    final upiUri = Uri.parse(
      'upi://pay?pa=maktab@upi'
      '&pn=MaktabQuran'
      '&am=${amount.toStringAsFixed(2)}'
      '&cu=INR'
      '&tn=Fee_${item.student.admissionNumber}',
    );

    debugPrint('[UPI-TRACE] launching uri=$upiUri');
    debugPrint('[Teacher UPI] launching $upiUri');

    try {
      await launchUrl(upiUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Teacher UPI] launch failed: $e');
    }

    if (!mounted) return;
    _showRecordDialog(item, defaultMode: 'UPI', defaultAmount: amount);
  }

  Future<void> _sendWhatsAppReminder(FeeStudentItem item) async {
    final s = item.student;
    final phone = s.guardianPhone ?? s.phone ?? '';
    final msg = ReminderFormatter.formatFeeReminder(
      amountDue: item.amountDue,
      studentName: s.name,
      admissionNumber: s.admissionNumber,
      dueDate: item.dueDate,
      languageCode: LanguageResolver.forStudent(s),
    );
    await WhatsAppUtility.launchWhatsApp(phone, msg, context: context);
  }

  Future<void> _triggerNotification(FeeStudentItem item) async {
    final s = item.student;
    final granted = await PermissionHelper.requestPermissionWithRationale(
      context: context,
      permission: Permission.notification,
      title: 'Notification Permission',
      rationale: 'Maktab App needs permission to show instant fee reminder notifications on your device.',
    );
    if (!granted) return;

    await NotificationService().showFeeReminderNotification(
      studentName: s.name,
      amount: item.amountDue,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent for ${s.name}', maxLines: 2, overflow: TextOverflow.ellipsis)),
      );
    }
  }

  void _showRecordDialog(FeeStudentItem item, {String defaultMode = 'Cash', double? defaultAmount}) {
    String selectedMode = defaultMode;
    final modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Online'];
    final audioRecorder = AudioRecorder();
    bool isRecording = false;
    String? recordFilePath;

    final monthlyFee = (item.student.feesAmount ?? 500).toDouble();
    final remainingDue = item.amountDue;
    final alreadyPaid = (monthlyFee - remainingDue).clamp(0.0, monthlyFee);

    final defaultAmtVal = defaultAmount ?? (remainingDue > 0 ? remainingDue : monthlyFee);
    final amountCtrl = TextEditingController(text: defaultAmtVal.toInt().toString());
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();
    bool sendReceiptWhatsApp = true;

    final formKey = GlobalKey<FormState>();

    debugPrint('[UPI-TRACE] showDialog fired from _showRecordDialog line 295');
    debugPrint('[showDialog] opening RecordFeePaymentDialog for ${item.student.name}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateBuilder) {
          final payingNow = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final totalAfter = alreadyPaid + payingNow;
          final remainingAfter = (monthlyFee - totalAfter).clamp(0.0, monthlyFee);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Record Fee Payment: ${item.student.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFE9F1E9), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Expanded(child: Text('Monthly Fee:', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            SizedBox(width: 90, child: Text('₹${monthlyFee.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Expanded(child: Text('Already Paid:', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            SizedBox(width: 90, child: Text('₹${alreadyPaid.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Expanded(child: Text('Remaining Due:', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            SizedBox(width: 90, child: Text('₹${remainingDue.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paying Now (₹)',
                        prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setStateBuilder(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                        final amt = int.tryParse(val.trim());
                        if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: modes.contains(selectedMode) ? selectedMode : modes.first,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: modes.toSet().map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        if (v != null) setStateBuilder(() => selectedMode = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setStateBuilder(() => paymentDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(paymentDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference / UTR / Cheque (Optional)',
                        prefixIcon: Icon(Icons.numbers, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'After Payment Due: ₹${remainingAfter.toInt()}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            totalAfter >= monthlyFee ? 'PAID ✓' : 'PARTIAL ⚠',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalAfter >= monthlyFee ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: sendReceiptWhatsApp,
                      onChanged: (val) => setStateBuilder(() => sendReceiptWhatsApp = val ?? true),
                      title: const Text('Send receipt to parent via WhatsApp', style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(height: 20),
                    const Text('Add Voice Confirmation / Note:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          if (isRecording) {
                            final path = await audioRecorder.stop();
                            setStateBuilder(() {
                              isRecording = false;
                              recordFilePath = path;
                            });
                          } else {
                            if (await PermissionHelper.requestPermissionWithRationale(
                              context: dialogCtx,
                              permission: Permission.microphone,
                              title: 'Microphone Permission',
                              rationale: 'Maktab App requires microphone permission to record voice notes.',
                            )) {
                              final directory = await getApplicationDocumentsDirectory();
                              final p = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
                              await audioRecorder.start(const RecordConfig(), path: p);
                              setStateBuilder(() {
                                isRecording = true;
                                recordFilePath = null;
                              });
                            }
                          }
                        },
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: isRecording ? Colors.red : AppIcons.primaryTeal,
                          child: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isRecording) const Center(child: Text('Recording...', style: TextStyle(color: Colors.red, fontSize: 12))),
                    if (recordFilePath != null)
                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            await _audioPlayer.play(DeviceFileSource(recordFilePath!));
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play Voice Note', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isRecording) audioRecorder.stop();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (isRecording) await audioRecorder.stop();

                  final amt = int.parse(amountCtrl.text.trim());
                  final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate);
                  final month = DateFormat('MMMM yyyy').format(paymentDate);

                  final newPayment = FeePayment(
                    studentId: item.student.id!,
                    amount: amt,
                    mode: selectedMode,
                    timestamp: paymentDate.toIso8601String(),
                    reference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    voiceNotePath: recordFilePath,
                    receiptSent: sendReceiptWhatsApp ? 1 : 0,
                    receiptSentAt: sendReceiptWhatsApp ? DateTime.now().toIso8601String() : null,
                    collectedBy: _teacherId,
                  );

                  await _feeRepo.insertFeePayment(newPayment);

                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    _loadFeeRecords();

                    if (sendReceiptWhatsApp) {
                      await WhatsAppUtility.sendFeeReceipt(
                        context,
                        item.student.phone ?? '',
                        item.student.name,
                        amt.toDouble(),
                        month,
                        paymentMode: selectedMode,
                        dateTime: formattedTime,
                        collectorName: _teacherName,
                        languageCode: LanguageResolver.forStudent(item.student),
                        senderName: _teacherName,
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Payment Logged Successfully!'),
                        action: SnackBarAction(
                          label: 'Receipt',
                          textColor: Colors.amber,
                          onPressed: () {
                            WhatsAppUtility.sendFeeReceipt(
                              context,
                              item.student.phone ?? '',
                              item.student.name,
                              amt.toDouble(),
                              month,
                              paymentMode: selectedMode,
                              dateTime: formattedTime,
                              collectorName: _teacherName,
                              languageCode: LanguageResolver.forStudent(item.student),
                              senderName: _teacherName,
                            );
                          },
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                child: const Text('Log Payment & Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editFeeStructure(FeeStudentItem item) {
    final amountCtrl = TextEditingController(text: (item.student.feesAmount ?? 500).toString());

    debugPrint('[UPI-TRACE] showDialog fired from _editFeeStructure line 586');
    debugPrint('[showDialog] opening EditFeeDialog for ${item.student.name}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${item.student.name}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Monthly Fee Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = int.tryParse(amountCtrl.text) ?? 500;
              final updatedStudent = item.student.copyWith(feesAmount: newAmount);

              final db = await DatabaseHelper.instance.database;
              await db.update('students', updatedStudent.toMap(), where: 'id = ?', whereArgs: [updatedStudent.id]);

              if (context.mounted) {
                Navigator.pop(context);
                _loadFeeRecords();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee structure updated successfully', maxLines: 2, overflow: TextOverflow.ellipsis)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppIcons.primaryTeal, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReceipt(FeeStudentItem item) async {
    final payments = await _feeRepo.getPaymentsForStudent(item.student.id!);
    if (payments.isEmpty) return;
    final lastPayment = payments.first;

    final phone = item.student.phone ?? '';
    final rawTime = lastPayment.timestamp;
    final parsed = DateTime.tryParse(rawTime);
    final formattedTime = parsed != null ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed) : rawTime;
    final month = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : rawTime.split('T')[0];

    if (!mounted) return;
    await WhatsAppUtility.sendFeeReceipt(
      context,
      phone,
      item.student.name,
      lastPayment.amount.toDouble(),
      month,
      paymentMode: lastPayment.mode,
      dateTime: formattedTime,
      collectorName: _teacherName,
      languageCode: LanguageResolver.forStudent(item.student),
      senderName: _teacherName,
    );
  }


  Future<void> _payToManagerThenRecord(User manager, double amount) async {
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to settle with the manager.')),
        );
      }
      return;
    }

    // Resolve manager's UPI ID
    final managerUpi = manager.upiId?.trim();
    if (managerUpi == null || managerUpi.isEmpty) {
      // Manager has no UPI ID configured — go straight to the record dialog (Cash mode)
      if (!mounted) return;
      _showHandoverDialog(manager, defaultAmount: amount.toInt(), defaultMode: 'Cash');
      return;
    }

    final upiUri = Uri.parse(
      'upi://pay'
      '?pa=${Uri.encodeComponent(managerUpi)}'
      '&pn=${Uri.encodeComponent(manager.name)}'
      '&am=${amount.toStringAsFixed(2)}'
      '&cu=INR'
      '&tn=FeeHandover_$_teacherId',
    );

    debugPrint('[UPI-TRACE] launching uri=$upiUri');
    debugPrint('[Handover UPI] launching $upiUri');

    try {
      await launchUrl(upiUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Handover UPI] launch failed: $e');
    }

    if (!mounted) return;
    _showHandoverDialog(manager, defaultAmount: amount.toInt(), defaultMode: 'UPI');
  }

  void _showHandoverDialog(User manager, {int defaultAmount = 0, String defaultMode = 'Cash'}) {
    final amountCtrl = TextEditingController(text: defaultAmount > 0 ? defaultAmount.toString() : '');
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMode = defaultMode;
    DateTime paymentDate = DateTime.now();
    bool sendReceiptToManager = true;
    final modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Online'];

    final formKey = GlobalKey<FormState>();

    debugPrint('[UPI-TRACE] showDialog fired from _showHandoverDialog line 709');
    debugPrint('[showDialog] opening HandoverDialog (Pay to Manager)');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setStateBuilder) {
          final payingNow = int.tryParse(amountCtrl.text.trim()) ?? 0;
          final remainingAfter = (_outstandingOwed - payingNow).clamp(0, 9999999);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Hand Over Fees to ${manager.name.isNotEmpty ? manager.name : "Manager"}',
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF004D40),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F1E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Total Collected:', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '₹$_totalCollected',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Already Handed Over:', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '₹$_totalHandedOver',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Outstanding Due:', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '₹$_outstandingOwed',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Handover Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setStateBuilder(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter handover amount';
                        final amt = int.tryParse(val.trim());
                        if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: modes.contains(selectedMode) ? selectedMode : modes.first,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        if (v != null) setStateBuilder(() => selectedMode = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setStateBuilder(() => paymentDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(paymentDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference / UTR / Cheque (Optional)',
                        prefixIcon: Icon(Icons.numbers, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Remaining Outstanding: ₹$remainingAfter',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            remainingAfter <= 0 ? 'SETTLED ✓' : 'PARTIAL ⚠',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: remainingAfter <= 0 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: sendReceiptToManager,
                      onChanged: (val) => setStateBuilder(() => sendReceiptToManager = val ?? true),
                      title: const Text('Send receipt to Manager via WhatsApp', style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amt = int.parse(amountCtrl.text.trim());
                  final ref = refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null;
                  final notes = notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null;

                  final handover = FeeHandover(
                    teacherId: _teacherId,
                    managerId: manager.id,
                    amount: amt,
                    mode: selectedMode,
                    timestamp: paymentDate.toIso8601String(),
                    reference: ref,
                    notes: notes,
                    receiptSent: sendReceiptToManager ? 1 : 0,
                    receiptSentAt: sendReceiptToManager ? DateTime.now().toIso8601String() : null,
                  );

                  await _handoverRepo.insertHandover(handover);

                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    _loadFeeRecords();

                    if (sendReceiptToManager && manager.mobile != null && manager.mobile!.isNotEmpty) {
                      final dateStr = DateFormat('dd MMM yyyy').format(paymentDate);
                      final receiptMsg = 'Assalamu Alaikum,\n\n'
                          'Fee Handover Recorded:\n'
                          '• Amount: ₹$amt\n'
                          '• Date: $dateStr\n'
                          '• Mode: $selectedMode\n'
                          '${ref != null ? '• Reference: $ref\n' : ''}'
                          '• Teacher: $_teacherName\n\n'
                          'Please verify in the Maktab app.';
                      await WhatsAppUtility.launchWhatsApp(manager.mobile!, receiptMsg, context: context);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Handover of ₹$amt recorded successfully!')),
                    );
                  }
                },
                child: const Text('Save Handover'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOutstandingBanner() {
    final owed = _outstandingOwed;
    if (owed <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'All settled with the manager.',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppIcons.primaryTeal, Color(0xFF00695C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppIcons.primaryTeal.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppIcons.gold, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Outstanding to Manager',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'You owe ₹$owed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final mgr = _manager ?? User(
                  id: 0,
                  name: 'Manager',
                  pinHash: '',
                  role: 'admin',
                  createdAt: DateTime.now().toIso8601String(),
                );
                _payToManagerThenRecord(mgr, owed.toDouble());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppIcons.gold,
                foregroundColor: const Color(0xFF004D40),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PAY TO MANAGER',
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionA(List<FeeStudentItem> filtered, AppLocalizations? loc) {
    return RefreshIndicator(
      onRefresh: _loadFeeRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtotal Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppIcons.primaryTeal, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Collected from Students',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹$_totalCollected',
                          style: const TextStyle(
                            color: Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Segmented toggle: Collections History vs Student Dues
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _sectionASubTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _sectionASubTab == 0 ? AppIcons.primaryTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                'Collections Log (${_myCollections.length})',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _sectionASubTab == 0 ? Colors.white : AppIcons.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _sectionASubTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _sectionASubTab == 1 ? AppIcons.primaryTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                'Student Dues (${_feeItems.length})',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _sectionASubTab == 1 ? Colors.white : AppIcons.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_sectionASubTab == 0) ...[
              // Collections Log
              if (_myCollections.isEmpty && _unattributedCollections.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No collections recorded by you yet.', style: TextStyle(color: Colors.black45)),
                  ),
                )
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myCollections.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = _myCollections[index];
                    final rawTime = (p['timestamp'] ?? '').toString();
                    final parsed = DateTime.tryParse(rawTime);
                    final formattedDate = parsed != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed)
                        : rawTime;
                    final studentName = p['student_name'] ?? 'Student';
                    final admNo = p['admission_number'] ?? '';
                    final ref = p['reference']?.toString();
                    final mode = p['mode']?.toString() ?? 'Cash';
                    final receiptSent = p['receipt_sent'] == 1;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0F2F1),
                          child: Icon(
                            mode == 'UPI' ? Icons.qr_code_rounded : Icons.currency_rupee_rounded,
                            color: AppIcons.primaryTeal,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '$studentName ${admNo.isNotEmpty ? "($admNo)" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$formattedDate\nMode: $mode${ref != null && ref.isNotEmpty ? " • Ref: $ref" : ""}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${p['amount']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF004D40),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  receiptSent ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                  size: 13,
                                  color: receiptSent ? Colors.green : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  receiptSent ? 'Receipt sent' : 'No receipt',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: receiptSent ? Colors.green : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                if (_unattributedCollections.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Legacy / Unattributed Collections (${_unattributedCollections.length})\nRecorded before version 28 tracking.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _unattributedCollections.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = _unattributedCollections[index];
                      final rawTime = (p['timestamp'] ?? '').toString();
                      final parsed = DateTime.tryParse(rawTime);
                      final formattedDate = parsed != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed)
                          : rawTime;
                      final studentName = p['student_name'] ?? 'Student';
                      final admNo = p['admission_number'] ?? '';
                      final mode = p['mode']?.toString() ?? 'Cash';

                      return Card(
                        elevation: 0.5,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, color: Colors.grey),
                          title: Text('$studentName ${admNo.isNotEmpty ? "($admNo)" : ""}', style: const TextStyle(fontSize: 13)),
                          subtitle: Text('$formattedDate • $mode', style: const TextStyle(fontSize: 11)),
                          trailing: Text('₹${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ] else ...[
              // Student Dues & Recording list
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or admission no.',
                  prefixIcon: const Icon(Icons.search, color: AppIcons.primaryTeal),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['All', 'Overdue', 'Pending', 'Paid'].map((f) {
                          final isSel = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: isSel,
                              selectedColor: AppIcons.primaryTeal,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppIcons.primaryTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (_batches.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final uniqueBatches = {
                          for (final b in _batches)
                            if (b.id != null) b.id: b
                        }.values.toList();
                        final hasMatch = _selectedBatchId == null ||
                            uniqueBatches.any((b) => b.id == _selectedBatchId);
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: hasMatch ? _selectedBatchId : null,
                            hint: const Text('Filter Batch', maxLines: 1, overflow: TextOverflow.ellipsis),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Batches', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ...uniqueBatches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedBatchId = val;
                              });
                              _loadFeeRecords();
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading) ...[
                const ShimmerLoader(height: 110),
                const SizedBox(height: 12),
                const ShimmerLoader(height: 110),
              ] else if (filtered.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No fee records found.', style: TextStyle(color: Colors.black45)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return FeeCard(
                      item: item,
                      onPayUpi: () => _payViaUpiThenRecord(item),
                      onWhatsApp: () => _sendWhatsAppReminder(item),
                      onNotify: () => _triggerNotification(item),
                      onLog: () => _showRecordDialog(item),
                      onEdit: () => _editFeeStructure(item),
                      onReceipt: () => _sendReceipt(item),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionB() {
    return RefreshIndicator(
      onRefresh: _loadFeeRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtotal Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handshake_outlined, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Paid to Manager',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹$_totalHandedOver',
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action row for recording handover
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settlement History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                TextButton.icon(
                  onPressed: () {
                    final mgr = _manager ?? User(
                      id: 0,
                      name: 'Manager',
                      pinHash: '',
                      role: 'admin',
                      createdAt: DateTime.now().toIso8601String(),
                    );
                    _showHandoverDialog(mgr, defaultAmount: _outstandingOwed);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Record Handover'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_myHandovers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.handshake_outlined, size: 48, color: Colors.black26),
                      SizedBox(height: 10),
                      Text('No settlements made to manager yet.', style: TextStyle(color: Colors.black45)),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myHandovers.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final h = _myHandovers[index];
                  final parsed = DateTime.tryParse(h.timestamp);
                  final formattedDate = parsed != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed)
                      : h.timestamp;
                  final managerName = _manager?.name ?? 'Manager';

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3E0),
                        child: Icon(Icons.handshake_outlined, color: Colors.orange, size: 22),
                      ),
                      title: Text(
                        '₹${h.amount} via ${h.mode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40)),
                      ),
                      subtitle: Text(
                        '$formattedDate\nTo: $managerName${h.reference != null ? " • Ref: ${h.reference}" : ""}${h.notes != null ? "\nNotes: ${h.notes}" : ""}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            h.receiptSent == 1 ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            size: 16,
                            color: h.receiptSent == 1 ? Colors.green : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          if (_manager?.mobile != null && _manager!.mobile!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF004D40)),
                              tooltip: 'Share Receipt',
                              onPressed: () {
                                final dateStr = DateFormat('dd MMM yyyy').format(DateTime.tryParse(h.timestamp) ?? DateTime.now());
                                final receiptMsg = 'Assalamu Alaikum,\n\n'
                                    'Fee Handover Receipt:\n'
                                    '• Amount: ₹${h.amount}\n'
                                    '• Date: $dateStr\n'
                                    '• Mode: ${h.mode}\n'
                                    '${h.reference != null ? '• Reference: ${h.reference}\n' : ''}'
                                    '• Teacher: $_teacherName\n\n'
                                    'Recorded in Maktab app.';
                                WhatsAppUtility.launchWhatsApp(_manager!.mobile!, receiptMsg, context: context);
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase();
    final filtered = _feeItems.where((i) {
      final statusMatch = _filter == 'All' || i.status == _filter;
      final searchMatch = q.isEmpty ||
          i.student.name.toLowerCase().contains(q) ||
          (i.student.admissionNumber).toLowerCase().contains(q);
      return statusMatch && searchMatch;
    }).toList();

    final loc = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: loc?.translate('teacher_fees_title') ?? 'Student Fees',
          actions: [
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _openBulkMessagingDialog,
              tooltip: loc?.translate('teacher_fees_reminders') ?? 'Send Bulk Batch Reminders',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'Collected from Students',
                icon: Icon(Icons.payments_outlined, size: 18),
              ),
              Tab(
                text: 'Paid to Manager',
                icon: Icon(Icons.account_balance_outlined, size: 18),
              ),
            ],
            indicatorColor: AppIcons.gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildOutstandingBanner(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildSectionA(filtered, loc),
                    _buildSectionB(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showRecordPaymentDialog,
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_card_rounded, size: 22),
          label: Text(
            loc?.translate('fee_record_payment') ?? 'Record Payment',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _showRecordPaymentDialog() {
    if (_feeItems.isEmpty) return;
    final loc = AppLocalizations.of(context);
    debugPrint('[UPI-TRACE] showDialog fired from _showRecordPaymentDialog line 1745');
    debugPrint('[showDialog] opening RecordPaymentDialog (FAB/helper)');
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(loc?.translate('fee_record_payment') ?? 'Record Payment', maxLines: 1, overflow: TextOverflow.ellipsis),
        children: _feeItems.map((item) => SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            _showRecordDialog(item);
          },
          child: Text('${item.student.name} (ADM: ${item.student.admissionNumber})', maxLines: 2, overflow: TextOverflow.ellipsis),
        )).toList(),
      ),
    );
  }
}
