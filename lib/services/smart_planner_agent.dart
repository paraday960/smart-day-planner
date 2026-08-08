import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/feature_flags.dart';
import 'llama_backend.dart';
import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'task_repository.dart';
import 'voice_nlu.dart';
import 'work_learning_service.dart';

/// یک اقدام قابل‌اجرا توسط دستیار محلی.
///
/// نوع‌ها:
/// - `event`    → یک کار با زمان (قرار/رویداد) اضافه می‌کند
/// - `topup`    → اگر موجودی کمتر از هدف بود، موجودی را به هدف می‌رساند
/// - `task`     → یک کار ساده اضافه می‌کند
/// - `advice`   → فقط توصیه/اطلاع است (اجرا نمی‌شود)
class SmartAction {
  const SmartAction({
    required this.type,
    this.title = '',
    this.amount = 0,
    this.dueAt,
    this.message = '',
  });

  final String type;
  final String title;
  final int amount;
  final DateTime? dueAt;
  final String message;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'amount': amount,
        'dueAt': dueAt?.toIso8601String(),
        'message': message,
      };

  factory SmartAction.fromJson(Map<String, dynamic> j) {
    return SmartAction(
      type: j['type'] as String? ?? 'advice',
      title: j['title'] as String? ?? '',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      dueAt: j['dueAt'] is String
          ? DateTime.tryParse(j['dueAt'] as String)
          : null,
      message: j['message'] as String? ?? '',
    );
  }
}

/// خروجی پردازش سناریو.
class SmartPlanResult {
  const SmartPlanResult({
    required this.message,
    required this.actions,
    required this.reused,
  });

  final String message;
  final List<SmartAction> actions;
  /// آیا از سناریوی یادگرفته‌شده قبلی استفاده شد (بدون تماس با هوش آنلاین).
  final bool reused;
}

/// حافظهٔ یادگیری سناریو — دستیار محلی از سناریوهای قبلی یاد می‌گیرد و
/// سناریوهای مشابه را خودش انجام می‌دهد بدون اینکه دوباره از هوش آنلاین بپرسد.
class SmartScenarioMemory {
  SmartScenarioMemory._();
  static final SmartScenarioMemory instance = SmartScenarioMemory._();

  static const String _prefKey = 'smart_scenario_memory';
  Map<String, List<SmartAction>> _plans = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _plans = map.map((k, v) {
          final list = (v as List).map((e) {
            return SmartAction.fromJson(Map<String, dynamic>.from(e as Map));
          }).toList();
          return MapEntry(k, list);
        });
      }
    } catch (e, s) {
      debugPrint('SmartScenarioMemory: خطا در بارگذاری حافظه: $e\n$s');
    }
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _plans.map((k, v) => MapEntry(k, v.map((a) => a.toJson()).toList()));
      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (e, s) {
      debugPrint('SmartScenarioMemory: خطا در ذخیرهٔ حافظه: $e\n$s');
    }
  }

  List<SmartAction>? get(String fingerprint) => _plans[fingerprint];

  Future<void> remember(String fingerprint, List<SmartAction> actions) async {
    await load();
    _plans[fingerprint] = actions;
    await _save();
  }

  @visibleForTesting
  void reset() {
    _plans = {};
    _loaded = false;
  }
}

/// دستیار هوشمند سناریو.
///
/// گردش کار:
/// 1. **هوش آنلاین فکر می‌کند** (وقتی کلید تنظیم شده باشد): با یک prompt ساختارمند
///    از هوش آنلاین یک «برنامهٔ اقدام» می‌گیرد.
/// 2. **دستیار محلی اجرا می‌کند**: هر اقدام را مستقیم روی ریپازیتوری‌ها اعمال می‌کند
///    (کار/قرار می‌سازد، موجودی را تنظیم می‌کند، هدف کاری روزانه را محاسبه می‌کند).
/// 3. **یادگیری**: برنامهٔ تولیدشده را با «اثر انگشت» سناریو ذخیره می‌کند؛
///    سناریوهای مشابه دفعهٔ بعد خودش انجام می‌شوند و دیگر هوش آنلاین صدا زده نمی‌شود.
class SmartPlannerAgent {
  SmartPlannerAgent({this.onlineBackend, SmartScenarioMemory? memory})
      : memory = memory ?? SmartScenarioMemory.instance;

