import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
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

  static const String _rtdbUrl = 'https://maktab-management-99001-default-rtdb.asia-southeast1.firebasedatabase.app';

  FirebaseDatabase? get _db {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      );
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

  bool _isExplicitLoggingIn = false;

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
      if (_isExplicitLoggingIn) return; // Prevent race condition during active login
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

      if (_currentUser != null) {
        try {
          final mId = await CloudSyncService.instance.getMaktabId();
          await CloudSyncService.instance.pullAllDataForMaktab(mId);
          CloudSyncService.instance.startRealtimeSync(mId);
        } catch (e) {
          debugPrint('Error starting cloud sync on session restore: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  // ── Teacher Provisioning via Secondary FirebaseApp (Spark Plan Compatible) ──

  Future<bool> provisionTeacherAuthAccount({
    required int teacherId,
    required String name,
    required String rawPin,
    String? mobile,
  }) async {
    try {
      final maktabId = await CloudSyncService.instance.getMaktabId();
      final derivedEmail = 'teacher_${maktabId}_$teacherId@maktab.app';
      final saltedHash = _hashPin(rawPin);
      final derivedPassword = saltedHash.padRight(32, '0').substring(0, 32);

      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('TeacherProvisioner');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'TeacherProvisioner',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = fb_auth.FirebaseAuth.instanceFor(app: secondaryApp);
      
      fb_auth.UserCredential? cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: derivedEmail,
          password: derivedPassword,
        ).timeout(const Duration(seconds: 8));
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          debugPrint('Teacher Firebase Auth account already exists.');
          await secondaryAuth.signOut();
          return true;
        }
        rethrow;
      }

      final teacherUid = cred.user?.uid;
      if (teacherUid != null && _db != null) {
        // Manager's primary Firebase session writes /users/$teacherUid profile with mobile & pinHash
        await _db!.ref('users/$teacherUid').set({
          'name': name,
          'email': derivedEmail,
          'role': 'teacher',
          'maktabId': maktabId,
          'teacherId': teacherId,
          'mobile': mobile ?? '',
          'pinHash': saltedHash,
          'active': true,
        }).timeout(const Duration(seconds: 5));
      }
      await secondaryAuth.signOut();
      return true;
    } catch (e) {
      debugPrint('provisionTeacherAuthAccount Error: $e');
      return false;
    }
  }

  Future<void> _provisionAllTeachersInBackground() async {
    try {
      final teachers = await _userRepository.getAllTeachers();
      for (var t in teachers) {
        if (t.id != null) {
          await provisionTeacherAuthAccount(
            teacherId: t.id!,
            name: t.name,
            rawPin: '1234',
            mobile: t.mobile,
          );
        }
      }
    } catch (e) {
      debugPrint('Background teacher provisioning note: $e');
    }
  }

  // ── Firebase Email + Password Authentication ──────────────────────────────

  Future<bool> loginWithEmail(String email, String password) async {
    if (isLockedOut) {
      _lastAuthError = 'Account locked due to multiple failed attempts. Retry in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _isExplicitLoggingIn = true;
    _lastAuthError = '';
    notifyListeners();

    try {
      if (_fbAuth == null) {
        _lastAuthError = 'Firebase Auth not initialized.';
        _isLoading = false;
        _isExplicitLoggingIn = false;
        notifyListeners();
        return false;
      }

      final credential = await _fbAuth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      ).timeout(const Duration(seconds: 8), onTimeout: () {
        throw TimeoutException('Firebase login request timed out. Check internet connection.');
      });

      if (credential.user != null) {
        final success = await _loadFirebaseUserProfile(credential.user!.uid, isManagerLogin: true);
        if (success) {
          _failedAttempts = 0;
          _lockoutEndTime = null;
          _lastAuthError = '';
          _isLoading = false;
          _isExplicitLoggingIn = false;
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
      _lastAuthError = e is TimeoutException
          ? e.message ?? 'Login request timed out. Check connection.'
          : 'Network or connection error. Please try again.';
    }

    _isLoading = false;
    _isExplicitLoggingIn = false;
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

  Future<bool> _loadFirebaseUserProfile(String uid, {bool isManagerLogin = false}) async {
    try {
      final snapshot = await _db?.ref('users/$uid').get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Profile load query timed out.'),
      );
      if (snapshot != null && snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final maktabId = data['maktabId'] as String?;
        final role = data['role'] as String? ?? 'teacher';
        final active = data['active'] as bool? ?? true;

        if (maktabId == null || maktabId.trim().isEmpty) {
          _lastAuthError = 'Profile configuration error: missing maktabId in /users/$uid profile.';
          await logout();
          return false;
        }

        if (isManagerLogin && role != 'manager' && role != 'admin' && role != 'operator') {
          _lastAuthError = 'Unauthorized: Account role "$role" is not manager, operator, or admin.';
          await logout();
          return false;
        }

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

        try {
          await CloudSyncService.instance.pullAllDataForMaktab(maktabId);
        } catch (e) {
          debugPrint('Initial pull note in _loadFirebaseUserProfile: $e');
        }
        CloudSyncService.instance.startRealtimeSync(maktabId);
        if (role == 'manager' || role == 'admin' || role == 'operator') {
          _provisionAllTeachersInBackground();
        }
        return true;
      } else {
        _lastAuthError = 'Firebase User authenticated, but database profile /users/$uid does not exist.';
        await logout();
        return false;
      }
    } catch (e) {
      debugPrint('Error loading Firebase user profile: $e');
      _lastAuthError = e is TimeoutException
          ? 'Network timeout loading user profile /users/$uid. Check internet connection.'
          : 'Permission denied or error reading user profile /users/$uid.';
    }
    return false;
  }

  // ── PIN & Local Fallback Auth ─────────────────────────────────────────────

  Future<bool> loginTeacherWithPin(String teacherIdOrMobile, String pin) async {
    if (isLockedOut) {
      _lastAuthError = 'Account locked due to multiple failed attempts. Retry in ${remainingLockoutSeconds}s.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _isExplicitLoggingIn = true;
    _lastAuthError = '';
    notifyListeners();

    final input = teacherIdOrMobile.trim();
    final saltedHash = _hashPin(pin);

    List<User> allTeachers = await _userRepository.getAllTeachers();
    User? matchedUser;

    final parsedId = int.tryParse(input.replaceAll(RegExp(r'\D'), ''));
    for (var u in allTeachers) {
      bool idMatch = false;
      if (u.id != null) {
        if (u.id.toString() == input || (parsedId != null && u.id == parsedId)) {
          idMatch = true;
        }
      }
      bool mobileMatch = u.mobile != null && u.mobile!.contains(input);
      bool nameMatch = u.name.toLowerCase().contains(input.toLowerCase());

      if (idMatch || mobileMatch || nameMatch) {
        if (u.pinHash == saltedHash || u.pinHash == sha256.convert(utf8.encode(pin)).toString()) {
          matchedUser = u;
          break;
        }
      }
    }

    matchedUser ??= await _userRepository.authenticateUser(saltedHash);
    matchedUser ??= await _userRepository.authenticateUser(sha256.convert(utf8.encode(pin)).toString());

    // Firebase RTDB direct Teacher lookup fallback for fresh device installations across all Maktabs
    if (matchedUser == null && _db != null) {
      try {
        final maktabsSnap = await _db!.ref('maktabs').get().timeout(const Duration(seconds: 4));
        if (maktabsSnap.exists && maktabsSnap.value is Map) {
          final maktabsMap = Map<String, dynamic>.from(maktabsSnap.value as Map);
          for (var maktabEntry in maktabsMap.entries) {
            final mId = maktabEntry.key.toString();
            final mVal = maktabEntry.value;
            if (mVal is Map && mVal['teachers'] is Map) {
              final tMap = Map<String, dynamic>.from(mVal['teachers'] as Map);
              for (var entry in tMap.entries) {
                try {
                  final item = Map<String, dynamic>.from(entry.value as Map);
                  item['id'] ??= int.tryParse(entry.key.toString());
                  final u = User.fromMap(item);
                  if (u.role == 'teacher' && (u.pinHash == saltedHash || u.pinHash == sha256.convert(utf8.encode(pin)).toString())) {
                    final idMatch = parsedId != null && u.id == parsedId;
                    final mobileMatch = input.isNotEmpty && (u.mobile ?? '').replaceAll(RegExp(r'\D'), '').endsWith(input);
                    final nameMatch = u.name.toLowerCase().contains(input.toLowerCase());
                    if (idMatch || mobileMatch || nameMatch || input.isEmpty) {
                      matchedUser = u;
                      await CloudSyncService.instance.setMaktabId(mId);
                      await _userRepository.insertUser(u);
                      break;
                    }
                  }
                } catch (_) {}
              }
            }
            if (matchedUser != null) break;
          }
        }
      } catch (e) {
        debugPrint('Firebase RTDB direct Teacher lookup note: $e');
      }
    }

    // Firebase Auth direct sign-in fallback for fresh device installations
    if (matchedUser == null && _fbAuth != null) {
      try {
        final activeMaktabId = await CloudSyncService.instance.getMaktabId();
        final teacherIdGuess = parsedId ?? 1;
        final derivedEmail = 'teacher_${activeMaktabId}_$teacherIdGuess@maktab.app';
        final derivedPassword = saltedHash.padRight(32, '0').substring(0, 32);

        final cred = await _fbAuth!.signInWithEmailAndPassword(
          email: derivedEmail,
          password: derivedPassword,
        ).timeout(const Duration(seconds: 4));

        if (cred.user != null && _db != null) {
          final snapshot = await _db!.ref('users/${cred.user!.uid}').get().timeout(const Duration(seconds: 3));
          if (snapshot.exists && snapshot.value is Map) {
            final val = Map<String, dynamic>.from(snapshot.value as Map);
            final uTeacherId = val['teacherId'] as int? ?? teacherIdGuess;
            final uName = val['name']?.toString() ?? 'Teacher';
            final uMobile = val['mobile']?.toString() ?? '';
            final isActive = val['active'] != false;

            matchedUser = User(
              id: uTeacherId,
              name: uName,
              mobile: uMobile,
              pinHash: saltedHash,
              role: 'teacher',
              isActive: isActive,
              createdAt: DateTime.now().toIso8601String(),
            );
            try {
              await _userRepository.insertUser(matchedUser);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Firebase direct Teacher Auth fallback note: $e');
      }
    }

    if (matchedUser != null) {
      final teacher = matchedUser;
      if (!teacher.isActive) {
        _lastAuthError = 'Teacher account is inactive. Contact your administrator.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = teacher;
      _failedAttempts = 0;
      _lockoutEndTime = null;
      _lastAuthError = '';

      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (teacher.id != null) {
        await prefs.setInt('logged_in_user_id', teacher.id!);
      }

      String activeMaktabId = await CloudSyncService.instance.getMaktabId();

      // Bind Teacher PIN authentication to a secure Firebase Auth identity
      try {
        if (_fbAuth != null) {
          final derivedEmail = 'teacher_${activeMaktabId}_${teacher.id ?? 1}@maktab.app';
          final derivedPassword = _hashPin(pin).padRight(32, '0').substring(0, 32);
          fb_auth.UserCredential? cred;
          try {
            cred = await _fbAuth!.signInWithEmailAndPassword(
              email: derivedEmail,
              password: derivedPassword,
            ).timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint('Teacher Firebase Auth sign-in failed, attempting provisioning: $e');
            if (teacher.id != null) {
              await provisionTeacherAuthAccount(
                teacherId: teacher.id!,
                name: teacher.name,
                rawPin: pin,
                mobile: teacher.mobile,
              );
              try {
                cred = await _fbAuth!.signInWithEmailAndPassword(
                  email: derivedEmail,
                  password: derivedPassword,
                ).timeout(const Duration(seconds: 5));
              } catch (e2) {
                try {
                  cred = await _fbAuth!.createUserWithEmailAndPassword(
                    email: derivedEmail,
                    password: derivedPassword,
                  ).timeout(const Duration(seconds: 5));
                } catch (e3) {
                  try {
                    cred = await _fbAuth!.signInAnonymously().timeout(const Duration(seconds: 5));
                  } catch (_) {}
                }
              }
            }
          }

          if (cred?.user != null && _db != null) {
            try {
              final userUid = cred!.user!.uid;
              final snapshot = await _db!.ref('users/$userUid/maktabId').get().timeout(const Duration(seconds: 3));
              if (snapshot.exists && snapshot.value != null) {
                activeMaktabId = snapshot.value.toString();
                await CloudSyncService.instance.setMaktabId(activeMaktabId);
              } else {
                await _db!.ref('users/$userUid').set({
                  'name': teacher.name,
                  'email': derivedEmail,
                  'role': 'teacher',
                  'maktabId': activeMaktabId,
                  'teacherId': teacher.id ?? 1,
                  'active': true,
                  'mobile': teacher.mobile ?? '',
                }).timeout(const Duration(seconds: 4));
              }
            } catch (eProfile) {
              debugPrint('Error verifying/provisioning Teacher profile node in RTDB: $eProfile');
            }
          }
        }
      } catch (e) {
        debugPrint('Firebase Teacher auth note: $e');
      }

      try {
        await CloudSyncService.instance.pullAllDataForMaktab(activeMaktabId);
      } catch (e) {
        debugPrint('Initial pull note on teacher login: $e');
      }
      CloudSyncService.instance.startRealtimeSync(activeMaktabId);

      _isLoading = false;
      _isExplicitLoggingIn = false;
      notifyListeners();
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
      _lastAuthError = '5 failed attempts! Security lockout active for 30 seconds.';
    } else {
      _lastAuthError = 'Invalid Teacher ID or PIN. ${5 - _failedAttempts} attempts remaining until lockout.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
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

      try {
        if (_fbAuth != null) {
          if (_fbAuth!.currentUser != null && _fbAuth!.currentUser!.isAnonymous == false && user.role == 'teacher') {
            await _fbAuth!.signOut();
          }
          if (user.role == 'teacher') {
            final derivedEmail = 'teacher_${maktabId}_${user.id}@maktab.app';
            final derivedPassword = _hashPin(pin).padRight(32, '0').substring(0, 32);
            try {
              await _fbAuth!.signInWithEmailAndPassword(
                email: derivedEmail,
                password: derivedPassword,
              ).timeout(const Duration(seconds: 6));
            } catch (e) {
              debugPrint('Teacher Firebase Auth login note: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Firebase Teacher auth note: $e');
      }

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

        try {
          final mId = await CloudSyncService.instance.getMaktabId();
          await CloudSyncService.instance.pullAllDataForMaktab(mId);
          CloudSyncService.instance.startRealtimeSync(mId);
        } catch (e) {
          debugPrint('Error starting cloud sync on biometric login: $e');
        }

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
