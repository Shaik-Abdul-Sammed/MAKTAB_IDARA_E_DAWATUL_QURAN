import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService();

  final List<Map<String, String>> _recentNotifications = [
    {
      'title': 'Daily Checklist Reminder',
      'body': 'Don\'t forget to complete your Maktab daily operational checklist!',
      'time': 'Today, 08:00 AM',
    },
    {
      'title': 'Monthly Fee Alert',
      'body': '5 students have pending fee payments for August.',
      'time': 'Yesterday, 05:30 PM',
    },
    {
      'title': 'System Backup Successful',
      'body': 'Database backup created and saved locally.',
      'time': '03 Aug 2026',
    },
  ];

  Future<void> _sendTestNotification() async {
    await _notificationService.showInstantNotification(
      title: 'Maktab App Test Alert 🔔',
      body: 'Notifications are working perfectly on your device!',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent! Check system tray.'), backgroundColor: Color(0xFF004D40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Notification Center',
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () {
              setState(() => _recentNotifications.clear());
            },
            tooltip: 'Clear All',
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
              _buildBanner(),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
                  ElevatedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.notifications_active, size: 16),
                    label: const Text('Test Alert', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF004D40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_recentNotifications.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No notifications received yet.', style: TextStyle(color: Colors.black45)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentNotifications.length,
                  itemBuilder: (context, index) {
                    final item = _recentNotifications[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF004D40),
                            child: Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(item['body']!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(item['time']!, style: const TextStyle(fontSize: 10, color: Colors.black38)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD700), size: 40),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Local Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 4),
              Text('Managed via Flutter Local Notifications', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
