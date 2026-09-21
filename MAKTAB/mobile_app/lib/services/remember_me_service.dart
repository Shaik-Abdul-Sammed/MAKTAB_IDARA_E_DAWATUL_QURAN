import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service managing 'Remember Me' credentials securely.
///
/// // Credentials stored in encrypted secure storage via flutter_secure_storage. Do not move to SharedPreferences.
class RememberMeService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Keys for Manager
  static const String keyRememberManager = 'remember_manager';
  static const String keyManagerEmail = 'remember_manager_email';
  static const String keyManagerPassword = 'remember_manager_password';

  // Keys for Teacher
  static const String keyRememberTeacher = 'remember_teacher';
  static const String keyTeacherId = 'remember_teacher_id';
  static const String keyTeacherPin = 'remember_teacher_pin';

  // ── Manager Credentials ───────────────────────────────────────────────────

  /// Saves manager email and password in encrypted storage.
  static Future<void> saveManagerCredentials({
    required String email,
    required String password,
  }) async {
    // Credentials stored in encrypted secure storage via flutter_secure_storage. Do not move to SharedPreferences.
    await _storage.write(key: keyRememberManager, value: 'true');
    await _storage.write(key: keyManagerEmail, value: email.trim());
    await _storage.write(key: keyManagerPassword, value: password);
  }

  /// Loads saved manager credentials if 'remember_manager' is set.
  static Future<Map<String, String?>> loadManagerCredentials() async {
    final remember = await _storage.read(key: keyRememberManager);
    if (remember == 'true') {
      final email = await _storage.read(key: keyManagerEmail);
      final password = await _storage.read(key: keyManagerPassword);
      return {
        'remember': 'true',
        'email': email,
        'password': password,
      };
    }
    return {'remember': 'false'};
  }

  /// Clears stored manager credentials.
  static Future<void> clearManagerCredentials() async {
    await _storage.delete(key: keyRememberManager);
    await _storage.delete(key: keyManagerEmail);
    await _storage.delete(key: keyManagerPassword);
  }

  // ── Teacher Credentials ───────────────────────────────────────────────────

  /// Saves teacher ID/mobile and PIN in encrypted storage.
  static Future<void> saveTeacherCredentials({
    required String teacherIdOrMobile,
    required String pin,
  }) async {
    // Credentials stored in encrypted secure storage via flutter_secure_storage. Do not move to SharedPreferences.
    await _storage.write(key: keyRememberTeacher, value: 'true');
    await _storage.write(key: keyTeacherId, value: teacherIdOrMobile.trim());
    await _storage.write(key: keyTeacherPin, value: pin.trim());
  }

  /// Loads saved teacher credentials if 'remember_teacher' is set.
  static Future<Map<String, String?>> loadTeacherCredentials() async {
    final remember = await _storage.read(key: keyRememberTeacher);
    if (remember == 'true') {
      final id = await _storage.read(key: keyTeacherId);
      final pin = await _storage.read(key: keyTeacherPin);
      return {
        'remember': 'true',
        'id': id,
        'pin': pin,
      };
    }
    return {'remember': 'false'};
  }

  /// Clears stored teacher credentials.
  static Future<void> clearTeacherCredentials() async {
    await _storage.delete(key: keyRememberTeacher);
    await _storage.delete(key: keyTeacherId);
    await _storage.delete(key: keyTeacherPin);
  }
}
