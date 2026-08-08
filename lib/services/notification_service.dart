import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/notification_service_port.dart';
import '../models/task.dart';

class NotificationService implements NotificationServicePort {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;
  FlutterLocalNotificationsPlugin get _pluginInstance {
    _plugin ??= FlutterLocalNotificationsPlugin();
    return _plugin!;
  }

  bool _initialized = false;

  /// ثبت پایدار شناسهٔ اعلان برای هر task — تا دو task مختلف هرگز
  /// شناسهٔ یکسان نگیرند (هش دست‌ساز قبلی احتمال برخورد داشت و یک
  /// یادآوری بی‌صدا جایگزین دیگری می‌شد).
  static const _idRegistryKey = 'smart_day_planner.notification.id_registry.v1';
  static const _nextIdKey = 'smart_day_planner.notification.next_id.v1';

  /// شناسه‌های تخصیص‌داده‌شده (taskId → notificationId).
  Map<String, int>? _idRegistry;
  int? _nextId;

  Future<int> _allocateNotificationId(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    _idRegistry ??= _decodeRegistry(prefs.getString(_idRegistryKey));
    _nextId ??= prefs.getInt(_nextIdKey) ?? 1000;
    final existing = _idRegistry![taskId];
    if (existing != null) return existing;

    final id = _nextId!;
    _idRegistry![taskId] = id;
    _nextId = id + 1;
    await prefs.setString(_idRegistryKey, jsonEncode(_idRegistry));
    await prefs.setInt(_nextIdKey, _nextId!);
    return id;
  }

  Future<int?> _notificationIdFor(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    _idRegistry ??= _decodeRegistry(prefs.getString(_idRegistryKey));
    return _idRegistry![taskId];
  }

  Future<void> _releaseNotificationId(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    _idRegistry ??= _decodeRegistry(prefs.getString(_idRegistryKey));
    if (_idRegistry!.remove(taskId) != null) {
      await prefs.setString(_idRegistryKey, jsonEncode(_idRegistry));
    }
  }

  Map<String, int> _decodeRegistry(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _pluginInstance.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _pluginInstance
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _pluginInstance
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
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

    // شناسهٔ پایدار و بدون برخورد برای این task
    final notificationId = await _allocateNotificationId(task.id);

    await _pluginInstance.zonedSchedule(
      notificationId,
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

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    if (_plugin == null) return;
    final id = await _notificationIdFor(taskId);
    if (id == null) return;
    await _plugin!.cancel(id);
    await _releaseNotificationId(taskId);
  }

  @override
  Future<void> scheduleSmartAlert({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await initialize();
    await _pluginInstance.zonedSchedule(
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

  // ── حذف شد: شناسهٔ هش دست‌ساز قدیمی (احتمال برخورد) جای خود را به
  //    رجیستری پایدار (_allocateNotificationId) داد.
}
