import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/widgets/custom_app_bar.dart';
import '../../utils/whatsapp_utility.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final UserRepository _userRepo = UserRepository();
  List<User> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final teachers = await _userRepo.getAllTeachers();
    setState(() {
      _teachers = teachers;
      _isLoading = false;
    });
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
              await WhatsAppUtility.sendNoticeMessage(
                context,
                title: titleCtrl.text,
                content: contentCtrl.text,
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
                            backgroundColor: const Color(0xFF004D40),
                            foregroundColor: Colors.white,
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
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF004D40),
                                child: Text(
                                  teacher.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(teacher.name),
                              subtitle: const Text('Tap to open chat'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final name = Uri.encodeComponent(teacher.name);
                                context.push('/chat/${teacher.id}?name=$name');
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
