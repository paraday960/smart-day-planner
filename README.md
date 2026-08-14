# دستیار روزانه هوشمند ایرانی — برنامه‌ریزی، حسابداری و فرمان صوتی فارسی

![Flutter CI](https://github.com/paraday960/smart-day-planner/actions/workflows/flutter_ci.yml/badge.svg)
![Android Release Build](https://github.com/paraday960/smart-day-planner/actions/workflows/release_android.yml/badge.svg)

> ## 🤖 قوانین برای هوش مصنوعی و توسعه‌دهندگان (الزامی)
> **هر هوش مصنوعی (Claude Code، Cursor، Copilot، Gemini CLI و…) یا همکاری که می‌خواهد روی این ریپو کار کند، باید اول فایل [`AGENTS.md`](AGENTS.md) را کامل بخواند و به همهٔ قوانین آن پایبند باشد.**
> این قوانین شامل معماری (domain/models/services/application/presentation)، قالب‌بندی فارسی و شمسی، امنیت رمزنگاری (PBKDF2 + AES-GCM)، پرهیز از تغییر فرمت بکاپ/دیتابیس بدون مهاجرت، احترام به Feature Flags، تست اجباری، پیام کامیت فارسی و ممنوعیت ثبت توکن/سکرت است.
>
> **Rules for AI agents (mandatory):** any AI or contributor must read and follow [`AGENTS.md`](AGENTS.md) before making changes.

> ## 🟢 وضعیت فعلی (۲۰۲۶-08-07)
> - **CI کاملاً سبز است**: ۱۳۰ تست واحد + ۵ تست feature-gating + بیلد APK دیباگ ✅
> - **شکاف‌های KNOWN_GAPS رفع شدند**: refactor فایل‌های بزرگ (VoiceNlu)، تست «همهٔ
>   repoها»، اسکلت وب و iOS، و workflow جدید ساخت APK آفلاین (Vosk + LLM محلی) 🚀
> - 📖 **برای ورود سریع (مخصوص AI ها و همکاران جدید): [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md)**
> - 📦 **دانلود آخرین APK:** تب Actions → آخرین ران سبز → Artifacts → `smart-day-planner-debug-apk`
> - 🧠 **APK با فرمان صوتی آفلاین و LLM محلی:** تب Actions → `Offline Capabilities Build` → Run workflow

این پروژه یک Starter Code رایگان برای ساخت اپ اندروید و iOS با Flutter است. رابط کاربری فارسی و راست‌چین است، تاریخ‌ها شمسی نمایش داده می‌شوند، واحد پول تومان است و فرمان صوتی فارسی پشتیبانی می‌شود. هسته برنامه بدون API پولی کار می‌کند و می‌تواند برای تشخیص گفتار از سرویس رایگان گوشی استفاده کند.








































## وضعیت فاز ۳۹
فاز ۳۹ اضافه شد:

- Feature Flags برای خاموش/روشن کردن قابلیت‌های پرریسک
- Build امن debug برای عیب‌یابی
- اسکریپت dependency audit
- چک‌لیست Release Candidate
- تست feature flags

## وضعیت فاز ۳۸
فاز ۳۸ اضافه شد:

- اسکریپت Stabilization Sprint
- اسکریپت جمع‌آوری diagnostics
- مستند ریسک‌های احتمالی Build
- برنامه تست بتا
- تمرکز روی Build → Test → Fix → Retest به جای افزودن قابلیت جدید

## وضعیت فاز ۳۷
فاز ۳۷ اضافه شد:

- تست `CommandConfidenceService` برای عملیات حساس و مبهم
- تست لغو عملیات مالی حساس در `VoiceCommandProcessor`
- تست خطای بازیابی بکاپ با رمز اشتباه
- اضافه شدن اسکریپت خلاصه Coverage
- افزایش حداقل Coverage در CI از ۲۰٪ به ۳۰٪
- اضافه شدن coverage summary به GitHub Actions

## وضعیت فاز ۳۶
فاز ۳۶ اضافه شد:

- تست end-to-end سناریوی بدهی، اشاره‌فهمی، پاکت پول و ریسک
- تست بازیابی بکاپ با fake repositoryها
- ایجاد fake repositoryهای مشترک برای تست‌ها
- اضافه شدن اسکریپت حداقل coverage
- سخت‌گیرانه‌تر شدن CI با `flutter test --coverage` و threshold پوشش تست

## وضعیت فاز ۳۵
فاز ۳۵ اضافه شد:

- تست `VoiceCommandProcessor` برای مکالمه چندمرحله‌ای بدهی
- تست اشاره‌فهمی و تأیید «پونصد براش کنار بذار»
- تست `BackupActionsController` برای ساخت wrapper بکاپ رمزنگاری‌شده
- اجرای `flutter test --coverage` در CI
- آپلود `coverage/lcov.info` به عنوان artifact

## وضعیت فاز ۳۴
فاز ۳۴ اضافه شد:

- ساخت Fake Platform Services برای Notification، Calendar، ShareFile و VoiceResponse
- تست `TaskActionsController` با `FakeNotificationService`
- تست `ReportActionsController` با `FakeCalendarService`
- آماده‌سازی تست‌های بدون وابستگی به گوشی و سرویس‌های واقعی پلتفرم

## وضعیت فاز ۳۳
فاز ۳۳ اضافه شد:

- تعریف Port برای Notification، Calendar، ShareFile و VoiceResponse
- پیاده‌سازی این Portها توسط سرویس‌های واقعی
- جدا شدن `CalendarEventSummary` و `AssistantVoiceGender` به models
- استفاده TaskActionsController و HomeCoordinator از NotificationServicePort
- استفاده ReportActionsController از CalendarServicePort و ShareFileServicePort
- اضافه شدن Providerهای پلتفرمی قابل override

## وضعیت فاز ۳۲
فاز ۳۲ اضافه شد:

- تعریف Port برای Goal، PlannedExpense، CategoryBudget و Availability
- انتقال `WorkTimeSettings` به models
- پیاده‌سازی Portهای جدید توسط repositoryهای واقعی
- مهاجرت HomeCoordinator اصلی به Repository Portها
- نزدیک‌تر شدن ActionControllerها به interfaceها
- کامل‌تر شدن تست Repository Portها

## وضعیت فاز ۳۱
فاز ۳۱ اضافه شد:

- Repositoryهای واقعی حالا Portهای domain را implement می‌کنند
- ایجاد `HomeCoordinatorFactory`
- ایجاد `homeCoordinatorV2Provider`
- تست اتصال repositoryهای واقعی به Portها
- نزدیک‌تر شدن پروژه به Clean Architecture واقعی

## وضعیت فاز ۳۰
فاز ۳۰ اضافه شد:

- تعریف Repository Portها برای Task، Finance، Debt و Allocation
- ایجاد `HomeCoordinatorV2` مبتنی بر interfaceها
- اضافه شدن fake repositoryها در تست
- تست پرداخت بدهی و پاکت پول بدون دیتابیس واقعی
- آماده‌سازی مسیر Clean Architecture واقعی

## وضعیت فاز ۲۹
فاز ۲۹ اضافه شد:

- ایجاد `HomeCoordinator`
- ایجاد `homeCoordinatorProvider`
- انتقال بخشی از عملیات HomeScreen به coordinator
- متمرکز شدن عملیات کارها، بدهی، پاکت پول، اهداف، بکاپ و امنیت
- کاهش حجم `home_screen.dart` به حدود ۶۷۰ خط

## وضعیت فاز ۲۸
فاز ۲۸ اضافه شد:

- تبدیل `SettingsTab` به ConsumerWidget
- تبدیل `AssistantTab` به ConsumerWidget
- اتصال بیشتر FinanceTab به Providerها
- اضافه شدن Widget Test برای `TasksTab`
- اضافه شدن Widget Test برای `FinanceTab`
- افزایش پوشش تست تب‌های اصلی با ProviderScope overrides

## وضعیت فاز ۲۷
فاز ۲۷ اضافه شد:

- اتصال بیشتر FinanceTab به Riverpod
- استفاده FinanceTab از `financeControllerProvider`
- خواندن repositoryها و planning serviceها داخل FinanceTab با `ref.watch`
- حذف بخشی از dependency passing از FinanceTab
- اضافه شدن Widget Test برای DashboardTab با ProviderScope overrides

## وضعیت فاز ۲۶
فاز ۲۶ اضافه شد:

- تبدیل `DashboardTab` به ConsumerWidget
- خواندن repositoryها و controllerهای داشبورد با `ref.watch` داخل DashboardTab
- تبدیل `TasksTab` به ConsumerWidget
- خواندن taskRepository و smartPlanner داخل TasksTab
- شروع ConsumerWidget شدن FinanceTab و استفاده از `financeControllerProvider`
- کوچک‌تر شدن constructorهای تب‌ها و کاهش dependency passing

## وضعیت فاز ۲۵
فاز ۲۵ اضافه شد:

- حذف constructor شلوغ از `HomeScreen`
- خواندن repositoryها و سرویس‌ها با `ref.read` داخل HomeScreen
- ساده‌تر شدن `SmartDayPlannerRoot`
- آماده‌سازی بهتر برای widget test و Provider override
- کاهش coupling بین main.dart، Root و صفحه اصلی

## وضعیت فاز ۲۴
فاز ۲۴ اضافه شد:

- ایجاد `SmartDayPlannerRoot` به عنوان ConsumerWidget
- خواندن repositoryها و سرویس‌های اصلی از Riverpod در Root
- حذف constructor شلوغ از `SmartDayPlannerApp`
- ساده‌تر شدن `main.dart` و استفاده بهتر از ProviderScope overrides
- آماده‌سازی برای حذف dependencyهای دستی از `HomeScreen`

## وضعیت فاز ۲۳
فاز ۲۳ اضافه شد:

- Provider برای repositoryها و سرویس‌های اصلی
- تابع `buildAppOverrides` برای تزریق وابستگی‌ها در `ProviderScope`
- override کردن repositoryهای initialize شده در `main.dart`
- تست smoke برای Provider override
- آماده‌سازی برای حذف constructorهای شلوغ UI

## وضعیت فاز ۲۲
فاز ۲۲ اضافه شد:

- تبدیل `HomeScreen` به `ConsumerStatefulWidget`
- استفاده عملی از `ref.read` برای ActionControllerها و سرویس‌ها
- استفاده از `ref.watch` برای DashboardController و TimeAwarePlanner
- اضافه شدن `timeAwarePlannerProvider`
- شروع مهاجرت واقعی UI به Riverpod

## وضعیت فاز ۲۱
فاز ۲۱ اضافه شد:

- ایجاد `DebtActionsController`
- ایجاد `AllocationActionsController`
- انتقال منطق پرداخت بدهی/دریافت طلب به controller
- انتقال منطق پاکت پول به controller
- اضافه شدن Providerهای مربوطه
- اضافه شدن تست برای ActionControllerها

## وضعیت فاز ۲۰
فاز ۲۰ اضافه شد:

- ایجاد `GoalActionsController`
- ایجاد `ReportActionsController`
- استخراج `GoalDialogs`
- انتقال منطق گزارش، CSV، PDF، تقویم و هشدارها به ReportActionsController
- به‌روزرسانی Providerها برای ActionControllerهای جدید
- کاهش بیشتر حجم `home_screen.dart`

## وضعیت فاز ۱۹
فاز ۱۹ اضافه شد:

- ایجاد `SecurityActionsController`
- ایجاد `BackupActionsController`
- استخراج `SecurityDialogs`
- استخراج `BackupDialogs`
- ساده‌تر شدن عملیات PIN، بکاپ و بازیابی در HomeScreen
- کاهش بیشتر حجم `home_screen.dart`

## وضعیت فاز ۱۸
فاز ۱۸ اضافه شد:

- استخراج `PlanningDialogs`
- جداسازی dialogهای هزینه آینده، بدهی/طلب، پرداخت، پاکت پول، بودجه و زمان آزاد
- ساده‌تر شدن متدهای coordinator داخل `home_screen.dart`
- کاهش حجم `home_screen.dart` به حدود ۹۰۰ خط
- تکمیل مسیر refactor دیالوگ‌های مالی و برنامه‌ریزی

## وضعیت فاز ۱۷
فاز ۱۷ اضافه شد:

- ایجاد `TaskActionsController` برای عملیات کارها
- ایجاد `FinanceActionsController` برای عملیات مالی پرتکرار
- استخراج `TaskDialogs` برای زمان واقعی و حذف کار
- استخراج `FinanceDialogs` برای ثبت درآمد/هزینه و درآمد بعد از کار
- استفاده HomeScreen از Action Controllerها و Dialogهای جدید
- کاهش بیشتر مسئولیت مستقیم `home_screen.dart`

## وضعیت فاز ۱۶
فاز ۱۶ اضافه شد:

- استخراج تب کارها به `presentation/tasks/tasks_tab.dart`
- استخراج `TaskCard` از `home_screen.dart`
- ایجاد پوشه `presentation/dialogs`
- اضافه شدن helperهای مشترک Dialog مثل confirm، askSecretText و showLargeText
- سبک‌تر شدن HomeScreen و نزدیک‌تر شدن به coordinator واقعی

## وضعیت فاز ۱۵
فاز ۱۵ اضافه شد:

- استخراج تب حسابدار به `presentation/finance/finance_tab.dart`
- استخراج تب دستیار به `presentation/assistant/assistant_tab.dart`
- استخراج تب تنظیمات به `presentation/settings/settings_tab.dart`
- کاهش قابل توجه حجم `home_screen.dart`
- تبدیل HomeScreen به coordinator سبک‌تر برای تب‌های اصلی

## وضعیت فاز ۱۴
فاز ۱۴ اضافه شد:

- استخراج ویجت‌های مشترک مثل MetricCard، GoalProgressCard و PlanCard
- استخراج تب «امروز» به `presentation/dashboard/dashboard_tab.dart`
- اتصال واقعی `DashboardController` به UI داشبورد
- شروع کاهش حجم `home_screen.dart`
- آماده‌سازی پوشه‌های presentation برای Finance، Assistant و Settings

## وضعیت فاز ۱۳
فاز ۱۳ اضافه شد:

- شروع refactor معماری پروژه
- اضافه شدن Riverpod و ProviderScope
- پوشه app و provider های اصلی
- لایه application برای Dashboard و Finance
- لایه domain و usecase قابل تست
- تست جدید برای محاسبه درآمد روزانه لازم
- مستند معماری پروژه

## وضعیت فاز ۱۲
فاز ۱۲ اضافه شد:

- GitHub Actions برای analyze/test/build خودکار
- workflow ساخت APK/AAB release
- قالب Pull Request
- قالب گزارش باگ و درخواست قابلیت
- CHANGELOG
- اسکریپت افزایش نسخه
- راهنمای CI/CD و روند انتشار

## وضعیت فاز ۱۱
فاز ۱۱ اضافه شد:

- فایل تنظیمات محصول و نسخه
- تست واحد اولیه برای فرمت فارسی
- اسکریپت بررسی سلامت پروژه
- اسکریپت فرمت و analyze
- راهنمای تنظیم package name و permission ها
- متن سیاست حریم خصوصی فارسی
- متن معرفی مارکت
- ماتریس QA برای تست روی گوشی واقعی

## وضعیت فاز ۱۰
فاز ۱۰ اضافه شد:

- فونت فارسی Vazirmatn برای UI
- استفاده از فونت فارسی در PDF واقعی
- اشتراک‌گذاری بکاپ رمزنگاری‌شده به صورت فایل
- اسکریپت ساخت APK دیباگ و ریلیز
- قالب Permission های اندروید
- راهنمای ساخت، نصب و آماده‌سازی خروجی

## وضعیت فاز ۹
فاز ۹ اضافه شد:

- اتصال به تقویم گوشی و خواندن رویدادهای آینده
- زمان‌بندی هشدارهای هوشمند برای فردا صبح
- ساخت PDF واقعی از گزارش ماه شمسی
- ذخیره و اشتراک‌گذاری فایل با Share Sheet گوشی
- دکمه‌های جدید در تب تنظیمات برای تقویم، هشدار و PDF

## وضعیت فاز ۸
فاز ۸ اضافه شد:

- تنظیم پنجره کاری و روز غیرکاری
- برنامه‌ریزی کارها داخل زمان آزاد واقعی
- پیش‌نمایش هشدارهای هوشمند برای بدهی، هزینه آینده و بودجه
- گزارش HTML آماده تبدیل به PDF
- آپدیت شبیه‌ساز وب برای تست این قابلیت‌ها

## وضعیت فاز ۷
فاز ۷ اضافه شد:

- سیستم اعتمادسنجی فرمان‌های مالی
- تأیید قبل از عملیات حساس یا مبهم
- امکان گفتن «تأیید» یا «لغو» برای عملیات مالی
- نمودار درآمد و هزینه ۷ روز اخیر
- نمودار سهم هزینه‌های ماه شمسی بر اساس دسته‌بندی

## وضعیت فاز ۶
فاز ۶ اضافه شد:

- اشاره‌فهمی اولیه مثل «براش» برای آخرین بدهی/موجودیت
- تأیید قبل از اجرای فرمان‌های مبهم
- تشخیص مبلغ‌های محاوره‌ای مبهم مثل «پونصد»
- تحلیل عادت‌های کاری و مالی
- بخش جدید «تحلیل عادت‌های تو» در داشبورد

## وضعیت فاز ۵
فاز ۵ اضافه شد:

- مکالمه چندمرحله‌ای برای فرمان‌های ناقص
- حافظه کوتاه‌مدت مکالمه
- سناریوسازی «اگر فردا کار نکنم چی میشه؟»
- تخمین «اگر امروز چند ساعت کار کنم چقدر درآمد احتمالی دارم؟»
- ریسک‌سنجی بدهی‌ها و هزینه‌های آینده
- شبیه‌ساز وب با تست مکالمه چندمرحله‌ای

## وضعیت فاز ۴
فاز ۴ اضافه شد:

- پاکت پول برای بدهی‌ها
- پاکت پول برای هزینه‌های آینده
- بودجه‌بندی ماهانه دسته‌بندی‌ها
- هشدار نزدیک شدن یا رد شدن از بودجه
- محاسبه دقیق‌تر باقی‌مانده براساس پول واقعاً کنار گذاشته‌شده
- فرمان صوتی مثل «پونصد هزار برای بدهی ممد کنار بگذار»

## وضعیت فاز ۳
فاز ۳ هم اضافه شد:

- قفل برنامه با رمز PIN
- بکاپ رمزنگاری‌شده با رمز دلخواه کاربر
- بازیابی بکاپ رمزنگاری‌شده
- خروجی CSV کارها و تراکنش‌های مالی
- گزارش ماه شمسی قابل کپی
- تب جدید «تنظیمات» برای امکانات حرفه‌ای

## وضعیت فاز ۲
فاز ۲ هم اضافه شد:

- هدف درآمد روزانه و هدف درآمد ماه شمسی
- نمایش پیشرفت هدف‌ها در داشبورد و حسابدار
- اتصال زمان و درآمد برای پیشنهاد کار ارزشمندتر
- تحلیل عملکرد هفته و دقت تخمین زمان
- فرمان صوتی برای تنظیم هدف درآمدی
- پاسخ به سؤال «چقدر باید کار کنم؟» براساس هدف درآمد و میانگین درآمد ساعتی

## وضعیت فاز ۱
فاز ۱ به پروژه اضافه شد:

- مهاجرت از ذخیره‌سازی ساده به SQLite با `sqflite`
- سرویس نوتیفیکیشن محلی برای یادآوری مهلت انجام کارها
- گزارش مالی هفتگی و ماهانه
- گزارش درآمد/هزینه بر اساس دسته‌بندی
- بهبود فرمان صوتی فارسی برای تاریخ، ساعت و مبلغ‌های ایرانی
- فارسی‌سازی و ایرانی‌سازی رابط کاربری، اعداد، پول و تاریخ شمسی

## چرا Flutter؟
- رایگان و متن‌باز
- خروجی Android و iOS از یک کد مشترک
- مناسب MVP سریع
- بدون نیاز به API پولی یا اینترنت

## قابلیت‌های ساخته‌شده در این نسخه
- ثبت، ویرایش، حذف و تکمیل کارها
- ذخیره‌سازی محلی با `shared_preferences`
- اولویت‌بندی هوشمند براساس:
  - اهمیت
  - ددلاین
  - مدت زمان تخمینی
  - سطح انرژی لازم
  - قدیمی شدن کار
- ساخت «برنامه امروز» با زمان شروع/پایان پیشنهادی
- پیشنهادهای هوشمند فارسی مثل شکستن کارهای طولانی، هشدار عقب‌افتادگی، پیشنهاد کار بعدی
- یادگیری ساده از زمان واقعی انجام کارهای کامل‌شده
- حسابدار شخصی آفلاین برای درآمد/هزینه
- پرسیدن درآمد بعد از تکمیل کارهای کاری و اضافه کردن خودکار به درآمد فعلی
- محاسبه درآمد امروز، درآمد ماه، خالص ماه و میانگین درآمد ساعتی
- فرمان صوتی فارسی با دکمه نگه‌داشتنی میکروفون
- پاسخ صوتی فارسی دستیار با انتخاب صدای زن یا مرد
- اجرای فرمان‌هایی مثل افزودن کار، ثبت درآمد، ثبت هزینه، تکمیل کار و چیدن برنامه امروز
- نمایش تاریخ شمسی و اعداد فارسی
- گزارش مالی ماه شمسی و هفته ایرانی
- ساختار آماده برای وصل کردن LLM آفلاین واقعی در آینده

## راه‌اندازی
اگر Flutter نصب نیست:
```bash
# راهنمای نصب رسمی: https://docs.flutter.dev/get-started/install
flutter doctor
```

بعد داخل پوشه پروژه:
```bash
cd smart_day_planner_flutter
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

> اگر فقط اندروید می‌خواهی: `flutter create --platforms=android .`

## مسیرهای مهم
- `lib/main.dart` — شروع برنامه
- `lib/models/task.dart` — مدل کار
- `lib/services/task_repository.dart` — ذخیره‌سازی آفلاین
- `lib/services/smart_planner.dart` — موتور اولویت‌بندی و برنامه‌ریزی
- `lib/services/local_assistant.dart` — دستیار فارسی آفلاین و جایگاه اتصال LLM محلی
- `lib/models/finance_transaction.dart` — مدل تراکنش درآمد/هزینه
- `lib/services/finance_repository.dart` — ذخیره‌سازی و محاسبات مالی آفلاین
- `lib/services/finance_assistant.dart` — تحلیل و پیشنهاد مالی آفلاین
- `lib/services/voice_command_processor.dart` — پردازش فرمان‌های صوتی فارسی
- `docs/VOICE_COMMANDS.md` — راهنمای فعال‌سازی میکروفون و فرمان صوتی
- `docs/VOICE_RESPONSE.md` — راهنمای پاسخ صوتی فارسی زن/مرد
- `docs/FREE_INTERNET_STRATEGY.md` — روش استفاده از اینترنت بدون API پولی
- `docs/IRANIAN_LOCALIZATION.md` — توضیح فارسی‌سازی و ایرانی‌سازی کامل
- `docs/PHASE_1_ADDED.md` — خلاصه امکانات فاز ۱ اضافه‌شده
- `docs/PHASE_2_ADDED.md` — خلاصه امکانات فاز ۲ اضافه‌شده
- `docs/PHASE_3_ADDED.md` — خلاصه امکانات فاز ۳ اضافه‌شده
- `docs/PHASE_4_ADDED.md` — خلاصه امکانات فاز ۴ اضافه‌شده
- `docs/PHASE_5_ADDED.md` — خلاصه امکانات فاز ۵ اضافه‌شده
- `docs/PHASE_6_ADDED.md` — خلاصه امکانات فاز ۶ اضافه‌شده
- `docs/PHASE_7_ADDED.md` — خلاصه امکانات فاز ۷ اضافه‌شده
- `docs/PHASE_8_ADDED.md` — خلاصه امکانات فاز ۸ اضافه‌شده
- `docs/PHASE_9_ADDED.md` — خلاصه امکانات فاز ۹ اضافه‌شده
- `docs/PHASE_10_ADDED.md` — خلاصه امکانات فاز ۱۰ اضافه‌شده
- `docs/PHASE_11_STABILIZATION.md` — پایدارسازی، تست و آماده‌سازی انتشار
- `docs/PHASE_12_CI_CD.md` — CI/CD، مدیریت نسخه و فرآیند توسعه تیمی
- `docs/PHASE_13_REFACTOR.md` — معماری تمیزتر و شروع Refactor
- `docs/PHASE_14_REFACTOR_UI.md` — شکستن UI و اتصال اولیه Controller ها
- `docs/PHASE_15_REFACTOR_TABS.md` — استخراج تب‌های حسابدار، دستیار و تنظیمات
- `docs/PHASE_16_REFACTOR_TASKS_DIALOGS.md` — استخراج تب کارها و شروع جداسازی Dialogها
- `docs/PHASE_17_ACTIONS_DIALOGS.md` — استخراج Dialogها و Action Controllerها
- `docs/PHASE_18_DIALOG_EXTRACTION.md` — استخراج Dialogهای مالی/برنامه‌ریزی
- `docs/PHASE_19_SECURITY_BACKUP_REFACTOR.md` — استخراج Security/Backup Dialogs و Action Controllerها
- `docs/PHASE_20_GOAL_REPORT_ACTIONS.md` — Goal/Report Action Controllers و تکمیل استخراج Dialogها
- `docs/PHASE_21_DEBT_ALLOCATION_ACTIONS.md` — Debt/Allocation Actions و تست Controllerها
- `docs/PHASE_22_RIVERPOD_INTEGRATION.md` — اتصال عملی Riverpod به HomeScreen
- `docs/PHASE_23_REPOSITORY_PROVIDERS.md` — Repository Providers و تست override با Riverpod
- `docs/PHASE_24_REPOSITORY_INJECTION.md` — تزریق Repositoryها از Riverpod و سبک‌تر شدن main.dart
- `docs/PHASE_25_HOME_DEPENDENCY_REMOVAL.md` — حذف dependencyهای دستی از HomeScreen
- `docs/PHASE_26_CONSUMER_TABS.md` — ConsumerWidget کردن تب‌ها و استفاده مستقیم‌تر از Providerها
- `docs/PHASE_27_FINANCE_CONSUMER_WIDGETS.md` — تکمیل Riverpod در تب‌ها و Widget Test
- `docs/PHASE_28_WIDGET_TESTS_CONSUMER_REFACTOR.md` — ConsumerWidget تکمیلی و Widget Testهای بیشتر
- `docs/PHASE_29_HOME_COORDINATOR.md` — HomeCoordinator و سبک‌تر شدن HomeScreen
- `docs/PHASE_30_PORTS_AND_COORDINATOR_TESTS.md` — Repository Ports و تست HomeCoordinator
- `docs/PHASE_31_PORT_IMPLEMENTATIONS.md` — اتصال Repositoryهای واقعی به Portها
- `docs/PHASE_32_PORT_MIGRATION.md` — مهاجرت Coordinator اصلی به Portها و تکمیل Contracts
- `docs/PHASE_33_PLATFORM_PORTS.md` — Platform Service Ports و تست‌پذیری سرویس‌های سیستمی
- `docs/PHASE_34_FAKE_PLATFORM_TESTS.md` — Fake Platform Services و تست ActionControllerها
- `docs/PHASE_35_VOICE_AND_COVERAGE_TESTS.md` — تست VoiceCommandProcessor، BackupActions و Coverage در CI
- `docs/PHASE_36_E2E_AND_COVERAGE.md` — تست سناریوی کامل، Backup Restore و حداقل Coverage
- `docs/PHASE_37_ERROR_CONFIDENCE_COVERAGE.md` — تست خطا، Confidence و گزارش Coverage
- `docs/PHASE_38_STABILIZATION_SPRINT.md` — Stabilization Sprint و آماده‌سازی تست واقعی
- `docs/PHASE_39_RELEASE_CANDIDATE_HARDENING.md` — Release Candidate Hardening و Feature Flags
- `docs/KNOWN_BUILD_RISKS.md` — ریسک‌های احتمالی Build و راه‌حل‌ها
- `docs/ARCHITECTURE.md` — مستند معماری پروژه
- `docs/CI_CD_GUIDE.md` — راهنمای GitHub Actions و انتشار
- `docs/BUILD_RELEASE_GUIDE.md` — راهنمای ساخت APK و نصب
- `docs/PLANNED_EXPENSES_SMART_BUDGETING.md` — برنامه‌ریزی هوشمند هزینه‌های آینده
- `docs/DEBT_AND_RECEIVABLES.md` — مدیریت هوشمند بدهی و طلب
- `lib/utils/persian_format.dart` — فرمت تاریخ شمسی، تومان و اعداد فارسی
- `lib/screens/home_screen.dart` — صفحه اصلی
- `lib/widgets/task_form_sheet.dart` — فرم افزودن/ویرایش کار




## قابلیت جدید: مدیریت بدهی و طلب
برنامه حالا می‌تواند جمله‌هایی مثل این را بفهمد:

```text
به ممد یک میلیون بدهکارم تا دو روز دیگه باید پس بدم
```

بعد بدهی را ثبت می‌کند، مهلت را تشخیص می‌دهد و حساب می‌کند تا آن تاریخ روزانه چقدر باید درآمد داشته باشی. اگر یک روز کمتر درآمد ثبت شود، محاسبه روزهای بعدی با باقی‌مانده جدید به‌روزرسانی می‌شود.

## قابلیت جدید: برنامه‌ریزی هزینه‌های آینده
برنامه حالا می‌تواند جمله‌هایی مثل این را بفهمد:

```text
هفته دیگه می‌خوام با دوست دخترم برم بیرون و این کار یک میلیون تومان خرج داره
```

بعد خودش هزینه آینده را ثبت می‌کند و حساب می‌کند تا آن تاریخ روزانه چقدر باید درآمد داشته باشی. اگر یک روز کمتر درآمد ثبت شود، محاسبه روزهای بعدی خودکار با باقی‌مانده جدید انجام می‌شود.

## پاسخ صوتی دستیار
در تب «دستیار»، کاربر می‌تواند پاسخ صوتی را روشن کند و بین «صدای زن» و «صدای مرد» انتخاب کند. اپ بعد از اجرای فرمان یا پاسخ متنی، جواب را با موتور گفتار فارسی گوشی می‌خواند. این قابلیت API پولی لازم ندارد، اما کیفیت و وجود صدای زن/مرد به گوشی کاربر وابسته است.

## فرمان صوتی فارسی
در تب «دستیار»، دکمه میکروفون را نگه دار و فارسی حرف بزن. وقتی دکمه را رها کنی، متن تشخیص داده‌شده پردازش و فرمان اجرا می‌شود. نمونه‌ها:

- «کار جدید تماس با مشتری اضافه کن»
- «درآمد سه میلیون تومان ثبت کن»
- «هزینه دویست هزار تومان ثبت کن»
- «کار پروژه فروش کامل شد»
- «برنامه امروزمو بچین»

برای Permission های Android/iOS فایل `docs/VOICE_COMMANDS.md` را ببین. برای سیاست بدون هزینه پولی هم `docs/FREE_INTERNET_STRATEGY.md` اضافه شده است.

## اضافه کردن LLM آفلاین واقعی
در این Starter Code فعلاً موتور هوشمند محلی Rule-Based است تا سبک، رایگان و قابل اجرا باشد. برای LLM واقعی آفلاین، یکی از مسیرها:

1. استفاده از مدل‌های کوچک GGUF مثل TinyLlama / Phi کوچک / Qwen کوچک با کوانتیزیشن Q4
2. اضافه کردن یک binding برای llama.cpp یا ONNX Runtime Mobile
3. قرار دادن مدل در assets یا دانلود یک‌بار مصرف توسط کاربر
4. پیاده‌سازی کلاس `LocalLlmAdapter` در `lib/services/local_assistant.dart`

پیشنهاد عملی: اول MVP را با همین موتور آفلاین بساز، بعد اگر گوشی‌های هدف قوی هستند، LLM محلی اضافه کن؛ چون LLM روی موبایل حجم و مصرف باتری بالایی دارد.

## ایده‌های مرحله بعد
- اتصال به Calendar گوشی با اجازه کاربر
- نوتیفیکیشن آفلاین
- ویجت صفحه اصلی
- تحلیل هفتگی عملکرد
- تخمین زمان با مدل کوچک TensorFlow Lite
- پشتیبان‌گیری رمزنگاری‌شده محلی
