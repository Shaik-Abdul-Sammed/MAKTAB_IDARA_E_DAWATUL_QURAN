import 'package:flutter/material.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  User? _currentUser;
  bool _isLoading = false;
  bool _hasRegisteredAdmin = false;

  // Security Lockout State
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  String _lastAuthError = '';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
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

    // Ensure default admin exists
    await _userRepository.initializeDefaultAdmin();
    
    // Check if registered admin exists
    _hasRegisteredAdmin = await _userRepository.hasRegisteredAdmin();

    // Restore active session
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loggedInUserId = prefs.getInt('logged_in_user_id');
    if (loggedInUserId != null) {
      _currentUser = await _userRepository.getUserById(loggedInUserId);
    }

    // Auto-migrate & sync existing local Manager data to Cloud Backend
    CloudSyncService.instance.syncAll().catchError((_) {});

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String pin) async {
    if (isLockedOut) {
      _lastAuthError = 'Account locked due to multiple failed attempts. Retry in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastAuthError = '';
    notifyListeners();

    // Try salted hash first, fallback to unsalted legacy hash for backwards compatibility
    String saltedHash = _hashPin(pin);
    User? user = await _userRepository.authenticateUser(saltedHash);

    if (user == null) {
      // Fallback check for initial default admin plain sha256 hash
      final legacyHash = sha256.convert(utf8.encode(pin)).toString();
      user = await _userRepository.authenticateUser(legacyHash);
    }

    // ── Multi-Device Cloud Fallback Auth ─────────────────────────────────────
    // If user is NOT found locally on Device B, check Cloud DB across active Maktabs
    if (user == null) {
      user = await CloudSyncService.instance.authenticateTeacherCloud(saltedHash);
      if (user == null) {
        final legacyHash = sha256.convert(utf8.encode(pin)).toString();
        user = await CloudSyncService.instance.authenticateTeacherCloud(legacyHash);
      }
    }

    if (user != null) {
      _currentUser = user;
      _failedAttempts = 0;
      _lockoutEndTime = null;
      _lastAuthError = '';

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('logged_in_user_id', user.id!);

      // Trigger background sync for this Maktab
      final maktabId = await CloudSyncService.instance.getMaktabId();
      CloudSyncService.instance.pullAllDataForMaktab(maktabId).catchError((_) => false);
      
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

  Future<void> purgeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Complete cache wipe
    _failedAttempts = 0;
    _lockoutEndTime = null;
    _currentUser = null;
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

  Future<bool> registerFirstUser({
    required String name,
    required String mobile,
    required String pin,
    required String dob,
  }) async {
    _isLoading = true;
    notifyListeners();

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

  Future<void> logout() async {
    _currentUser = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id'); // Clear session
    notifyListeners();
  }
}
