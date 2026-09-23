import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'budget_item.dart';
import 'budget_repository.dart';

class BudgetService extends ChangeNotifier {
  BudgetService(this._repository);
  final BudgetRepository _repository;

  List<BudgetItem> _items = [];
  List<String> _history = [];
  late DateTime _cycleMonth;

  List<BudgetItem> get dueItems => _items.where((e) => !e.paid).toList();
  List<BudgetItem> get paidItems => _items.where((e) => e.paid).toList();
  List<String> get history => List.unmodifiable(_history);
  String get monthTitle => DateFormat('MMMM yyyy').format(_cycleMonth);
  double get dueTotal => dueItems.fold(0, (sum, e) => sum + e.amount);
  double get paidTotal => paidItems.fold(0, (sum, e) => sum + e.amount);

  static const _seed = <BudgetItem>[
    BudgetItem(id:'rent', name:'Rent', amount:4000, note:'Aug'),
    BudgetItem(id:'groceries', name:'Groceries', amount:2000),
    BudgetItem(id:'rain', name:'Rain wifi', amount:1000, note:'Aug'),
    BudgetItem(id:'mom', name:'Mom ', amount:2000, note:'Aug'),
    BudgetItem(id:'funeral', name:'Standard funeral policy', amount:800, note:'Aug'),
    BudgetItem(id:'momentum', name:'Momentum life insurance ', amount:300, note:'Aug'),
    BudgetItem(id:'capfin', name:'Capfin', amount:1200, note:'Aug'),
    BudgetItem(id:'vodacom', name:'Vodacom wifi', amount:1600),
    BudgetItem(id:'chatgpt', name:'Chatgpt', amount:200, note:'Aug'),
    BudgetItem(id:'office', name:'Office Days', amount:300, note:'Aug'),
    BudgetItem(id:'youtube', name:'YouTube ', amount:100, note:'Aug'),
    BudgetItem(id:'browser', name:'Browser', amount:100, note:'Aug'),
    BudgetItem(id:'apple', name:'Apple music', amount:70, note:'Aug'),
    BudgetItem(id:'cash', name:'Cash crusaders ', amount:3500, note:'Aug'),
    BudgetItem(id:'crunchy', name:'Crunchyroll', amount:50, note:'Aug'),
    BudgetItem(id:'netflix', name:'Netflix ', amount:100, note:'Aug'),
    BudgetItem(id:'ezviz', name:'EzViz', amount:200, note:'Aug'),
    BudgetItem(id:'water', name:'Water', amount:400),
    BudgetItem(id:'mbali', name:'Mbali', amount:1000),
  ];

  DateTime _cycleFor(DateTime now) =>
      now.day >= 22 ? DateTime(now.year, now.month + 1) : DateTime(now.year, now.month);

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}';

  Future<void> initialize() async {
    final now = DateTime.now();
    _cycleMonth = _cycleFor(now);
    _items = await _repository.loadItems() ?? List.of(_seed);
    _history = await _repository.loadHistory();
    final storedCycle = await _repository.loadCycleKey();
    if (storedCycle != null && storedCycle != _key(_cycleMonth)) {
      _archive(storedCycle);
      _items = _items.map((e) => e.copyWith(paid:false)).toList();
      await _repository.saveHistory(_history);
    }
    await _persist();
  }

  void _archive(String cycle) {
    final buffer = StringBuffer()
      ..writeln('Budget history: $cycle')
      ..writeln('--------------------------------');
    for (final item in _items) {
      buffer.writeln('${item.paid ? "[PAID]" : "[DUE]"} ${item.name}\tR${item.amount.toStringAsFixed(2)}\t${item.note}');
    }
    buffer
      ..writeln('Total: R${_items.fold<double>(0,(s,e)=>s+e.amount).toStringAsFixed(2)}')
      ..writeln();
    _history.add(buffer.toString());
  }

  Future<void> togglePaid(BudgetItem item, bool paid) async {
    _items = _items.map((e) => e.id == item.id ? e.copyWith(paid: paid) : e).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addItem(String name, double amount, String note) async {
    _items.add(BudgetItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      note: note,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> deleteItem(BudgetItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _repository.saveItems(_items);
    await _repository.saveCycleKey(_key(_cycleMonth));
  }
}
