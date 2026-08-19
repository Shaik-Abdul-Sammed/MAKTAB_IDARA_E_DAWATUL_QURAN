import 'package:flutter/material.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';

class StudentPromotionScreen extends StatefulWidget {
  const StudentPromotionScreen({super.key});

  @override
  State<StudentPromotionScreen> createState() => _StudentPromotionScreenState();
}

class _StudentPromotionScreenState extends State<StudentPromotionScreen> {
  List<Batch> _batches = [];
  List<Student> _studentsInSourceBatch = [];
  
  Batch? _sourceBatch;
  Batch? _targetBatch;
  
  bool _isLoading = true;
  bool _isPromoting = false;
  
  Set<int> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    final batches = await BatchRepository().getAllBatches();
    setState(() {
      _batches = batches;
      _isLoading = false;
    });
  }

  Future<void> _loadStudentsForSourceBatch(Batch batch) async {
    setState(() {
      _sourceBatch = batch;
      _isLoading = true;
      _selectedStudentIds.clear();
    });
    
    final allStudents = await StudentRepository().getAllStudents();
    setState(() {
      _studentsInSourceBatch = allStudents.where((s) => s.batchId == batch.id).toList();
      _isLoading = false;
    });
  }

  void _toggleStudentSelection(int studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  void _selectAllStudents() {
    setState(() {
      if (_selectedStudentIds.length == _studentsInSourceBatch.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds = _studentsInSourceBatch.map((s) => s.id!).toSet();
      }
    });
  }

  Future<void> _promoteSelectedStudents() async {
    if (_targetBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Target Batch first.')),
      );
      return;
    }
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected for promotion.')),
      );
      return;
    }
    if (_sourceBatch?.id == _targetBatch?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and Target batch cannot be the same.')),
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Promotion'),
        content: Text('Promote ${_selectedStudentIds.length} students to ${_targetBatch!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isPromoting = true);
      await DatabaseHelper.instance.promoteStudents(_selectedStudentIds.toList(), _targetBatch!.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully promoted ${_selectedStudentIds.length} students!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isPromoting = false);
        _targetBatch = null;
        _loadStudentsForSourceBatch(_sourceBatch!); // reload list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _studentsInSourceBatch.isNotEmpty && _selectedStudentIds.length == _studentsInSourceBatch.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Bulk Student Promotion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40), // Dark green
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step 1: Select Source Batch
                    const Text('1. Select Source Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Batch>(
                          hint: const Text('Select Batch...'),
                          value: _sourceBatch,
                          isExpanded: true,
                          items: _batches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                          onChanged: (val) {
                            if (val != null) _loadStudentsForSourceBatch(val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Step 2: Select Students
                    if (_sourceBatch != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('2. Select Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton(
                            onPressed: _selectAllStudents,
                            child: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(color: Color(0xFF004D40))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _studentsInSourceBatch.isEmpty
                            ? const Center(child: Text('No students in this batch.'))
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: ListView.separated(
                                  itemCount: _studentsInSourceBatch.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final student = _studentsInSourceBatch[index];
                                    final isSelected = _selectedStudentIds.contains(student.id);
                                    return Material(
                                      color: Colors.transparent,
                                      child: CheckboxListTile(
                                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text(student.fatherName ?? 'No Guardian Info'),
                                        value: isSelected,
                                        activeColor: const Color(0xFF004D40),
                                        onChanged: (val) => _toggleStudentSelection(student.id!),
                                        secondary: CircleAvatar(
                                          backgroundColor: const Color(0xFFE8F5E9),
                                          child: Text(student.name[0], style: const TextStyle(color: Color(0xFF004D40))),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Step 3: Select Target Batch
                      const Text('3. Select Target Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Batch>(
                            hint: const Text('Select Destination Batch...'),
                            value: _targetBatch,
                            isExpanded: true,
                            items: _batches.where((b) => b.id != _sourceBatch?.id).map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                            onChanged: (val) {
                              setState(() => _targetBatch = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Step 4: Promote
                      ElevatedButton.icon(
                        onPressed: _isPromoting ? null : _promoteSelectedStudents,
                        icon: _isPromoting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upgrade),
                        label: Text(_isPromoting ? 'Promoting...' : 'Promote ${_selectedStudentIds.length} Students'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700), // Gold
                          foregroundColor: const Color(0xFF004D40),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
