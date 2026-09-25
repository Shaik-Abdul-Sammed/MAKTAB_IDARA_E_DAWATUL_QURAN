import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/fee_payment.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/student_repository.dart';
import '../../services/database_helper.dart';
import '../../utils/receipt_templates.dart';
import '../../utils/receipt_pdf_generator.dart';
import '../../utils/whatsapp_utility.dart';
import '../../widgets/receipt_preview_dialog.dart';

class FeePaymentsListWidget extends StatefulWidget {
  final int? teacherId;
  final VoidCallback? onPaymentRecorded;

  const FeePaymentsListWidget({
    super.key,
    this.teacherId,
    this.onPaymentRecorded,
  });

  @override
  State<FeePaymentsListWidget> createState() => _FeePaymentsListWidgetState();
}

class _FeePaymentsListWidgetState extends State<FeePaymentsListWidget> {
  final FeePaymentRepository _repo = FeePaymentRepository();

  List<Map<String, dynamic>> _allRows = [];
  Map<String, dynamic> _totals = {'total': 0, 'count': 0, 'byMode': <String, int>{}};
  bool _isLoading = true;

  String _dateFilter = 'This Month';
  String _modeFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _modes = ['All', 'Cash', 'UPI', 'Bank', 'Cheque'];
  static const _dateFilters = ['Today', 'This Week', 'This Month', 'All'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeePaymentsListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherId != widget.teacherId) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  (String?, String?) _dateRange() {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    switch (_dateFilter) {
      case 'Today':
        return (today, today);
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return (DateFormat('yyyy-MM-dd').format(startOfWeek), today);
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (DateFormat('yyyy-MM-dd').format(startOfMonth), today);
      default:
        return (null, null);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final (from, to) = _dateRange();
      List<Map<String, dynamic>> rows;
      if (widget.teacherId != null) {
        rows = await _repo.getPaymentsByTeacher(widget.teacherId!);
      } else {
        rows = await _repo.getAllPaymentRows();
      }

      // Calculate totals
      int total = 0;
      int count = 0;
      final Map<String, int> byMode = {};

      for (var r in rows) {
        final ts = (r['timestamp'] as String? ?? '').substring(0, 10.clamp(0, (r['timestamp'] as String? ?? '').length));
        if (from != null && ts.compareTo(from) < 0) continue;
        if (to != null && ts.compareTo(to) > 0) continue;

        final amt = (r['amount'] as int?) ?? 0;
        final mode = (r['mode'] as String?) ?? 'Cash';
        total += amt;
        count++;
        byMode[mode] = (byMode[mode] ?? 0) + amt;
      }

      if (mounted) {
        setState(() {
          _allRows = rows;
          _totals = {
            'total': total,
            'count': count,
            'byMode': byMode,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FeePaymentsListWidget] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final (from, to) = _dateRange();
    final q = _searchQuery.toLowerCase();

    return _allRows.where((row) {
      if (from != null || to != null) {
        final rawTs = row['timestamp'] as String? ?? '';
        final ts = rawTs.length >= 10 ? rawTs.substring(0, 10) : rawTs;
        if (from != null && ts.compareTo(from) < 0) return false;
        if (to != null && ts.compareTo(to) > 0) return false;
      }
      if (_modeFilter != 'All') {
        final rowMode = (row['mode'] as String? ?? '').toLowerCase();
        if (rowMode != _modeFilter.toLowerCase()) return false;
      }
      if (q.isNotEmpty) {
        final name = (row['student_name'] as String? ?? '').toLowerCase();
        final adm = (row['student_admission'] as String? ?? '').toLowerCase();
        final phone = (row['student_phone'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !adm.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showRecordDialog({Map<String, dynamic>? existing}) async {
    List<Student> students = [];
    try {
      if (widget.teacherId != null) {
        students = await StudentRepository().getStudentsByTeacher(widget.teacherId!);
      } else {
        students = await StudentRepository().getAllStudents();
      }
    } catch (e) {
      debugPrint('[FeePaymentsListWidget] student load error: $e');
    }

    if (!mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found.')),
      );
      return;
    }

    Student? selectedStudent;
    if (existing != null) {
      final sid = existing['student_id'] as int?;
      try {
        selectedStudent = students.firstWhere((s) => s.id == sid);
      } catch (_) {}
    }

    final amountCtrl = TextEditingController(
      text: existing != null ? '${existing['amount']}' : '',
    );
    final notesCtrl = TextEditingController(
      text: existing?['notes'] as String? ?? '',
    );
    String selectedMode = (existing?['mode'] as String?) ?? 'Cash';
    final isEdit = existing != null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Edit Payment' : 'Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEdit)
                  Builder(
                    builder: (context) {
                      final uniqueStudents = {
                        for (final s in students)
                          if (s.id != null) s.id!: s
                      }.values.toList();
                      final hasMatch = selectedStudent != null &&
                          uniqueStudents.any((s) => s.id == selectedStudent?.id);
                      return DropdownButtonFormField<Student?>(
                        initialValue: hasMatch ? selectedStudent : null,
                        decoration: const InputDecoration(
                          labelText: 'Student',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: uniqueStudents
                            .map((s) => DropdownMenuItem<Student?>(
                                  value: s,
                                  child: Text('${s.name} (${s.admissionNumber})',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (s) => setLocal(() => selectedStudent = s),
                      );
                    },
                  )
                else
                  Text(
                    'Student: ${existing['student_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ['Cash', 'UPI', 'Bank', 'Cheque'].contains(selectedMode)
                      ? selectedMode
                      : 'Cash',
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['Cash', 'UPI', 'Bank', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => selectedMode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amt = int.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount.')),
                  );
                  return;
                }
                if (!isEdit && selectedStudent == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Select a student.')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                if (isEdit) {
                  final updated = FeePayment(
                    id: existing['id'] as int,
                    studentId: existing['student_id'] as int,
                    amount: amt,
                    mode: selectedMode,
                    timestamp: existing['timestamp'] as String,
                    receiptSent: (existing['receipt_sent'] as int?) ?? 0,
                    receiptSentAt: existing['receipt_sent_at'] as String?,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  await _repo.updateFeePayment(updated);
                } else {
                  final payment = FeePayment(
                    studentId: selectedStudent!.id!,
                    amount: amt,
                    mode: selectedMode,
                    timestamp: DateTime.now().toIso8601String(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  await _repo.insertFeePayment(payment);
                }

                _load();
                widget.onPaymentRecorded?.call();
              },
              child: Text(isEdit ? 'Save Changes' : 'Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete payment of ₹${row['amount']} for ${row['student_name']}?'),
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

    if (confirmed == true) {
      await _repo.deleteFeePayment(id);
      _load();
      widget.onPaymentRecorded?.call();
    }
  }

  Future<void> _sendReceipt(Map<String, dynamic> row) async {
    final studentName = row['student_name'] as String? ?? 'Student';
    final admissionNumber = row['student_admission'] as String? ?? '-';
    final amount = (row['amount'] as int?) ?? 0;
    final mode = (row['mode'] as String?) ?? '-';
    final notes = row['notes'] as String?;
    final phone = row['student_phone'] as String? ?? '';
    final lang = (row['student_lang'] as String?) ?? 'en';
    final ts = row['timestamp'] as String? ?? '';
    final parsed = DateTime.tryParse(ts);
    final formattedTime = parsed != null ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed) : ts;
    final month = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : '';

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final collectorName = auth.currentUser?.name ?? 'Maktab Management';

    final labels = ReceiptTemplates.feeReceiptLabels(lang);
    final buf = StringBuffer();
    buf.writeln(labels['header']);
    buf.writeln('--------------------------------');
    buf.writeln('${labels['student']}: $studentName ($admissionNumber)');
    buf.writeln('${labels['date']}: $formattedTime');
    buf.writeln('${labels['amount']}: ₹$amount');
    buf.writeln('${labels['mode']}: $mode');
    if (notes != null && notes.trim().isNotEmpty) {
      buf.writeln('${labels['notes']}: $notes');
    }
    buf.writeln();
    buf.writeln(labels['footer']);
    final receiptText = buf.toString();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => ReceiptPreviewDialog(
        title: 'Fee Receipt',
        receiptText: receiptText,
        recipientPhone: phone,
        onSend: () {
          Navigator.pop(ctx);
          WhatsAppUtility.sendFeeReceipt(
            context,
            phone,
            studentName,
            amount.toDouble(),
            month,
            paymentMode: mode,
            dateTime: formattedTime,
            collectorName: collectorName,
            languageCode: lang,
            senderName: collectorName,
          );
        },
        onBuildPdf: () => ReceiptPdfGenerator.buildFeeReceiptPdf(
          maktabName: 'Maktab Idara E Dawatul Quran',
          collectorName: collectorName,
          recordedAt: parsed ?? DateTime.now(),
          children: [
            {
              'name': studentName,
              'admissionNumber': admissionNumber,
              'amount': amount,
              'mode': mode,
              'notes': notes ?? '',
            },
          ],
          labels: labels,
          senderName: collectorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderCard()),
          SliverToBoxAdapter(child: _buildFilterBar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, admission no. or phone',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primaryTeal),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
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
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No payments found.',
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PaymentCardItem(
                    row: filtered[index],
                    onEdit: () => _showRecordDialog(existing: filtered[index]),
                    onDelete: () => _confirmDelete(filtered[index]),
                    onReceipt: () => _sendReceipt(filtered[index]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final total = (_totals['total'] as int?) ?? 0;
    final count = (_totals['count'] as int?) ?? 0;
    final byMode = (_totals['byMode'] as Map<String, int>?) ?? {};

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Collected',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '$count payment${count == 1 ? '' : 's'} · $_dateFilter',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (byMode.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: byMode.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${e.key}: ₹${e.value}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateFilters.map((f) {
                  final sel = _dateFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      selectedColor: AppColors.primaryTeal,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        setState(() => _dateFilter = f);
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _modes.contains(_modeFilter) ? _modeFilter : _modes.first,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTeal,
            ),
            items: _modes
                .toSet()
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _modeFilter = v);
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentCardItem extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReceipt;

  const _PaymentCardItem({
    required this.row,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = row['student_name'] as String? ?? '-';
    final admission = row['student_admission'] as String? ?? '-';
    final amount = (row['amount'] as int?) ?? 0;
    final mode = (row['mode'] as String?) ?? '-';
    final ts = row['timestamp'] as String? ?? '';
    final parsed = DateTime.tryParse(ts);
    final displayTime = parsed != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed)
        : ts;
    final receiptSent = (row['receipt_sent'] as int?) == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded, color: AppColors.primaryTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('ADM: $admission',
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('₹$amount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryTeal,
                          )),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Text(mode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTeal,
                            )),
                      ),
                      if (receiptSent) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(displayTime,
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.black45),
              onSelected: (value) {
                if (value == 'receipt') onReceipt();
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'receipt',
                  child: Row(children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primaryTeal),
                    SizedBox(width: 8),
                    Text('Send Receipt'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
