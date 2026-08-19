import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/dtos/user_dto.dart';
import '../../providers/teacher_form_provider.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class TeacherEditScreen extends StatefulWidget {
  final UserDTO teacher;
  const TeacherEditScreen({super.key, required this.teacher});

  @override
  State<TeacherEditScreen> createState() => _TeacherEditScreenState();
}

class _TeacherEditScreenState extends State<TeacherEditScreen> {
  late final TeacherFormProvider _provider;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _pinCtrl;
  bool _pinObscured = true;
  bool _changePin = false;

  @override
  void initState() {
    super.initState();
    _provider = TeacherFormProvider(TeacherRepository());
    _nameCtrl = TextEditingController(text: widget.teacher.name);
    _mobileCtrl = TextEditingController(text: widget.teacher.mobile ?? '');
    _pinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.updateTeacher(
      existing: widget.teacher,
      name: _nameCtrl.text,
      mobile: _mobileCtrl.text,
      newPin: _changePin ? _pinCtrl.text : null,
    );
    if (!mounted) return;
    if (_provider.status == TeacherFormStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher updated successfully!'),
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
        appBar: CustomAppBar(title: 'Edit Teacher', actions: [
          Consumer<TeacherFormProvider>(
            builder: (_, p, _) => TextButton(
              onPressed: p.isLoading ? null : _submit,
              child: const Text('SAVE', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  const _SectionHeader(icon: Icons.person_outline, title: 'Personal Information'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.badge_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required.';
                      if (v.trim().length < 2) return 'Min 2 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _mobileCtrl,
                    label: 'Mobile Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mobile is required.';
                      if (v.length != 10) return 'Must be exactly 10 digits.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildChangePinSection(),
                  const SizedBox(height: 36),
                  Consumer<TeacherFormProvider>(
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
                          disabledBackgroundColor: Colors.amber.shade200,
                        ),
                        child: p.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF004D40), strokeWidth: 2.5),
                              )
                            : const Text('Update Teacher',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildProfileHeader() {
    final initials = widget.teacher.name.isNotEmpty
        ? widget.teacher.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'T'; // ignore: avoid_empty_else
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
            tag: 'teacher_avatar_${widget.teacher.id}',
            child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF004D40),
              child: Text(initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.teacher.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
              const SizedBox(height: 4),
              Text('ID: ${widget.teacher.id ?? '-'} · ${widget.teacher.role}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.teacher.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.teacher.isActive ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  widget.teacher.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.teacher.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangePinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeader(icon: Icons.lock_outline, title: 'Change PIN'),
            const Spacer(),
            Switch(
              value: _changePin,
              activeThumbColor: const Color(0xFF004D40),
              onChanged: (v) => setState(() {
                _changePin = v;
                if (!v) _pinCtrl.clear();
              }),
            ),
          ],
        ),
        if (_changePin) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _pinCtrl,
            obscureText: _pinObscured,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _changePin
                ? (v) {
                    if (v == null || v.isEmpty) return 'PIN is required when changing.';
                    if (v.length < 4 || v.length > 6) return 'PIN must be 4–6 digits.';
                    return null;
                  }
                : null,
            decoration: InputDecoration(
              labelText: 'New PIN (4–6 digits)',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF004D40), size: 20),
              suffixIcon: IconButton(
                icon: Icon(_pinObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.black38, size: 20),
                onPressed: () => setState(() => _pinObscured = !_pinObscured),
              ),
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
          ),
        ],
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF004D40), size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
      ],
    );
  }
}
