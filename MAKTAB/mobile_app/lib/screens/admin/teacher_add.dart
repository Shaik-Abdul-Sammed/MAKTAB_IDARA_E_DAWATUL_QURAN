import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/utils/whatsapp_utility.dart';
import 'package:provider/provider.dart';
import '../../providers/teacher_form_provider.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as flutter_contacts;
import 'package:permission_handler/permission_handler.dart';

class TeacherAddScreen extends StatefulWidget {
  const TeacherAddScreen({super.key});

  @override
  State<TeacherAddScreen> createState() => _TeacherAddScreenState();
}

class _TeacherAddScreenState extends State<TeacherAddScreen> {
  late final TeacherFormProvider _provider;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _pinCtrl;
  late final TextEditingController _confirmPinCtrl;
  bool _pinObscured = true;
  bool _confirmPinObscured = true;

  @override
  void initState() {
    super.initState();
    _provider = TeacherFormProvider(TeacherRepository());
    _nameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _pinCtrl = TextEditingController();
    _confirmPinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _provider.dispose();
    super.dispose();
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
      
      // Import package dynamically or statically
      final contact = await flutter_contacts.FlutterContacts.openExternalPick();
      if (contact == null) return;
      
      // Read full details of the picked contact
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
        if (name.isNotEmpty) _nameCtrl.text = name;
        if (phone.isNotEmpty) _mobileCtrl.text = phone;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.addTeacher(
      name: _nameCtrl.text,
      mobile: _mobileCtrl.text,
      pin: _pinCtrl.text,
    );
    if (!mounted) return;
    if (_provider.status == TeacherFormStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher added successfully!'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
      
      if (mounted && _mobileCtrl.text.trim().isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Share PIN'),
            content: const Text('Do you want to send the PIN to the teacher via WhatsApp?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  WhatsAppUtility.sendTeacherCredentials(context, _mobileCtrl.text.trim(), _nameCtrl.text.trim(), _pinCtrl.text);
                },
                child: const Text('Yes, Send'),
              ),
            ],
          ),
        );
      }
      if (mounted) context.pop(true);
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
        appBar: const CustomAppBar(title: 'Add New Teacher'),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    trailing: TextButton.icon(
                      onPressed: _fillFromContact,
                      icon: const Icon(Icons.contact_phone, size: 16),
                      label: const Text('Import Contact', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF004D40)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. Shaikh Yusuf Ahmad',
                    icon: Icons.badge_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required.';
                      if (v.trim().length < 2) return 'Name must be at least 2 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _mobileCtrl,
                    label: 'Mobile Number',
                    hint: '10-digit number (e.g. 9876543210)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mobile number is required.';
                      if (v.length != 10) return 'Must be exactly 10 digits.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(icon: Icons.lock_outline, title: 'Login PIN'),
                  const SizedBox(height: 12),
                  _buildPinField(
                    controller: _pinCtrl,
                    label: 'Set PIN (4–6 digits)',
                    obscured: _pinObscured,
                    onToggle: () => setState(() => _pinObscured = !_pinObscured),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'PIN is required.';
                      if (v.length < 4 || v.length > 6) return 'PIN must be 4–6 digits.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPinField(
                    controller: _confirmPinCtrl,
                    label: 'Confirm PIN',
                    obscured: _confirmPinObscured,
                    onToggle: () => setState(() => _confirmPinObscured = !_confirmPinObscured),
                    validator: (v) {
                      if (v != _pinCtrl.text) return 'PINs do not match.';
                      return null;
                    },
                  ),
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
                                  color: Color(0xFF004D40),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save Teacher',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF004D40), size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.black38, size: 20),
          onPressed: onToggle,
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

// ── Section Header ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF004D40), size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}
