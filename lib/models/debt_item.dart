enum DebtType { debt, receivable }

enum DebtStatus { active, settled, cancelled }

extension DebtTypeLabel on DebtType {
  String get faLabel {
    switch (this) {
      case DebtType.debt:
        return 'بدهی';
      case DebtType.receivable:
        return 'طلب';
    }
  }
}

class DebtItem {
  const DebtItem({
    required this.id,
    required this.type,
    required this.personName,
    required this.amount,
    required this.dueAt,
    required this.createdAt,
    this.paidAmount = 0,
    this.status = DebtStatus.active,
    this.notes = '',
  });

  final String id;
  final DebtType type;
  final String personName;
  final int amount;
  final DateTime dueAt;
  final DateTime createdAt;
  final int paidAmount;
  final DebtStatus status;
  final String notes;

  bool get isActive => status == DebtStatus.active;
  int get remainingAmount => (amount - paidAmount).clamp(0, amount).toInt();

  DebtItem copyWith({
    String? id,
    DebtType? type,
    String? personName,
    int? amount,
    DateTime? dueAt,
    DateTime? createdAt,
    int? paidAmount,
    DebtStatus? status,
    String? notes,
  }) {
    return DebtItem(
      id: id ?? this.id,
      type: type ?? this.type,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'personName': personName,
        'amount': amount,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'paidAmount': paidAmount,
        'status': status.name,
        'notes': notes,
      };

  factory DebtItem.fromJson(Map<String, dynamic> json) {
    return DebtItem(
      id: json['id'] as String,
      type: DebtType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DebtType.debt,
      ),
      personName: json['personName'] as String? ?? 'نامشخص',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      paidAmount: (json['paidAmount'] as num?)?.toInt() ?? 0,
      status: DebtStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DebtStatus.active,
      ),
      notes: json['notes'] as String? ?? '',
    );
  }
}
