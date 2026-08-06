import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/notification_service_port.dart';
import '../models/task.dart';

class NotificationService implements NotificationServicePort {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueAt == null || task.isDone) {
      await cancelTaskReminder(task.id);
      return;
    }

    final now = DateTime.now();
    var reminderAt = task.dueAt!.subtract(const Duration(minutes: 15));
    if (reminderAt.isBefore(now)) reminderAt = task.dueAt!;
    if (reminderAt.isBefore(now)) return;

    await initialize();

    await _plugin.zonedSchedule(
      _notificationId(task.id),
      'یادآوری کار',
      'تا مهلت انجام «${task.title}» زمان زیادی نمانده.',
      tz.TZDateTime.from(reminderAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'یادآوری کارها',
          channelDescription: 'یادآوری مهلت انجام و شروع کارهای روزانه',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:${task.id}',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _plugin.cancel(_notificationId(taskId));
  }

  Future<void> scheduleSmartAlert({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await initialize();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_alerts',
          'هشدارهای هوشمند',
          channelDescription: 'هشدارهای مالی و زمانی هوشمند',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'smart_alert',
    );
  }

  int _notificationId(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
