import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:maktab_app/services/backup_restore_service.dart';
import 'package:maktab_app/services/remember_me_service.dart';
import 'package:maktab_app/l10n/app_localizations.dart';
import 'package:maktab_app/providers/locale_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teacherIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _obscurePassword = true;
  bool _obscurePin = true;
  String _selectedRole = 'manager'; // Default selected role ('manager' or 'teacher')
  bool _rememberManager = false;
  bool _rememberTeacher = false;
  String? _rememberedManagerEmail;
  String? _rememberedTeacherId;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final managerCreds = await RememberMeService.loadManagerCredentials();
    final teacherCreds = await RememberMeService.loadTeacherCredentials();
    if (!mounted) return;
    setState(() {
      if (managerCreds['remember'] == 'true') {
        _rememberManager = true;
        _emailController.text = managerCreds['email'] ?? '';
        _passwordController.text = managerCreds['password'] ?? '';
        _rememberedManagerEmail = managerCreds['email'];
      }
      if (teacherCreds['remember'] == 'true') {
        _rememberTeacher = true;
        _teacherIdController.text = teacherCreds['id'] ?? '';
        _pinController.text = teacherCreds['pin'] ?? '';
        _rememberedTeacherId = teacherCreds['id'];
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _teacherIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    bool success = false;
    if (_selectedRole == 'manager') {
      success = await auth.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      success = await auth.loginTeacherWithPin(
        _teacherIdController.text.trim(),
        _pinController.text.trim(),
      );
    }

    if (!mounted) return;

    if (success) {
      if (_selectedRole == 'manager') {
        if (_rememberManager) {
          await RememberMeService.saveManagerCredentials(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        } else {
          await RememberMeService.clearManagerCredentials();
        }
      } else {
        if (_rememberTeacher) {
          await RememberMeService.saveTeacherCredentials(
            teacherIdOrMobile: _teacherIdController.text.trim(),
            pin: _pinController.text.trim(),
          );
        } else {
          await RememberMeService.clearTeacherCredentials();
        }
      }

      // Direct user based on authorized profile role
      final role = auth.currentUser?.role;
      if (role == 'admin' || role == 'manager' || role == 'operator') {
        router.go('/admin');
      } else {
        router.go('/teacher');
      }
    } else {
      if (auth.lastErrorIsRetryable) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(auth.lastAuthError.isNotEmpty ? auth.lastAuthError : 'Cannot reach server. Check your internet connection and try again.'),
            action: SnackBarAction(label: 'Retry', onPressed: _handleLogin),
            duration: const Duration(seconds: 8),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(auth.lastAuthError.isNotEmpty ? auth.lastAuthError : 'Authentication failed. Check credentials.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Color(0xFF004D40)),
            SizedBox(width: 8),
            Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address below. We will send a secure link to reset your password.',
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email, color: Color(0xFF004D40)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address.')),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final success = await auth.sendPasswordReset(email);
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Password reset link sent to $email. Check your inbox.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(auth.lastAuthError.isNotEmpty ? auth.lastAuthError : 'Failed to send reset email.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
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
                final nav = Navigator.of(context);
                final success = await auth.verifyAdminDob(dobController.text);
                nav.pop(success);
              },
              child: const Text('Verify & Proceed')
            ),
          ],
        );
      }
    );

    if (authorized != true) {
      if (!mounted) return;
      if (dobController.text.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF004D40), // Dark Islamic Emerald Green
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Color(0xFFFFD700)),
            tooltip: loc?.translate('language') ?? 'Language',
            onSelected: (code) {
              localeProvider.setLocale(Locale(code));
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'en', child: Text('English')),
              const PopupMenuItem(value: 'ur', child: Text('اردو (Urdu)')),
              const PopupMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
              const PopupMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo / Branding
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.mosque,
                    size: 64,
                    color: Color(0xFFFFD700), // Gold
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc?.translate('app_title') ?? "MAKTAB",
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  "Idara-e-Dawatul Qur'an",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Card Container for Login Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role Selection Button Bar ("Manager / Admin" vs "Teacher")
                        Text(
                          loc?.translate('login') ?? "SELECT LOGGING ROLE",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004D40),
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: const Color(0xFF004D40),
                            selectedForegroundColor: Colors.white,
                          ),
                          segments: [
                            ButtonSegment<String>(
                              value: 'manager',
                              label: Text(loc?.translate('login_as_manager') ?? 'Manager / Admin'),
                              icon: const Icon(Icons.admin_panel_settings),
                            ),
                            ButtonSegment<String>(
                              value: 'teacher',
                              label: Text(loc?.translate('login_as_teacher') ?? 'Teacher'),
                              icon: const Icon(Icons.school),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedRole = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        if (_selectedRole == 'manager') ...[
                          // Manager / Operator Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: loc?.translate('email') ?? 'Email Address',
                              hintText: 'manager@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF004D40)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF5F7F5),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return loc?.translate('enter_valid_email') ?? 'Please enter your email';
                              if (!val.contains('@')) return loc?.translate('enter_valid_email') ?? 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: loc?.translate('password') ?? 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF004D40)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF5F7F5),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return loc?.translate('enter_password') ?? 'Please enter your password';
                              if (val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Remember Me & Forgot Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberManager,
                                      activeColor: const Color(0xFF004D40),
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberManager = val ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    loc?.translate('remember_me') ?? 'Remember me',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  loc?.translate('forgot_password') ?? 'Forgot Password?',
                                  style: const TextStyle(
                                    color: Color(0xFF004D40),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_rememberedManagerEmail != null && _rememberedManagerEmail!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.flash_on, size: 18, color: Color(0xFF004D40)),
                                label: Text(
                                  'Quick Login as $_rememberedManagerEmail',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF004D40),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF004D40)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: auth.isLoading ? null : _handleLogin,
                              ),
                            ),
                          ],
                        ] else ...[
                          // Teacher ID / Mobile Field
                          TextFormField(
                            controller: _teacherIdController,
                            decoration: InputDecoration(
                              labelText: loc?.translate('teacher_id') ?? 'Teacher ID or Mobile',
                              hintText: 'e.g. 2026-1 or 9177024433',
                              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF004D40)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF5F7F5),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return loc?.translate('enter_teacher_id') ?? 'Please enter Teacher ID or Mobile';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Teacher 4-Digit PIN Field
                          TextFormField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: loc?.translate('pin') ?? '4-Digit PIN',
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF004D40)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePin = !_obscurePin;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF5F7F5),
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return loc?.translate('enter_pin') ?? 'Please enter 4-digit PIN';
                              if (val.trim().length < 4) return 'PIN must be at least 4 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Remember Me Row
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberTeacher,
                                  activeColor: const Color(0xFF004D40),
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberTeacher = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                loc?.translate('remember_me') ?? 'Remember Teacher ID',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (_rememberedTeacherId != null && _rememberedTeacherId!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.flash_on, size: 18, color: Color(0xFF004D40)),
                                label: Text(
                                  'Quick Login as $_rememberedTeacherId',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF004D40),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF004D40)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: auth.isLoading ? null : _handleLogin,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),

                        // Login Action Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: auth.isLoading ? null : _handleLogin,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _selectedRole == 'manager'
                                      ? (loc?.translate('login_as_manager') ?? 'LOGIN AS MANAGER').toUpperCase()
                                      : (loc?.translate('login_as_teacher') ?? 'LOGIN AS TEACHER').toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Options Footer
                TextButton.icon(
                  onPressed: _handleEmergencyRestore,
                  icon: const Icon(Icons.settings_backup_restore, color: Colors.white70, size: 18),
                  label: const Text("Emergency Restore Backup", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
