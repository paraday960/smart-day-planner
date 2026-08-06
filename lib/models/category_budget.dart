class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    required this.createdAt,
  });

  final String id;
  final String category;
  final int monthlyLimit;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'monthlyLimit': monthlyLimit,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CategoryBudget.fromJson(Map<String, dynamic> json) {
    return CategoryBudget(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'عمومی',
      monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
