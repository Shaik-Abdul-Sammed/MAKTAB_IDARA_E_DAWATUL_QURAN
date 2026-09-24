import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';

String formatRupees(int amount) {
  final s = amount.toString();
  if (s.length <= 3) return '₹$s';
  final lastThree = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buffer = StringBuffer();
  int count = 0;
  for (int i = rest.length - 1; i >= 0; i--) {
    buffer.write(rest[i]);
    count++;
    if (count == 2 && i != 0) {
      buffer.write(',');
      count = 0;
    }
  }
  final grouped = buffer.toString().split('').reversed.join();
  return '₹$grouped,$lastThree';
}

class FinanceTotalsCard extends StatelessWidget {
  final String title;
  final Map<String, int> periodTotals;    // keys: today, week, month, allTime
  final Map<String, int> modeBreakdown;   // keys: Cash, UPI, Bank Transfer, Cheque

  const FinanceTotalsCard({
    super.key,
    required this.title,
    required this.periodTotals,
    required this.modeBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final today = periodTotals['today'] ?? 0;
    final week = periodTotals['week'] ?? 0;
    final month = periodTotals['month'] ?? 0;
    final allTime = periodTotals['allTime'] ?? 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title & All-time total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.primaryTeal,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Total: ${formatRupees(allTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: Three stat tiles side by side
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    label: 'Today',
                    amount: today,
                    color: const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    label: 'This Week',
                    amount: week,
                    color: const Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    label: 'This Month',
                    amount: month,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),

            // Row 3: Horizontal chip strip showing mode totals
            if (modeBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: modeBreakdown.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconForMode(entry.key),
                            size: 13,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key}: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            formatRupees(entry.value),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required int amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupees(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'upi':
        return Icons.qr_code_rounded;
      case 'bank transfer':
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      case 'cheque':
        return Icons.description_outlined;
      default:
        return Icons.payment_rounded;
    }
  }
}
