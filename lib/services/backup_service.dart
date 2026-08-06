import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/category_budget.dart';
import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/money_allocation.dart';
import '../models/planned_expense_goal.dart';
import '../models/task.dart';

/// رمزنگاری امن بکاپ با:
///  - استخراج کلید با PBKDF2-HMAC-SHA256 (نمک اختصاصی + تکرار بالا) به‌جای SHA-256 خام
///  - رمزنگاری با AES-GCM (محرمانگی + احراز اصالت) به‌جای AES-CBC بدون MAC
///
/// قبل از تغییر: کلید از sha256(prefix|passphrase) بدون نمک استخراج می‌شد و
/// AES-CBC بدون MAC استفاده می‌شد (قابلیت دستکاری بایت‌ها). الان کلید از
/// PBKDF2 با نمک تصادفی و تکرار زیاد می‌آید و GCM هم اصالت را تضمین می‌کند.
class BackupService {
  const BackupService();

  static const int _iterations = 200000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12; // 96-bit nonce استاندارد GCM

  /// [backupFormatVersion] نسخهٔ قالب بکاپ است. نسخهٔ ۲ یعنی قالب امن جدید.
  /// بکاپ‌های قدیمی (نسخهٔ ۱) دیگر قابل بازیابی نیستند.
  static const int backupFormatVersion = 2;

  String createEncryptedBackup({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    required int dailyIncomeGoal,
    required int monthlyIncomeGoal,
    required int dailyDeepWorkMinutes,
    required List<PlannedExpenseGoal> plannedExpenses,
    required List<DebtItem> debts,
    required List<MoneyAllocation> allocations,
    required List<CategoryBudget> categoryBudgets,
    required String passphrase,
  }) {
    if (passphrase.trim().length < 6) {
      throw ArgumentError('رمز بکاپ باید حداقل ۶ کاراکتر باشد.');
    }

    final payload = {
      'app': 'smart_day_planner_iranian',
      'version': 3,
      'createdAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'plannedExpenses': plannedExpenses.map((e) => e.toJson()).toList(),
      'debts': debts.map((e) => e.toJson()).toList(),
      'allocations': allocations.map((e) => e.toJson()).toList(),
      'categoryBudgets': categoryBudgets.map((e) => e.toJson()).toList(),
      'goals': {
        'dailyIncomeGoal': dailyIncomeGoal,
        'monthlyIncomeGoal': monthlyIncomeGoal,
        'dailyDeepWorkMinutes': dailyDeepWorkMinutes,
      },
    };

    final plain = utf8.encode(jsonEncode(payload));

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = _deriveKey(passphrase, salt, _iterations);

    final encrypted = _aesGcmEncrypt(key: key, nonce: nonce, plaintext: plain);

    return jsonEncode({
      'type': 'smart_day_planner_encrypted_backup',
      'format': backupFormatVersion,
      'salt': base64Encode(salt),
      'iterations': _iterations,
      'iv': base64Encode(nonce),
      'data': base64Encode(encrypted),
    });
  }

  RestoredBackup restoreEncryptedBackup({required String encryptedBackup, required String passphrase}) {
    final wrapper = jsonDecode(encryptedBackup.trim()) as Map<String, dynamic>;
    if (wrapper['type'] != 'smart_day_planner_encrypted_backup') {
      throw ArgumentError('فرمت بکاپ معتبر نیست.');
    }

    final format = (wrapper['format'] as num?)?.toInt() ?? 1;
    if (format != backupFormatVersion) {
      throw ArgumentError(
        'قالب بکاپ (نسخهٔ $format) پشتیبانی نمی‌شود. این نسخه فقط نسخهٔ $backupFormatVersion را می‌خواند.',
      );
    }

    final salt = _base64Bytes(wrapper['salt'] as String);
    final nonce = _base64Bytes(wrapper['iv'] as String);
    final encrypted = _base64Bytes(wrapper['data'] as String);
    final iterations = (wrapper['iterations'] as num?)?.toInt() ?? _iterations;
    if (iterations < 1000) {
      throw ArgumentError('بکاپ معتبر نیست: تعداد تکرار کلید خیلی کم است.');
    }

    final key = _deriveKey(passphrase, salt, iterations);

    final Uint8List plain;
    try {
      plain = _aesGcmDecrypt(key: key, nonce: nonce, ciphertext: encrypted);
    } on ArgumentError {
      rethrow;
    } catch (_) {
      // GCM در صورت اشتباه بودن رمز یا دستکاری فایل در doFinal خطا می‌دهد.
      throw ArgumentError('رمز بکاپ اشتباه است یا فایل دستکاری شده است.');
    }

    final payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;

    return RestoredBackup(
      tasks: ((payload['tasks'] as List<dynamic>?) ?? [])
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
      transactions: ((payload['transactions'] as List<dynamic>?) ?? [])
          .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      plannedExpenses: ((payload['plannedExpenses'] as List<dynamic>?) ?? [])
          .map((e) => PlannedExpenseGoal.fromJson(e as Map<String, dynamic>))
          .toList(),
      debts: ((payload['debts'] as List<dynamic>?) ?? [])
          .map((e) => DebtItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      allocations: ((payload['allocations'] as List<dynamic>?) ?? [])
          .map((e) => MoneyAllocation.fromJson(e as Map<String, dynamic>))
          .toList(),
      categoryBudgets: ((payload['categoryBudgets'] as List<dynamic>?) ?? [])
          .map((e) => CategoryBudget.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyIncomeGoal: ((payload['goals'] as Map<String, dynamic>?)?['dailyIncomeGoal'] as num?)?.toInt() ?? 0,
      monthlyIncomeGoal: ((payload['goals'] as Map<String, dynamic>?)?['monthlyIncomeGoal'] as num?)?.toInt() ?? 0,
      dailyDeepWorkMinutes: ((payload['goals'] as Map<String, dynamic>?)?['dailyDeepWorkMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  /// استخراج کلید از رمز عبور با PBKDF2-HMAC-SHA256 و نمک اختصاصی.
  Uint8List _deriveKey(String passphrase, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(utf8.encode(passphrase.trim())) as Uint8List;
  }

  /// AES-GCM با nonce ۹۶-بیت. خروجی شامل ciphertext + tag احراز اصالت است.
  Uint8List _aesGcmEncrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final out = Uint8List(cipher.getOutputSize(plaintext.length));
    final len1 = cipher.processBytes(plaintext, 0, plaintext.length, out, 0);
    final len2 = cipher.doFinal(out, len1);
    return Uint8List.sublistView(out, 0, len1 + len2);
  }

  Uint8List _aesGcmDecrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final out = Uint8List(cipher.getOutputSize(ciphertext.length));
    final len1 = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
    final len2 = cipher.doFinal(out, len1);
    return Uint8List.sublistView(out, 0, len1 + len2);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _base64Bytes(String value) {
    return Uint8List.fromList(base64Decode(value));
  }
}

class RestoredBackup {
  const RestoredBackup({
    required this.tasks,
    required this.transactions,
    required this.plannedExpenses,
    required this.debts,
    required this.allocations,
    required this.categoryBudgets,
    required this.dailyIncomeGoal,
    required this.monthlyIncomeGoal,
    required this.dailyDeepWorkMinutes,
  });

  final List<Task> tasks;
  final List<FinanceTransaction> transactions;
  final List<PlannedExpenseGoal> plannedExpenses;
  final List<DebtItem> debts;
  final List<MoneyAllocation> allocations;
  final List<CategoryBudget> categoryBudgets;
  final int dailyIncomeGoal;
  final int monthlyIncomeGoal;
  final int dailyDeepWorkMinutes;
}
