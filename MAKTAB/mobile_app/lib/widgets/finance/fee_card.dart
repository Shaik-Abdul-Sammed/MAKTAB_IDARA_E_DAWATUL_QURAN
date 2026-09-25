import 'package:flutter/material.dart';
import '../../config/app_icons.dart';
import '../../models/student.dart';

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

class FeeCard extends StatelessWidget {
  final FeeStudentItem item;
  final VoidCallback onPayUpi;
  final VoidCallback onWhatsApp;
  final VoidCallback onNotify;
  final VoidCallback onLog;
  final VoidCallback onEdit;
  final VoidCallback? onReceipt;

  const FeeCard({
    super.key,
    required this.item,
    required this.onPayUpi,
    required this.onWhatsApp,
    required this.onNotify,
    required this.onLog,
    required this.onEdit,
    this.onReceipt,
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'ADM: ${s.admissionNumber} · ${s.phone ?? 'No phone'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
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
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Due: ${item.dueDate}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                '₹${item.amountDue.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppIcons.primaryTeal,
                ),
              ),
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
                    label: const Text(
                      'Pay UPI',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
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
                    onPressed: onReceipt,
                    icon: const Icon(AppIcons.whatsapp, size: 14),
                    label: const Text(
                      'Send Receipt',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
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
