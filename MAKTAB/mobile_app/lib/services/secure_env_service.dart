import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

class SecureEnvService {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'db_encryption_key';

  static String get geminiApiKey {
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyBx6p3ZzWLwq821vcctpOpD45TVW0U14Zk');
  }

  static Future<String> getDatabaseEncryptionKey() async {
    String? key = await _storage.read(key: _dbKeyName);
    if (key == null) {
      // Generate a strong random key for SQLCipher
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(values);
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  static Future<void> setDatabaseEncryptionKey(String key) async {
    await _storage.write(key: _dbKeyName, value: key);
  }
}
