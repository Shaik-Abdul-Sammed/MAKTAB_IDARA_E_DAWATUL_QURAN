import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
}