import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../utils/reminder_formatter.dart";
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_icons.dart';
import '../../config/app_routes.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../services/notification_service.dart';
import '../../services/database_helper.dart';
import '../../models/batch.dart';
import '../../utils/whatsapp_utility.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

import '../../widgets/bulk_fee_messaging_dialog.dart';

class FeeStudentItem {
  final Student student;
  final double amountDue;
  final String dueDate;
  final String status;

  FeeStudentItem({
    required this.student,
    required this.amountDue,
    required this.dueDate,
    required this.status,
  });
}

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  List<FeeStudentItem> _feeItems = [];
  List<Batch> _batches = [];
  bool _isLoading = true;
  String _filter = 'All';
  int? _selectedBatchId;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFeeRecords();
  }

  Future<void> _loadFeeRecords() async {
    setState(() => _isLoading = true);
    try {
      final students = await StudentRepository().getAllStudents();
      final batches = await BatchRepository().getAllBatches();
      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
      
      final List<FeeStudentItem> items = [];
      for (var s in students) {
        if (_selectedBatchId != null && s.batchId != _selectedBatchId) continue;
        
        final feeAmount = (s.feesAmount ?? 500).toDouble();
        final payments = await FeePaymentRepository().getPaymentsForStudent(s.id!);
        
        // Check if there is a payment in the current month
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
      
      if (mounted) {
        setState(() {
          _batches = batches;
          _feeItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerNotification(FeeStudentItem item) async {
    final granted = await PermissionHelper.requestPermissionWithRationale(
      context: context,
      permission: Permission.notification,
      title: 'Notification Permission',
      rationale: 'Maktab App needs permission to show instant fee reminder notifications on your device.',
    );
    if (!granted) return;

    await NotificationService().showFeeReminderNotification(
      studentName: item.student.name,
      amount: item.amountDue,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification sent for ${item.student.name}!'),
        backgroundColor: AppIcons.primaryTeal,
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(FeeStudentItem item) async {
    final phone = item.student.phone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
      ReminderFormatter.formatFeeReminder(
        amountDue: item.amountDue,
        studentName: item.student.name,
        admissionNumber: item.student.admissionNumber,
        dueDate: item.dueDate,
      ),
    );
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $phone')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to launch WhatsApp.')),
      );
    }
  }

  Future<void> _payViaUpi(FeeStudentItem item) async {
    final upiUrl = Uri.parse(
      'upi://pay?pa=maktab@upi&pn=MaktabQuran&am=${item.amountDue}&cu=INR&tn=Fee_${item.student.admissionNumber}',
    );
    try {
      if (await canLaunchUrl(upiUrl)) {
        await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPI App launched for ₹${item.amountDue.toInt()}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulated UPI intent for ₹${item.amountDue.toInt()}')),
      );
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

  @override
  Widget build(BuildContext context) {
    final filtered = _feeItems.where((i) {
      if (_filter == 'All') return true;
      return i.status == _filter;
    }).toList();

    final totalPending = _feeItems
        .where((i) => i.status != 'Paid')
        .fold(0.0, (sum, item) => sum + item.amountDue);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Fee Management & Reminders',
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: _openBulkMessagingDialog,
            tooltip: 'Send Bulk Batch Reminders',
          ),
          IconButton(
            icon: const Icon(AppIcons.history),
            onPressed: () => context.push(AppRoutes.adminFeeHistory),
            tooltip: 'Payment History',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryBanner(totalPending),
              const SizedBox(height: 20),

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
                    DropdownButton<int?>(
                      value: _selectedBatchId,
                      hint: const Text('Filter Batch'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Batches')),
                        ..._batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedBatchId = val;
                        });
                        _loadFeeRecords();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading) ...[
                ShimmerLoader(height: 110),
                const SizedBox(height: 12),
                ShimmerLoader(height: 110),
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
                    return _FeeCard(
                      item: item,
                      onPayUpi: () => _payViaUpi(item),
                      onWhatsApp: () => _sendWhatsAppReminder(item),
                      onNotify: () => _triggerNotification(item),
                      onLog: () => _showRecordDialog(item),
                      onEdit: () => _editFeeStructure(item),
                    );
                  },
                ),
              ],
            ],
          ),
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
              
              // We need to update the student in DB
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
    final payments = await FeePaymentRepository().getPaymentsForStudent(item.student.id!);
    if (payments.isEmpty) return;
    final lastPayment = payments.first; // desc timestamp

    final phone = item.student.phone ?? '';
    final rawTime = lastPayment.timestamp;
    final parsed = DateTime.tryParse(rawTime);
    final formattedTime = parsed != null ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed) : rawTime;
    final month = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : rawTime.split('T')[0];

    if (!mounted) return;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final collectorName = currentUser != null && currentUser.name.isNotEmpty ? currentUser.name : 'Management';

    await WhatsAppUtility.sendFeeReceipt(
      context,
      phone,
      item.student.name,
      lastPayment.amount.toDouble(),
      month,
      paymentMode: lastPayment.mode,
      dateTime: formattedTime,
      collectorName: collectorName,
    );
  }

  void _showRecordDialog(FeeStudentItem item) {
    bool isRecording = false;
    final AudioRecorder audioRecorder = AudioRecorder();
    String? recordFilePath;
    String selectedMode = 'Cash';
    final modes = ['Cash', 'Online', 'UPI', 'Cheque', 'Bank Transfer'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: Text('Log Payment: ${item.student.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Fee: ₹${item.student.feesAmount ?? 500}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setStateBuilder(() => selectedMode = val);
                },
              ),
              const SizedBox(height: 16),
              const Text('Voice Note (Optional):', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      if (await audioRecorder.hasPermission()) {
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
                await FeePaymentRepository().insertFeePayment(newPayment);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadFeeRecords();

                  final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                  final collectorName = currentUser?.name ?? 'Management';
                  final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(now);
                  final month = DateFormat('MMMM yyyy').format(now);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment Logged Successfully!'),
                      backgroundColor: const Color(0xFF004D40),
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
                            collectorName: collectorName,
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
          Row(
            children: [
              const Icon(AppIcons.fees, color: AppIcons.gold, size: 40),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pending Monthly Fees', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹${totalPending.toInt()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                ],
              ),
            ],
          ),
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
}

class _FeeCard extends StatelessWidget {
  final FeeStudentItem item;
  final VoidCallback onPayUpi;
  final VoidCallback onWhatsApp;
  final VoidCallback onNotify;
  final VoidCallback onLog;
  final VoidCallback onEdit;

  const _FeeCard({
    required this.item,
    required this.onPayUpi,
    required this.onWhatsApp,
    required this.onNotify,
    required this.onLog,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = item.student;
    Color statusColor = Colors.green.shade700;
    if (item.status == 'Overdue') statusColor = Colors.red.shade700;
    if (item.status == 'Pending') statusColor = Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppIcons.primaryTeal,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('ADM: ${s.admissionNumber} · ${s.phone ?? 'No phone'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(item.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Due: ${item.dueDate}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('₹${item.amountDue.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppIcons.primaryTeal)),
            ],
          ),
          const SizedBox(height: 12),

          if (item.status != 'Paid') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPayUpi,
                    icon: const Icon(Icons.payment_rounded, size: 14),
                    label: const Text('Pay UPI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppIcons.gold,
                      foregroundColor: AppIcons.primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(AppIcons.whatsapp, size: 14),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppIcons.whatsappGreen,
                      side: const BorderSide(color: AppIcons.whatsappGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLog,
                    icon: const Icon(Icons.mic, size: 14),
                    label: const Text('Log/Voice', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blueGrey, size: 20),
                    tooltip: 'Edit Fee Amount',
                    onPressed: onEdit,
                  ),
                IconButton(
                  icon: const Icon(AppIcons.notification, color: AppIcons.primaryTeal, size: 20),
                  tooltip: 'Send Local App Notification',
                  onPressed: onNotify,
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => (context as Element).findAncestorStateOfType<_FeeManagementScreenState>()?._sendReceipt(item),
                    icon: const Icon(AppIcons.whatsapp, size: 14),
                    label: const Text('Send Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppIcons.whatsappGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
