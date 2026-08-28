import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/batch.dart';
import '../models/student.dart';
import '../repositories/fee_payment_repository.dart';
import '../repositories/student_repository.dart';
import '../services/notification_service.dart';
import '../utils/whatsapp_utility.dart';

class BulkFeeMessagingDialog extends StatefulWidget {
  final List<Batch> batches;
  final int? initialBatchId;
  final List<Student>? students;

  const BulkFeeMessagingDialog({
    super.key,
    required this.batches,
    this.initialBatchId,
    this.students,
  });

  @override
  State<BulkFeeMessagingDialog> createState() => _BulkFeeMessagingDialogState();
}

class _BulkFeeStudentItem {
  final Student student;
  final String batchName;
  final double amountDue;
  final String status;
  bool isSelected;

  _BulkFeeStudentItem({
    required this.student,
    required this.batchName,
    required this.amountDue,
    required this.status,
    this.isSelected = true,
  });
}

class _BulkFeeMessagingDialogState extends State<BulkFeeMessagingDialog> {
  int? _selectedBatchId;
  String _statusFilter = 'Pending/Overdue'; // 'Pending/Overdue', 'Overdue Only', 'All'
  bool _isLoading = true;
  List<_BulkFeeStudentItem> _items = [];
  final Map<int, String> _batchMap = {};

