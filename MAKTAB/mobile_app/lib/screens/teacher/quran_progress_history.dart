import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/screens/teacher/quran_progress_entry.dart';
import '../../providers/auth_provider.dart';
import '../../../models/quran_progress.dart';
import '../../../models/student.dart';
import '../../../repositories/quran_progress_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../utils/whatsapp_utility.dart';

class QuranProgressHistoryScreen extends StatefulWidget {
  const QuranProgressHistoryScreen({super.key});

  @override
  State<QuranProgressHistoryScreen> createState() => _QuranProgressHistoryScreenState();
}

class _QuranProgressHistoryScreenState extends State<QuranProgressHistoryScreen> {
  List<QuranProgress> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final canonicalTeacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
      final repo = QuranProgressRepository();
      final records = canonicalTeacherId != null
          ? await repo.getProgressByTeacher(canonicalTeacherId)
          : <QuranProgress>[];
      if (mounted) {
        setState(() {
          _items = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _sendSabaqToParent(QuranProgress entry) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final student = await StudentRepository().getStudentById(entry.studentId);
    if (student == null) return;
    final phone = student.guardianPhone ?? student.phone ?? '';
    if (phone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No parent contact number on record.')),
        );
      }
      return;
    }

    final senderName = auth.currentUser?.name ?? 'Maktab Management';
    const maktabName = 'MAKTAB IDARA E DAWATUL QURAN';
    final remarks = (entry.remarks ?? '').trim();

    final msg = '''
بسم الله الرحمن الرحيم

السلام عليكم ورحمة الله وبركاته

Respected Parent/Guardian,

We are pleased to share today's Sabaq progress for your child, *${student.name}* (Adm. No. ${student.admissionNumber}).

━━━━━━━━━━━━━━━━━━━━
📖 *Sabaq Details*
━━━━━━━━━━━━━━━━━━━━
• *Surah:* ${entry.surah}
• *Ayah:* ${entry.ayahFrom}–${entry.ayahTo}
• *Type:* ${entry.recitationType}
• *Grade:* ${entry.grade}
• *Date:* ${entry.date}

━━━━━━━━━━━━━━━━━━━━
📝 *Teacher's Note*
━━━━━━━━━━━━━━━━━━━━
${remarks.isEmpty ? 'Alhamdulillah, the recitation was completed with focus and care.' : remarks}

We encourage you to review this portion with your child at home and continue the daily revision practice.

May Allah bless your child with steadfastness in learning the Qur'an.

جزاك الله خيرًا

Warm regards,
*$senderName*
$maktabName
''';

    if (!mounted) return;
    await WhatsAppUtility.launchWhatsApp(phone, msg, context: context);
  }

  Future<void> _sendDailyProgressToParents() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final canonicalTeacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
    if (canonicalTeacherId == null) return;
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    final allProgress = await QuranProgressRepository().getProgressByTeacher(canonicalTeacherId);
    final todayEntries = allProgress.where((p) => p.date == todayStr).toList();

