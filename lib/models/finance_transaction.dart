enum FinanceTransactionType { income, expense }

extension FinanceTransactionTypeLabel on FinanceTransactionType {
  String get faLabel {
    switch (this) {
      case FinanceTransactionType.income:
        return 'درآمد';
      case FinanceTransactionType.expense:
        return 'هزینه';
    }
  }
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.note = '',
    this.category = 'عمومی',
    this.taskId,
    this.minutesWorked,
    this.currency = 'تومان',
  });

  final String id;
  final FinanceTransactionType type;

  /// مبلغ مثبت ذخیره می‌شود؛ نوع تراکنش تعیین می‌کند درآمد است یا هزینه.
  final int amount;
  final DateTime createdAt;
  final String note;
  final String category;
  final String? taskId;
  final int? minutesWorked;
  final String currency;

  int get signedAmount => type == FinanceTransactionType.income ? amount : -amount;

  double? get hourlyRate {
    final minutes = minutesWorked;
    if (type != FinanceTransactionType.income || minutes == null || minutes <= 0) return null;
    return amount / minutes * 60;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'category': category,
        'taskId': taskId,
        'minutesWorked': minutesWorked,
        'currency': currency,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      type: FinanceTransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FinanceTransactionType.income,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String? ?? '',
      category: json['category'] as String? ?? 'عمومی',
      taskId: json['taskId'] as String?,
      minutesWorked: (json['minutesWorked'] as num?)?.toInt(),
      currency: json['currency'] as String? ?? 'تومان',
    );
  }
}
