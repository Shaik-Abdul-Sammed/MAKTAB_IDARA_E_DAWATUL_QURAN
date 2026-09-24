import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/salary_payment.dart';
import 'package:maktab_app/models/app_message.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/salary_repository.dart';
import 'package:maktab_app/repositories/message_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/utils/salary_pdf_generator.dart';
import 'package:maktab_app/utils/whatsapp_utility.dart';
import 'package:maktab_app/utils/receipt_templates.dart';
import 'package:maktab_app/utils/receipt_pdf_generator.dart';
import 'package:maktab_app/widgets/receipt_preview_dialog.dart';
import 'package:maktab_app/widgets/finance/salary_totals_card.dart';

class TeacherSalaryManagementScreen extends StatefulWidget {
  const TeacherSalaryManagementScreen({super.key});

  @override
  State<TeacherSalaryManagementScreen> createState() => _TeacherSalaryManagementScreenState();
}

class _TeacherSalaryManagementScreenState extends State<TeacherSalaryManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final SalaryRepository _salaryRepository = SalaryRepository();
  final CloudSyncService _cloudSyncService = CloudSyncService.instance;
  StreamSubscription<String>? _syncSub;

  DateTime _selectedDate = DateTime.now();
  List<User> _teachers = [];
  Map<int, List<SalaryPayment>> _paymentsMap = {};
  Map<int, List<SalaryPayment>> _allPaymentsMap = {};
  Map<String, int> _salaryTotals = const {};
  bool _isLoading = true;

  String get _selectedMonthStr => DateFormat('yyyy-MM').format(_selectedDate);
  String get _monthDisplayStr => DateFormat('MMMM yyyy').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
    _syncSub = _cloudSyncService.onDataSynced.listen((col) {
      if (col == 'salary_payments' || col == 'teachers') {
        _loadSalaryData();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSalaryData() async {
    setState(() => _isLoading = true);
    final teachers = await _userRepository.getAllTeachers();

    final Map<int, List<SalaryPayment>> map = {};
    final Map<int, List<SalaryPayment>> allMap = {};
    for (var teacher in teachers) {
      if (teacher.id != null) {
        final payments = await _salaryRepository.getPaymentsForTeacherAndMonth(teacher.id!, _selectedMonthStr);
        map[teacher.id!] = payments;
        final allPayments = await _salaryRepository.getPaymentsForTeacher(teacher.id!);
        allMap[teacher.id!] = allPayments;
      }
    }

    final salaryTotals = await _salaryRepository.getSalaryTotals();

    if (mounted) {
      setState(() {
        _teachers = teachers;
        _paymentsMap = map;
        _allPaymentsMap = allMap;
        _salaryTotals = salaryTotals;
        _isLoading = false;
      });
    }
  }

  int _getPaidAmountForTeacher(int teacherId) {
    final payments = _paymentsMap[teacherId] ?? [];
    return payments.fold(0, (sum, p) => sum + p.amount);
  }

  String _getStatusForTeacher(User teacher) {
    final monthlySalary = teacher.monthlySalary ?? 0;
    final paid = _getPaidAmountForTeacher(teacher.id!);
    if (monthlySalary <= 0) return 'NOT CONFIG';
    if (paid >= monthlySalary) return 'PAID';
    if (paid > 0) return 'PARTIALLY PAID';
    return 'PENDING';
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
    });
    _loadSalaryData();
  }

  // ── UPI Launch Handler ──────────────────────────────────────────────────

  Future<void> _launchUpiPayment(User teacher, int remainingAmount) async {
    if (teacher.upiId == null || teacher.upiId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher has no UPI ID configured. Edit salary profile first.')),
      );
      return;
    }

    final upiId = teacher.upiId!.trim();
    final name = Uri.encodeComponent(teacher.name);
    final upiUrl = 'upi://pay?pa=$upiId&pn=$name&am=$remainingAmount&cu=INR';
    final uri = Uri.parse(upiUrl);

    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[TeacherSalaryManagementScreen._launchUpiPayment] launch failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the app. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('UPI Payment Initiated', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UPI App launch status: ${launched ? "Success" : "Manual / App Open"}'),
            const SizedBox(height: 8),
            Text('Paying to: $upiId'),
            Text('Target Amount: ₹$remainingAmount'),
            const SizedBox(height: 12),
            const Text(
              'IMPORTANT:\nOpening the UPI application is NOT confirmation of payment. Complete the transaction in your UPI app, then tap "Record Payment" to update records.',
              style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _showRecordPaymentDialog(teacher, defaultMode: 'UPI', defaultRef: 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  // ── Record Payment Dialog ────────────────────────────────────────────────

  void _showRecordPaymentDialog(User teacher, {String defaultMode = 'Cash', String defaultRef = ''}) {
    final monthlySalary = teacher.monthlySalary ?? 0;
    final alreadyPaid = _getPaidAmountForTeacher(teacher.id!);
    final remaining = (monthlySalary - alreadyPaid).clamp(0, monthlySalary);

    final amountController = TextEditingController(text: remaining > 0 ? remaining.toString() : '0');
    final refController = TextEditingController(text: defaultRef);
    final notesController = TextEditingController();
    String selectedMode = defaultMode;
    DateTime paymentDate = DateTime.now();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final payingNow = int.tryParse(amountController.text.trim()) ?? 0;
            final newTotal = alreadyPaid + payingNow;
            final newRemaining = (monthlySalary - newTotal).clamp(0, monthlySalary);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Record Salary Payment — ${teacher.name}', style: const TextStyle(fontSize: 18, color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFE9F1E9), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Monthly Salary:'), Text('₹$monthlySalary', style: const TextStyle(fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Already Paid:'), Text('₹$alreadyPaid', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Remaining Due:'), Text('₹$remaining', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount Paying Now (₹)',
                          prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setDialogState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                          final amt = int.tryParse(val.trim());
                          if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ['UPI', 'Bank Transfer', 'Cash', 'Other'].contains(selectedMode) ? selectedMode : 'Cash',
                        decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                        items: ['UPI', 'Bank Transfer', 'Cash', 'Other']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedMode = val ?? 'Cash'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference / Txn ID (Optional)',
                          prefixIcon: Icon(Icons.numbers, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
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
                            Text('After Payment Due: ₹$newRemaining', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(newTotal >= monthlySalary ? 'PAID ✓' : 'PARTIAL ⚠', style: TextStyle(fontWeight: FontWeight.bold, color: newTotal >= monthlySalary ? Colors.green : Colors.orange)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amount = int.parse(amountController.text.trim());
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final maktabId = auth.currentUser?.dob ?? 'MAKTAB-001';

                      final totalAfter = alreadyPaid + amount;
                      String finalStatus = 'PAID';
                      if (totalAfter < monthlySalary) {
                        finalStatus = 'PARTIALLY PAID';
                      }

                      final sp = SalaryPayment(
                        teacherId: teacher.id!,
                        maktabId: maktabId,
                        salaryMonth: _selectedMonthStr,
                        amount: amount,
                        paymentDate: DateFormat('yyyy-MM-dd').format(paymentDate),
                        paymentMode: selectedMode,
                        upiIdSnapshot: teacher.upiId,
                        transactionReference: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                        status: finalStatus,
                        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        createdAt: DateTime.now().toIso8601String(),
                        updatedAt: DateTime.now().toIso8601String(),
                      );

                      final id = await _salaryRepository.insertPayment(sp);
                      final fullSp = sp.copyWith(id: id);
                      await _cloudSyncService.pushSalaryPayment(fullSp);

                      final managerId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
                      if (managerId != null) {
                        try {
                          await MessageRepository().insertMessage(
                            AppMessage(
                              senderId: managerId,
                              receiverId: teacher.teacherId ?? teacher.id ?? 0,
                              content:
                                  'Your salary for ${fullSp.salaryMonth} of ₹${fullSp.amount} '
                                  'has been paid via ${fullSp.paymentMode}.',
                              timestamp: DateTime.now(),
                            ),
                          );
                          CloudSyncService.instance.notifyDataChanged('messages');
                        } catch (e) {
                          debugPrint('[SalaryManagement] Error notifying teacher: $e');
                        }
                      }

                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        _loadSalaryData();

                        final receiptText = SalaryPdfGenerator.generatePaymentReceiptText(
                          payment: fullSp,
                          teacherName: teacher.name,
                          teacherMobile: teacher.mobile ?? '',
                          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
                        );

                        await showDialog(
                          context: context,
                          builder: (previewCtx) => ReceiptPreviewDialog(
                            title: 'Salary Recorded',
                            receiptText: receiptText,
                            recipientPhone: teacher.mobile ?? '',
                            onSend: () async {
                              Navigator.pop(previewCtx);
                              if (teacher.mobile != null && teacher.mobile!.isNotEmpty) {
                                final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
                                await WhatsAppUtility.sendSalarySlip(
                                  context,
                                  teacher.mobile!,
                                  teacher.name,
                                  (teacher.monthlySalary ?? fullSp.amount).toDouble(),
                                  fullSp.amount.toDouble(),
                                  fullSp.salaryMonth,
                                  paymentMode: fullSp.paymentMode,
                                  upiId: teacher.upiId,
                                  languageCode: 'en',
                                  senderName: sender,
                                );
                                await _salaryRepository.markReceiptSent(id);
                                _loadSalaryData();
                              }
                            },
                            onBuildPdf: () async {
                              final labels = ReceiptTemplates.get('en');
                              final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
                              return ReceiptPdfGenerator.buildSalaryReceiptPdf(
                                maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
                                teacherName: teacher.name,
                                salaryMonth: fullSp.salaryMonth,
                                amount: fullSp.amount,
                                paymentMode: fullSp.paymentMode,
                                paymentDate: DateTime.tryParse(fullSp.paymentDate) ?? DateTime.now(),
                                issuedBy: 'Management',
                                labels: labels,
                                senderName: sender,
                                notes: fullSp.notes,
                                transactionReference: fullSp.transactionReference,
                              );
                            },
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm & Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Share Receipt ───────────────────────────────────────────────────────

  void _shareReceipt(SalaryPayment payment, User teacher) {
    final receiptText = SalaryPdfGenerator.generatePaymentReceiptText(
      payment: payment,
      teacherName: teacher.name,
      teacherMobile: teacher.mobile ?? '',
      maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
    );

    showDialog(
      context: context,
      builder: (previewCtx) => ReceiptPreviewDialog(
        title: 'Salary Receipt',
        receiptText: receiptText,
        recipientPhone: teacher.mobile ?? '',
        onSend: () async {
          Navigator.pop(previewCtx);
          if (teacher.mobile != null && teacher.mobile!.isNotEmpty) {
            final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
            await WhatsAppUtility.sendSalarySlip(
              context,
              teacher.mobile!,
              teacher.name,
              (teacher.monthlySalary ?? payment.amount).toDouble(),
              payment.amount.toDouble(),
              payment.salaryMonth,
              paymentMode: payment.paymentMode,
              upiId: teacher.upiId,
              languageCode: 'en',
              senderName: sender,
            );
            if (payment.id != null) {
              await _salaryRepository.markReceiptSent(payment.id!);
              _loadSalaryData();
            }
          }
        },
        onBuildPdf: () async {
          final labels = ReceiptTemplates.get('en');
          final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
          return ReceiptPdfGenerator.buildSalaryReceiptPdf(
            maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
            teacherName: teacher.name,
            salaryMonth: payment.salaryMonth,
            amount: payment.amount,
            paymentMode: payment.paymentMode,
            paymentDate: DateTime.tryParse(payment.paymentDate) ?? DateTime.now(),
            issuedBy: 'Management',
            labels: labels,
            senderName: sender,
            notes: payment.notes,
            transactionReference: payment.transactionReference,
          );
        },
      ),
    );
  }

  // ── Edit Teacher Salary Config Dialog ────────────────────────────────────

  void _showEditSalaryConfigDialog(User teacher) {
    final salaryController = TextEditingController(text: (teacher.monthlySalary ?? 0).toString());
    final upiController = TextEditingController(text: teacher.upiId ?? '');
    String selectedMode = teacher.preferredPaymentMode ?? 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Salary Config — ${teacher.name}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: salaryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Salary (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: upiController,
              decoration: const InputDecoration(labelText: 'UPI ID (e.g. teacher@upi)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: ['UPI', 'Bank Transfer', 'Cash', 'Other'].contains(selectedMode) ? selectedMode : 'Cash',
              decoration: const InputDecoration(labelText: 'Preferred Payment Mode', border: OutlineInputBorder()),
              items: ['UPI', 'Bank Transfer', 'Cash', 'Other']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => selectedMode = val ?? 'Cash',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () async {
              final salary = int.tryParse(salaryController.text.trim()) ?? 0;
              final updated = teacher.copyWith(
                monthlySalary: salary,
                upiId: upiController.text.trim().isNotEmpty ? upiController.text.trim() : null,
                preferredPaymentMode: selectedMode,
              );
              await _userRepository.updateUser(updated);
              await _cloudSyncService.pushUser(updated);
              if (context.mounted) {
                Navigator.pop(ctx);
                _loadSalaryData();
              }
            },
            child: const Text('Save Config'),
          ),
        ],
      ),
    );
  }

  // ── Edit Payment Dialog ──────────────────────────────────────────────────

  void _showEditPaymentDialog(SalaryPayment payment, User teacher) {
    final amountController = TextEditingController(text: payment.amount.toString());
    final refController = TextEditingController(text: payment.transactionReference ?? '');
    final notesController = TextEditingController(text: payment.notes ?? '');
    String selectedMode = payment.paymentMode;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit Salary Payment — ${teacher.name}',
                style: const TextStyle(fontSize: 18, color: Color(0xFF004D40), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Payment Amount (₹)',
                          prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                          final amt = int.tryParse(val.trim());
                          if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ['UPI', 'Bank Transfer', 'Cash', 'Other'].contains(selectedMode) ? selectedMode : 'Cash',
                        decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                        items: ['UPI', 'Bank Transfer', 'Cash', 'Other']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedMode = val ?? 'Cash'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference / Txn ID (Optional)',
                          prefixIcon: Icon(Icons.numbers, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          prefixIcon: Icon(Icons.note_alt_outlined, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amount = int.parse(amountController.text.trim());
                      final updated = payment.copyWith(
                        amount: amount,
                        paymentMode: selectedMode,
                        transactionReference: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        updatedAt: DateTime.now().toIso8601String(),
                      );
                      await _salaryRepository.updatePayment(updated);
                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment updated successfully')),
                        );
                        _loadSalaryData();
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Delete Payment ────────────────────────────────────────────────────────

  Future<void> _deletePayment(SalaryPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Salary Payment'),
        content: Text('Delete this salary payment of ₹${payment.amount} for ${payment.salaryMonth}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && payment.id != null) {
      await _salaryRepository.deletePayment(payment.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully')),
        );
        _loadSalaryData();
      }
    }
  }

  // ── PDF Salary Report ───────────────────────────────────────────────────

  void _generateAndSharePdfReport() async {
    int totalSalary = 0;
    int totalPaid = 0;
    List<Map<String, dynamic>> reportData = [];

    for (var teacher in _teachers) {
      final sal = teacher.monthlySalary ?? 0;
      final paid = _getPaidAmountForTeacher(teacher.id!);
      final pending = (sal - paid).clamp(0, sal);
      totalSalary += sal;
      totalPaid += paid;

      reportData.add({
        'name': teacher.name,
        'monthlySalary': sal,
        'paid': paid,
        'pending': pending,
        'status': _getStatusForTeacher(teacher),
      });
    }

    final totalPending = (totalSalary - totalPaid).clamp(0, totalSalary);

    final pdfBytes = await SalaryPdfGenerator.generateSalaryReportPdf(
      maktabName: 'IDARA E DAWATHUL QURAAN',
      month: _monthDisplayStr,
      teacherSalaryData: reportData,
      totalSalary: totalSalary,
      totalPaid: totalPaid,
      totalPending: totalPending,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'Salary_Report_$_selectedMonthStr.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.currentUser?.role ?? 'teacher';

    // Verify Manager/Operator role authorization
    if (userRole != 'admin' && userRole != 'manager' && userRole != 'operator') {
      return Scaffold(
        appBar: AppBar(title: const Text('Salary Management')),
        body: const Center(
          child: Text('Access Denied. Only Managers/Operators can view salary data.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }

    int totalTeachers = _teachers.length;
    int totalMonthlySalary = _teachers.fold(0, (sum, t) => sum + (t.monthlySalary ?? 0));
    int totalPaidThisMonth = 0;
    for (var t in _teachers) {
      totalPaidThisMonth += _getPaidAmountForTeacher(t.id!);
    }
    int totalPendingThisMonth = (totalMonthlySalary - totalPaidThisMonth).clamp(0, totalMonthlySalary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary & Payment Management'),
                flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Report',
            onPressed: _generateAndSharePdfReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSalaryData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_salaryTotals.isNotEmpty) ...[
                      SalaryTotalsCard(totals: _salaryTotals),
                      const SizedBox(height: 16),
                    ],
                    // Month Navigation Header
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Color(0xFF004D40)),
                              onPressed: () => _changeMonth(-1),
                            ),
                            Text(
                              _monthDisplayStr.toUpperCase(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Color(0xFF004D40)),
                              onPressed: () => _changeMonth(1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Salary Summary Dashboard Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        _buildSummaryCard('Total Teachers', totalTeachers.toString(), Icons.group, Colors.blue),
                        _buildSummaryCard('Monthly Salary', '₹$totalMonthlySalary', Icons.account_balance_wallet, const Color(0xFF004D40)),
                        _buildSummaryCard('Paid This Month', '₹$totalPaidThisMonth', Icons.check_circle, Colors.green),
                        _buildSummaryCard('Pending Due', '₹$totalPendingThisMonth', Icons.pending_actions, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TEACHER SALARY LIST',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Summary'),
                          onPressed: () {
                            final summary = 'SALARY SUMMARY — $_monthDisplayStr\nTeachers: $totalTeachers\nTotal: ₹$totalMonthlySalary\nPaid: ₹$totalPaidThisMonth\nPending: ₹$totalPendingThisMonth';
                            final managerMobile = auth.currentUser?.mobile ?? '';
                            WhatsAppUtility.launchWhatsApp(managerMobile, summary);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Section 4: Teacher Salary List
                    _teachers.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No active teachers found.')),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _teachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _teachers[index];
                              final salary = teacher.monthlySalary ?? 0;
                              final paid = _getPaidAmountForTeacher(teacher.id!);
                              final remaining = (salary - paid).clamp(0, salary);
                              final status = _getStatusForTeacher(teacher);

                              Color statusColor;
                              IconData statusIcon;
                              if (status == 'PAID') {
                                statusColor = Colors.green;
                                statusIcon = Icons.check_circle;
                              } else if (status == 'PARTIALLY PAID') {
                                statusColor = Colors.orange;
                                statusIcon = Icons.warning;
                              } else {
                                statusColor = Colors.red;
                                statusIcon = Icons.cancel;
                              }

                              final allTeacherPayments = _allPaymentsMap[teacher.id] ?? [];
                              final currentYearStr = DateTime.now().year.toString();
                              final totalPaidThisYear = allTeacherPayments
                                  .where((p) => p.salaryMonth.startsWith(currentYearStr))
                                  .fold(0, (sum, p) => sum + p.amount);
                              final totalPaidAllTime = allTeacherPayments.fold(0, (sum, p) => sum + p.amount);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                teacher.name,
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'This Month: ₹$paid / ₹$salary',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(statusIcon, size: 14, color: statusColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                status,
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildDetailColumn('Monthly Salary', '₹$salary'),
                                          _buildDetailColumn('Paid', '₹$paid', color: Colors.green),
                                          _buildDetailColumn('Pending Due', '₹$remaining', color: Colors.red),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Action Buttons Row
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.payments, size: 16),
                                            label: const Text('PAY SALARY'),
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _showRecordPaymentDialog(teacher),
                                          ),
                                          if (teacher.upiId != null && teacher.upiId!.isNotEmpty && remaining > 0)
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.qr_code, size: 16),
                                              label: const Text('PAY VIA UPI'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF004D40),
                                                side: const BorderSide(color: Color(0xFF004D40)),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () => _launchUpiPayment(teacher, remaining),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.settings, color: Colors.grey),
                                            tooltip: 'Edit Salary Config',
                                            onPressed: () => _showEditSalaryConfigDialog(teacher),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Expanded Header: Total paid this year & all time
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2F1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            Column(
                                              children: [
                                                const Text('Paid This Year', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                const SizedBox(height: 2),
                                                Text('₹$totalPaidThisYear', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                              ],
                                            ),
                                            Container(width: 1, height: 30, color: Colors.black26),
                                            Column(
                                              children: [
                                                const Text('Paid All Time', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                const SizedBox(height: 2),
                                                Text('₹$totalPaidAllTime', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Payment History Body
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Payment History (${allTeacherPayments.length})',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (allTeacherPayments.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Text('No salary payments recorded yet.', style: TextStyle(fontSize: 12, color: Colors.black45)),
                                        )
                                      else
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: allTeacherPayments.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, pIndex) {
                                            final p = allTeacherPayments[pIndex];
                                            return ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                p.receiptSent == 1 ? Icons.check_circle_rounded : Icons.access_time_rounded,
                                                color: p.receiptSent == 1 ? Colors.green : Colors.amber.shade800,
                                                size: 20,
                                              ),
                                              title: Text('₹${p.amount} — ${p.salaryMonth}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              subtitle: Text('${p.paymentDate} • ${p.paymentMode}${p.transactionReference != null && p.transactionReference!.isNotEmpty ? " • Ref: ${p.transactionReference}" : ""}'),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.share, size: 18, color: Color(0xFF004D40)),
                                                    tooltip: 'Share Receipt',
                                                    onPressed: () => _shareReceipt(p, teacher),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                                    tooltip: 'Edit Payment',
                                                    onPressed: () => _showEditPaymentDialog(p, teacher),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                    tooltip: 'Delete Payment',
                                                    onPressed: () => _deletePayment(p),
                                                  ),
                                                ],
                                              ),
                                            );
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
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }
}

/// Tab-body alias used by PaymentsHubScreen.
/// Delegates entirely to [TeacherSalaryManagementScreen]; no logic is changed.
class TeacherSalaryScreenBody extends StatelessWidget {
  const TeacherSalaryScreenBody({super.key});

  @override
  Widget build(BuildContext context) => const TeacherSalaryManagementScreen();
}