  final LlmBackend? onlineBackend;
  final SmartScenarioMemory memory;

  Future<SmartPlanResult> handle({
    required String rawText,
    required TaskRepository taskRepository,
    required FinanceRepository financeRepository,
    required WorkProfile workProfile,
  }) async {
    await memory.load();
    final normalized = PersianFormat.englishDigits(rawText.trim());

    // اثر انگشت سناریو — برای تشخیص سناریوهای مشابه
    final fingerprint = _fingerprint(normalized);

    // 1) سناریوی مشابه یادگرفته‌شده → خودش اجرا کن (بدون هوش آنلاین)
    final learned = memory.get(fingerprint);
    if (learned != null) {
      final executed = await _execute(learned, taskRepository, financeRepository,
          amount: _extractTarget(normalized));
      return SmartPlanResult(
        message: _buildMessage(normalized, executed),
        actions: executed,
        reused: true,
      );
    }

    // 2) آیا این یک «سناریوی برنامه‌ریزی هوشمند» است یا یک فرمان ساده؟
    final isScenario = _isScenario(normalized);
    if (!isScenario) {
      return const SmartPlanResult(
        message: '',
        actions: [],
        reused: false,
      );
    }

    // 3) همیشه برنامهٔ محلی را می‌سازیم (منبع معتبر و قابل‌اتکا).
    final localPlan = _localPlan(normalized, workProfile);

    // 4) هوش آنلاین (اختیاری، وقتی کلید باشد) می‌تواند برنامه را تکمیل کند.
    List<SmartAction> onlinePlan = const [];
    if (FeatureFlags.enableOnlineAi && onlineBackend != null) {
      onlinePlan = await _askOnlineForPlan(normalized);
    }

    // 5) ادغام: اقدامات اصلی (قرار/موجودی/هدف کاری) همیشه از برنامهٔ محلی می‌آیند
    //    تا صرف‌نظر از خروجی هوش آنلاین، به‌درستی اجرا شوند. هوش آنلاین فقط
    //    می‌تواند عنوان‌ها یا رویدادهای اضافه ارائه دهد.
    final plan = _mergePlans(localPlan, onlinePlan);

    // 6) اجرای محلی اقدامات
    final executed = await _execute(plan, taskRepository, financeRepository,
        amount: _extractTarget(normalized));

    // 6) یادگیری — ذخیرهٔ برنامه برای سناریوهای مشابه آینده
    await memory.remember(fingerprint, executed);

    return SmartPlanResult(
      message: _buildMessage(normalized, executed),
      actions: executed,
      reused: false,
    );
  }

  // ---------- تشخیص سناریو ----------

  bool _isScenario(String text) {
    // سناریوی «هدف مالی + تاریخ» مثل: «من یک میلیون پول دارم و هفته دیگه باید برم بیرون»
    final hasTarget = _extractTarget(text) > 0;
    final hasDateWord =
        text.contains('هفته') || text.contains('فردا') || text.contains('ماه');
    final hasEvent = text.contains('برم') ||
        text.contains('قرار') ||
        text.contains('بیرون') ||
        text.contains('دوست') ||
        text.contains('مهمونی') ||
        text.contains('مهمانی');
    // سناریو هم با هدف مالی و هم با یک قرارِ زمان‌دار (بدون مبلغ) صادق است.
    return (hasTarget && (hasDateWord || hasEvent)) || (hasEvent && hasDateWord);
  }

  String _fingerprint(String text) {
    final target = _extractTarget(text);
    String scale;
    if (target >= 1000000000) {
      scale = '1e9';
    } else if (target >= 1000000) {
      scale = '1e6';
    } else if (target >= 1000) {
      scale = '1e3';
    } else {
      scale = 'x';
    }
    final hasDate =
        text.contains('هفته') || text.contains('فردا') || text.contains('ماه');
    final hasEvent =
        text.contains('برم') || text.contains('قرار') || text.contains('بیرون');
    return 'scenario:$scale:date:$hasDate:event:$hasEvent';
  }

  int _extractTarget(String text) {
    // فقط اگر «پول دارم/دارم/می‌خوام» یا خود مبلغ هدف باشد
    final amt = VoiceNlu.parseAmount(text);
    return amt;
  }

  // ---------- برنامهٔ محلی ----------

