import '../../models/calendar_event_summary.dart';

abstract class CalendarServicePort {
  Future<bool> requestPermission();
  Future<List<CalendarEventSummary>> upcomingEvents({int days = 7});
  Future<bool> addReminderEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  });
}
