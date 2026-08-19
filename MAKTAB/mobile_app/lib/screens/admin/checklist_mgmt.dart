import 'package:flutter/material.dart';
import '../../../models/checklist.dart';
import '../../../repositories/checklist_repository.dart';

class ChecklistMgmtScreen extends StatefulWidget {
  const ChecklistMgmtScreen({super.key});

  @override
  State<ChecklistMgmtScreen> createState() => _ChecklistMgmtScreenState();
}

class _ChecklistMgmtScreenState extends State<ChecklistMgmtScreen> {
  List<ChecklistSubmission> _items = [];
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
        final repo = ChecklistRepository();
    final records = await repo.getAllSubmissions();
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


  void _showDetailSheet(ChecklistSubmission item) {
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

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) => item.date.toLowerCase().contains(_searchQuery.toLowerCase()) || item.teacherId.toString().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Admin Checklist Control',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40), // Dark green
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
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF004D40),
                                    foregroundColor: Colors.white,
                                    child: Icon(Icons.checklist, size: 18),
                                  ),
                                  title: Text('Date: ${item.date}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Teacher ID: ${item.teacherId} | Batch ID: ${item.batchId}'),
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
