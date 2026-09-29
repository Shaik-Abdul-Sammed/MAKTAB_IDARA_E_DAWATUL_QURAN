import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../utils/reminder_formatter.dart";
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_icons.dart';
import '../../models/fee_payment.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../services/notification_service.dart';
import '../../services/database_helper.dart';
import '../../models/batch.dart';
import '../../utils/whatsapp_utility.dart';
import '../../utils/language_resolver.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/finance/finance_totals_card.dart';
import '../../widgets/finance/fee_card.dart';
import '../../widgets/finance/fee_payments_list_widget.dart';

import '../../widgets/bulk_fee_messaging_dialog.dart';

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
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
      
      final feeTotals = await FeePaymentRepository().getFeeTotals();
      final modeBreakdown = await FeePaymentRepository().getFeeModeBreakdown();

      if (mounted) {
        setState(() {
          _batches = batches;
          _feeItems = items;
          _feeTotals = feeTotals;
          _modeBreakdown = modeBreakdown;
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
        content: Text('Notification sent for ${item.student.name}!', maxLines: 2, overflow: TextOverflow.ellipsis),
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
        languageCode: LanguageResolver.forStudent(item.student),
      ),
    );
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $phone', maxLines: 2, overflow: TextOverflow.ellipsis)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to launch WhatsApp.', maxLines: 2, overflow: TextOverflow.ellipsis)),
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
          title: loc?.translate('fee_mgmt_title') ?? 'Fee Management & Reminders',
          actions: [
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _openBulkMessagingDialog,
              tooltip: loc?.translate('fee_mgmt_bulk_reminders') ?? 'Send Bulk Batch Reminders',
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: loc?.translate('fee_mgmt_tab_status') ?? 'Fee Status', icon: const Icon(Icons.people_alt_outlined, size: 18)),
              Tab(text: loc?.translate('fee_mgmt_tab_history') ?? 'Payment History', icon: const Icon(Icons.history_rounded, size: 18)),
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
                          title: 'Collection Overview',
                          periodTotals: _feeTotals,
                          modeBreakdown: _modeBreakdown,
                        ),

                      // ── Search bar ──────────────────────────────────────────────
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
                            return FeeCard(
                              item: item,
                              onWhatsApp: () => _sendWhatsAppReminder(item),
                              onNotify: () => _triggerNotification(item),
                              onLog: () => _showRecordDialog(item, defaultAmount: item.amountDue > 0 ? item.amountDue : null),
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
                onPaymentRecorded: _loadFeeRecords,
              ),
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
              
              // We need to update the student in DB
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
      languageCode: LanguageResolver.forStudent(item.student),
      senderName: collectorName,
    );
  }

  void _showRecordDialog(FeeStudentItem item, {String defaultMode = 'Cash', double? defaultAmount}) {
    bool isRecording = false;
    final AudioRecorder audioRecorder = AudioRecorder();
    String? recordFilePath;
    String selectedMode = defaultMode;
    final modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Online'];

    final monthlyFee = (item.student.feesAmount ?? 500).toDouble();
    final remainingDue = item.amountDue;
    final alreadyPaid = (monthlyFee - remainingDue).clamp(0.0, monthlyFee);

    final defaultAmtVal = defaultAmount ?? (remainingDue > 0 ? remainingDue : 0.0);
    final amountCtrl = TextEditingController(text: defaultAmtVal > 0 ? defaultAmtVal.toInt().toString() : '');
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();
    bool sendReceiptWhatsApp = true;

    final formKey = GlobalKey<FormState>();

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
            title: Text('Record Collection: ${item.student.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
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
                            Flexible(child: Text('₹${monthlyFee.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Expanded(child: Text('Already Paid:', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Flexible(child: Text('₹${alreadyPaid.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Expanded(child: Text('Remaining Due:', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Flexible(child: Text('₹${remainingDue.toInt()}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount Paying Now',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setStateBuilder(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                        final amt = double.tryParse(val.trim());
                        if (amt == null || amt <= 0) return 'Enter a valid amount > 0';
                        return null;
                      },
                    ),
                    if (payingNow > remainingDue)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  remainingDue > 0
                                      ? 'Note: ₹${(payingNow - remainingDue).toInt()} will be recorded as advance payment.'
                                      : 'Note: Full amount of ₹${payingNow.toInt()} is an advance payment.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: modes.contains(selectedMode) ? selectedMode : modes.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: modes.toSet().map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        if (val != null) setStateBuilder(() => selectedMode = val);
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
                  if (!context.mounted) return;

                  final amt = int.tryParse(amountCtrl.text.trim()) ?? (double.tryParse(amountCtrl.text.trim())?.round() ?? 0);
                  final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate);
                  final month = DateFormat('MMMM yyyy').format(paymentDate);

                  final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
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
                    collectedBy: currentUser?.id,
                  );

                  await FeePaymentRepository().insertFeePayment(newPayment);

                  if (!context.mounted) return;
                  Navigator.pop(dialogCtx);
                  _loadFeeRecords();

                  final collectorName = currentUser?.name ?? 'Management';

                  if (sendReceiptWhatsApp) {
                    await WhatsAppUtility.sendFeeReceipt(
                      context,
                      item.student.phone ?? '',
                      item.student.name,
                      amt.toDouble(),
                      month,
                      paymentMode: selectedMode,
                      dateTime: formattedTime,
                      collectorName: collectorName,
                      languageCode: LanguageResolver.forStudent(item.student),
                      senderName: collectorName,
                    );
                  }

                  if (context.mounted) {
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
                              collectorName: collectorName,
                              languageCode: LanguageResolver.forStudent(item.student),
                              senderName: collectorName,
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

}

/// Tab-body alias used by PaymentsHubScreen.
/// Delegates entirely to [FeeManagementScreen]; no logic is changed.
class FeeManagementScreenBody extends StatelessWidget {
  const FeeManagementScreenBody({super.key});

  @override
  Widget build(BuildContext context) => const FeeManagementScreen();
}
