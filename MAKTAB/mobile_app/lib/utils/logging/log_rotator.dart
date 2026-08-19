import 'dart:io';
import 'package:flutter/foundation.dart';
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
      debugPrint('Log rotation failed: $e');
    }
  }
}