  final TextEditingController _templateCtrl = TextEditingController(
    text:
        'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN that the monthly fee of ₹{Amount} for {StudentName} (Adm: {AdmissionNo}) is due. JazakAllah Khair.',
  );

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.initialBatchId;
    for (var b in widget.batches) {
      if (b.id != null) {
        _batchMap[b.id!] = b.name;
      }
    }
    _loadStudentsAndFees();
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsAndFees() async {
    setState(() => _isLoading = true);
    try {
      final allStudents = widget.students ?? await StudentRepository().getAllStudents();
      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

      final List<_BulkFeeStudentItem> loaded = [];
      for (var s in allStudents) {
        if (_selectedBatchId != null && s.batchId != _selectedBatchId) {
          continue;
        }

        final bName = s.batchId != null ? (_batchMap[s.batchId!] ?? 'Unassigned Batch') : 'Unassigned Batch';
        final feeAmount = (s.feesAmount ?? 500).toDouble();

        bool paidThisMonth = false;
        if (s.id != null && widget.students == null) {
          try {
            final payments = await FeePaymentRepository().getPaymentsForStudent(s.id!);
            for (var p in payments) {
              if (p.timestamp.startsWith(currentMonthStr)) {
                paidThisMonth = true;
                break;
              }
            }
          } catch (_) {}
        }

        final isOverdue = !paidThisMonth && DateTime.now().day > 10;
        final status = paidThisMonth ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending');

        // Apply status filter
        if (_statusFilter == 'Pending/Overdue' && paidThisMonth) continue;
        if (_statusFilter == 'Overdue Only' && status != 'Overdue') continue;

        loaded.add(_BulkFeeStudentItem(
          student: s,
          batchName: bName,
          amountDue: paidThisMonth ? 0.0 : feeAmount,
          status: status,
          isSelected: true,
        ));
      }

      if (mounted) {
        setState(() {
          _items = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAll(bool select) {
    setState(() {
      for (var item in _items) {
        item.isSelected = select;
      }
    });
  }

  String _formatMessageForStudent(_BulkFeeStudentItem item) {
    final s = item.student;
    return _templateCtrl.text
        .replaceAll('{StudentName}', s.name)
        .replaceAll('{Amount}', item.amountDue.toInt().toString())
        .replaceAll('{AdmissionNo}', s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A')
        .replaceAll('{BatchName}', item.batchName);
  }

  Future<void> _startWhatsAppQueue() async {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected for message broadcast.')),
      );
      return;
    }

    final lang = await WhatsAppUtility.promptLanguageSelection(context);
    if (lang == null) return;

    // Set template based on selected language
    switch (lang) {
      case Language.english:
        _templateCtrl.text = 'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN that the monthly fee of ₹{Amount} for {StudentName} (Adm: {AdmissionNo}) is due. JazakAllah Khair.';
        break;
      case Language.urdu:
        _templateCtrl.text = 'السلام علیکم، یہ مکتب ادارہ دعوت القرآن کی طرف سے ایک یاد دہانی ہے کہ {StudentName} (داخلہ نمبر: {AdmissionNo}) کی ماہانہ فیس ₹{Amount} واجب الادا ہے۔ جزاک اللہ خیر۔';
        break;
      case Language.hindi:
        _templateCtrl.text = 'अस्सलामु अलैकुम, यह मकतब इदारा दावतुल कुरआन की ओर से एक अनुस्मारक है कि {StudentName} (प्रवेश संख्या: {AdmissionNo}) का मासिक शुल्क ₹{Amount} देय है। जज़ाकल्लाह खैर।';
        break;
      case Language.telugu:
        _templateCtrl.text = 'అస్సలాము అలైకుమ్, మక్తబ్ ఇదారా ఎ దావతుల్ ఖురాన్ నుండి ఇది ఒక జ్ఞాపిక. {StudentName} (అడ్మిషన్ నంబరు: {AdmissionNo}) నెలవారీ ఫీజు ₹{Amount} చెల్లించాల్సి ఉంది. జజాకల్లా ఖైర్.';
        break;
    }

    int sentCount = 0;
    for (int i = 0; i < selected.length; i++) {
      final item = selected[i];
      final phone = item.student.phone ?? item.student.guardianPhone ?? '';
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

      if (cleanPhone.isEmpty) continue;

      final text = _formatMessageForStudent(item);
      final formattedPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
      final url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}');

      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          sentCount++;
          // Give time for user to return before launching next in queue if multiple
          if (i < selected.length - 1 && mounted) {
            final continueNext = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: Text('WhatsApp Queue (${i + 1}/${selected.length})'),
                content: Text(
                  'Sent message to ${item.student.name}.\nNext student: ${selected[i + 1].student.name}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel Remaining'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Send to Next Student', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (continueNext != true) break;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completed WhatsApp Queue: Sent $sentCount reminders!'),
          backgroundColor: const Color(0xFF004D40),
        ),
      );
    }
  }

  Future<void> _sendLocalNotifications() async {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected for notification.')),
      );
      return;
    }

    int count = 0;
    for (var item in selected) {
      await NotificationService().showFeeReminderNotification(
        studentName: item.student.name,
        amount: item.amountDue,
      );
      count++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent $count local fee reminder notifications!'),
          backgroundColor: const Color(0xFF004D40),
        ),
      );
    }
  }

  void _shareBatchReport() {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return;

    final batchNameStr = _selectedBatchId != null ? (_batchMap[_selectedBatchId!] ?? 'Batch') : 'All Batches';
    final totalDue = selected.fold(0.0, (sum, i) => sum + i.amountDue);

    final buf = StringBuffer();
    buf.writeln('📋 BATCH FEE SUMMARY REPORT');
    buf.writeln('─────────────────────────');
    buf.writeln('🏫 Batch: $batchNameStr');
    buf.writeln('📅 Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}');
    buf.writeln('👥 Pending Students: ${selected.length}');
    buf.writeln('💰 Total Pending Amount: ₹${totalDue.toInt()}');
    buf.writeln('─────────────────────────\n');

    for (int i = 0; i < selected.length; i++) {
      final item = selected[i];
      final adm = item.student.admissionNumber.isNotEmpty ? item.student.admissionNumber : 'N/A';
      buf.writeln('${i + 1}. [Adm: $adm] ${item.student.name} — ₹${item.amountDue.toInt()} [${item.status}]');
    }

    buf.write('\n─────────────────────────\nFrom: MAKTAB IDARA E DAWATUL QURAN');
    SharePlus.instance.share(ShareParams(text: bufferToString(buf)));
  }

  String bufferToString(StringBuffer buf) => buf.toString();

  @override
  Widget build(BuildContext context) {
    final selectedCount = _items.where((i) => i.isSelected).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF9FBE7),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.send_rounded, color: Color(0xFF004D40), size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Bulk Batch Fee Reminders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004D40),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Batch & Status Filter Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedBatchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Class / Batch',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Batches', style: TextStyle(fontSize: 12))),
                      ...widget.batches.map(
                        (b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 12))),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBatchId = val);
                      _loadStudentsAndFees();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Status Filter',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Pending/Overdue', child: Text('Pending & Overdue', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'Overdue Only', child: Text('Overdue Only', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'All', child: Text('All Students', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _statusFilter = val);
                        _loadStudentsAndFees();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Template Language Selection Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Text('🇬🇧', style: TextStyle(fontSize: 10)),
                    label: const Text('English', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _templateCtrl.text =
                            'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN that the monthly fee of ₹{Amount} for {StudentName} (Adm: {AdmissionNo}) is due. JazakAllah Khair.';
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Text('🇵🇰', style: TextStyle(fontSize: 10)),
                    label: const Text('Urdu', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _templateCtrl.text =
                            'السلام علیکم، مکتب ادارہ دعوت القرآن کی طرف سے یاد دہانی کہ {StudentName} (داخلہ نمبر: {AdmissionNo}) کی ماہانہ فیس ₹{Amount} واجب الادا ہے۔ جزاک اللہ خیر۔';
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Text('🇮🇳', style: TextStyle(fontSize: 10)),
                    label: const Text('Hindi', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _templateCtrl.text =
                            'अस्सलामु अलैकुम, मकतब इदारे दावतुल क़ुरआन की ओर से अनुस्मारक कि {StudentName} (प्रवेश संख्या: {AdmissionNo}) की मासिक फीस ₹{Amount} देय है। जज़ाकल्लाह खैर।';
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Text('🇮🇳', style: TextStyle(fontSize: 10)),
                    label: const Text('Telugu (తెలుగు)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _templateCtrl.text =
                            'అస్సలాము అలైకుమ్, మక్తబ్ ఇదారా ఎ దావతుల్ ఖురాన్ నుండి గమనిక: విద్యార్థి {StudentName} (అడ్మిషన్ నం: {AdmissionNo}) నెలవారీ ఫీజు ₹{Amount} చెల్లించాల్సి ఉంది. జజాకల్లా ఖైర్.';
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Message Template Expansion / Field
            TextField(
              controller: _templateCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Message Template',
                helperText: 'Placeholders: {StudentName}, {Amount}, {AdmissionNo}, {BatchName}',
                helperStyle: const TextStyle(fontSize: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 8),

            // Selection controls header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Selected Students ($selectedCount / ${_items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF004D40)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _selectAll(true),
                      child: const Text('Select All', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton(
                      onPressed: () => _selectAll(false),
                      child: const Text('Deselect All', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),

            // Student List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching students found for this batch/filter.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final s = item.student;
                            final phone = s.phone ?? s.guardianPhone ?? 'No Phone';
                            return CheckboxListTile(
                              value: item.isSelected,
                              dense: true,
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                '[Adm: ${s.admissionNumber}] • ${item.batchName} • $phone\nStatus: ${item.status} (₹${item.amountDue.toInt()})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.status == 'Overdue' ? Colors.red.shade700 : Colors.black87,
                                ),
                              ),
                              activeColor: const Color(0xFF004D40),
                              onChanged: (val) {
                                setState(() {
                                  item.isSelected = val ?? false;
                                });
                              },
                            );
                          },
                        ),
            ),

            const SizedBox(height: 12),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selectedCount > 0 ? _sendLocalNotifications : null,
                    icon: const Icon(Icons.notifications_active_rounded, size: 16),
                    label: const Text('Device Alert', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selectedCount > 0 ? _shareBatchReport : null,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share Summary', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: selectedCount > 0 ? _startWhatsAppQueue : null,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text('Send WhatsApp ($selectedCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
