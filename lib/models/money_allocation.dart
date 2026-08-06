enum AllocationTargetType { debt, plannedExpense, free }

extension AllocationTargetTypeLabel on AllocationTargetType {
  String get faLabel {
    switch (this) {
      case AllocationTargetType.debt:
        return 'بدهی';
      case AllocationTargetType.plannedExpense:
        return 'هزینه آینده';
      case AllocationTargetType.free:
        return 'آزاد';
    }
  }
}

class MoneyAllocation {
  const MoneyAllocation({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.amount,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final AllocationTargetType targetType;
  final String targetId;
  final int amount;
  final DateTime createdAt;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetType': targetType.name,
        'targetId': targetId,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory MoneyAllocation.fromJson(Map<String, dynamic> json) {
    return MoneyAllocation(
      id: json['id'] as String,
      targetType: AllocationTargetType.values.firstWhere(
        (t) => t.name == json['targetType'],
        orElse: () => AllocationTargetType.free,
      ),
      targetId: json['targetId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String? ?? '',
    );
  }
}
