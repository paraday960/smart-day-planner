import 'package:device_calendar/device_calendar.dart';

import '../domain/services/calendar_service_port.dart';

import '../models/calendar_event_summary.dart';

class CalendarService implements CalendarServicePort {
  CalendarService({DeviceCalendarPlugin? plugin}) : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  Future<bool> requestPermission() async {
    final permissions = await _plugin.requestPermissions();
    return permissions.isSuccess && (permissions.data ?? false);
  }

  Future<List<CalendarEventSummary>> upcomingEvents({int days = 7}) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return const [];

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    final result = <CalendarEventSummary>[];

    for (final calendar in calendars.where((c) => !(c.isReadOnly ?? false) || true)) {
      final calendarId = calendar.id;
      if (calendarId == null) continue;
      final eventsResult = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: now, endDate: end),
      );
      final events = eventsResult.data ?? [];
      for (final event in events) {
        final start = event.start;
        final eventEnd = event.end;
        if (start == null || eventEnd == null) continue;
        result.add(CalendarEventSummary(
          title: event.title ?? 'رویداد بدون عنوان',
          start: start,
          end: eventEnd,
          calendarName: calendar.name ?? 'تقویم',
        ));
      }
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return result.take(20).toList();
  }

  Future<bool> addReminderEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];
    final writable = calendars.where((c) => !(c.isReadOnly ?? false)).toList();
    if (writable.isEmpty || writable.first.id == null) return false;

    final event = Event(
      writable.first.id,
      title: title,
      description: description,
      start: start,
      end: end,
    );
    final result = await _plugin.createOrUpdateEvent(event);
    return result?.isSuccess ?? false;
  }
}
