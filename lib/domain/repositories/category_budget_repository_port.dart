import '../../models/category_budget.dart';

abstract class CategoryBudgetRepositoryPort {
  List<CategoryBudget> get items;

  CategoryBudget? budgetFor(String category);
  Future<void> upsert(String category, int monthlyLimit);
  Future<void> delete(String id);
  Future<void> replaceAll(List<CategoryBudget> items);
}
