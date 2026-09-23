import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../../models/quran_progress.dart';
import '../../../repositories/quran_progress_repository.dart';

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
      final teacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
      final repo = QuranProgressRepository();
      final records = teacherId != null
          ? await repo.getProgressByTeacher(teacherId)
          : await repo.getAllProgress();
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
          'Review Progress History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, overflow: TextOverflow.ellipsis),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
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
                                    'No progress logged yet. Use the + button on the Quran screen to add a record.',
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
                                  return Card(
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
