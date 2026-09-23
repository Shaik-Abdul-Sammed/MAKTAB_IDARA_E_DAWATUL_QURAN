import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/fee_payment.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/fee_payment_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/utils/receipt_templates.dart';
import 'package:maktab_app/utils/receipt_pdf_generator.dart';
import 'package:maktab_app/utils/whatsapp_utility.dart';
import 'package:maktab_app/widgets/receipt_preview_dialog.dart';

// ─── Main screen ─────────────────────────────────────────────────────────────

class TeacherFeesScreen extends StatefulWidget {
  const TeacherFeesScreen({super.key});

  @override
  State<TeacherFeesScreen> createState() => _TeacherFeesScreenState();
}

class _TeacherFeesScreenState extends State<TeacherFeesScreen> {
  final _repo = FeePaymentRepository();

  // All rows from DB (joined with student info)
  List<Map<String, dynamic>> _allRows = [];

  // Aggregation totals for header card
  Map<String, dynamic> _totals = {'total': 0, 'count': 0, 'byMode': <String, int>{}};

  bool _isLoading = true;

  // Filter state
  String _dateFilter = 'This Month'; // Today / This Week / This Month / All
  String _modeFilter = 'All';        // All / Cash / UPI / Bank / Cheque
  String _searchQuery = '';

  final _searchCtrl = TextEditingController();

  // Derived from auth
  int _teacherId = 0;
  String _teacherName = '';

  static const _modes = ['All', 'Cash', 'UPI', 'Bank', 'Cheque'];
  static const _dateFilters = ['Today', 'This Week', 'This Month', 'All'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _boot() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _teacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;
    _teacherName = auth.currentUser?.name ?? 'Teacher';
    _load();
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
      final rows = await _repo.getPaymentsByTeacherBatches(_teacherId);
      final totals = await _repo.getTeacherTotals(
        canonicalTeacherId: _teacherId,
        fromDate: from,
        toDate: to,
      );
      if (mounted) {
        setState(() {
          _allRows = rows;
          _totals = totals;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherFeesScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    final (from, to) = _dateRange();
    final q = _searchQuery.toLowerCase();

    return _allRows.where((row) {
      // Date filter
      if (from != null || to != null) {
        final ts = (row['timestamp'] as String? ?? '').substring(0, 10);
        if (from != null && ts.compareTo(from) < 0) return false;
        if (to != null && ts.compareTo(to) > 0) return false;
      }
      // Mode filter
      if (_modeFilter != 'All') {
        final rowMode = (row['mode'] as String? ?? '').toLowerCase();
        if (rowMode != _modeFilter.toLowerCase()) return false;
      }
      // Search
      if (q.isNotEmpty) {
        final name = (row['student_name'] as String? ?? '').toLowerCase();
        final adm = (row['student_admission'] as String? ?? '').toLowerCase();
        final phone = (row['student_phone'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !adm.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── Record / Edit dialog ──────────────────────────────────────────────────

  Future<void> _showRecordDialog({Map<String, dynamic>? existing}) async {
    // Load students in teacher's batches
    List<Student> batchStudents = [];
    try {
      batchStudents = await StudentRepository().getStudentsByTeacher(_teacherId);
    } catch (e) {
      debugPrint('[TeacherFeesScreen] student load error: $e');
    }

    if (!mounted) return;
    if (batchStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found in your batches.')),
      );
      return;
    }

    // Pre-fill if editing
    Student? selectedStudent;
    if (existing != null) {
      final sid = existing['student_id'] as int?;
      try {
        selectedStudent = batchStudents.firstWhere((s) => s.id == sid);
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
                // Student picker — disabled for edit
                if (!isEdit)
                  DropdownButtonFormField<Student>(
                    initialValue: selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'Student',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: batchStudents
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} (${s.admissionNumber})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (s) => setLocal(() => selectedStudent = s),
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
                  initialValue: selectedMode,
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
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    isSynced: 0,
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

                await _load();

                if (mounted && !isEdit) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment recorded successfully!'),
                      backgroundColor: AppColors.primaryTeal,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Save' : 'Record'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'] as int?;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Delete ₹${row['amount']} payment for ${row['student_name']}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteFeePayment(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted.')),
        );
      }
    }
  }

  // ── Send receipt ──────────────────────────────────────────────────────────

  Future<void> _sendReceipt(Map<String, dynamic> row) async {
    final studentName = row['student_name'] as String? ?? '';
    final admissionNumber = row['student_admission'] as String? ?? '';
    final phone = row['student_phone'] as String? ?? '';
    final lang = row['student_lang'] as String? ?? 'en';
    final amount = (row['amount'] as int?) ?? 0;
    final mode = (row['mode'] as String?) ?? 'Cash';
    final notes = row['notes'] as String?;
    final ts = row['timestamp'] as String? ?? '';
    final parsed = DateTime.tryParse(ts);
    final formattedTime = parsed != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed)
        : ts;
    final month = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : ts;
    final labels = ReceiptTemplates.get(lang);

    // Build receipt text inline (same logic as WhatsAppUtility.sendFeeReceipt)
    final buf = StringBuffer();
    buf.writeln('*${labels['header']}*');
    buf.writeln('${labels['date']}: $formattedTime');
    buf.writeln('${labels['receivedBy']}: $_teacherName');
    buf.writeln();
    buf.writeln('*${labels['student']}:* $studentName');
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
            collectorName: _teacherName,
            languageCode: lang,
          );
        },
        onBuildPdf: () => ReceiptPdfGenerator.buildFeeReceiptPdf(
          maktabName: 'Maktab Idara E Dawatul Quran',
          collectorName: _teacherName,
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
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Student Fees'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordDialog(),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Payment'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header summary card ──────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeaderCard()),

            // ── Filter bar ───────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildFilterBar()),

            // ── Search box ───────────────────────────────────────────────
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

            // ── List ─────────────────────────────────────────────────────
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
                    (context, index) => _PaymentCard(
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
      ),
    );
  }

  // ── Header card ───────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final total = _totals['total'] as int;
    final count = _totals['count'] as int;
    final byMode = (_totals['byMode'] as Map<String, int>?) ?? {};

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Date chips
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
                      onSelected: (_) => setState(() {
                        _dateFilter = f;
                        _load();
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Mode dropdown
          DropdownButton<String>(
            value: _modeFilter,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTeal,
            ),
            items: _modes
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

// ─── Payment card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReceipt;

  const _PaymentCard({
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
