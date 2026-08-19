import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheckBiometrics;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Create the admin/first-user account using mobile number
      final success = await auth.registerFirstUser(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        pin: _pinController.text.trim(),
        dob: _dobController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Mark first-launch as done
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_registered', true);
        if (_canCheckBiometrics) {
          await prefs.setBool('use_biometric_login', _useBiometrics);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please log in.'),
            backgroundColor: Color(0xFF004D40),
          ),
        );
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => context.go('/welcome'),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_add_alt_1,
                          size: 56, color: Color(0xFFFFD700)),
                      SizedBox(height: 12),
                      Text(
                        'Administrator Registration',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'You will be the Admin of this Maktab.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Full Name
                _buildLabel('Full Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  id: 'field_name',
                  controller: _nameController,
                  hint: 'e.g. Shaikh Abdul Sammed',
                  icon: Icons.person_outline,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (val.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Mobile Number
                _buildLabel('Mobile Number'),
                const SizedBox(height: 6),
                _buildTextField(
                  id: 'field_mobile',
                  controller: _mobileController,
                  hint: 'e.g. 9876543210',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    if (val.trim().length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Date of Birth
                _buildLabel('Date of Birth'),
                const SizedBox(height: 6),
                _buildTextField(
                  id: 'field_dob',
                  controller: _dobController,
                  hint: 'YYYY-MM-DD',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select your Date of Birth';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // PIN
                _buildLabel('Set 4-Digit PIN'),
                const SizedBox(height: 6),
                _buildTextField(
                  id: 'field_pin',
                  controller: _pinController,
                  hint: '····',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please set a PIN';
                    if (val.length != 4) return 'PIN must be exactly 4 digits';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Confirm PIN
                _buildLabel('Confirm PIN'),
                const SizedBox(height: 6),
                _buildTextField(
                  id: 'field_confirm_pin',
                  controller: _confirmPinController,
                  hint: '····',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmPin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPin
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your PIN';
                    }
                    if (val != _pinController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),

                if (_canCheckBiometrics) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Enable Biometric Login',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Use fingerprint or FaceID to log in quickly.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _useBiometrics,
                      activeTrackColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFFFFD700),
                      onChanged: (bool value) {
                        setState(() {
                          _useBiometrics = value;
                        });
                      },
                      secondary: const Icon(Icons.fingerprint, color: Color(0xFFFFD700)),
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('btn_register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF004D40),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // I already have an account button
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Already have an account? Log In',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white38, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your mobile number is used as your identity. '
                          'You can add teachers from the Admin Dashboard later.',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildTextField({
    required String id,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      key: Key(id),
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
