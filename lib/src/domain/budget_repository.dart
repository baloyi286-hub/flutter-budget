import 'budget_item.dart';

abstract interface class BudgetRepository {
  Future<List<BudgetItem>?> loadItems();
  Future<void> saveItems(List<BudgetItem> items);
  Future<String?> loadCycleKey();
  Future<void> saveCycleKey(String key);
  Future<List<String>> loadHistory();
  Future<void> saveHistory(List<String> history);
}
