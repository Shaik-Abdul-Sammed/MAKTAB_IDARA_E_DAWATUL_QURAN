import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

enum ProvisionResult { success, failed, pwMismatch }

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

  final List<String> _provisionFailures = [];
  List<String> get provisionFailures => List.unmodifiable(_provisionFailures);

  final List<String> _provisionPwMismatches = [];
  List<String> get provisionPwMismatches => List.unmodifiable(_provisionPwMismatches);

  Future<void> _provisionerLock = Future.value();

  Future<T> _withProvisionerLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _provisionerLock = _provisionerLock.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

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

  static String hashPin(String pin) {
    const salt = 'idara_maktab_sec_salt_2026';
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _hashPin(String pin) => hashPin(pin);

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
          CloudSyncService.instance.enableAlwaysOnSync(mId);
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

  Future<ProvisionResult> provisionTeacherAuthAccount({
    required int teacherId,
    required String name,
    required String pinHash,
    String? mobile,
    String? maktabId,
  }) {
    return _withProvisionerLock(() async {
      try {
        final activeMaktabId = maktabId ?? await CloudSyncService.instance.getMaktabId();
        final derivedEmail = 'teacher_${activeMaktabId}_$teacherId@maktab.app';
        final derivedPassword = pinHash.padRight(32, '0').substring(0, 32);

      final pinHashPrefix = pinHash.length >= 8 ? pinHash.substring(0, 8) : pinHash;
      final derivedPasswordPrefix = derivedPassword.length >= 8 ? derivedPassword.substring(0, 8) : derivedPassword;
      debugPrint('[DERIVATION] teacherId=$teacherId pinHashPrefix=$pinHashPrefix... derivedPasswordPrefix=$derivedPasswordPrefix...');

      FirebaseApp secondaryApp;
      if (Firebase.apps.any((a) => a.name == 'TeacherProvisioner')) {
        secondaryApp = Firebase.app('TeacherProvisioner');
      } else {
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
        debugPrint('[PROVISION CREATE] $derivedEmail');
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          debugPrint('[PROVISION FALLBACK] $derivedEmail exists — signing in on secondary app');
          try {
            cred = await secondaryAuth.signInWithEmailAndPassword(
              email: derivedEmail,
              password: derivedPassword,
            ).timeout(const Duration(seconds: 8));
          } on fb_auth.FirebaseAuthException catch (e2) {
            // Also attempt pinHash if account was created with 64-char hash
            bool recovered = false;
            try {
              cred = await secondaryAuth.signInWithEmailAndPassword(
                email: derivedEmail,
                password: pinHash,
              ).timeout(const Duration(seconds: 5));
              recovered = true;
            } catch (_) {}

            if (!recovered && (e2.code == 'wrong-password' || e2.code == 'invalid-credential')) {
              debugPrint('[PROVISION PW-MISMATCH] $derivedEmail — password differs from expected hash. Manual reset required.');
              await secondaryAuth.signOut();
              return ProvisionResult.pwMismatch;
            }
            if (!recovered) rethrow;
          }
        } else {
          rethrow;
        }
      }

      final teacherUid = cred?.user?.uid;
      if (teacherUid != null) {
        // Write /users/{teacherUid} from the secondary app so auth.uid == $uid
        // (clause B of the /users/$uid write rule) — independent of manager profile correctness.
        final secondaryDb = FirebaseDatabase.instanceFor(
          app: secondaryApp,
          databaseURL: _rtdbUrl,
        );
        try {
          await secondaryDb.ref('users/$teacherUid').set({
            'name': name,
            'email': derivedEmail,
            'role': 'teacher',
            'maktabId': activeMaktabId,
            'teacherId': teacherId,
            'mobile': mobile ?? '',
            'pinHash': pinHash,
            'active': true,
          }).timeout(const Duration(seconds: 6));

          final verify = await secondaryDb
              .ref('users/$teacherUid')
              .get()
              .timeout(const Duration(seconds: 3));

          if (!verify.exists || verify.value == null) {
            debugPrint('[PROVISION FAIL] write not confirmed teacherId=$teacherId uid=$teacherUid');
            await secondaryAuth.signOut();
            return ProvisionResult.failed;
          }
          debugPrint('[PROVISION OK] teacherId=$teacherId uid=$teacherUid');
        } catch (e, st) {
          debugPrint('[PROVISION EXCEPTION] teacherId=$teacherId error=$e\n$st');
          await secondaryAuth.signOut();
          return ProvisionResult.failed;
        }
      }
      await secondaryAuth.signOut();
      return ProvisionResult.success;

      } catch (e) {
        debugPrint('provisionTeacherAuthAccount Error: $e');
        return ProvisionResult.failed;
      }
    });
  }

  Future<void> _repairTeacherPinHashes() async {
    try {
      final teachers = await _userRepository.getAllTeachers();
      for (final t in teachers) {
        if (t.id == null) continue;
        final currentPinHash = t.pinHash.trim();
        // If pinHash looks like a 64-char hex string, leave it alone.
        if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(currentPinHash)) {
          continue;
        }
        // If it looks like a plaintext PIN (all digits, length < 8), replace it with _hashPin(pinHash)
        if (currentPinHash.isNotEmpty && currentPinHash.length < 8 && RegExp(r'^\d+$').hasMatch(currentPinHash)) {
          final migratedHash = _hashPin(currentPinHash);
          await _userRepository.updateUserPin(t.id!, migratedHash);
          debugPrint('[PINHASH MIGRATED] teacherId=${t.id}');
        }
      }
    } catch (e) {
      debugPrint('Teacher pinHash repair error: $e');
    }
  }

  Future<void> _provisionAllTeachersInBackground() async {
    try {
      await _repairTeacherPinHashes();
      _provisionFailures.clear();
      _provisionPwMismatches.clear();
      final teachers = await _userRepository.getAllTeachers();
      for (var t in teachers) {
        if (t.id != null) {
          final result = await provisionTeacherAuthAccount(
            teacherId: t.id!,
            name: t.name,
            pinHash: t.pinHash,
            mobile: t.mobile,
          );
          switch (result) {
            case ProvisionResult.success:
              break;
            case ProvisionResult.failed:
              _provisionFailures.add('Teacher ${t.id} (${t.name}) provisioning failed');
              debugPrint('[PROVISION FAIL] teacherId=${t.id} name=${t.name}');
              break;
            case ProvisionResult.pwMismatch:
              _provisionPwMismatches.add('Teacher ${t.id} (${t.name}) — password mismatch, manual reset required');
              debugPrint('[PROVISION PW-MISMATCH] teacherId=${t.id} name=${t.name}');
              break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Background teacher provisioning note: $e');
    }
  }

  Future<void> _backfillMissingTeacherProfiles() async {
    try {
      if (_db == null) return;
      final teachers = await _userRepository.getAllTeachers();
      final missing = <String>[];

      final maktabId = await CloudSyncService.instance.getMaktabId();

      FirebaseApp secondaryApp;
      if (Firebase.apps.any((a) => a.name == 'TeacherProvisioner')) {
        secondaryApp = Firebase.app('TeacherProvisioner');
      } else {
        secondaryApp = await Firebase.initializeApp(
          name: 'TeacherProvisioner',
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = fb_auth.FirebaseAuth.instanceFor(app: secondaryApp);
      final secondaryDb = FirebaseDatabase.instanceFor(
        app: secondaryApp,
        databaseURL: _rtdbUrl,
      );

      for (final t in teachers) {
        if (t.id == null) continue;
        final derivedEmail = 'teacher_${maktabId}_${t.id}@maktab.app';
        final derivedPassword = t.pinHash.padRight(32, '0').substring(0, 32);

        bool needsProvision = false;
        await _withProvisionerLock(() async {
          try {
            // Sign in as teacher on secondary app to check their own /users/$uid node
            fb_auth.UserCredential cred;
            try {
              cred = await secondaryAuth.signInWithEmailAndPassword(
                email: derivedEmail,
                password: derivedPassword,
              );
            } catch (_) {
              // Try unpadded hash if padded failed
              cred = await secondaryAuth.signInWithEmailAndPassword(
                email: derivedEmail,
                password: t.pinHash,
              );
            }

            final uid = cred.user?.uid;
            if (uid != null) {
              final snap = await secondaryDb.ref('users/$uid').get()
                  .timeout(const Duration(seconds: 5));
              if (!snap.exists) {
                missing.add('teacherId=${t.id} uid=$uid');
                needsProvision = true;
              }
            }
          } on fb_auth.FirebaseAuthException catch (e) {
            if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
              // Account doesn't exist yet or password changed — provision will handle on next cycle
              debugPrint('[BACKFILL] teacherId=${t.id} unprovisioned (${e.code})');
            }
          } catch (e) {
            debugPrint('[BACKFILL] teacherId=${t.id} check failed: $e');
          } finally {
            await secondaryAuth.signOut();
          }
        });

        if (needsProvision) {
          // Re-provision this specific teacher
          await provisionTeacherAuthAccount(
            name: t.name,
            pinHash: t.pinHash,
            teacherId: t.id!,
            maktabId: maktabId,
          );
        }
      }

      if (missing.isNotEmpty) {
        debugPrint('[BACKFILL] Missing /users nodes for: ${missing.join(', ')}');
      } else {
        debugPrint('[BACKFILL] All teacher /users nodes present.');
      }
    } catch (e) {
      debugPrint('[BACKFILL ERROR] $e');
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
        final teacherId = data['teacherId'];

        final localMaktabId = await CloudSyncService.instance.getMaktabId();
        final remoteMaktabId = maktabId ?? '';

        debugPrint('[PROFILE AUDIT RAW] ${jsonEncode(snapshot.value)}');
        debugPrint('[MAKTAB MATCH] local="$localMaktabId" remote="$remoteMaktabId" equal=${localMaktabId == remoteMaktabId} localLen=${localMaktabId.length} remoteLen=${remoteMaktabId.length}');

        debugPrint('[PROFILE AUDIT] uid=$uid');
        debugPrint('  exists: true');
        debugPrint('  role: "$role"');
        debugPrint('  maktabId: "$maktabId"');
        debugPrint('  active: $active (type: ${active.runtimeType})');
        debugPrint('  teacherId: $teacherId');

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
        logMaktabFingerprint('manager_login', maktabId);

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

        CloudSyncService.instance.enableAlwaysOnSync(maktabId);
        if (role == 'manager' || role == 'admin' || role == 'operator') {
          unawaited(
            _provisionAllTeachersInBackground()
                .then((_) => _backfillMissingTeacherProfiles())
                .catchError((e) => debugPrint('[PROVISION CHAIN ERROR] $e')),
          );
        }
        return true;
      } else {
        if (isManagerLogin && _fbAuth?.currentUser?.email != null) {
          final userEmail = _fbAuth!.currentUser!.email!;
          String derivedMaktabId = 'MAKTAB-001';

          try {
            final maktabsSnap = await _db?.ref('maktabs').get().timeout(const Duration(seconds: 3));
            if (maktabsSnap != null && maktabsSnap.exists && maktabsSnap.value is Map) {
              final map = Map<String, dynamic>.from(maktabsSnap.value as Map);
              for (var key in map.keys) {
                final kStr = key.toString();
                if (map[kStr] is Map && map[kStr]['students'] != null) {
                  derivedMaktabId = kStr;
                  break;
                }
              }
              if (derivedMaktabId == 'MAKTAB-001' && map.keys.isNotEmpty) {
                derivedMaktabId = map.keys.first.toString();
              }
            }
          } catch (_) {}

          final managerProfile = {
            'name': userEmail.split('@').first.toUpperCase(),
            'email': userEmail,
            'role': 'admin',
            'maktabId': derivedMaktabId,
            'active': true,
            'teacherId': 1,
            'mobile': '',
          };

          try {
            await _db?.ref('users/$uid').set(managerProfile).timeout(const Duration(seconds: 4));
            await CloudSyncService.instance.setMaktabId(derivedMaktabId);

            _currentUser = User(
              id: 1,
              name: managerProfile['name'] as String,
              mobile: '',
              pinHash: '',
              role: 'admin',
              createdAt: DateTime.now().toIso8601String(),
            );

            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt('logged_in_user_id', 1);

            CloudSyncService.instance.enableAlwaysOnSync(derivedMaktabId);
            unawaited(
              _provisionAllTeachersInBackground()
                  .then((_) => _backfillMissingTeacherProfiles())
                  .catchError((e) => debugPrint('[PROVISION CHAIN ERROR] $e')),
            );
            return true;
          } catch (e) {
            debugPrint('Auto-provisioning Manager profile error: $e');
          }
        }

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

      if (kDebugMode) {
        debugPrint('[TEACHER PIN]');
        debugPrint('Local authentication: SUCCESS');
        debugPrint('Teacher ID: ${teacher.id}');
        debugPrint('Maktab ID: $activeMaktabId');
      }

      bool fbAuthSuccess = false;
      String? fbUid;
      String profileStatus = 'MISSING';
      String profileRole = 'unknown';
      String profileMaktabId = activeMaktabId;
      bool profileActive = false;

      // Bind Teacher PIN authentication to a secure Firebase Auth identity
      try {
        if (_fbAuth != null) {
          final derivedEmail = 'teacher_${activeMaktabId}_${teacher.id ?? 1}@maktab.app';
          final derivedPassword = _hashPin(pin).padRight(32, '0').substring(0, 32);

          if (kDebugMode) {
            debugPrint('[TEACHER FIREBASE AUTH]');
            debugPrint('Starting Firebase authentication');
            debugPrint('Attempting: $derivedEmail');
          }

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
                pinHash: _hashPin(pin),
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
                  debugPrint('Teacher Firebase Auth login failed gracefully: $e3');
                }
              }
            }
          }

          fbUid = cred?.user?.uid ?? _fbAuth!.currentUser?.uid;
          fbAuthSuccess = fbUid != null && _fbAuth!.currentUser != null && !_fbAuth!.currentUser!.isAnonymous;

          if (kDebugMode) {
            debugPrint('[TEACHER FIREBASE AUTH]');
            debugPrint('Authentication: ${fbAuthSuccess ? 'SUCCESS' : 'FAILED'}');
            debugPrint('UID: ${fbUid ?? 'null'}');
          }

          if (fbUid != null && _db != null) {
            try {
              final snapshot = await _db!.ref('users/$fbUid').get().timeout(const Duration(seconds: 3));
              if (snapshot.exists && snapshot.value is Map) {
                profileStatus = 'FOUND';
                final val = Map<String, dynamic>.from(snapshot.value as Map);
                profileRole = val['role']?.toString() ?? 'teacher';
                profileMaktabId = val['maktabId']?.toString() ?? activeMaktabId;
                profileActive = val['active'] != false;

                debugPrint('[PROFILE AUDIT RAW] ${jsonEncode(snapshot.value)}');
                debugPrint('[MAKTAB MATCH] local="$activeMaktabId" remote="$profileMaktabId" equal=${activeMaktabId == profileMaktabId} localLen=${activeMaktabId.length} remoteLen=${profileMaktabId.length}');

                activeMaktabId = profileMaktabId;
                await CloudSyncService.instance.setMaktabId(activeMaktabId);
              } else {
                debugPrint('[SELF-PROVISION FIRED] provisioning did not reach this teacher — self-healing uid=$fbUid teacherId=${teacher.id}');
                if (teacher.id == null) {
                  debugPrint('[SELF-PROVISION ABORT] teacher.id is null — refusing to write teacherId=1');
                  profileStatus = 'MISSING';
                } else {
                  await _db!.ref('users/$fbUid').set({
                    'name': teacher.name,
                    'email': derivedEmail,
                    'role': 'teacher',
                    'maktabId': activeMaktabId,
                    'teacherId': teacher.id,
                    'active': true,
                    'mobile': teacher.mobile ?? '',
                    'pinHash': _hashPin(pin),
                  }).timeout(const Duration(seconds: 4));

                  final verify = await _db!.ref('users/$fbUid').get().timeout(const Duration(seconds: 3));
                  if (verify.exists) {
                    debugPrint('[SELF-PROVISION OK] uid=$fbUid teacherId=${teacher.id} maktabId=$activeMaktabId');
                    profileStatus = 'FOUND';
                    profileRole = 'teacher';
                    profileMaktabId = activeMaktabId;
                    profileActive = true;
                  } else {
                    debugPrint('[SELF-PROVISION FAIL] verification failed uid=$fbUid');
                    profileStatus = 'MISSING';
                  }
                }
              }
            } catch (eProfile) {
              debugPrint('Error verifying/provisioning Teacher profile node in RTDB: $eProfile');
            }
          }

          if (kDebugMode) {
            debugPrint('[PROFILE AUDIT] uid=$fbUid');
            debugPrint('  exists: ${profileStatus == 'FOUND'}');
            debugPrint('  role: "$profileRole"');
            debugPrint('  maktabId: "$profileMaktabId"');
            debugPrint('  active: $profileActive (type: ${profileActive.runtimeType})');
            debugPrint('  teacherId: ${teacher.id}');

            debugPrint('[TEACHER PROFILE]');
            debugPrint('Profile: $profileStatus');
            debugPrint('Role: $profileRole');
            debugPrint('MaktabId: $profileMaktabId');
            debugPrint('Active: $profileActive');
          }
        }
      } catch (e) {
        debugPrint('Firebase Teacher auth note: $e');
      }

      if (fbAuthSuccess && profileStatus == 'FOUND' && profileActive) {
        logMaktabFingerprint('teacher_login', activeMaktabId);
        if (kDebugMode) {
          debugPrint('[SYNC]');
          debugPrint('Authentication verified: YES');
          debugPrint('Starting CloudSyncService');
        }
        CloudSyncService.instance.enableAlwaysOnSync(activeMaktabId);
      } else {
        if (kDebugMode) {
          debugPrint('[SYNC]');
          debugPrint('Authentication verified: NO');
          debugPrint('CloudSyncService deferred (offline / unauthenticated)');
        }
      }

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

      CloudSyncService.instance.enableAlwaysOnSync(maktabId);

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
          CloudSyncService.instance.enableAlwaysOnSync(mId);
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
    CloudSyncService.instance.stopAlwaysOnSync();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id');
    notifyListeners();
  }
}
