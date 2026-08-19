import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/lib"

files = {
    # ---------------- SECURITY ----------------
    "utils/security/encryption_helper.dart": """import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionHelper {
  // A simple hashing mechanism for offline PIN verification.
  // We use SHA-256 for secure PIN hashing.
  static String hashPin(String pin) {
    var bytes = utf8.encode(pin); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Base64 encoding for simple data obfuscation (since true offline AES requires key management).
  static String encodeData(String data) {
    return base64Encode(utf8.encode(data));
  }

  static String decodeData(String encodedData) {
    return utf8.decode(base64Decode(encodedData));
  }
}""",

    "utils/security/auth_interceptor.dart": """// This is an offline-first app, so "intercepting" usually means checking 
// local session validity before allowing critical actions.
class AuthInterceptor {
  static bool isSessionValid(String token, String expiry) {
    try {
      DateTime expiryDate = DateTime.parse(expiry);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  static String generateLocalSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}""",

    "utils/security/input_validator.dart": """class InputValidator {
  static String? validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length < 4 || value.length > 6) {
      return 'PIN must be 4-6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name is too short';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^[0-9]{10,12}$').hasMatch(value)) {
        return 'Enter a valid phone number (10-12 digits)';
      }
    }
    return null;
  }
}""",

    "utils/security/role_manager.dart": """class RoleManager {
  static const String ROLE_ADMIN = 'admin';
  static const String ROLE_TEACHER = 'teacher';

  static bool hasAdminPrivileges(String currentRole) {
    return currentRole == ROLE_ADMIN;
  }

  static bool canEditBatch(String currentRole, int teacherId, int batchTeacherId) {
    if (hasAdminPrivileges(currentRole)) return true;
    return teacherId == batchTeacherId;
  }
}""",

    "utils/security/session_manager.dart": """import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  final _storage = const FlutterSecureStorage();

  Future<void> saveSession(String token, String role) async {
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'auth_role', value: role);
    final expiry = DateTime.now().add(const Duration(hours: 12)).toIso8601String();
    await _storage.write(key: 'auth_expiry', value: expiry);
  }

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: 'auth_token');
    final expiryStr = await _storage.read(key: 'auth_expiry');
    
    if (token == null || expiryStr == null) return false;

    try {
      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isBefore(expiry);
    } catch (_) {
      return false;
    }
  }

  Future<String?> getCurrentRole() async {
    return await _storage.read(key: 'auth_role');
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_role');
    await _storage.delete(key: 'auth_expiry');
  }
}""",

    # ---------------- LOGGING ----------------
    "utils/logging/logger.dart": """import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static const bool _isDebug = true; // Set to false in production

  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    return File('${directory.path}/maktab_log_$date.txt');
  }

  static Future<void> info(String message) async {
    if (_isDebug) print('INFO: $message');
    await _writeToFile('INFO', message);
  }

  static Future<void> warning(String message) async {
    if (_isDebug) print('WARN: $message');
    await _writeToFile('WARN', message);
  }

  static Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    if (_isDebug) print('ERROR: $message \\n$error \\n$stackTrace');
    await _writeToFile('ERROR', '$message \\n$error \\n$stackTrace');
  }

  static Future<void> _writeToFile(String level, String message) async {
    try {
      final file = await _localFile;
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] [$level] $message\\n', mode: FileMode.append);
    } catch (e) {
      // Don't crash if logging fails
      print('Logging failed: $e');
    }
  }
}""",

    "utils/logging/log_rotator.dart": """import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogRotator {
  static const int maxLogAgeDays = 7;

  static Future<void> cleanOldLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      
      final now = DateTime.now();
      
      for (var file in files) {
        if (file is File && file.path.contains('maktab_log_')) {
          final lastModified = await file.lastModified();
          final difference = now.difference(lastModified).inDays;
          
          if (difference > maxLogAgeDays) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Log rotation failed: $e');
    }
  }
}""",

    "utils/logging/analytics_helper.dart": """// Local usage tracking.
class AnalyticsHelper {
  static Map<String, int> _eventCounts = {};

  static void logEvent(String eventName) {
    if (_eventCounts.containsKey(eventName)) {
      _eventCounts[eventName] = _eventCounts[eventName]! + 1;
    } else {
      _eventCounts[eventName] = 1;
    }
    // Could eventually dump this to a local DB table to see which features are used most
  }
  
  static Map<String, int> getUsageStats() {
    return _eventCounts;
  }
}""",
}

for file_path, content in files.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Filled {file_path}")
