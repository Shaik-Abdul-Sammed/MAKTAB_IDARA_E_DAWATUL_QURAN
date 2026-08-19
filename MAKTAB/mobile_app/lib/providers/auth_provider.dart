import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class AuthProvider with ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  fb_auth.FirebaseAuth? get _fbAuth {
    try {
      return fb_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  User? _currentUser;
  bool _isLoading = false;
  bool _hasRegisteredAdmin = false;

  // Security Lockout State
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  String _lastAuthError = '';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null || (_fbAuth?.currentUser != null);
  bool get hasRegisteredAdminUser => _hasRegisteredAdmin;
  int get failedAttempts => _failedAttempts;
  String get lastAuthError => _lastAuthError;

  bool get isLockedOut {
    if (_lockoutEndTime == null) return false;
    if (DateTime.now().isAfter(_lockoutEndTime!)) {
      _lockoutEndTime = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  int get remainingLockoutSeconds {
    if (_lockoutEndTime == null) return 0;
    final diff = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String _hashPin(String pin) {
    const salt = 'idara_maktab_sec_salt_2026';
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> checkRegistrationStatus() async {
    _hasRegisteredAdmin = await _userRepository.hasRegisteredAdmin();
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Ensure default admin exists in SQLite
    await _userRepository.initializeDefaultAdmin();
    _hasRegisteredAdmin = await _userRepository.hasRegisteredAdmin();

    // Listen for Firebase Auth persistent state changes
    _fbAuth?.authStateChanges().listen((fbUser) async {
      if (fbUser != null) {
        await _loadFirebaseUserProfile(fbUser.uid);
      } else {
        // Restore local fallback session if no Firebase user
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final loggedInUserId = prefs.getInt('logged_in_user_id');
        if (loggedInUserId != null) {
          _currentUser = await _userRepository.getUserById(loggedInUserId);
        }
      }
      _isLoading = false;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  // ── Firebase Email + Password Authentication ──────────────────────────────

  Future<bool> loginWithEmail(String email, String password) async {
    if (isLockedOut) {
      _lastAuthError = 'Account locked due to multiple failed attempts. Retry in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastAuthError = '';
    notifyListeners();

    try {
      if (_fbAuth == null) {
        _lastAuthError = 'Firebase Auth not initialized.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final credential = await _fbAuth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        final success = await _loadFirebaseUserProfile(credential.user!.uid);
        if (success) {
          _failedAttempts = 0;
          _lockoutEndTime = null;
          _lastAuthError = '';
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
        _lastAuthError = '5 failed attempts! Lockout active for 30s.';
      } else {
        _lastAuthError = e.message ?? 'Authentication failed.';
      }
    } catch (e) {
      _lastAuthError = 'Network or connection error. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _fbAuth?.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      _lastAuthError = 'Password reset failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _loadFirebaseUserProfile(String uid) async {
    try {
      final snapshot = await _db?.ref('users/$uid').get();
      if (snapshot != null && snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final maktabId = data['maktabId'] as String? ?? 'MAKTAB-001';
        final role = data['role'] as String? ?? 'teacher';
        final active = data['active'] as bool? ?? true;

        if (!active) {
          _lastAuthError = 'Your account has been deactivated. Contact your administrator.';
          await logout();
          return false;
        }

        await CloudSyncService.instance.setMaktabId(maktabId);

        // Map to local User model
        _currentUser = User(
          id: data['teacherId'] as int? ?? 1,
          name: data['name'] as String? ?? 'User',
          mobile: data['mobile'] as String? ?? '',
          pinHash: '',
          role: role,
          createdAt: DateTime.now().toIso8601String(),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('logged_in_user_id', _currentUser!.id!);

        // Start background realtime sync for this Maktab
        CloudSyncService.instance.startRealtimeSync(maktabId);
        return true;
      }
    } catch (e) {
      debugPrint('Error loading Firebase user profile: $e');
    }
    return false;
  }

  // ── PIN & Local Fallback Auth ─────────────────────────────────────────────

  Future<bool> login(String pin) async {
    if (isLockedOut) {
      _lastAuthError = 'Account locked due to multiple failed attempts. Retry in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastAuthError = '';
    notifyListeners();

    String saltedHash = _hashPin(pin);
    User? user = await _userRepository.authenticateUser(saltedHash);

    if (user == null) {
      final legacyHash = sha256.convert(utf8.encode(pin)).toString();
      user = await _userRepository.authenticateUser(legacyHash);
    }

    if (user != null) {
      _currentUser = user;
      _failedAttempts = 0;
      _lockoutEndTime = null;
      _lastAuthError = '';

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('logged_in_user_id', user.id!);

      final maktabId = await CloudSyncService.instance.getMaktabId();
      CloudSyncService.instance.startRealtimeSync(maktabId);

      _isLoading = false;
      notifyListeners();
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
      _lastAuthError = '5 failed attempts! Security lockout active for 30 seconds.';
    } else {
      _lastAuthError = 'Invalid PIN. ${5 - _failedAttempts} attempts remaining until lockout.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithBiometrics() async {
    if (isLockedOut) return false;
    _isLoading = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loggedInUserId = prefs.getInt('logged_in_user_id');

    if (loggedInUserId != null) {
      User? user = await _userRepository.getUserById(loggedInUserId);
      if (user != null) {
        _currentUser = user;
        _failedAttempts = 0;
        _lockoutEndTime = null;
        _lastAuthError = '';

        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerFirstUser({
    required String name,
    required String mobile,
    required String pin,
    required String dob,
    String? email,
    String? password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (email != null && password != null && email.isNotEmpty && password.isNotEmpty && _fbAuth != null) {
        final cred = await _fbAuth!.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        if (cred.user != null) {
          const maktabId = 'MAKTAB-001';
          await _db?.ref('users/${cred.user!.uid}').set({
            'name': name,
            'email': email.trim(),
            'role': 'admin',
            'maktabId': maktabId,
            'active': true,
            'teacherId': 1,
            'mobile': mobile,
          });
        }
      }
    } catch (e) {
      debugPrint('Firebase Admin Creation Note: $e');
    }

    final saltedHashPin = _hashPin(pin);
    final success = await _userRepository.registerFirstUser(
      name: name,
      mobile: mobile,
      pin: saltedHashPin,
      dob: dob,
    );

    if (success) {
      _hasRegisteredAdmin = true;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> verifyAdminDob(String dob) async {
    User? admin = await _userRepository.getAdminUser();
    if (admin == null) return false;
    return admin.dob == dob;
  }

  Future<bool> resetAdminPin(String newPin, String dob) async {
    _isLoading = true;
    notifyListeners();

    User? admin = await _userRepository.getAdminUser();
    if (admin == null) {
      _lastAuthError = 'Admin account not found.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (admin.dob != dob) {
      _lastAuthError = 'Incorrect Date of Birth.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final newHashedPin = _hashPin(newPin);
    await _userRepository.updateUserPin(admin.id!, newHashedPin);
    _failedAttempts = 0;
    _lockoutEndTime = null;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _fbAuth?.signOut();
    CloudSyncService.instance.stopRealtimeSync();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id');
    notifyListeners();
  }
}
