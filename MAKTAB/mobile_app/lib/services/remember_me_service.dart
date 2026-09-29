import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents a saved teacher profile for quick switching & remembered multi-teacher login.
class RememberedTeacher {
  final String teacherId; // teacher ID or mobile
  final String name; // teacher display name
  final String pin;
  final int lastUsed; // millisecondsSinceEpoch

  RememberedTeacher({
    required this.teacherId,
    this.name = '',
    required this.pin,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'teacherId': teacherId,
    'name': name,
    'pin': pin,
    'lastUsed': lastUsed,
  };

  factory RememberedTeacher.fromJson(Map<String, dynamic> json) => RememberedTeacher(
    teacherId: json['teacherId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    pin: json['pin']?.toString() ?? '',
    lastUsed: json['lastUsed'] is int
        ? json['lastUsed'] as int
        : int.tryParse(json['lastUsed']?.toString() ?? '0') ?? 0,
  );
}

/// Service managing 'Remember Me' credentials securely.
///
/// Credentials stored in encrypted secure storage via flutter_secure_storage. Do not move to SharedPreferences.
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
  static const String keyRememberedTeachersList = 'remembered_teachers_list';

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

  // ── Multi-Teacher Credentials ─────────────────────────────────────────────

  /// Returns all remembered teacher profiles, sorted with most recently used first.
  static Future<List<RememberedTeacher>> getRememberedTeachers() async {
    try {
      final raw = await _storage.read(key: keyRememberedTeachersList);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => RememberedTeacher.fromJson(e as Map<String, dynamic>))
            .where((t) => t.teacherId.isNotEmpty)
            .toList();
        list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
        return list;
      }
    } catch (_) {}

    // Fallback: check legacy single teacher keys if list is empty
    final legacy = await loadTeacherCredentials();
    if (legacy['remember'] == 'true' && (legacy['id'] ?? '').isNotEmpty) {
      final t = RememberedTeacher(
        teacherId: legacy['id']!,
        name: legacy['id']!,
        pin: legacy['pin'] ?? '',
        lastUsed: DateTime.now().millisecondsSinceEpoch,
      );
      await _saveTeachersList([t]);
      return [t];
    }
    return [];
  }

  /// Saves or updates a remembered teacher profile.
  static Future<void> saveRememberedTeacher({
    required String teacherIdOrMobile,
    required String pin,
    String? name,
  }) async {
    final cleanId = teacherIdOrMobile.trim();
    if (cleanId.isEmpty) return;

    final existing = await getRememberedTeachers();
    final updatedList = <RememberedTeacher>[];
    bool matched = false;

    for (final t in existing) {
      if (t.teacherId == cleanId) {
        matched = true;
        updatedList.add(RememberedTeacher(
          teacherId: cleanId,
          name: (name != null && name.trim().isNotEmpty) ? name.trim() : (t.name.isNotEmpty ? t.name : cleanId),
          pin: pin.trim(),
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        updatedList.add(t);
      }
    }

    if (!matched) {
      updatedList.insert(
        0,
        RememberedTeacher(
          teacherId: cleanId,
          name: (name != null && name.trim().isNotEmpty) ? name.trim() : cleanId,
          pin: pin.trim(),
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    // Keep active single teacher legacy pointers updated
    await _storage.write(key: keyRememberTeacher, value: 'true');
    await _storage.write(key: keyTeacherId, value: cleanId);
    await _storage.write(key: keyTeacherPin, value: pin.trim());

    await _saveTeachersList(updatedList);
  }

  /// Removes a specific teacher from the remembered list.
  static Future<void> removeRememberedTeacher(String teacherIdOrMobile) async {
    final cleanId = teacherIdOrMobile.trim();
    final existing = await getRememberedTeachers();
    final remaining = existing.where((t) => t.teacherId != cleanId).toList();
    await _saveTeachersList(remaining);

    // If active legacy pointer was this teacher, update or clear
    final activeId = await _storage.read(key: keyTeacherId);
    if (activeId == cleanId) {
      if (remaining.isNotEmpty) {
        await _storage.write(key: keyTeacherId, value: remaining.first.teacherId);
        await _storage.write(key: keyTeacherPin, value: remaining.first.pin);
      } else {
        await clearTeacherCredentials();
      }
    }
  }

  /// Helper to persist the list to secure storage.
  static Future<void> _saveTeachersList(List<RememberedTeacher> list) async {
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _storage.write(key: keyRememberedTeachersList, value: jsonString);
  }

  /// Legacy helper: Saves teacher ID/mobile and PIN in encrypted storage.
  static Future<void> saveTeacherCredentials({
    required String teacherIdOrMobile,
    required String pin,
    String? name,
  }) async {
    await saveRememberedTeacher(teacherIdOrMobile: teacherIdOrMobile, pin: pin, name: name);
  }

  /// Legacy helper: Loads saved teacher credentials if 'remember_teacher' is set.
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

  /// Clears all stored teacher credentials.
  static Future<void> clearTeacherCredentials() async {
    await _storage.delete(key: keyRememberTeacher);
    await _storage.delete(key: keyTeacherId);
    await _storage.delete(key: keyTeacherPin);
    await _storage.delete(key: keyRememberedTeachersList);
  }
}
