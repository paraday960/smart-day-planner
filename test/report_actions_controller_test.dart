import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/report_actions_controller.dart';
import 'package:smart_day_planner/models/calendar_event_summary.dart';

import 'fakes/fake_platform_services.dart';

void main() {
  test('calendarPreviewText returns upcoming event summaries', () async {
    final calendar = FakeCalendarService(
      events: [
        CalendarEventSummary(
          title: 'جلسه کاری',
          start: DateTime(2026, 1, 1, 10),
          end: DateTime(2026, 1, 1, 11),
          calendarName: 'کاری',
        ),
      ],
    );
    final controller = ReportActionsController(shareFileService: FakeShareFileService());

    final text = await controller.calendarPreviewText(calendar);

    expect(text, contains('جلسه کاری'));
    expect(text, contains('کاری'));
  });

  test('calendarPreviewText handles missing permission or empty events', () async {
    final calendar = FakeCalendarService(permission: false);
    final controller = ReportActionsController(shareFileService: FakeShareFileService());

    final text = await controller.calendarPreviewText(calendar);

    expect(text, 'رویدادی پیدا نشد یا دسترسی تقویم داده نشده است.');
  });
}
