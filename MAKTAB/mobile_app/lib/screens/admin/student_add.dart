import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/batch.dart';
import '../../providers/student_form_provider.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../services/database_helper.dart';
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
  late final TextEditingController _guardianPhoneCtrl;
  late final TextEditingController _feesCtrl;
  final FocusNode _phoneFocusNode = FocusNode();
  String? _selectedPhotoPath;
  String? _defaultAdmNumber;

  String _gender = 'Male';
  String _preferredLanguage = 'en';
  int? _selectedBatchId;
  List<Batch> _batches = [];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _provider = StudentFormProvider(StudentRepository());
    _admCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _arabicNameCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _fatherNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _guardianPhoneCtrl = TextEditingController();
    _feesCtrl = TextEditingController();
    _loadBatches();
    _loadDefaultAdmissionNumber();
  }

  Future<void> _loadDefaultAdmissionNumber() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery('SELECT MAX(id) as max_id FROM students');
      final maxId = (res.isNotEmpty ? res.first['max_id'] as int? : null) ?? 0;
      final nextSeq = (maxId + 1).toString().padLeft(3, '0');
      final year = DateTime.now().year;
      if (mounted) {
        setState(() {
          _defaultAdmNumber = 'ADM-$year-$nextSeq';
        });
      }
    } catch (e, st) {
      debugPrint('[StudentAddScreen._loadDefaultAdmissionNumber] load failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load data.')),
        );
      }
    }
  }

  Future<void> _loadBatches() async {
    try {
      final list = await BatchRepository().getAllBatches();
      int? lastUsedBatchId;
      try {
        final prefs = await SharedPreferences.getInstance();
        lastUsedBatchId = prefs.getInt('last_used_batch_id');
      } catch (e) {
        debugPrint('[StudentAddScreen._loadBatches] failed to read last_used_batch_id: $e');
      }

      if (mounted) {
        setState(() {
          _batches = list;
          _loadingBatches = false;
          if (lastUsedBatchId != null && list.any((b) => b.id == lastUsedBatchId)) {
            _selectedBatchId = lastUsedBatchId;
          } else if (list.isNotEmpty) {
            _selectedBatchId = list.first.id;
          }
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
    _guardianPhoneCtrl.dispose();
    _feesCtrl.dispose();
    _phoneFocusNode.dispose();
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

    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      final existing = await StudentRepository().findByPhone(phone);
      if (existing != null && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Mobile Number'),
            content: Text(
              'A student with this mobile number already exists:\n${existing.name} (ID: ${existing.id ?? existing.admissionNumber})\n\nDo you want to continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          _phoneFocusNode.requestFocus();
          return;
        }
      }
    }

    String adm = _admCtrl.text.trim();
    if (adm.isEmpty) {
      if (_defaultAdmNumber != null) {
        adm = _defaultAdmNumber!;
      } else {
        try {
          final db = await DatabaseHelper.instance.database;
          final res = await db.rawQuery('SELECT MAX(id) as max_id FROM students');
          final maxId = (res.isNotEmpty ? res.first['max_id'] as int? : null) ?? 0;
          final nextSeq = (maxId + 1).toString().padLeft(3, '0');
          adm = 'ADM-${DateTime.now().year}-$nextSeq';
        } catch (_) {
          adm = 'ADM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        }
      }
    }

    String? guardianPhone = _guardianPhoneCtrl.text.trim();
    if (guardianPhone.isEmpty && phone.isNotEmpty) {
      guardianPhone = phone;
    }

    await _provider.addStudent(
      admissionNumber: adm,
      name: _nameCtrl.text.trim(),
      arabicName: _arabicNameCtrl.text.trim().isEmpty ? null : _arabicNameCtrl.text.trim(),
      dob: _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
      gender: _gender,
      fatherName: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      phone: phone.isEmpty ? null : phone,
      guardianPhone: guardianPhone.isEmpty ? null : guardianPhone,
      photoPath: _selectedPhotoPath,
      batchId: _selectedBatchId,
      preferredLanguage: _preferredLanguage,
    );
    if (!mounted) return;
    if (_provider.status == StudentFormStatus.success) {
      if (_selectedBatchId != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_used_batch_id', _selectedBatchId!);
        } catch (e) {
          debugPrint('[StudentAddScreen._submit] failed to save last_used_batch_id: $e');
        }
      }
      if (!mounted) return;
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
                    child: Builder(
                      builder: (context) {
                        final photoFile = _selectedPhotoPath != null && _selectedPhotoPath!.isNotEmpty ? File(_selectedPhotoPath!) : null;
                        final hasPhoto = photoFile != null && photoFile.existsSync();
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFFE9F1E9),
                                backgroundImage: hasPhoto ? FileImage(photoFile) : null,
                                child: hasPhoto ? null : const Icon(Icons.person, color: Color(0xFF004D40), size: 40),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_a_photo, size: 18),
                              label: Text(_selectedPhotoPath == null ? 'Add Photo' : 'Change Photo'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _admCtrl,
                    label: 'Admission Number',
                    hint: _defaultAdmNumber ?? 'e.g. ADM-${DateTime.now().year}-001',
                    icon: Icons.confirmation_number_outlined,
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: ['en', 'ur', 'hi', 'te'].contains(_preferredLanguage)
                        ? _preferredLanguage
                        : 'en',
                    decoration: const InputDecoration(
                      labelText: 'Preferred Language for Receipts',
                      prefixIcon: Icon(Icons.translate),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('اردو (Urdu)')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                      DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                    ],
                    onChanged: (v) => setState(() => _preferredLanguage = v ?? 'en'),
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('Student Profile'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Student Full Name',
                    hint: 'e.g. Muhammad Zaid',
                    icon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.words,
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
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocusNode,
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
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _guardianPhoneCtrl,
                    label: 'Guardian Phone Number (Optional)',
                    hint: '10-digit number',
                    helperText: 'Leave blank to use phone number above.',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 10) {
                        return 'Guardian phone must be exactly 10 digits';
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
    final uniqueBatches = {
      for (final b in _batches)
        if (b.id != null) b.id: b
    }.values.toList();
    final hasMatch = _selectedBatchId != null &&
        uniqueBatches.any((b) => b.id == _selectedBatchId);

    return DropdownButtonFormField<int?>(
      initialValue: hasMatch ? _selectedBatchId : null,
      decoration: _inputDecoration(
        label: 'Assigned Batch',
        hint: 'Select Batch',
        icon: Icons.class_outlined,
      ),
      items: uniqueBatches.map((b) {
        return DropdownMenuItem<int?>(
          value: b.id,
          child: Text(b.name, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedBatchId = val),
    );
  }

  Widget _buildGenderSelector() {
    const validGenders = ['Male', 'Female'];
    final effectiveGender = validGenders.contains(_gender) ? _gender : validGenders.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8D5), width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveGender,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF004D40)),
          items: validGenders.map((g) {
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
    String? helperText,
    FocusNode? focusNode,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(label: label, hint: hint, helperText: helperText, icon: icon),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? helperText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11, color: Colors.black54),
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
