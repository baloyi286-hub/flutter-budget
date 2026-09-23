import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/cloud_budget_store.dart';
import 'budget_item.dart';
import 'budget_repository.dart';

class BudgetService extends ChangeNotifier {
  BudgetService(this._repository,{this.cloud});
  final BudgetRepository _repository;
  final CloudBudgetStore? cloud;
  List<BudgetItem> _items=[]; List<String> _history=[]; late DateTime _cycleMonth;
  List<BudgetItem> get dueItems=>_items.where((e)=>!e.paid).toList();
  List<BudgetItem> get paidItems=>_items.where((e)=>e.paid).toList();
  List<String> get history=>List.unmodifiable(_history);
  String get monthTitle=>DateFormat('MMMM yyyy').format(_cycleMonth);
  double get dueTotal=>dueItems.fold(0,(s,e)=>s+e.amount);
  double get paidTotal=>paidItems.fold(0,(s,e)=>s+e.amount);
  bool get cloudEnabled=>cloud?.user!=null;

  static const _seed=<BudgetItem>[
    BudgetItem(id:'rent',name:'Rent',amount:4000,note:'Aug'), BudgetItem(id:'groceries',name:'Groceries',amount:2000),
    BudgetItem(id:'rain',name:'Rain wifi',amount:1000,note:'Aug'), BudgetItem(id:'mom',name:'Mom ',amount:2000,note:'Aug'),
    BudgetItem(id:'funeral',name:'Standard funeral policy',amount:800,note:'Aug'), BudgetItem(id:'momentum',name:'Momentum life insurance ',amount:300,note:'Aug'),
    BudgetItem(id:'capfin',name:'Capfin',amount:1200,note:'Aug'), BudgetItem(id:'vodacom',name:'Vodacom wifi',amount:1600),
    BudgetItem(id:'chatgpt',name:'Chatgpt',amount:200,note:'Aug'), BudgetItem(id:'office',name:'Office Days',amount:300,note:'Aug'),
    BudgetItem(id:'youtube',name:'YouTube ',amount:100,note:'Aug'), BudgetItem(id:'browser',name:'Browser',amount:100,note:'Aug'),
    BudgetItem(id:'apple',name:'Apple music',amount:70,note:'Aug'), BudgetItem(id:'cash',name:'Cash crusaders ',amount:3500,note:'Aug'),
    BudgetItem(id:'crunchy',name:'Crunchyroll',amount:50,note:'Aug'), BudgetItem(id:'netflix',name:'Netflix ',amount:100,note:'Aug'),
    BudgetItem(id:'ezviz',name:'EzViz',amount:200,note:'Aug'), BudgetItem(id:'water',name:'Water',amount:400), BudgetItem(id:'mbali',name:'Mbali',amount:1000),
  ];
  DateTime _cycleFor(DateTime n)=>n.day>=22?DateTime(n.year,n.month+1):DateTime(n.year,n.month);
  String _key(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}';

  Future<void> initialize() async {
    _cycleMonth=_cycleFor(DateTime.now());
    final current=_key(_cycleMonth), stored=await _repository.loadCycleKey();
    _items=await _repository.loadItems()??List.of(_seed);
    _history=await _repository.loadHistory();
    if(stored!=null&&stored!=current){
      await _archive(stored,_items);
      _items=_items.map((e)=>e.copyWith(paid:false)).toList();
    }
    if(cloudEnabled){
      final remote=await cloud!.loadMonth(current);
      if(remote!=null){_items=remote;} else {await cloud!.saveMonth(current,_items);}
      final remoteHistory=await cloud!.loadHistoryText();
      if(remoteHistory.isNotEmpty){_history=remoteHistory;}
    }
    await _persist(); notifyListeners();
  }

  Future<void> _archive(String cycle,List<BudgetItem> items) async {
    final b=StringBuffer()..writeln('Budget history: $cycle')..writeln('--------------------------------');
    for(final i in items){b.writeln('${i.paid?'[PAID]':'[DUE]'} ${i.name}\tR${i.amount.toStringAsFixed(2)}\t${i.note}');}
    final total=items.fold<double>(0,(s,e)=>s+e.amount), paid=items.where((e)=>e.paid).fold<double>(0,(s,e)=>s+e.amount);
    b..writeln('Paid: R${paid.toStringAsFixed(2)}')..writeln('Outstanding: R${(total-paid).toStringAsFixed(2)}')..writeln('Total: R${total.toStringAsFixed(2)}')..writeln();
    if(!_history.any((h)=>h.startsWith('Budget history: $cycle'))){_history.add(b.toString());await _repository.saveHistory(_history);}
    if(cloudEnabled){await cloud!.archiveMonth(cycle,items);}
  }

  Future<void> togglePaid(BudgetItem item,bool paid) async{_items=_items.map((e)=>e.id==item.id?e.copyWith(paid:paid):e).toList();await _persist();notifyListeners();}
  Future<void> addItem(String name,double amount,String note) async{_items.add(BudgetItem(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,amount:amount,note:note));await _persist();notifyListeners();}
  Future<void> deleteItem(BudgetItem item) async{_items.removeWhere((e)=>e.id==item.id);await _persist();notifyListeners();}
  Future<void> refreshFromCloud() async{if(!cloudEnabled)return;final remote=await cloud!.loadMonth(_key(_cycleMonth));if(remote!=null)_items=remote!;_history=await cloud!.loadHistoryText();await _repository.saveItems(_items);await _repository.saveHistory(_history);notifyListeners();}
  Future<void> _persist() async{final key=_key(_cycleMonth);await _repository.saveItems(_items);await _repository.saveCycleKey(key);if(cloudEnabled)await cloud!.saveMonth(key,_items);}
}
