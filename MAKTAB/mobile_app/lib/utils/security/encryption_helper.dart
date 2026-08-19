import 'dart:convert';
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
}