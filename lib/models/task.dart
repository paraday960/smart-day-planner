enum TaskStatus { todo, done }

enum EnergyLevel { low, medium, high }

extension EnergyLevelLabel on EnergyLevel {
  String get faLabel {
    switch (this) {
      case EnergyLevel.low:
        return 'کم';
      case EnergyLevel.medium:
        return 'متوسط';
      case EnergyLevel.high:
        return 'زیاد';
    }
  }
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.category = 'عمومی',
    this.dueAt,
    this.importance = 3,
    this.energy = EnergyLevel.medium,
    this.estimatedMinutes = 30,
    this.actualMinutes,
    this.status = TaskStatus.todo,
    this.completedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String notes;
  final String category;
  final DateTime createdAt;
  final DateTime? dueAt;

  /// 1 تا 5
  final int importance;
  final EnergyLevel energy;

  /// تخمین فعلی کاربر/اپ
  final int estimatedMinutes;

  /// مدت واقعی وقتی کار کامل شد؛ برای یادگیری استفاده می‌شود.
  final int? actualMinutes;
  final TaskStatus status;
  final DateTime? completedAt;
  final bool isPinned;

  bool get isDone => status == TaskStatus.done;
  bool get isOverdue => dueAt != null && !isDone && dueAt!.isBefore(DateTime.now());

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    String? category,
    DateTime? createdAt,
    DateTime? dueAt,
    bool clearDueAt = false,
    int? importance,
    EnergyLevel? energy,
    int? estimatedMinutes,
    int? actualMinutes,
    bool clearActualMinutes = false,
    TaskStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isPinned,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      importance: importance ?? this.importance,
      energy: energy ?? this.energy,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: clearActualMinutes ? null : actualMinutes ?? this.actualMinutes,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'importance': importance,
        'energy': energy.name,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'status': status.name,
        'completedAt': completedAt?.toIso8601String(),
        'isPinned': isPinned,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      category: json['category'] as String? ?? 'عمومی',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      dueAt: json['dueAt'] == null ? null : DateTime.tryParse(json['dueAt'] as String),
      importance: (json['importance'] as num?) == null
          ? 3
          : (json['importance'] as num).toInt().clamp(1, 5).toInt(),
      energy: EnergyLevel.values.firstWhere(
        (e) => e.name == json['energy'],
        orElse: () => EnergyLevel.medium,
      ),
      estimatedMinutes: (json['estimatedMinutes'] as num?) == null
          ? 30
          : (json['estimatedMinutes'] as num).toInt().clamp(5, 24 * 60).toInt(),
      actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.todo,
      ),
      completedAt: json['completedAt'] == null ? null : DateTime.tryParse(json['completedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
