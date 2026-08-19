import 'package:flutter/material.dart';
import 'package:maktab_app/widgets/empty_state_widget.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/widgets/shimmer_loader.dart';

class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  _BatchManagementScreenState createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  final BatchRepository _batchRepository = BatchRepository();
  final UserRepository _userRepository = UserRepository();
  
  List<Batch> _batches = [];
  List<User> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final batches = await _batchRepository.getAllBatches();
    final teachers = await _userRepository.getAllTeachers();
    setState(() {
      _batches = batches;
      _teachers = teachers;
      _isLoading = false;
    });
  }

  String _getTeacherName(int? teacherId) {
    if (teacherId == null) return 'Unassigned';
    try {
      return _teachers.firstWhere((t) => t.id == teacherId).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showAddBatchDialog() {
    final nameController = TextEditingController();
    final timingController = TextEditingController();
    int? selectedTeacherId;
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Create New Batch', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Batch Name (e.g., Batch 1)',
                          prefixIcon: const Icon(Icons.class_, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter batch name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: timingController,
                        decoration: InputDecoration(
                          labelText: 'Timing (e.g., Asar to Maghrib)',
                          prefixIcon: const Icon(Icons.access_time, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter timings' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        decoration: InputDecoration(
                          labelText: 'Assign Teacher',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        initialValue: selectedTeacherId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ..._teachers.map((t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text(t.name),
                          )),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedTeacherId = val;
                          });
                        },
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
                    if (formKey.currentState!.validate()) {
                      final newBatch = Batch(
                        name: nameController.text.trim(),
                        timing: timingController.text.trim(),
                        teacherId: selectedTeacherId,
                      );
                      await _batchRepository.insertBatch(newBatch);
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showEditBatchDialog(Batch batch) {
    final nameController = TextEditingController(text: batch.name);
    final timingController = TextEditingController(text: batch.timing);
    int? selectedTeacherId = batch.teacherId;
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edit Batch: ${batch.name}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Batch Name (e.g., Batch 1)',
                          prefixIcon: const Icon(Icons.class_, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter batch name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: timingController,
                        decoration: InputDecoration(
                          labelText: 'Timing (e.g., Asar to Maghrib)',
                          prefixIcon: const Icon(Icons.access_time, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter timings' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        decoration: InputDecoration(
                          labelText: 'Assign Teacher',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        initialValue: selectedTeacherId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ..._teachers.map((t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text(t.name),
                          )),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedTeacherId = val;
                          });
                        },
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
                    if (formKey.currentState!.validate()) {
                      final updatedBatch = Batch(
                        id: batch.id,
                        name: nameController.text.trim(),
                        timing: timingController.text.trim(),
                        teacherId: selectedTeacherId,
                      );
                      await _batchRepository.updateBatch(updatedBatch);
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(Batch batch) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${batch.name}? Student references to this batch will remain, but the batch itself will be deleted.'),
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

  Future<void> _showManageStudentsDialog(Batch batch) async {
    final StudentRepository studentRepo = StudentRepository();
    List<Student> allStudents = [];
    Set<int> selectedStudentIds = {};
    bool isLoading = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (isLoading) {
              studentRepo.getAllStudents().then((students) {
                if (context.mounted) {
                  setStateDialog(() {
                    allStudents = students;
                    selectedStudentIds = students
                        .where((s) => s.batchId == batch.id)
                        .map((s) => s.id!)
                        .toSet();
                    isLoading = false;
                  });
                }
              });
            }

            return AlertDialog(
              title: Text('Manage Students - ${batch.name}', style: const TextStyle(color: Color(0xFF004D40))),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : allStudents.isEmpty
                        ? const Center(child: Text('No students found.'))
                        : ListView.builder(
                            itemCount: allStudents.length,
                            itemBuilder: (context, index) {
                              final student = allStudents[index];
                              final isSelected = selectedStudentIds.contains(student.id);
                              return Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  activeColor: const Color(0xFF004D40),
                                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ADM: ${student.admissionNumber}'),
                                  value: isSelected,
                                  onChanged: (bool? checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        selectedStudentIds.add(student.id!);
                                      } else {
                                        selectedStudentIds.remove(student.id!);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
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
                  ),
                  onPressed: () async {
                    setStateDialog(() => isLoading = true);
                    try {
                      // We need to update each student's batchId.
                      for (final student in allStudents) {
                        if (selectedStudentIds.contains(student.id)) {
                          if (student.batchId != batch.id) {
                            final updated = student.copyWith(batchId: batch.id);
                            await studentRepo.updateStudent(updated);
                          }
                        } else {
                          if (student.batchId == batch.id) {
                            // Only set to null if they were previously in THIS batch. Don't touch students in other batches.
                            final updated = student.copyWith(batchId: null);
                            await studentRepo.updateStudent(updated);
                          }
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Students updated successfully'))
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating students: $e'))
                        );
                      }
                    } finally {
                      setStateDialog(() => isLoading = false);
                    }
                  },
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text('Batch Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16.0), child: ShimmerListLoader())
          : _batches.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.class_,
                  title: 'No Batches Found',
                  message: 'There are currently no batches created yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Dismissible(
                      key: Key('batch_${batch.id}'),
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
                          return await _showDeleteConfirmation(batch);
                        } else {
                          _showEditBatchDialog(batch);
                          return false;
                        }
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          await _batchRepository.deleteBatch(batch.id!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${batch.name} deleted successfully'))
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
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE9F1E9),
                            radius: 25,
                            child: Icon(Icons.class_, color: Color(0xFF004D40)),
                          ),
                          title: Text(
                            batch.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF004D40)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text('Timing: ${batch.timing}'),
                              Text('Teacher: ${_getTeacherName(batch.teacherId)}'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Color(0xFF004D40)),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditBatchDialog(batch);
                              } else if (value == 'manage_students') {
                                _showManageStudentsDialog(batch);
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(batch).then((confirm) async {
                                  if (confirm == true) {
                                    await _batchRepository.deleteBatch(batch.id!);
                                    _fetchData();
                                  }
                                });
                              }
                            },
                            itemBuilder: (context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Color(0xFF004D40)),
                                  title: Text('Edit details'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'manage_students',
                                child: ListTile(
                                  leading: Icon(Icons.group_add_rounded, color: Color(0xFF004D40)),
                                  title: Text('Manage Students'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red),
                                  title: Text('Delete batch'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBatchDialog,
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('Create Batch', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
