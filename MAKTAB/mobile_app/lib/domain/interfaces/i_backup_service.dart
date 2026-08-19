abstract class IBackupService {
  Future<String> createLocalBackup();
  Future<bool> restoreFromLocalBackup(String path);
  Future<bool> shareBackupFile(String path);
  Future<bool> verifyBackupIntegrity(String path);
}