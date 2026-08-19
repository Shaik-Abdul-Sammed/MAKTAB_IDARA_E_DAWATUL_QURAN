import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../providers/student_form_provider.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudentEditScreen extends StatefulWidget {
  final Student student;
  const StudentEditScreen({super.key, required this.student});

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
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


  late String _gender;
  int? _selectedBatchId;
  List<Batch> _batches = [];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _provider = StudentFormProvider(StudentRepository());
    final s = widget.student;
    _admCtrl = TextEditingController(text: s.admissionNumber);
    _nameCtrl = TextEditingController(text: s.name);
    _arabicNameCtrl = TextEditingController(text: s.arabicName ?? '');
    _dobCtrl = TextEditingController(text: s.dob ?? '');
    _fatherNameCtrl = TextEditingController(text: s.fatherName ?? '');
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _gender = s.gender ?? 'Male';
    _selectedBatchId = s.batchId;
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final list = await BatchRepository().getAllBatches();
      if (mounted) {
        setState(() {
          _batches = list;
          _loadingBatches = false;
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
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 8));
    if (_dobCtrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobCtrl.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.updateStudent(
      existing: widget.student,
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
          content: Text('Student profile updated!'),
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: 'Edit Student',
          actions: [
            Consumer<StudentFormProvider>(
              builder: (_, p, _) => TextButton(
                onPressed: p.isLoading ? null : _submit,
                child: const Text('SAVE', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  const _SectionTitle('Academic Details'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _admCtrl,
                    label: 'Admission Number',
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
                    icon: Icons.badge_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _arabicNameCtrl,
                    label: 'Arabic Name (Optional)',
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

                  const _SectionTitle('Guardian Contact'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _fatherNameCtrl,
                    label: "Father's / Guardian Name",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Parent Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
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
                            : const Text('Update Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildHeaderCard() {
    final s = widget.student;
    final initials = s.name.isNotEmpty
        ? s.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8D5), width: 1.2),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Hero(
                tag: 'student_avatar_${s.id}',
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF004D40),
                    backgroundImage: _selectedPhotoPath != null ? FileImage(File(_selectedPhotoPath!)) : null,
                    child: _selectedPhotoPath == null ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo, size: 14),
                label: const Text('Change Photo', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
                const SizedBox(height: 4),
                Text('ADM: ${s.admissionNumber}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        ],
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
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(label: label, icon: icon ?? Icons.edit),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)));
  }
}
