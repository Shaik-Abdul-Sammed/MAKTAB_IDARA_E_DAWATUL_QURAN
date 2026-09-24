import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/announcement.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/message_provider.dart';
import 'package:maktab_app/repositories/announcement_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/utils/whatsapp_utility.dart';
import 'package:maktab_app/widgets/language_picker_dialog.dart';

class MessageBoxScreen extends StatefulWidget {
  final int initialTab;
  const MessageBoxScreen({super.key, this.initialTab = 0});

  @override
  State<MessageBoxScreen> createState() => _MessageBoxScreenState();
}

class _MessageBoxScreenState extends State<MessageBoxScreen> {
  int _adminId = 1;

  // Announcements state
  List<Announcement> _announcements = [];
  bool _isLoadingAnnouncements = true;
  String _announcementSearchQuery = '';
  final _announcementRepo = AnnouncementRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        final teacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;

        final adminUser = await UserRepository().getAdminUser();
        if (adminUser != null && mounted) {
          setState(() {
            _adminId = adminUser.teacherId ?? adminUser.id ?? 1;
          });
        }

        if (mounted) {
          Provider.of<MessageProvider>(context, listen: false)
              .loadUserMessages(teacherId);
        }
      }
    });

    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoadingAnnouncements = true);
    try {
      final records = await _announcementRepo.getAllAnnouncements();
      if (mounted) {
        setState(() {
          _announcements = records;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAnnouncements = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading announcements: $e')),
      );
    }
  }

  void _showAddEditAnnouncementDialog([Announcement? item]) {
    final isEditing = item != null;
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    final contentCtrl = TextEditingController(text: item?.content ?? '');
    final dateCtrl = TextEditingController(
      text: item?.date ?? DateTime.now().toIso8601String().split('T')[0],
    );
    final batchCtrl = TextEditingController(text: item?.batchId.toString() ?? '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content'), maxLines: 3),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
              TextField(controller: batchCtrl, decoration: const InputDecoration(labelText: 'Batch ID'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
            onPressed: () async {
              final newObj = Announcement(
                id: item?.id,
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim(),
                date: dateCtrl.text.trim(),
                batchId: int.tryParse(batchCtrl.text.trim()) ?? 1,
              );
              if (isEditing) {
                await _announcementRepo.updateAnnouncement(newObj);
              } else {
                await _announcementRepo.insertAnnouncement(newObj);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                _loadAnnouncements();
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDetailSheet(Announcement item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Announcement Details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddEditAnnouncementDialog(item);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _announcementRepo.deleteAnnouncement(item.id!);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          _loadAnnouncements();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Date: ${item.date} | Batch ID: ${item.batchId}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(item.content, style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    label: const Text('Share via WhatsApp',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final lang = await LanguagePickerDialog.show(context);
                      if (lang == null || !mounted) return;
                      final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
                      await WhatsAppUtility.sendNoticeMessage(
                        context,
                        title: item.title,
                        content: item.content,
                        languageCode: lang,
                        senderName: sender,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: AppBar(
          title: const Text(
            'Messages & Bulletins',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: AppColors.goldAccent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chats'),
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Announcements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Chats
            Consumer<MessageProvider>(
              builder: (context, msgProvider, child) {
                if (msgProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
                }

                final messages = msgProvider.userMessages;
                final unreadBroadcasts =
                    messages.where((m) => m.receiverId == null && !m.isRead).length;
                final unreadDirect =
                    messages.where((m) => m.receiverId != null && !m.isRead).length;

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
                        context.push('/chat/$_adminId?name=Administration');
                      },
                    ),
                  ],
                );
              },
            ),

            // Tab 2: Announcements
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _announcementSearchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search announcements...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                        ),
                        onPressed: () => _showAddEditAnnouncementDialog(),
                        icon: const Icon(Icons.add, color: AppColors.goldAccent),
                        tooltip: 'New Announcement',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAnnouncements,
                    color: const Color(0xFF004D40),
                    child: _isLoadingAnnouncements
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                        : _buildAnnouncementsList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    final filtered = _announcements.where((item) {
      final q = _announcementSearchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q) || item.content.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No announcements found.', style: TextStyle(color: Colors.black54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF004D40),
              foregroundColor: Colors.white,
              child: Icon(Icons.announcement, size: 18),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Date: ${item.date} | ${item.content}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAnnouncementDetailSheet(item),
          ),
        );
      },
    );
  }

  Widget _buildChatTile(
    BuildContext context, {
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
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: unreadCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: Colors.redAccent,
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
