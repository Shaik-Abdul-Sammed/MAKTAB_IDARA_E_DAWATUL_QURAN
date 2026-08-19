import 'package:flutter/material.dart';
import '../../../models/student.dart';
import '../../../repositories/student_repository.dart';

class StudentHealthInfoScreen extends StatefulWidget {
  const StudentHealthInfoScreen({super.key});

  @override
  State<StudentHealthInfoScreen> createState() => _StudentHealthInfoScreenState();
}

class _StudentHealthInfoScreenState extends State<StudentHealthInfoScreen> {
  List<Student> _items = [];
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
        final repo = StudentRepository();
    final records = await repo.getAllStudents();
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


  void _showDetailSheet(Student item) {
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
    final filteredItems = _items.where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Student Health & Emergency Contacts',
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
                        : Scrollbar(
                            thumbVisibility: true,
                            thickness: 6.0,
                            radius: const Radius.circular(8),
                            child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF004D40),
                                    foregroundColor: Colors.white,
                                    child: Icon(Icons.health_and_safety, size: 18),
                                  ),
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(item.teacherNotes?.isEmpty ?? true ? 'No medical info' : item.teacherNotes!),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showDetailSheet(item),
                                ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
