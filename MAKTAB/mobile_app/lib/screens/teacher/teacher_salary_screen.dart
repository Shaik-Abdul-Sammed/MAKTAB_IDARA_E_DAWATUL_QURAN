import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/salary_payment.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/salary_repository.dart';

class TeacherSalaryScreen extends StatefulWidget {
  const TeacherSalaryScreen({super.key});

  @override
  State<TeacherSalaryScreen> createState() => _TeacherSalaryScreenState();
}

class _TeacherSalaryScreenState extends State<TeacherSalaryScreen> {
  final SalaryRepository _salaryRepository = SalaryRepository();
  List<SalaryPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final canonicalTeacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;
      final payments = await _salaryRepository.getPaymentsForTeacher(canonicalTeacherId);
      if (mounted) {
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherSalaryScreen] error loading payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMonth(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length >= 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final dt = DateTime(year, month);
        return DateFormat('MMMM yyyy').format(dt);
      }
    } catch (e) {
      debugPrint('[TeacherSalaryScreen._formatMonth] failed to format month $monthStr: $e');
    }
    return monthStr;
  }

  String _formatPaymentDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      debugPrint('[TeacherSalaryScreen._formatPaymentDate] failed to parse date $dateStr: $e');
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year.toString();
    final totalEarnedThisYear = _payments
        .where((p) => p.salaryMonth.startsWith(currentYear))
        .fold(0, (sum, p) => sum + p.amount);
    final totalEarnedAllTime = _payments.fold(0, (sum, p) => sum + p.amount);
    final lastPaymentDate = _payments.isNotEmpty ? _formatPaymentDate(_payments.first.paymentDate) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('My Salary'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayments,
        color: AppColors.primaryTeal,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // ── Header Card ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00695C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: AppColors.goldAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Earnings Overview',
                                style: TextStyle(color: AppColors.goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('This Year', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹$totalEarnedThisYear',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(width: 1, height: 40, color: Colors.white24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('All Time', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹$totalEarnedAllTime',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white24),
                          Row(
                            children: [
                              const Icon(Icons.event_available_rounded, color: Colors.white60, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                lastPaymentDate != null
                                    ? 'Last Payment: $lastPaymentDate'
                                    : 'No payments yet',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Section Title ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, color: Color(0xFF004D40), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Payment History (${_payments.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004D40),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Payments List ─────────────────────────────────────────
                  if (_payments.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No salary records yet. Contact your manager.',
                            style: TextStyle(color: Colors.black54, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = _payments[index];
                            final isReceiptSent = p.receiptSent == 1;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 1.5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    // Status icon
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isReceiptSent
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.amber.withValues(alpha: 0.12),
                                      child: Icon(
                                        isReceiptSent ? Icons.check_circle_rounded : Icons.access_time_rounded,
                                        color: isReceiptSent ? Colors.green : Colors.amber.shade800,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Month, Mode & Date
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatMonth(p.salaryMonth),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF004D40),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0F2F1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  p.paymentMode,
                                                  style: const TextStyle(
                                                    color: Color(0xFF004D40),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatPaymentDate(p.paymentDate),
                                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Large Right-aligned Amount
                                    Text(
                                      '₹${p.amount}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF004D40),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _payments.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
