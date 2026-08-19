import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';

class PastStudentsScreen extends StatefulWidget {
  const PastStudentsScreen({super.key});

  @override
  State<PastStudentsScreen> createState() => _PastStudentsScreenState();
}

class _PastStudentsScreenState extends State<PastStudentsScreen> {
  final StudentRepository _studentRepo = StudentRepository();
  final BatchRepository _batchRepo = BatchRepository();

  bool _isLoading = true;
  List<Student> _pastStudents = [];
  List<Student> _filteredStudents = [];
  List<Batch> _batches = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _studentRepo.getDeletedStudents();
      final batches = await _batchRepo.getAllBatches();
      if (mounted) {
        setState(() {
          _pastStudents = students;
          _batches = batches;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading past students: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _filter(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredStudents = _pastStudents);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredStudents = _pastStudents.where((s) {
        final nameMatch = s.name.toLowerCase().contains(q);
        final admMatch = s.admissionNumber.toLowerCase().contains(q);
        final fatherMatch = (s.fatherName ?? '').toLowerCase().contains(q);
        return nameMatch || admMatch || fatherMatch;
      }).toList();
    });
  }

  String _getBatchName(int? batchId) {
    if (batchId == null) return 'Unassigned';
    final match = _batches.firstWhere(
      (b) => b.id == batchId,
      orElse: () => Batch(id: 0, name: 'Unknown Batch', timing: ''),
    );
    return match.name;
  }

  Future<void> _restoreStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Student'),
        content: Text(
          'Are you sure you want to restore ${student.name} (ADM: ${student.admissionNumber}) back to active students list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && student.id != null) {
      await _studentRepo.restoreStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} has been restored to active list.'),
            backgroundColor: const Color(0xFF004D40),
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _permanentlyDeleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Student', style: TextStyle(color: Colors.red)),
        content: Text(
          'WARNING: This will PERMANENTLY remove ${student.name} (ADM: ${student.admissionNumber}) and all associated records from the database. This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && student.id != null) {
      await _studentRepo.permanentlyDeleteStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} was permanently deleted.'),
            backgroundColor: Colors.red,
          ),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past / Archived Students'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE8F5E9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.archive_rounded, color: Color(0xFF004D40)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total Past/Deleted Records: ${_pastStudents.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004D40),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: 'Search by name, admission no, father name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.folder_off_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No past or deleted student records found.',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final delDateStr = student.deletedAt != null
                              ? DateFormat('MMM dd, yyyy').format(DateTime.tryParse(student.deletedAt!) ?? DateTime.now())
                              : 'Archived';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey.shade300,
                                      child: Text(
                                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                    ),
                                    title: Text(
                                      student.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      'ADM: ${student.admissionNumber} | Father: ${student.fatherName ?? 'N/A'}\nBatch: ${_getBatchName(student.batchId)}',
                                      style: const TextStyle(fontSize: 13, height: 1.4),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Archived: $delDateStr',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.person, size: 16),
                                        label: const Text('View Profile'),
                                        onPressed: () {
                                          if (student.id != null) {
                                            context.push('/admin/students/${student.id}');
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF004D40),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                                        label: const Text('Restore'),
                                        onPressed: () => _restoreStudent(student),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                                        tooltip: 'Permanently Delete',
                                        onPressed: () => _permanentlyDeleteStudent(student),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
