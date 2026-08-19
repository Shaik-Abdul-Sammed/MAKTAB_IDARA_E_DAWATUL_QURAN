import 'package:flutter/material.dart';
import 'package:maktab_app/widgets/empty_state_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/widgets/shimmer_loader.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  _StudentManagementScreenState createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final StudentRepository _studentRepository = StudentRepository();
  final BatchRepository _batchRepository = BatchRepository();
  
  List<Student> _students = [];
  List<Batch> _batches = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final students = await _studentRepository.getAllStudents();
    final batches = await _batchRepository.getAllBatches();
    setState(() {
      _students = students;
      _batches = batches;
      _isLoading = false;
    });
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final admissionController = TextEditingController();
    final phoneController = TextEditingController();
    final fatherNameController = TextEditingController();
    int? selectedBatchId = _batches.isNotEmpty ? _batches.first.id : null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Register New Student', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: admissionController,
                        decoration: InputDecoration(
                          labelText: 'Admission Number',
                          prefixIcon: const Icon(Icons.numbers, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Student Name',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fatherNameController,
                        decoration: InputDecoration(
                          labelText: 'Father\'s Name',
                          prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Guardian Mobile',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      if (_batches.isEmpty)
                        const Text('Please create a batch first in Batch Management', style: TextStyle(color: Colors.red))
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedBatchId,
                          decoration: InputDecoration(
                            labelText: 'Assign Batch',
                            prefixIcon: const Icon(Icons.class_, color: Color(0xFF004D40)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _batches.map((batch) {
                            return DropdownMenuItem<int>(
                              value: batch.id,
                              child: Text(batch.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedBatchId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Please select a batch' : null,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedBatchId != null) {
                      final newStudent = Student(
                        name: nameController.text.trim(),
                        admissionNumber: admissionController.text.trim(),
                        fatherName: fatherNameController.text.trim().isNotEmpty ? fatherNameController.text.trim() : null,
                        phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                        batchId: selectedBatchId!,
                        createdAt: DateTime.now().toIso8601String(),
                      );
                      await _studentRepository.insertStudent(newStudent);
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(Student student) {
    final nameController = TextEditingController(text: student.name);
    final admissionController = TextEditingController(text: student.admissionNumber);
    final phoneController = TextEditingController(text: student.phone ?? '');
    final fatherNameController = TextEditingController(text: student.fatherName ?? '');
    int? selectedBatchId = student.batchId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edit Student: ${student.name}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: admissionController,
                        decoration: InputDecoration(
                          labelText: 'Admission Number',
                          prefixIcon: const Icon(Icons.numbers, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Student Name',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fatherNameController,
                        decoration: InputDecoration(
                          labelText: 'Father\'s Name',
                          prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Guardian Mobile',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedBatchId,
                        decoration: InputDecoration(
                          labelText: 'Assign Batch',
                          prefixIcon: const Icon(Icons.class_, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _batches.map((batch) {
                          return DropdownMenuItem<int>(
                            value: batch.id,
                            child: Text(batch.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedBatchId = val;
                          });
                        },
                        validator: (val) => val == null ? 'Please select a batch' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedBatchId != null) {
                      final updatedStudent = Student(
                        id: student.id,
                        name: nameController.text.trim(),
                        admissionNumber: admissionController.text.trim(),
                        fatherName: fatherNameController.text.trim().isNotEmpty ? fatherNameController.text.trim() : null,
                        phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                        batchId: selectedBatchId!,
                        createdAt: student.createdAt,
                      );
                      await _studentRepository.updateStudent(updatedStudent);
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(Student student) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${student.name}? This will permanently wipe their attendance and Quran progress logs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where((student) {
      final query = _searchQuery.toLowerCase();
      return student.name.toLowerCase().contains(query) || student.admissionNumber.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text('Student Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by name or admission number...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
            ),
            
            // Student list roster
            Expanded(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: ShimmerListLoader())
                  : filteredStudents.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.school,
                          title: 'No Students Found',
                          message: 'There are currently no students registered matching the search query.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final batchName = _batches
                                .firstWhere((b) => b.id == student.batchId, orElse: () => Batch(name: 'Unassigned', timing: ''))
                                .name;
                                
                            return Dismissible(
                              key: Key('student_${student.id}'),
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20.0),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.edit, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade800,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  return await _showDeleteConfirmation(student);
                                } else {
                                  _showEditStudentDialog(student);
                                  return false;
                                }
                              },
                              onDismissed: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  await _studentRepository.deleteStudent(student.id!);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${student.name} deleted successfully'))
                                  );
                                  _fetchData();
                                }
                              },
                              child: Card(
                                color: Colors.white,
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF004D40),
                                    foregroundColor: Colors.white,
                                    child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S'),
                                  ),
                                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF004D40))),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Admission ID: ${student.admissionNumber}'),
                                      const SizedBox(height: 2),
                                      Text('Class Batch: $batchName'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF004D40)),
                                  onTap: () {
                                    context.push('/admin/students/profile', extra: student);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('Add Student', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
