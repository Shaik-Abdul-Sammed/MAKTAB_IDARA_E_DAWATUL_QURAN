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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 2,
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.status,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Due: ${item.dueDate}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '₹${item.amountDue.toInt()}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppIcons.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.status != 'Paid') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPayUpi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppIcons.gold,
                      foregroundColor: AppIcons.primaryTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_rounded, size: 14),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Pay UPI',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconAction(
                      icon: AppIcons.whatsapp,
                      tooltip: 'WhatsApp Reminder',
                      color: AppIcons.whatsappGreen,
                      onTap: onWhatsApp,
                    ),
                    _IconAction(
                      icon: Icons.mic,
                      tooltip: 'Log/Voice Payment',
                      color: AppIcons.primaryTeal,
                      onTap: onLog,
                    ),
                    _IconAction(
                      icon: Icons.edit_note,
                      tooltip: 'Edit Fee Amount',
                      color: Colors.blueGrey,
                      onTap: onEdit,
                    ),
                    _IconAction(
                      icon: AppIcons.notification,
                      tooltip: 'Send Local App Notification',
                      color: AppIcons.primaryTeal,
                      onTap: onNotify,
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReceipt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppIcons.whatsappGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.whatsapp, size: 14),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Send Receipt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 36,
          maxWidth: 36,
          minHeight: 36,
          maxHeight: 36,
        ),
      ),
    );
  }
}
