import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImageSaver {
  static Future<String> saveImageToAppStorage(String originalPath) async {
    final File originalFile = File(originalPath);
    if (!await originalFile.exists()) {
      throw Exception('Original file does not exist');
    }

    final directory = await getApplicationDocumentsDirectory();
    final String folderPath = path.join(directory.path, 'profiles');
    final Directory profileDir = Directory(folderPath);
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final String extension = path.extension(originalPath);
    final String newFileName = 'profile_${DateTime.now().millisecondsSinceEpoch}$extension';
    final String newPath = path.join(folderPath, newFileName);

    await originalFile.copy(newPath);
    return newPath;
  }
}
