import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/dtos/user_dto.dart';
import '../../providers/batch_form_provider.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class BatchAddScreen extends StatefulWidget {
  const BatchAddScreen({super.key});

  @override
  State<BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchAddScreenState extends State<BatchAddScreen> {
  late final BatchFormProvider _provider;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _timingCtrl;

  int? _selectedTeacherId;
  List<UserDTO> _teachers = [];
  bool _loadingTeachers = true;

  final List<String> _timingPresets = [
    '07:00 AM - 08:30 AM (Morning)',
    '08:30 AM - 10:00 AM (Forenoon)',
    '04:00 PM - 05:30 PM (Afternoon)',
    '05:30 PM - 07:00 PM (Evening)',
    '07:30 PM - 09:00 PM (Night)',
  ];

  @override
  void initState() {
    super.initState();
    _provider = BatchFormProvider(BatchRepository());
    _nameCtrl = TextEditingController();
    _timingCtrl = TextEditingController();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final list = await TeacherRepository().getAllTeachers();
      if (mounted) {
        setState(() {
          _teachers = list;
          _loadingTeachers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTeachers = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timingCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.addBatch(
      name: _nameCtrl.text,
      timing: _timingCtrl.text,
      teacherId: _selectedTeacherId,
    );
    if (!mounted) return;
    if (_provider.status == BatchFormStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch created successfully!'),
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
        appBar: const CustomAppBar(title: 'Create New Batch'),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Batch Information'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Batch Name',
                    hint: 'e.g. Hifz Morning Batch A',
                    icon: Icons.class_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Batch name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _timingCtrl,
                    label: 'Batch Timing',
                    hint: 'e.g. 07:00 AM - 08:30 AM',
                    icon: Icons.access_time_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Timing is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Timing Presets Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _timingPresets.map((preset) {
                      return ActionChip(
                        label: Text(preset, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD8E8D5)),
                        onPressed: () {
                          setState(() => _timingCtrl.text = preset);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('Teacher Assignment'),
                  const SizedBox(height: 12),
                  _buildTeacherDropdown(),
                  const SizedBox(height: 36),

                  Consumer<BatchFormProvider>(
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
                            : const Text('Save Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildTeacherDropdown() {
    if (_loadingTeachers) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return DropdownButtonFormField<int?>(
      initialValue: _selectedTeacherId,
      decoration: InputDecoration(
        labelText: 'Assign Teacher (Optional)',
        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF004D40), size: 20),
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
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Unassigned', style: TextStyle(fontSize: 14, color: Colors.black45)),
        ),
        ..._teachers.map((t) {
          return DropdownMenuItem<int?>(
            value: t.id,
            child: Text(t.name, style: const TextStyle(fontSize: 14)),
          );
        }),
      ],
      onChanged: (val) => setState(() => _selectedTeacherId = val),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
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
