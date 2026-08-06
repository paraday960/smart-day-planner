import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../models/category_budget.dart';
import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/money_allocation.dart';
import '../models/planned_expense_goal.dart';
import '../models/task.dart';

class BackupService {
  const BackupService();

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

    final plain = jsonEncode(payload);
    final key = _keyFromPassphrase(passphrase);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);

    return jsonEncode({
      'type': 'smart_day_planner_encrypted_backup',
      'version': 1,
      'iv': iv.base64,
      'data': encrypted.base64,
    });
  }

  RestoredBackup restoreEncryptedBackup({required String encryptedBackup, required String passphrase}) {
    final wrapper = jsonDecode(encryptedBackup.trim()) as Map<String, dynamic>;
    if (wrapper['type'] != 'smart_day_planner_encrypted_backup') {
      throw ArgumentError('فرمت بکاپ معتبر نیست.');
    }

    final key = _keyFromPassphrase(passphrase);
    final iv = enc.IV.fromBase64(wrapper['iv'] as String);
    final encrypted = enc.Encrypted.fromBase64(wrapper['data'] as String);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final plain = encrypter.decrypt(encrypted, iv: iv);
    final payload = jsonDecode(plain) as Map<String, dynamic>;

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

  enc.Key _keyFromPassphrase(String passphrase) {
    final digest = sha256.convert(utf8.encode('smart_day_planner|${passphrase.trim()}')).bytes;
    return enc.Key(Uint8List.fromList(digest));
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

