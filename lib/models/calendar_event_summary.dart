import '../utils/persian_format.dart';

class CalendarEventSummary {
  const CalendarEventSummary({
    required this.title,
    required this.start,
    required this.end,
    required this.calendarName,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String calendarName;

  String get faSummary => '$title • ${PersianFormat.jalaliDateTime(start)} تا ${PersianFormat.time(end)} • $calendarName';
}
