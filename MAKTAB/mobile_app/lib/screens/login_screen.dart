import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:maktab_app/services/backup_restore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  final int _pinLength = 4;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _hasBiometricSession = false; // only show if user previously enabled it
  bool _showPin = false;
  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) return;
    try {
      bool canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      // Only show biometric button if the user explicitly enabled it before
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('use_biometric_login') ?? false;
      if (mounted) {
        setState(() {
          _hasBiometricSession = canCheck && enabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _authenticateBiometric() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) return;
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to authenticate',
        biometricOnly: true,
      );
      if (authenticated && mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        bool success = await auth.loginWithBiometrics();
        if (success) {
          if (!mounted) return;
          if (auth.currentUser?.role == 'admin') {
            context.go('/admin');
          } else {
            context.go('/teacher');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No saved session found for biometrics. Login with PIN first.')),
            );
          }
        }
      }
    } catch (_) {}
  }


  void _onKeypadPressed(String digit) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == _pinLength) {
        _attemptLogin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _attemptLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = await auth.login(_pin);
    if (!mounted) return;
    
    if (success) {
      if (auth.currentUser?.role == 'admin') {
        context.go('/admin');
      } else {
        context.go('/teacher'); // Simplified login for teachers
      }
    } else {
      setState(() {
        _pin = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid PIN. Please try again.')),
      );
    }
  }

  Future<void> _handleEmergencyRestore() async {
    final TextEditingController dobController = TextEditingController();
    final bool? authorized = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emergency Restore Authorization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This action will overwrite the current database. Please verify your identity by entering the Admin Date of Birth.', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'Admin Date of Birth (YYYY-MM-DD)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final success = await auth.verifyAdminDob(dobController.text);
                if (!context.mounted) return;
                Navigator.pop(context, success);
              },
              child: const Text('Verify & Proceed')
            ),
          ],
        );
      }
    );

    if (authorized != true) {
      if (mounted && dobController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authorization Failed. Incorrect Date of Birth.')));
      }
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null) {
        final backupService = BackupRestoreService();
        final success = await backupService.restoreBackup(result.files.single.path!);
        
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored! Please log in.')));
          Provider.of<AuthProvider>(context, listen: false).initialize();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to restore backup')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restoring backup: $e')));
    }
  }

  void _showForgotPinDialog() {
    final TextEditingController dobController = TextEditingController();
    final TextEditingController newPinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Forgot PIN?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('If you are a Teacher, please contact your Administrator to reset your PIN.', style: TextStyle(color: Colors.black87)),
              SizedBox(height: 16),
              Text('If you are the Administrator, enter your Date of Birth to reset your PIN.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              TextField(
                controller: dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  }
                },
              ),
              TextField(
                controller: newPinController,
                decoration: InputDecoration(labelText: 'New 4-Digit PIN'),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final success = await auth.resetAdminPin(newPinController.text, dobController.text);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Admin PIN reset successfully!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed. Invalid Date of Birth or input.')));
                }
              }, 
              child: const Text('Reset Admin PIN')
            ),
          ],
        );
      }
    );
  }

  void _showEmailLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in with Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'teacher@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final nav = Navigator.of(ctx);
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final success = await auth.loginWithEmail(
                emailController.text,
                passwordController.text,
              );
              if (success) {
                nav.pop();
                if (auth.currentUser?.role == 'admin') {
                  router.go('/admin');
                } else {
                  router.go('/teacher');
                }
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(auth.lastAuthError.isNotEmpty ? auth.lastAuthError : 'Invalid credentials')),
                );
              }
            },
            child: const Text('Sign In', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE9F1E9), // Light Cream/Green
            foregroundColor: const Color(0xFF004D40), // Dark Green
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
            elevation: 2,
          ),
          onPressed: () {
            importFeedback();
            _onKeypadPressed(digit);
          },
          child: Text(
            digit,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }

  void importFeedback() {
    try {
      // Trigger a light tactile click haptic response
      HapticFeedback.lightImpact();
      Feedback.forTap(context);
    } catch (_) {}
  }

  final List<String> _keypadDigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

  Widget _buildKeyGrid() {
    List<String> digits = List.from(_keypadDigits);

    
    // Grid alignment helper
    final row1 = digits.sublist(0, 3);
    final row2 = digits.sublist(3, 6);
    final row3 = digits.sublist(6, 9);
    final zeroDigit = digits.last;

    return Column(
      children: [
        Row(
          children: row1.map((d) => _buildKeypadButton(d)).toList(),
        ),
        Row(
          children: row2.map((d) => _buildKeypadButton(d)).toList(),
        ),
        Row(
          children: row3.map((d) => _buildKeypadButton(d)).toList(),
        ),
        Row(
          children: [
            Expanded(
              child: _hasBiometricSession ? IconButton(
                icon: const Icon(Icons.fingerprint, color: Color(0xFFFFD700), size: 36),
                onPressed: _authenticateBiometric,
                tooltip: 'Biometric Login',
              ) : const SizedBox.shrink(),
            ),
            _buildKeypadButton(zeroDigit),
            Expanded(
              child: IconButton(
                icon: const Icon(Icons.backspace, color: Colors.white, size: 26),
                onPressed: _onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF004D40), // Dark Green Islamic UI
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                "MAKTAB",
                style: const TextStyle(
                  color: Color(0xFFFFD700), // Gold
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Text(
                "Idara-e-Dawatul Qur'an",
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (index) {
                      if (_showPin && index < _pin.length) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 20,
                          height: 24,
                          alignment: Alignment.center,
                          child: Text(
                            _pin[index],
                            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _pin.length ? const Color(0xFFFFD700) : Colors.white30,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _showPin ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPin = !_showPin;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 50),
              if (auth.isLoading) const CircularProgressIndicator(color: Color(0xFFFFD700)),
              if (!auth.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _buildKeyGrid(),
                ),
              if (!auth.isLoading) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700),
                    side: const BorderSide(color: Color(0xFFFFD700)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _showEmailLoginDialog,
                  icon: const Icon(Icons.email),
                  label: const Text('Sign in with Email (Firebase)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _showForgotPinDialog, 
                      icon: const Icon(Icons.help_outline, color: Colors.white70, size: 18),
                      label: const Text("Forgot PIN?", style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton.icon(
                      onPressed: _handleEmergencyRestore, 
                      icon: const Icon(Icons.settings_backup_restore, color: Colors.white70, size: 18),
                      label: const Text("Emergency Restore", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
