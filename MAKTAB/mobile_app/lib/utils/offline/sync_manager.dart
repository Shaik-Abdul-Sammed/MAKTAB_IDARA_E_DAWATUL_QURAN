import 'queue_manager.dart';
import '../logging/logger.dart';

class SyncManager {
  static bool isSyncing = false;

  static Future<void> syncPendingItems() async {
    if (isSyncing) return;
    
    isSyncing = true;
    try {
      final items = await QueueManager.getPendingItems();
      if (items.isEmpty) {
        AppLogger.info('No items to sync.');
        return;
      }

      AppLogger.info('Found ${items.length} items to sync.');
      for (var item in items) {
        // Here we would typically send to a server.
        // For Maktab offline, maybe we process local background tasks here.
        await Future.delayed(const Duration(milliseconds: 100)); // Simulate processing
        await QueueManager.markCompleted(item.id!);
      }
      AppLogger.info('Sync completed.');
    } catch (e) {
      AppLogger.error('Sync failed', e);
    } finally {
      isSyncing = false;
    }
  }
}