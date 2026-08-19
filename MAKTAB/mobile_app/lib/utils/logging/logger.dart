import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static const bool _isDebug = kDebugMode;

  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    return File('${directory.path}/maktab_log_$date.txt');
  }

  static Future<void> info(String message) async {
    if (_isDebug) debugPrint('INFO: $message');
    await _writeToFile('INFO', message);
  }

  static Future<void> warning(String message) async {
    if (_isDebug) debugPrint('WARN: $message');
    await _writeToFile('WARN', message);
  }

  static Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    if (_isDebug) debugPrint('ERROR: $message \n$error \n$stackTrace');
    await _writeToFile('ERROR', '$message \n$error \n$stackTrace');
  }

  static Future<void> _writeToFile(String level, String message) async {
    try {
      final file = await _localFile;
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] [$level] $message\n', mode: FileMode.append);
    } catch (e) {
      // Don't crash if logging fails
      debugPrint('Logging failed: $e');
    }
  }
}