    if (todayEntries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Sabaq entries recorded for today.')),
        );
      }
      return;
    }

    final senderName = auth.currentUser?.name ?? 'Maktab Management';
    const maktabName = 'MAKTAB IDARA E DAWATUL QURAN';
    final studentRepo = StudentRepository();
    final Map<String, List<Map<String, dynamic>>> groupedByPhone = {};

    for (final entry in todayEntries) {
      final student = await studentRepo.getStudentById(entry.studentId);
      if (student == null) continue;
      final phone = (student.guardianPhone ?? student.phone ?? '').trim();
      if (phone.isEmpty) continue;

      groupedByPhone.putIfAbsent(phone, () => []).add({
        'student': student,
        'entry': entry,
      });
    }

    if (groupedByPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid parent phone numbers found for today\'s entries.')),
        );
      }
      return;
    }

    for (final group in groupedByPhone.entries) {
      final phone = group.key;
      final items = group.value;

      final sections = <String>[];
      for (final item in items) {
        final student = item['student'] as Student;
        final p = item['entry'] as QuranProgress;
        final remarks = (p.remarks ?? '').trim();
        final note = remarks.isEmpty
            ? 'Alhamdulillah, the recitation was completed with focus and care.'
            : remarks;

        sections.add('''Child: *${student.name}* (Adm. No. ${student.admissionNumber})
━━━━━━━━━━━━━━━━━━━━
📖 *Sabaq Details*
━━━━━━━━━━━━━━━━━━━━
• *Surah:* ${p.surah}
• *Ayah:* ${p.ayahFrom}–${p.ayahTo}
• *Type:* ${p.recitationType}
• *Grade:* ${p.grade}
• *Date:* ${p.date}

━━━━━━━━━━━━━━━━━━━━
📝 *Teacher's Note*
━━━━━━━━━━━━━━━━━━━━
$note''');
      }

      final msg = '''
بسم الله الرحمن الرحيم

السلام عليكم ورحمة الله وبركاته

Respected Parent/Guardian,

We are pleased to share today's Sabaq progress for your child${items.length > 1 ? 'ren' : ''}:

${sections.join('\n\n')}

We encourage you to review this portion with your child at home and continue the daily revision practice.

May Allah bless your child with steadfastness in learning the Qur'an.

جزاك الله خيرًا

Warm regards,
*$senderName*
$maktabName
''';

      if (!mounted) return;
      await WhatsAppUtility.launchWhatsApp(phone, msg, context: context);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }


  void _showDetailSheet(QuranProgress item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Record Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const Divider(),
            const SizedBox(height: 12),
            
              // Try to cast to map, if fails, use toString
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    () {
                      try {
                        return (item as dynamic).toMap().entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                      } catch (_) {
                        return item.toString();
                      }
                    }(), 
                    style: const TextStyle(fontSize: 16)
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRecitationColor(String type) {
    switch (type.toLowerCase()) {
      case 'sabaq':
        return const Color(0xFF004D40);
      case 'sabaqi':
        return Colors.amber.shade800;
      case 'manzil':
        return Colors.deepPurple;
      default:
        return const Color(0xFF004D40);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) => item.surah.toLowerCase().contains(_searchQuery.toLowerCase()) || item.studentId.toString().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Sabaq History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, overflow: TextOverflow.ellipsis),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile),
            tooltip: 'Send Today\'s Sabaq to Parents',
            onPressed: _sendDailyProgressToParents,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search records...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ),
            
            // List view content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                color: const Color(0xFF004D40),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : _items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 64, color: Colors.black26),
                                  SizedBox(height: 16),
                                  Text(
                                    'No progress logged yet. Use the + button on the Sabaq screen to add a record.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredItems.isEmpty
                            ? const Center(child: Text('No matching records found.'))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  final badgeColor = _getRecitationColor(item.recitationType);
                                  return Dismissible(
                                    key: ValueKey('qp_${item.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      color: Colors.red.shade400,
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Sabaq Entry'),
                                          content: const Text('Delete this Sabaq entry? This cannot be undone.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) async {
                                      await QuranProgressRepository().deleteQuranProgress(item.id!);
                                      await CloudSyncService.instance.deleteQuranProgressCloud(item.id!);
                                      if (mounted) {
                                        setState(() {
                                          _items.removeWhere((e) => e.id == item.id);
                                        });
                                      }
                                    },
                                    child: Card(
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 1,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: badgeColor,
                                          foregroundColor: Colors.white,
                                          child: const Icon(Icons.book, size: 18),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Surah: ${item.surah}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: badgeColor, width: 1),
                                              ),
                                              child: Text(
                                                item.recitationType,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: badgeColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Text('Date: ${item.date} | Ayah: ${item.ayahFrom}–${item.ayahTo} | Grade: ${item.grade}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.send_rounded, color: Color(0xFF004D40)),
                                              tooltip: 'Send Sabaq Update to Parent',
                                              onPressed: () => _sendSabaqToParent(item),
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                        onLongPress: () => _showDetailSheet(item),
                                        onTap: () async {
                                          final changed = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => QuranProgressEntryScreen(existing: item),
                                            ),
                                          );
                                          if (changed == true && mounted) {
                                            _loadRecords();
                                          }
                                        },
                                      ),
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
