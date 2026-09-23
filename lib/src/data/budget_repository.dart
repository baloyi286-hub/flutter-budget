import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/budget_item.dart';
import '../domain/budget_repository.dart';

class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository(this._prefs,this.userId);
  final SharedPreferences _prefs;
  final String userId;
  String get _itemsKey=>'budget_items_v2_$userId';
  String get _cycleKey=>'budget_cycle_v2_$userId';
  String get _historyKey=>'budget_history_v2_$userId';

  @override Future<List<BudgetItem>?> loadItems() async{
    final raw=_prefs.getString(_itemsKey);if(raw==null)return null;
    return (jsonDecode(raw) as List<dynamic>).map((e)=>BudgetItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
  }
  @override Future<void> saveItems(List<BudgetItem> items)=>_prefs.setString(_itemsKey,jsonEncode(items.map((e)=>e.toJson()).toList()));
  @override Future<String?> loadCycleKey() async=>_prefs.getString(_cycleKey);
  @override Future<void> saveCycleKey(String key)=>_prefs.setString(_cycleKey,key);
  @override Future<List<String>> loadHistory() async=>_prefs.getStringList(_historyKey)??<String>[];
  @override Future<void> saveHistory(List<String> history)=>_prefs.setStringList(_historyKey,history);
}
