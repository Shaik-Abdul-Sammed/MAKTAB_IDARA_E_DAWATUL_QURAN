abstract class INotificationService {
  Future<void> showNotification({required String title, required String body});
  Future<void> scheduleNotification({required String title, required String body, required DateTime scheduledDate});
  Future<void> cancelAllNotifications();
}