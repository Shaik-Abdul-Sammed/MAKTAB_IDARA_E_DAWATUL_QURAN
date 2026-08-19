import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/batch.dart';
import '../../providers/student_form_provider.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as flutter_contacts;
import 'package:permission_handler/permission_handler.dart';

class StudentAddScreen extends StatefulWidget {
  const StudentAddScreen({super.key});

  @override
  State<StudentAddScreen> createState() => _StudentAddScreenState();
}

class _StudentAddScreenState extends State<StudentAddScreen> {
  late final StudentFormProvider _provider;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _admCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _arabicNameCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _fatherNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _feesCtrl;
  String? _selectedPhotoPath;


  String _gender = 'Male';
  int? _selectedBatchId;
  List<Batch> _batches = [];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _provider = StudentFormProvider(StudentRepository());
    _admCtrl = TextEditingController(text: 'ADM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    _nameCtrl = TextEditingController();
    _arabicNameCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _fatherNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _feesCtrl = TextEditingController();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final list = await BatchRepository().getAllBatches();
      if (mounted) {
        setState(() {
          _batches = list;
          _loadingBatches = false;
          if (list.isNotEmpty) _selectedBatchId = list.first.id;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  @override
  void dispose() {
    _admCtrl.dispose();
    _nameCtrl.dispose();
    _arabicNameCtrl.dispose();
    _dobCtrl.dispose();
    _fatherNameCtrl.dispose();
    _phoneCtrl.dispose();
    _feesCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
      setState(() {
        _selectedPhotoPath = savedImage.path;
      });
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004D40),
              onPrimary: Colors.white,
              onSurface: Color(0xFF004D40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    await _provider.addStudent(
      admissionNumber: _admCtrl.text,
      name: _nameCtrl.text,
      arabicName: _arabicNameCtrl.text,
      dob: _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
      gender: _gender,
      fatherName: _fatherNameCtrl.text,
      phone: _phoneCtrl.text,
      batchId: _selectedBatchId,
    );
    if (!mounted) return;
    if (_provider.status == StudentFormStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student registered successfully!'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_provider.errorMessage),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _submit),
        ),
      );
    }
  }

  Future<void> _fillFromContact() async {
    try {
      final granted = await Permission.contacts.request().isGranted;
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied.')),
        );
        return;
      }

      final contact = await flutter_contacts.FlutterContacts.openExternalPick();
      if (contact == null) return;

      final fullContact = await flutter_contacts.FlutterContacts.getContact(contact.id);
      if (fullContact == null) return;

      final name = fullContact.displayName;
      String phone = '';
      if (fullContact.phones.isNotEmpty) {
        phone = fullContact.phones.first.number.replaceAll(RegExp(r'\D'), '');
        if (phone.length > 10) {
          phone = phone.substring(phone.length - 10);
        }
      }

      if (!mounted) return;
      setState(() {
        if (name.isNotEmpty) _fatherNameCtrl.text = name;
        if (phone.isNotEmpty) _phoneCtrl.text = phone;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact imported: $name ($phone)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: const CustomAppBar(title: 'Enroll Student'),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Academic Details'),
                  const SizedBox(height: 12),

                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFFE9F1E9),
                            backgroundImage: _selectedPhotoPath != null ? FileImage(File(_selectedPhotoPath!)) : null,
                            child: _selectedPhotoPath == null ? const Icon(Icons.person, color: Color(0xFF004D40), size: 40) : null,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo, size: 18),
                          label: Text(_selectedPhotoPath == null ? 'Add Photo' : 'Change Photo'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _admCtrl,
                    label: 'Admission Number',
                    hint: 'e.g. ADM-1002',
                    icon: Icons.confirmation_number_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildField(
                    controller: _feesCtrl,
                    label: 'Fees Amount (Optional)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildBatchDropdown(),
                  const SizedBox(height: 24),

                  const _SectionTitle('Student Profile'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Student Full Name',
                    hint: 'e.g. Muhammad Zaid',
                    icon: Icons.badge_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _arabicNameCtrl,
                    label: 'Arabic Name (Optional)',
                    hint: 'محمد زيد',
                    icon: Icons.translate_rounded,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dobCtrl,
                          readOnly: true,
                          onTap: _pickDob,
                          decoration: _inputDecoration(
                            label: 'Date of Birth',
                            hint: 'YYYY-MM-DD',
                            icon: Icons.cake_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGenderSelector()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle(
                    'Guardian Contact',
                    trailing: TextButton.icon(
                      onPressed: _fillFromContact,
                      icon: const Icon(Icons.contact_phone, size: 16),
                      label: const Text('Import Contact', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _fatherNameCtrl,
                    label: "Father's / Guardian Name",
                    hint: 'e.g. Abdullah Khan',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Parent Phone Number',
                    hint: '10-digit number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 10) {
                        return 'Must be 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  Consumer<StudentFormProvider>(
                    builder: (_, p, _) => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: p.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: p.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Color(0xFF004D40), strokeWidth: 2.5),
                              )
                            : const Text('Save Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchDropdown() {
    if (_loadingBatches) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _selectedBatchId,
      decoration: _inputDecoration(
        label: 'Assigned Batch',
        hint: 'Select Batch',
        icon: Icons.class_outlined,
      ),
      items: _batches.map((b) {
        return DropdownMenuItem<int>(
          value: b.id,
          child: Text(b.name, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedBatchId = val),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8D5), width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF004D40)),
          items: const ['Male', 'Female'].map((g) {
            return DropdownMenuItem<String>(
              value: g,
              child: Text(g, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _gender = val);
          },
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF004D40), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8E8D5), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004D40), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
        // ignore: use_null_aware_elements
        if (trailing != null) trailing!,
      ],
    );
  }
}
