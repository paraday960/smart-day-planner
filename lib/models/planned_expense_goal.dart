enum PlannedExpenseStatus { active, done, cancelled }

class PlannedExpenseGoal {
  const PlannedExpenseGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.dueAt,
    required this.createdAt,
    this.status = PlannedExpenseStatus.active,
    this.notes = '',
  });

  final String id;
  final String title;
  final int targetAmount;
  final DateTime dueAt;
  final DateTime createdAt;
  final PlannedExpenseStatus status;
  final String notes;

  bool get isActive => status == PlannedExpenseStatus.active;

  PlannedExpenseGoal copyWith({
    String? id,
    String? title,
    int? targetAmount,
    DateTime? dueAt,
    DateTime? createdAt,
    PlannedExpenseStatus? status,
    String? notes,
  }) {
    return PlannedExpenseGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'notes': notes,
      };

  factory PlannedExpenseGoal.fromJson(Map<String, dynamic> json) {
    return PlannedExpenseGoal(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'هزینه برنامه‌ریزی‌شده',
      targetAmount: (json['targetAmount'] as num?)?.toInt() ?? 0,
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: PlannedExpenseStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PlannedExpenseStatus.active,
      ),
      notes: json['notes'] as String? ?? '',
    );
  }
}
