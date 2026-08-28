import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:maktab_app/widgets/empty_state_widget.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/widgets/shimmer_loader.dart';
import 'package:maktab_app/utils/whatsapp_utility.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  _TeacherManagementScreenState createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final BatchRepository _batchRepository = BatchRepository();
  List<Batch> _allBatches = [];
  List<User> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await _userRepository.getAllTeachers();
    final batches = await _batchRepository.getAllBatches();
    setState(() {
      _teachers = teachers;
      _allBatches = batches;
      _isLoading = false;
    });
  }

  String _hashPin(String pin) {
    const salt = 'idara_maktab_sec_salt_2026';
    var bytes = utf8.encode('$salt$pin');
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final mobileController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedPhotoPath;
    List<int> selectedBatchIds = [];
    
    Future<void> pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = p.basename(pickedFile.path);
        final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
        setState(() {
          selectedPhotoPath = savedImage.path;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Teacher', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => pickImage(setState),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFE9F1E9),
                          backgroundImage: selectedPhotoPath != null ? FileImage(File(selectedPhotoPath!)) : null,
                          child: selectedPhotoPath == null ? const Icon(Icons.add_a_photo, color: Color(0xFF004D40), size: 30) : null,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => pickImage(setState),
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: Text(selectedPhotoPath == null ? 'Add Photo' : 'Change Photo'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Teacher Name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter teacher name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinController,
                    decoration: InputDecoration(
                      labelText: '4-Digit PIN',
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (val) {
                      if (val == null || val.length < 6) return 'PIN must be at least 6 digits';
                      if (int.tryParse(val) == null) return 'PIN must be numeric';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Assign Batches:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: _allBatches.map((batch) {
                      final isSelected = selectedBatchIds.contains(batch.id);
                      return ChoiceChip(
                        label: Text(batch.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedBatchIds.add(batch.id!);
                            } else {
                              selectedBatchIds.remove(batch.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  )
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
                  final newUser = User(
                    name: nameController.text.trim(),
                    pinHash: _hashPin(pinController.text),
                    role: 'teacher',
                    mobile: mobileController.text.trim().isNotEmpty ? mobileController.text.trim() : null,
                    photoPath: selectedPhotoPath,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  int newTeacherId = await _userRepository.insertUser(newUser);

                  // Provision Teacher Auth Account via Secondary FirebaseApp (Manager session remains intact)
                  if (context.mounted) {
                    await context.read<AuthProvider>().provisionTeacherAuthAccount(
                      teacherId: newTeacherId,
                      name: nameController.text.trim(),
                      rawPin: pinController.text,
                      mobile: mobileController.text.trim(),
                    );
                  }
                  
                  // Assign batches
                  for (int batchId in selectedBatchIds) {
                    await _batchRepository.assignTeacherToBatch(batchId, newTeacherId);
                  }
                  
                  final teacherMobile = mobileController.text.trim();
                  final teacherName = nameController.text.trim();
                  final teacherPin = pinController.text.trim();

                  if (context.mounted) Navigator.pop(context);
                  _fetchTeachers();
                  
                  // Ask if they want to share via WhatsApp
                  if (context.mounted && teacherMobile.isNotEmpty) {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Share PIN'),
                        content: const Text('Do you want to send the PIN to the teacher via WhatsApp?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              if (context.mounted) {
                                await WhatsAppUtility.sendTeacherCredentials(context, teacherMobile, teacherName, teacherPin);
                              }
                            },
                            child: const Text('Yes, Send'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Teacher'),
            ),
          ],
            );
          },
        );
      },
    );
  }
  void _showEditTeacherDialog(User teacher) {
    final nameController = TextEditingController(text: teacher.name);
    final mobileController = TextEditingController(text: teacher.mobile ?? '');
    final formKey = GlobalKey<FormState>();
    String? selectedPhotoPath = teacher.photoPath;
    
    // Find currently assigned batches for this teacher
    List<int> initialBatchIds = _allBatches.where((b) => b.teacherId == teacher.id).map((b) => b.id!).toList();
    List<int> selectedBatchIds = List.from(initialBatchIds);

    Future<void> pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = p.basename(pickedFile.path);
        final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
        setState(() {
          selectedPhotoPath = savedImage.path;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Teacher Details', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => pickImage(setState),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFE9F1E9),
                          backgroundImage: selectedPhotoPath != null ? FileImage(File(selectedPhotoPath!)) : null,
                          child: selectedPhotoPath == null ? const Icon(Icons.add_a_photo, color: Color(0xFF004D40), size: 30) : null,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => pickImage(setState),
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: Text(selectedPhotoPath == null ? 'Add Photo' : 'Change Photo'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Teacher Name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter teacher name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Assign Batches:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: _allBatches.map((batch) {
                      final isSelected = selectedBatchIds.contains(batch.id);
                      return ChoiceChip(
                        label: Text(batch.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedBatchIds.add(batch.id!);
                            } else {
                              selectedBatchIds.remove(batch.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  )
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
                  final updatedUser = User(
                    id: teacher.id,
                    name: nameController.text.trim(),
                    pinHash: teacher.pinHash,
                    role: teacher.role,
                    mobile: mobileController.text.trim().isNotEmpty ? mobileController.text.trim() : null,
                    photoPath: selectedPhotoPath,
                    isActive: teacher.isActive,
                    createdAt: teacher.createdAt,
                  );
                  await _userRepository.updateUser(updatedUser);
                  
                  // Update batch assignments
                  for (int batchId in initialBatchIds) {
                    if (!selectedBatchIds.contains(batchId)) {
                      await _batchRepository.removeTeacherFromBatch(batchId);
                    }
                  }
                  for (int batchId in selectedBatchIds) {
                    if (!initialBatchIds.contains(batchId)) {
                      await _batchRepository.assignTeacherToBatch(batchId, teacher.id!);
                    }
                  }
                  
                  if (context.mounted) Navigator.pop(context);
                  _fetchTeachers();
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
  // _sendPinToWhatsApp removed in favor of WhatsAppUtility

  void _showResetPinDialog(User teacher) {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset PIN for ${teacher.name}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: pinController,
              decoration: InputDecoration(
                labelText: 'New 4-Digit PIN',
                prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF004D40)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (val) {
                if (val == null || val.length != 4) return 'PIN must be exactly 4 digits';
                if (int.tryParse(val) == null) return 'PIN must be numeric';
                return null;
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _userRepository.updateUserPin(teacher.id!, _hashPin(pinController.text));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PIN successfully updated for ${teacher.name}'))
                    );
                    
                    if (teacher.mobile != null && teacher.mobile!.isNotEmpty) {
                       showDialog(
                         context: context,
                         builder: (ctx) => AlertDialog(
                           title: const Text('Share PIN'),
                           content: const Text('Do you want to send the new PIN to the teacher via WhatsApp?'),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                             ElevatedButton(
                               onPressed: () {
                                 Navigator.pop(ctx);
                                 WhatsAppUtility.sendTeacherCredentials(context, teacher.mobile!, teacher.name, pinController.text);
                               },
                               child: const Text('Yes, Send'),
                             ),
                           ],
                         ),
                       );
                    }
                  }
                }
              },
              child: const Text('Update PIN'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(User teacher) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${teacher.name}? This will remove their profile from the local SQLite database.'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text('Teacher Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16.0), child: ShimmerListLoader())
          : _teachers.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.person_off,
                  title: 'No Teachers Found',
                  message: 'There are currently no teachers added yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _teachers[index];
                    return Dismissible(
                      key: Key('teacher_${teacher.id}'),
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
                          return await _showDeleteConfirmation(teacher);
                        } else {
                          _showEditTeacherDialog(teacher);
                          return false; // Prevent auto dismiss on swipe-to-edit
                        }
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          await _userRepository.deleteUser(teacher.id!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${teacher.name} deleted successfully'))
                          );
                          _fetchTeachers();
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
                            backgroundColor: const Color(0xFFE9F1E9),
                            radius: 25,
                            backgroundImage: teacher.photoPath != null ? FileImage(File(teacher.photoPath!)) : null,
                            child: teacher.photoPath == null ? const Icon(Icons.person, color: Color(0xFF004D40)) : null,
                          ),
                          title: Text(
                            teacher.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF004D40)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Mobile: ${teacher.mobile ?? "N/A"}'),
                              const SizedBox(height: 2),
                              Text('Role: ${teacher.role}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (teacher.mobile != null && teacher.mobile!.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.message, color: Colors.green),
                                  tooltip: 'Send/Reset PIN via WhatsApp',
                                  onPressed: () {
                                    _showResetPinDialog(teacher);
                                  },
                                ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Color(0xFF004D40)),
                                    onSelected: (value) async {
                                      if (value == 'reset_password') {
                                        if (teacher.mobile != null && teacher.mobile!.contains('@')) {
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          final success = await auth.sendPasswordReset(teacher.mobile!);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(success ? 'Password reset link sent to ${teacher.mobile}' : 'Failed to send reset link')),
                                            );
                                          }
                                        } else {
                                          _showResetPinDialog(teacher);
                                        }
                                      } else if (value == 'edit') {
                                        _showEditTeacherDialog(teacher);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit, color: Color(0xFF004D40)),
                                          title: Text('Edit Details'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'reset_password',
                                        child: ListTile(
                                          leading: Icon(Icons.mark_email_unread, color: Color(0xFF004D40)),
                                          title: Text('Send Password Reset Link'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('Add Teacher', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
