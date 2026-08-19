import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../domain/dtos/user_dto.dart';
import '../../providers/batch_form_provider.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class BatchEditScreen extends StatefulWidget {
  final Batch batch;
  const BatchEditScreen({super.key, required this.batch});

  @override
  State<BatchEditScreen> createState() => _BatchEditScreenState();
}

class _BatchEditScreenState extends State<BatchEditScreen> {
  late final BatchFormProvider _provider;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _timingCtrl;

  int? _selectedTeacherId;
  List<UserDTO> _teachers = [];
  bool _loadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _provider = BatchFormProvider(BatchRepository());
    final b = widget.batch;
    _nameCtrl = TextEditingController(text: b.name);
    _timingCtrl = TextEditingController(text: b.timing);
    _selectedTeacherId = b.teacherId;
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
    await _provider.updateBatch(
      existing: widget.batch,
      name: _nameCtrl.text,
      timing: _timingCtrl.text,
      teacherId: _selectedTeacherId,
    );
    if (!mounted) return;
    if (_provider.status == BatchFormStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch updated successfully!'),
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
          title: 'Edit Batch',
          actions: [
            Consumer<BatchFormProvider>(
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
                  const _SectionTitle('Batch Information'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Batch Name',
                    icon: Icons.class_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Batch name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _timingCtrl,
                    label: 'Batch Timing',
                    icon: Icons.access_time_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Timing is required' : null,
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
                            : const Text('Update Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    final b = widget.batch;
    final initials = b.name.isNotEmpty
        ? b.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'B';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8D5), width: 1.2),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'batch_avatar_${b.id}',
            child: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF004D40),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
              const SizedBox(height: 4),
              Text('Timing: ${b.timing}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        ],
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
        labelText: 'Assign Teacher',
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
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
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
