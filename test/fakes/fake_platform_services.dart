import 'dart:io';
import 'dart:typed_data';

import 'package:smart_day_planner/domain/services/calendar_service_port.dart';
import 'package:smart_day_planner/domain/services/notification_service_port.dart';
import 'package:smart_day_planner/domain/services/share_file_service_port.dart';
import 'package:smart_day_planner/domain/services/voice_response_port.dart';
import 'package:smart_day_planner/models/assistant_voice_gender.dart';
import 'package:smart_day_planner/models/calendar_event_summary.dart';
import 'package:smart_day_planner/models/task.dart';

class FakeNotificationService implements NotificationServicePort {
  bool initialized = false;
  final scheduledTaskIds = <String>[];
  final cancelledTaskIds = <String>[];
  final smartAlerts = <String>[];

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> scheduleTaskReminder(Task task) async {
    scheduledTaskIds.add(task.id);
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> scheduleSmartAlert({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    smartAlerts.add('$id|$title|$body|${when.toIso8601String()}');
  }
}

class FakeCalendarService implements CalendarServicePort {
  FakeCalendarService({this.permission = true, List<CalendarEventSummary>? events}) : events = events ?? [];

  bool permission;
  final List<CalendarEventSummary> events;
  final createdEvents = <CalendarEventSummary>[];

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<CalendarEventSummary>> upcomingEvents({int days = 7}) async {
    if (!permission) return const [];
    return events.take(20).toList();
  }

  @override
  Future<bool> addReminderEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    if (!permission) return false;
    createdEvents.add(
      CalendarEventSummary(
        title: title,
        start: start,
        end: end,
        calendarName: 'Fake Calendar',
      ),
    );
    return true;
  }
}

class FakeShareFileService implements ShareFileServicePort {
  final savedFiles = <File>[];
  final sharedFiles = <File>[];
  final sharedTexts = <String?>[];

  @override
  Future<File> saveBytes({required String fileName, required Uint8List bytes}) async {
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    savedFiles.add(file);
    return file;
  }

  @override
  Future<File> saveText({required String fileName, required String text}) async {
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsString(text, flush: true);
    savedFiles.add(file);
    return file;
  }

  @override
  Future<void> shareFile(File file, {String? text}) async {
    sharedFiles.add(file);
    sharedTexts.add(text);
  }
}

class FakeVoiceResponseService implements VoiceResponsePort {
  @override
  bool enabled = true;

  @override
  AssistantVoiceGender gender = AssistantVoiceGender.feminine;

  final spokenTexts = <String>[];
  bool initialized = false;
  bool stopped = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<void> setGender(AssistantVoiceGender gender) async {
    this.gender = gender;
  }

  @override
  Future<void> speak(String text, {bool force = false}) async {
    if (enabled || force) spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<String> testVoice() async {
    const sample = 'تست صدا';
    await speak(sample, force: true);
    return sample;
  }
}
