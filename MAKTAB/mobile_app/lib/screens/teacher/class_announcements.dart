import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../../../repositories/announcement_repository.dart';
import '../../../utils/whatsapp_utility.dart';

class ClassAnnouncementsScreen extends StatefulWidget {
  const ClassAnnouncementsScreen({super.key});

  @override
  State<ClassAnnouncementsScreen> createState() => _ClassAnnouncementsScreenState();
}

class _ClassAnnouncementsScreenState extends State<ClassAnnouncementsScreen> {
  List<Announcement> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _repo = AnnouncementRepository();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
        final records = await _repo.getAllAnnouncements();
        if (mounted) {
            setState(() {
                _items = records;
                _isLoading = false;
            });
        }
    } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  void _showAddEditDialog([Announcement? item]) {
    final isEditing = item != null;
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    final contentCtrl = TextEditingController(text: item?.content ?? '');
    final dateCtrl = TextEditingController(text: item?.date ?? DateTime.now().toIso8601String().split('T')[0]);
    final batchCtrl = TextEditingController(text: item?.batchId.toString() ?? '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newObj = Announcement(
                id: item?.id,
                title: titleCtrl.text,
                content: contentCtrl.text,
                date: dateCtrl.text,
                batchId: int.tryParse(batchCtrl.text) ?? 1,
              );
              if (isEditing) {
                await _repo.updateAnnouncement(newObj);
              } else {
                await _repo.insertAnnouncement(newObj);
              }
              if (context.mounted) {
                Navigator.pop(context);
                _loadRecords();
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showDetailSheet(Announcement item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Announcement Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {
                      Navigator.pop(context);
                      _showAddEditDialog(item);
                    }),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                      await _repo.deleteAnnouncement(item.id!);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadRecords();
                      }
                    }),
                  ],
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  () {
                    try {
                      return (item as dynamic).toMap().entries.map((e) => '${e.key}: ${e.value}').join('\\n\\n');
                    } catch (_) {
                      return item.toString();
                    }
                  }(), 
                  style: const TextStyle(fontSize: 16)
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    label: const Text('Share via WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    onPressed: () {
                      Navigator.pop(context);
                      WhatsAppUtility.sendNoticeMessage(
                        context,
                        title: item.title,
                        content: item.content,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                  onPressed: () => Navigator.pop(context),
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
    final filteredItems = _items.where((item) => item.title.toLowerCase().contains(_searchQuery.toLowerCase()) || item.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Post Announcements & Bulletins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('New Announcement', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search records...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                color: const Color(0xFF004D40),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : filteredItems.isEmpty
                        ? const Center(child: Text('No matching records found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  leading: const CircleAvatar(backgroundColor: Color(0xFF004D40), foregroundColor: Colors.white, child: Icon(Icons.announcement, size: 18)),
                                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Date: ${item.date} | ${item.content}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showDetailSheet(item),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
