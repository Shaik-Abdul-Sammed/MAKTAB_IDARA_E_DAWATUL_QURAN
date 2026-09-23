import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/message_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/widgets/custom_app_bar.dart';
import '../../utils/whatsapp_utility.dart';
import '../../widgets/language_picker_dialog.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final UserRepository _userRepo = UserRepository();
  final MessageRepository _messageRepo = MessageRepository();
  List<User> _teachers = [];
  Map<int, Map<String, dynamic>> _previews = {};
  Map<int, int> _unreadCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 1;
    final teachers = await _userRepo.getAllTeachers();

    final previews = <int, Map<String, dynamic>>{};
    final unreadCounts = <int, int>{};

    for (final teacher in teachers) {
      final tId = teacher.teacherId ?? teacher.id;
      if (tId != null) {
        final preview = await _messageRepo.getLatestMessageBetween(adminId, tId);
        if (preview != null) {
          previews[tId] = preview;
        }
        final unread = await _messageRepo.getUnreadCountBetween(adminId, tId, isAdmin: true);
        unreadCounts[tId] = unread;
      }
    }

    if (mounted) {
      setState(() {
        _teachers = teachers;
        _previews = previews;
        _unreadCounts = unreadCounts;
        _isLoading = false;
      });
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString());
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  void _showWhatsAppBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 10),
            Text('WhatsApp Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Notice Title', hintText: 'e.g. Maktab Holiday Notice'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notice Content', hintText: 'Enter notice details...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: const Icon(Icons.language, color: Colors.white, size: 18),
            label: const Text('Select Language & Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final lang = await LanguagePickerDialog.show(context);
              if (lang == null || !mounted) return;
              await WhatsAppUtility.sendNoticeMessage(
                context,
                title: titleCtrl.text,
                content: contentCtrl.text,
                languageCode: lang,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Messaging & Bulletins'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push('/chat/0?name=All%20Teachers');
                          },
                          icon: const Icon(Icons.campaign),
                          label: const Text('App Broadcast'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF004D40),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showWhatsAppBroadcastDialog(),
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('WhatsApp Notice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _teachers.isEmpty
                      ? const Center(child: Text('No teachers found.'))
                      : ListView.builder(
                          itemCount: _teachers.length,
                          itemBuilder: (context, index) {
                            final teacher = _teachers[index];
                            final teacherId = teacher.teacherId ?? teacher.id;
                            if (teacherId == null) return const SizedBox.shrink();

                            final preview = _previews[teacherId];
                            final unreadCount = _unreadCounts[teacherId] ?? 0;
                            final snippet = preview != null ? preview['content'] as String : 'Tap to open chat';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF004D40),
                                child: Text(
                                  teacher.name.isNotEmpty ? teacher.name.substring(0, 1).toUpperCase() : 'T',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      teacher.name,
                                      style: TextStyle(
                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (preview != null && preview['timestamp'] != null)
                                    Text(
                                      _formatTime(preview['timestamp']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: unreadCount > 0 ? const Color(0xFF004D40) : Colors.grey[600],
                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  snippet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                              onTap: () async {
                                final name = Uri.encodeComponent(teacher.name);
                                await context.push('/chat/$teacherId?name=$name');
                                if (mounted) {
                                  _loadTeachers();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
