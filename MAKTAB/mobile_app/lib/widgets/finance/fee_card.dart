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
  final VoidCallback? onPayUpi;
  final VoidCallback onWhatsApp;
  final VoidCallback onNotify;
  final VoidCallback onLog;
  final VoidCallback onEdit;
  final VoidCallback? onReceipt;

  const FeeCard({
    super.key,
    required this.item,
    this.onPayUpi,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
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
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.status != 'Paid') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPayUpi ?? onLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: onPayUpi != null ? AppIcons.gold : const Color(0xFF004D40),
                      foregroundColor: onPayUpi != null ? AppIcons.primaryTeal : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(onPayUpi != null ? Icons.payment_rounded : Icons.add_card_rounded, size: 14),
                        const SizedBox(width: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            onPayUpi != null ? 'Pay UPI' : 'RECORD COLLECTION',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.blueGrey),
                        padding: EdgeInsets.zero,
                        tooltip: 'More options',
                        onSelected: (val) {
                          if (val == 'log') {
                            onLog();
                          } else if (val == 'edit') {
                            onEdit();
                          } else if (val == 'notify') {
                            onNotify();
                          }
                        },
                        itemBuilder: (context) => [
                          if (onPayUpi != null)
                            const PopupMenuItem(
                              value: 'log',
                              child: Row(
                                children: [
                                  Icon(Icons.mic, size: 20, color: AppIcons.primaryTeal),
                                  SizedBox(width: 8),
                                  Text('Log/Voice Payment', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note, size: 20, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text('Edit Fee Amount', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'notify',
                            child: Row(
                              children: [
                                Icon(AppIcons.notification, size: 20, color: AppIcons.primaryTeal),
                                SizedBox(width: 8),
                                Text('Send Notification', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.whatsapp, size: 14),
                        SizedBox(width: 2),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Send Receipt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
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
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 19, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 32,
          maxWidth: 32,
          minHeight: 32,
          maxHeight: 32,
        ),
      ),
    );
  }
}
