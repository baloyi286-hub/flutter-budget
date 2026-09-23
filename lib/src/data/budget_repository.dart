import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/budget_item.dart';
import '../domain/budget_repository.dart';

class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _itemsKey = 'budget_items_v1';
  static const _cycleKey = 'budget_cycle_v1';
  static const _historyKey = 'budget_history_v1';

  @override
  Future<List<BudgetItem>?> loadItems() async {
    final raw = _prefs.getString(_itemsKey);
    if (raw == null) return null;
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveItems(List<BudgetItem> items) =>
      _prefs.setString(_itemsKey, jsonEncode(items.map((e) => e.toJson()).toList()));

  @override
  Future<String?> loadCycleKey() async => _prefs.getString(_cycleKey);

  @override
  Future<void> saveCycleKey(String key) => _prefs.setString(_cycleKey, key);

  @override
  Future<List<String>> loadHistory() async =>
      _prefs.getStringList(_historyKey) ?? <String>[];

  @override
  Future<void> saveHistory(List<String> history) =>
      _prefs.setStringList(_historyKey, history);
}
