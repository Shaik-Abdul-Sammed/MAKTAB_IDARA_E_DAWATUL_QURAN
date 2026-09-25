import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/app_icons.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../models/fee_payment.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../utils/reminder_formatter.dart';
import '../../utils/whatsapp_utility.dart';
import '../../utils/language_resolver.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/finance/finance_totals_card.dart';
import '../../widgets/finance/fee_card.dart';
import '../../widgets/finance/fee_payments_list_widget.dart';
import '../../widgets/bulk_fee_messaging_dialog.dart';

class TeacherFeesScreen extends StatefulWidget {
  const TeacherFeesScreen({super.key});

  @override
  State<TeacherFeesScreen> createState() => _TeacherFeesScreenState();
}

class _TeacherFeesScreenState extends State<TeacherFeesScreen> {
  final FeePaymentRepository _feeRepo = FeePaymentRepository();
  final StudentRepository _studentRepo = StudentRepository();
  final BatchRepository _batchRepo = BatchRepository();

  List<FeeStudentItem> _feeItems = [];
  List<Batch> _batches = [];
  Map<String, int> _feeTotals = const {};
  Map<String, int> _modeBreakdown = const {};
  bool _isLoading = true;
  String _filter = 'All';
  String _searchQuery = '';
  int? _selectedBatchId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  int _teacherId = 0;
  String _teacherName = '';

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
    _teacherName = auth.currentUser?.name ?? 'Teacher';
    _loadFeeRecords();
  }

  Future<void> _loadFeeRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final students = await _studentRepo.getStudentsByTeacher(_teacherId);
      final batches = await _batchRepo.getBatchesByTeacher(_teacherId);
      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

      final List<FeeStudentItem> items = [];
      for (var s in students) {
        if (_selectedBatchId != null && s.batchId != _selectedBatchId) continue;

        final feeAmount = (s.feesAmount ?? 500).toDouble();
        final payments = await _feeRepo.getPaymentsForStudent(s.id!);

        bool paidThisMonth = false;
        for (var p in payments) {
          if (p.timestamp.startsWith(currentMonthStr)) {
            paidThisMonth = true;
            break;
          }
        }

        final dueDate = DateFormat('yyyy-MM-10').format(DateTime.now());
        final isOverdue = !paidThisMonth && DateTime.now().day > 10;

        items.add(FeeStudentItem(
          student: s,
          amountDue: paidThisMonth ? 0.0 : feeAmount,
          dueDate: dueDate,
          status: paidThisMonth ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending'),
        ));
      }

      final feeTotals = await _feeRepo.getFeeTotalsForTeacher(_teacherId);
      final modeBreakdown = await _feeRepo.getFeeModeBreakdown(canonicalTeacherId: _teacherId);

      if (mounted) {
        setState(() {
          _batches = batches;
          _feeItems = items;
          _feeTotals = feeTotals;
          _modeBreakdown = modeBreakdown;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherFeesScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBulkMessagingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BulkFeeMessagingDialog(
        batches: _batches,
        initialBatchId: _selectedBatchId,
      ),
    ).then((_) => _loadFeeRecords());
  }

  Future<void> _payViaUpi(FeeStudentItem item) async {
    final s = item.student;
    final upiUrl = 'upi://pay?pa=maktab@upi&pn=Maktab&am=${item.amountDue}&cu=INR&tn=Fee_${s.admissionNumber}';
    final uri = Uri.parse(upiUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI application found on device.')),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder(FeeStudentItem item) async {
    final s = item.student;
    final phone = s.guardianPhone ?? s.phone ?? '';
    final msg = ReminderFormatter.formatFeeReminder(
      studentName: s.name,
      amount: item.amountDue,
      dueDate: item.dueDate,
      lang: LanguageResolver.forStudent(s),
      senderName: _teacherName,
    );
    await WhatsAppUtility.sendMessage(context, phone, msg);
  }

  Future<void> _triggerNotification(FeeStudentItem item) async {
    final s = item.student;
    await NotificationService().showNotification(
      id: s.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Fee Reminder: ${s.name}',
      body: 'Monthly fee of ₹${item.amountDue.toInt()} is ${item.status.toLowerCase()}.',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent for ${s.name}')),
      );
    }
  }

  void _showRecordDialog(FeeStudentItem item) {
    String selectedMode = 'Cash';
    final audioRecorder = AudioRecorder();
    bool isRecording = false;
    String? recordFilePath;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: Text('Record Fee Payment: ${item.student.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Fee: ₹${item.student.feesAmount ?? 500}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                items: ['Cash', 'UPI', 'Bank', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) {
                  if (v != null) setStateBuilder(() => selectedMode = v);
                },
              ),
              const SizedBox(height: 16),
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
                      if (await PermissionHelper.requestMicrophonePermission(context)) {
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
                    radius: 32,
                    backgroundColor: isRecording ? Colors.red : AppIcons.primaryTeal,
                    child: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
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
          actions: [
            TextButton(
              onPressed: () {
                if (isRecording) audioRecorder.stop();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isRecording) await audioRecorder.stop();
                final amt = item.student.feesAmount ?? 500;
                final now = DateTime.now();
                final timestamp = now.toIso8601String();

                final newPayment = FeePayment(
                  studentId: item.student.id!,
                  amount: amt,
                  mode: selectedMode,
                  timestamp: timestamp,
                  voiceNotePath: recordFilePath,
                );
                await _feeRepo.insertFeePayment(newPayment);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadFeeRecords();

                  final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(now);
                  final month = DateFormat('MMMM yyyy').format(now);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment Logged Successfully!'),
                      action: SnackBarAction(
                        label: 'Send Receipt',
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
        ),
      ),
    );
  }

  void _editFeeStructure(FeeStudentItem item) {
    final amountCtrl = TextEditingController(text: (item.student.feesAmount ?? 500).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${item.student.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee structure updated successfully')));
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

  Widget _buildSummaryBanner(double totalPending) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppIcons.primaryTeal, Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppIcons.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(AppIcons.fees, color: AppIcons.gold, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pending Monthly Fees',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalPending.toInt()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _openBulkMessagingDialog,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Bulk Batch Reminders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppIcons.gold,
              foregroundColor: const Color(0xFF004D40),
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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

    final totalPending = _feeItems
        .where((i) => i.status != 'Paid')
        .fold(0.0, (sum, item) => sum + item.amountDue);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: 'Student Fees',
          actions: [
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _openBulkMessagingDialog,
              tooltip: 'Send Bulk Batch Reminders',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fee Status', icon: Icon(Icons.people_alt_outlined, size: 18)),
              Tab(text: 'Payment History', icon: Icon(Icons.history_rounded, size: 18)),
            ],
            indicatorColor: AppIcons.gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: _loadFeeRecords,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_feeTotals.isNotEmpty)
                        FinanceTotalsCard(
                          title: 'My Collection',
                          periodTotals: _feeTotals,
                          modeBreakdown: _modeBreakdown,
                        ),
                      _buildSummaryBanner(totalPending),
                      const SizedBox(height: 16),

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
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
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
                                return DropdownButton<int?>(
                                  value: hasMatch ? _selectedBatchId : null,
                                  hint: const Text('Filter Batch'),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Batches')),
                                    ...uniqueBatches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBatchId = val;
                                    });
                                    _loadFeeRecords();
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

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
                              onPayUpi: () => _payViaUpi(item),
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
                  ),
                ),
              ),
              FeePaymentsListWidget(
                teacherId: _teacherId,
                onPaymentRecorded: _loadFeeRecords,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