  List<SmartAction> _localPlan(String text, WorkProfile profile) {
    final actions = <SmartAction>[];
    final target = _extractTarget(text);
    final dueAt = VoiceNlu.guessDueAt(text) ?? DateTime.now().add(const Duration(days: 7));

    // ۱) رویداد/قرار — «هفته دیگه باید با دوست برم بیرون»
    final eventTitle = _detectEventTitle(text);
    if (eventTitle != null) {
      actions.add(SmartAction(
        type: 'event',
        title: eventTitle,
        dueAt: dueAt,
        message: 'قرار «$eventTitle» برای ${PersianFormat.jalaliLong(dueAt)} زمان‌بندی شد.',
      ));
    }

    // ۲) رساندن موجودی به هدف — «اگر خالی بود یک میلیون افزایش بده»
    if (target > 0) {
      actions.add(SmartAction(
        type: 'topup',
        amount: target,
        message: 'هدف مالی: ${PersianFormat.money(target)}.',
      ));
    }

    // ۳) محاسبهٔ هدف کاری روزانه تا مهلت
    if (target > 0) {
      actions.add(SmartAction(
        type: 'work_target',
        amount: target,
        dueAt: dueAt,
        message: _workTargetMessage(target, dueAt, profile),
      ));
    }

    return actions;
  }

  /// ادغام برنامهٔ محلی (معتبر) با برنامهٔ آنلاین (تکمیلی).
  ///
  /// اقدامات اصلی (قرار، موجودی، هدف کاری) از برنامهٔ محلی می‌آیند تا هرگز
  /// از بین نروند. رویدادها/توصیه‌های اضافه از هوش آنلاین هم اضافه می‌شوند.
  List<SmartAction> _mergePlans(
      List<SmartAction> local, List<SmartAction> online) {
    if (online.isEmpty) return local;

    final merged = <SmartAction>[...local];
    final localTitles = local.map((a) => a.title).toSet();

    for (final a in online) {
      // اگر از نوع اصلی است (topup/work_target) نادیده بگیر — محلی معتبرتر است.
      if (a.type == 'topup' || a.type == 'work_target') continue;
      // رویداد/توصیهٔ تکراری اضافه نکن.
      if (a.type == 'event' && localTitles.contains(a.title)) continue;
      merged.add(a);
    }
    return merged;
  }

  String? _detectEventTitle(String text) {
    if (text.contains('دوست دختر')) {
      return 'قرار با دوست دختر';
    }
    if (text.contains('دوست')) {
      return 'قرار با دوست';
    }
    if (text.contains('قرار')) return 'قرار';
    if (text.contains('بیرون')) return 'برنامهٔ بیرون';
    if (text.contains('مهمونی') || text.contains('مهمانی')) return 'مهمانی';
    if (text.contains('سفارت') || text.contains('اداره')) return 'کار اداری';
    return null;
  }

  String _workTargetMessage(int target, DateTime dueAt, WorkProfile profile) {
    final now = DateTime.now();
    // تعداد روزهای واقعیِ باقی‌مانده (به‌سطح کامل روز گرد شود).
    var days = (dueAt.difference(now).inMinutes / (24 * 60)).ceil();
    if (days < 1) days = 1;

    final hourlyRate = profile.avgHourlyRate > 0 ? profile.avgHourlyRate : 100000.0;
    final perDay = (target / days).round();
    final minutes = (perDay / hourlyRate * 60).round();

    final b = StringBuffer();
    b.writeln('تا ${PersianFormat.jalaliLong(dueAt)} (${PersianFormat.digits(days)} روز دیگر)، برای رسیدن به ${PersianFormat.money(target)}:');
    b.writeln('• روزی ${PersianFormat.money(perDay)} درآمد لازم است.');
    b.writeln('• با نرخ ${PersianFormat.money(hourlyRate.round())} در ساعت، روزی حدود ${PersianFormat.digits(minutes)} دقیقه کار لازم است.');
    if (!profile.hasEnoughData) {
      b.writeln('(نرخ از مقدار پیش‌فرض ۱۰۰ هزار تومان بر ساعت برآورد شد؛ با ثبت درآمدهای واقعی دقیق‌تر می‌شود.)');
    }
    return b.toString();
  }

  // ---------- هوش آنلاین فکر می‌کند ----------

