import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (status.isGranted) return true;
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'maktab_instant_channel',
      'Maktab General Notifications',
      channelDescription: 'Instant notifications for Maktab Quran Management App',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> showFeeReminderNotification({
    required String studentName,
    required double amount,
  }) async {
    await showInstantNotification(
      title: 'Fee Payment Due Reminder 💰',
      body: 'Monthly fee of ₹${amount.toInt()} for student $studentName is pending. Tap to process payment via UPI or WhatsApp.',
      payload: 'fee_reminder',
    );
  }

  Future<void> scheduleDailyChecklistReminder() async {
    await init();
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'maktab_checklist',
      'Daily Checklist Reminders',
      channelDescription: 'Reminds teachers to fill out the daily checklist',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterLocalNotificationsPlugin.periodicallyShow(
        id: 101,
        title: 'Daily Maktab Readiness Checklist 📋',
        body: 'Don\'t forget to complete your Maktab daily operational checklist!',
        repeatInterval: RepeatInterval.daily,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
