import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/secure_env_service.dart';

class BackupRestoreService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Exports the encrypted database and its encryption key to a ZIP file.
  Future<String?> createBackup({Directory? outDir}) async {
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        throw Exception('Database file not found for backup');
      }

      final key = await SecureEnvService.getDatabaseEncryptionKey();
      
      final archive = Archive();
      
      // 1. Add database file to archive
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('maktab.db', dbBytes.length, dbBytes));
      
      // 2. Add metadata.json to archive
      final metaBytes = utf8.encode(jsonEncode({'db_encryption_key': key}));
      archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
      
      Directory? defaultDir;
      if (Platform.isAndroid) {
        defaultDir = await getExternalStorageDirectory();
      } else {
        defaultDir = await getApplicationDocumentsDirectory();
      }
      outDir ??= defaultDir;
      
      if (outDir != null) {
        final zipPath = join(outDir.path, 'maktab_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
        final zipBytes = ZipEncoder().encode(archive);
        
        // Encrypt ZIP bytes with AES-256
        final key = enc.Key.fromUtf8('MaktabBackupPasscode2026@SecureX'); // 32 chars
        final iv = enc.IV.fromLength(16);
        final encrypter = enc.Encrypter(enc.AES(key));
        final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);
        
        // Write IV + Encrypted Data
        final outBytes = <int>[...iv.bytes, ...encrypted.bytes];
        
        final zipFile = File(zipPath);
        await zipFile.writeAsBytes(outBytes);
        return zipPath;
      }
      return null;
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      rethrow;
    }
  }

  /// Restores a database from a ZIP file containing maktab.db and metadata.json.
  Future<bool> restoreBackup(String zipFilePath) async {
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) return false;

      final tempDir = await getTemporaryDirectory();
      final restoreStagingDir = Directory(join(tempDir.path, 'maktab_restore_staging'));
      if (await restoreStagingDir.exists()) {
        await restoreStagingDir.delete(recursive: true);
      }
      await restoreStagingDir.create();

      // 1. Extract ZIP
      final bytes = await zipFile.readAsBytes();
      
      // Decrypt ZIP bytes with AES-256
      final key = enc.Key.fromUtf8('MaktabBackupPasscode2026@SecureX');
      final iv = enc.IV(Uint8List.fromList(bytes.sublist(0, 16)));
      final encrypter = enc.Encrypter(enc.AES(key));
      final encryptedData = enc.Encrypted(Uint8List.fromList(bytes.sublist(16)));
      final decryptedBytes = encrypter.decryptBytes(encryptedData, iv: iv);
      
      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File(join(restoreStagingDir.path, filename))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      // 2. Read metadata and DB
      final metadataFile = File(join(restoreStagingDir.path, 'metadata.json'));
      final dbFile = File(join(restoreStagingDir.path, 'maktab.db'));

      if (!await metadataFile.exists() || !await dbFile.exists()) {
        debugPrint('Invalid backup format');
        return false;
      }

      final metadata = jsonDecode(await metadataFile.readAsString());
      final String? backupKey = metadata['db_encryption_key'];
      if (backupKey == null) {
        debugPrint('Missing encryption key in backup');
        return false;
      }

      // 3. Replace current DB and Key
      await _dbHelper.close(); // Close active connection

      // Overwrite the key in secure storage
      await SecureEnvService.setDatabaseEncryptionKey(backupKey);

      // Overwrite DB file
      final currentDbPath = await _dbHelper.databasePath;
      await dbFile.copy(currentDbPath);

      // Cleanup
      await restoreStagingDir.delete(recursive: true);
      
      return true;
    } catch (e) {
      debugPrint('Restore Error: $e');
      return false;
    }
  }
}
