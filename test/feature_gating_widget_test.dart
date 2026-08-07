import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_day_planner/app/app_providers.dart';
import 'package:smart_day_planner/app/feature_flags.dart';
import 'package:smart_day_planner/screens/home_screen.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/availability_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/security_service.dart';
import 'package:smart_day_planner/services/task_repository.dart';

import 'fakes/fake_platform_services.dart';

/// تأیید می‌کند که feature flagها واقعاً روی رفتار برنامه اثر می‌گذارند.
///
/// چون راه‌اندازی speech_to_text در محیط تست باعث کرش رانر تست می‌شود،
/// این تست فقط وقتی اجرا می‌شود که فرمان صوتی خاموش باشد:
///
/// ```bash
/// flutter test test/feature_gating_widget_test.dart \
///   --dart-define=ENABLE_VOICE_INPUT=false
/// ```
///
/// برای بررسی حالت «همه قابلیت‌ها خاموش»:
///
/// ```bash
/// flutter test test/feature_gating_widget_test.dart \
///   --dart-define=ENABLE_VOICE_INPUT=false \
///   --dart-define=ENABLE_VOICE_RESPONSE=false \
///   --dart-define=ENABLE_CALENDAR=false \
///   --dart-define=ENABLE_PDF_EXPORT=false \
///   --dart-define=ENABLE_SHARE_FILES=false \
///   --dart-define=ENABLE_SMART_NOTIFICATIONS=false \
///   --dart-define=ENABLE_ENCRYPTED_BACKUP=false
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const runGatingTests = !FeatureFlags.enableVoiceInput;

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildAppOverrides(
            taskRepository: TaskRepository(),
            financeRepository: FinanceRepository(),
            goalRepository: GoalRepository(),
            plannedExpenseRepository: PlannedExpenseRepository(),
            debtRepository: DebtRepository(),
            allocationRepository: AllocationRepository(),
            categoryBudgetRepository: CategoryBudgetRepository(),
            availabilityRepository: AvailabilityRepository(),
            conversationMemoryService: ConversationMemoryService(),
            notificationService: FakeNotificationService(),
            voiceResponseService: FakeVoiceResponseService(),
            securityService: SecurityService.instance,
          ),
          calendarServiceProvider.overrideWith((ref) => FakeCalendarService()),
          shareFileServiceProvider.overrideWith((ref) => FakeShareFileService()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    // تب دستیار آواتار متحرک دارد که به‌صورت پیوسته (repeat) انیمیشن می‌سازد؛
    // پس به‌جای pumpAndSettle که هرگز settle نمی‌شود، با pump پیش می‌رویم.
    await tester.pump(const Duration(seconds: 1));

    // رفتن به تب تنظیمات
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSettingsButton(WidgetTester tester, Finder button) async {
    // لیست تنظیمات lazy است؛ باید اسکرول کنیم تا دکمه ساخته شود.
    await tester.scrollUntilVisible(button, 150, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('feature flags gate platform features', () {
    testWidgets(
      'تقویم گوشی: flag روشن → دیالوگ رویدادها، خاموش → پیام غیرفعال',
      skip: !runGatingTests,
      (tester) async {
        await pumpHomeScreen(tester);
        await tapSettingsButton(tester, find.widgetWithText(OutlinedButton, 'تقویم گوشی'));

        if (FeatureFlags.enableCalendar) {
          expect(find.text('رویدادهای تقویم ۷ روز آینده'), findsOneWidget);
          expect(find.textContaining('رویدادی پیدا نشد'), findsOneWidget);
        } else {
          expect(find.text('قابلیت «تقویم گوشی» در این نسخه غیرفعال است.'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'هشدارهای هوشمند (پیش‌نمایش): flag روشن → دیالوگ، خاموش → پیام غیرفعال',
      skip: !runGatingTests,
      (tester) async {
        await pumpHomeScreen(tester);
        await tapSettingsButton(tester, find.widgetWithText(OutlinedButton, 'هشدارهای هوشمند'));

        if (FeatureFlags.enableSmartNotifications) {
          expect(find.text('پیش‌نمایش هشدارهای هوشمند'), findsOneWidget);
        } else {
          expect(find.text('قابلیت «هشدارهای هوشمند» در این نسخه غیرفعال است.'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'زمان‌بندی هشدار: flag روشن → زمان‌بندی، خاموش → پیام غیرفعال',
      skip: !runGatingTests,
      (tester) async {
        await pumpHomeScreen(tester);
        await tapSettingsButton(tester, find.widgetWithText(OutlinedButton, 'زمان‌بندی هشدار'));

        if (FeatureFlags.enableSmartNotifications) {
          expect(find.text('هشدار فوری برای زمان‌بندی پیدا نشد.'), findsOneWidget);
        } else {
          expect(find.text('قابلیت «زمان‌بندی هشدار» در این نسخه غیرفعال است.'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'PDF و اشتراک‌گذاری: flag خاموش → پیام غیرفعال (مسیر روشن در گوشی واقعی تست می‌شود)',
      skip: !runGatingTests,
      (tester) async {
        await pumpHomeScreen(tester);
        await tapSettingsButton(tester, find.widgetWithText(FilledButton, 'PDF واقعی و اشتراک‌گذاری'));

        if (!FeatureFlags.enablePdfExport || !FeatureFlags.enableShareFiles) {
          expect(find.text('قابلیت «PDF و اشتراک‌گذاری» در این نسخه غیرفعال است.'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'بکاپ رمزنگاری‌شده: flag خاموش → پیام غیرفعال',
      skip: !runGatingTests,
      (tester) async {
        await pumpHomeScreen(tester);
        await tapSettingsButton(tester, find.widgetWithText(FilledButton, 'ساخت بکاپ'));

        if (!FeatureFlags.enableEncryptedBackup) {
          expect(find.text('قابلیت «بکاپ رمزنگاری‌شده» در این نسخه غیرفعال است.'), findsOneWidget);
        }
      },
    );
  });
}
