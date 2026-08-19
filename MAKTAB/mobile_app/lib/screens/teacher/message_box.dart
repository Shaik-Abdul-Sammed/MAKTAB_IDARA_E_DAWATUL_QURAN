import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/message_provider.dart';

class MessageBoxScreen extends StatefulWidget {
  const MessageBoxScreen({super.key});

  @override
  State<MessageBoxScreen> createState() => _MessageBoxScreenState();
}

class _MessageBoxScreenState extends State<MessageBoxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<MessageProvider>(context, listen: false).loadUserMessages(auth.currentUser!.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Messages & Bulletins'),
      body: Consumer<MessageProvider>(
        builder: (context, msgProvider, child) {
          if (msgProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = msgProvider.userMessages;
          final unreadBroadcasts = messages.where((m) => m.receiverId == null && !m.isRead).length;
          final unreadDirect = messages.where((m) => m.receiverId != null && !m.isRead).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildChatTile(
                context,
                title: 'Broadcast Announcements',
                subtitle: 'Messages from Administration to all teachers',
                icon: Icons.campaign,
                unreadCount: unreadBroadcasts,
                onTap: () {
                  context.push('/chat/0?name=Broadcast%20Announcements');
                },
              ),
              const SizedBox(height: 12),
              _buildChatTile(
                context,
                title: 'Administration (Direct)',
                subtitle: 'Private chat with Admin',
                icon: Icons.admin_panel_settings,
                unreadCount: unreadDirect,
                onTap: () {
                  // Admin is user ID 1 in this single-device offline flow usually
                  context.push('/chat/1?name=Administration');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
          child: Icon(icon, color: const Color(0xFF004D40), size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(subtitle),
        ),
        trailing: unreadCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: Colors.redAccent,
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