  Future<List<SmartAction>> _askOnlineForPlan(String text) async {
    final backend = onlineBackend;
    if (backend == null) return const [];
    final ok = await backend.available;
    if (!ok) return const [];

    final target = _extractTarget(text);
    final dueAt = VoiceNlu.guessDueAt(text) ?? DateTime.now().add(const Duration(days: 7));
    final prompt =
        'تو یک دستیار برنامه‌ریزی هوشمند فارسی هستی. کاربر این خواسته را دارد:\n'
        '«$text»\n'
        'یک برنامهٔ اقدام به‌صورت JSON (فقط آرایه‌ای از اشیاء) برگردان. هر شیء می‌تواند یکی از این نوع‌ها باشد:\n'
        '1. {"type":"event","title":"عنوان قرار","dueAt":"ISO date"} — برای زمان‌بندی یک قرار/رویداد\n'
        '2. {"type":"topup","amount":<عدد>} — برای رساندن موجودی به هدف مالی\n'
        '3. {"type":"work_target","amount":<عدد>,"dueAt":"ISO date"} — برای محاسبهٔ هدف کاری روزانه\n'
        '4. {"type":"advice","message":"توصیه"} — برای یک توصیه\n'
        'فقط JSON برگردان، بدون توضیح اضافه. مبلغ هدف ≈ $target و تاریخ مهلت ≈ ${dueAt.toIso8601String()}.';

    try {
      final raw = await backend.generate(prompt);
      final parsed = _parsePlanJson(raw);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      return const [];
    }
    return const [];
  }

  List<SmartAction> _parsePlanJson(String raw) {
    // JSON را با حذف چارچوب markdown و متن اضافی استخراج کن
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    try {
      final list = jsonDecode(cleaned.substring(start, end + 1)) as List;
      final actions = <SmartAction>[];
      for (final e in list) {
        if (e is Map) {
          actions.add(SmartAction.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return actions;
    } catch (_) {
      return const [];
    }
  }

  // ---------- اجرای محلی ----------

  Future<List<SmartAction>> _execute(
    List<SmartAction> plan,
    TaskRepository taskRepository,
    FinanceRepository financeRepository, {
    int amount = 0,
  }) async {
    final done = <SmartAction>[];
    final balance = financeRepository.net();

    for (final a in plan) {
      switch (a.type) {
        case 'event':
          await taskRepository.add(Task(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: a.title.isEmpty ? 'قرار' : a.title,
            createdAt: DateTime.now(),
            dueAt: a.dueAt,
            importance: 4,
            category: 'قرار',
            estimatedMinutes: 120,
          ));
          done.add(a);
          break;

        case 'task':
          await taskRepository.add(Task(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: a.title,
            createdAt: DateTime.now(),
            dueAt: a.dueAt,
            importance: 3,
          ));
          done.add(a);
          break;

        case 'topup':
          final target = amount > 0 ? amount : a.amount;
          if (balance < target) {
            final diff = target - balance;
            await financeRepository.add(FinanceTransaction(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: FinanceTransactionType.income,
              amount: diff,
              createdAt: DateTime.now(),
              note: 'تنظیم خودکار موجودی به هدف',
              category: 'تسویه',
            ));
            done.add(SmartAction(
              type: 'advice',
              title: a.title,
              message: 'موجودی خالی بود؛ ${PersianFormat.money(diff)} به حساب اضافه شد تا به ${PersianFormat.money(target)} برسد.',
            ));
          } else {
            done.add(SmartAction(
              type: 'advice',
              title: a.title,
              message: 'موجودی فعلی (${PersianFormat.money(balance)}) از هدف (${PersianFormat.money(target)}) کمتر نیست؛ نیازی به افزایش نیست.',
            ));
          }
          break;

        case 'work_target':
          done.add(SmartAction(
            type: 'advice',
            title: a.title,
            amount: a.amount,
            dueAt: a.dueAt,
            message: a.message,
          ));
          break;

        default:
          done.add(a);
      }
    }
    return done;
  }

  String _buildMessage(String text, List<SmartAction> actions) {
    if (actions.isEmpty) {
      return 'این یک سناریوی برنامه‌ریزی بود ولی اقدام قابل‌اجرایی تشخیص داده نشد.';
    }
    final b = StringBuffer()..writeln('🤖 برنامهٔ هوشمند اجرا شد:');
    for (final a in actions) {
      if (a.message.isNotEmpty) b.writeln('• ${a.message}');
    }
    return b.toString();
  }
}
