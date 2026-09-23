import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/cloud_budget_store.dart';
import 'budget_item.dart';
import 'budget_repository.dart';

class BudgetService extends ChangeNotifier {
  BudgetService(this._repository,{this.cloud});
  final BudgetRepository _repository; final CloudBudgetStore? cloud;
  List<BudgetItem> _items=[];List<String> _history=[];late DateTime _cycleMonth;
  Timer? _syncTimer; bool _syncing=false; bool _online=true;
  List<BudgetItem> get dueItems=>_items.where((e)=>!e.deleted&&!e.paid).toList();
  List<BudgetItem> get paidItems=>_items.where((e)=>!e.deleted&&e.paid).toList();
  List<String> get history=>List.unmodifiable(_history);
  String get monthTitle=>DateFormat('MMMM yyyy').format(_cycleMonth);
  double get dueTotal=>dueItems.fold(0,(s,e)=>s+e.amount);
  double get paidTotal=>paidItems.fold(0,(s,e)=>s+e.amount);
  bool get cloudEnabled=>cloud?.user!=null; bool get online=>_online;

  static const _seed=<BudgetItem>[
    BudgetItem(id:'rent',name:'Rent',amount:4000,note:'Aug'),BudgetItem(id:'groceries',name:'Groceries',amount:2000),
    BudgetItem(id:'rain',name:'Rain wifi',amount:1000,note:'Aug'),BudgetItem(id:'mom',name:'Mom ',amount:2000,note:'Aug'),
    BudgetItem(id:'funeral',name:'Standard funeral policy',amount:800,note:'Aug'),BudgetItem(id:'momentum',name:'Momentum life insurance ',amount:300,note:'Aug'),
    BudgetItem(id:'capfin',name:'Capfin',amount:1200,note:'Aug'),BudgetItem(id:'vodacom',name:'Vodacom wifi',amount:1600),
    BudgetItem(id:'chatgpt',name:'Chatgpt',amount:200,note:'Aug'),BudgetItem(id:'office',name:'Office Days',amount:300,note:'Aug'),
    BudgetItem(id:'youtube',name:'YouTube ',amount:100,note:'Aug'),BudgetItem(id:'browser',name:'Browser',amount:100,note:'Aug'),
    BudgetItem(id:'apple',name:'Apple music',amount:70,note:'Aug'),BudgetItem(id:'cash',name:'Cash crusaders ',amount:3500,note:'Aug'),
    BudgetItem(id:'crunchy',name:'Crunchyroll',amount:50,note:'Aug'),BudgetItem(id:'netflix',name:'Netflix ',amount:100,note:'Aug'),
    BudgetItem(id:'ezviz',name:'EzViz',amount:200,note:'Aug'),BudgetItem(id:'water',name:'Water',amount:400),BudgetItem(id:'mbali',name:'Mbali',amount:1000),
  ];
  DateTime _cycleFor(DateTime n)=>n.day>=22?DateTime(n.year,n.month+1):DateTime(n.year,n.month);
  String _key(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}';
  DateTime _stamp(BudgetItem i)=>i.updatedAt??DateTime.fromMillisecondsSinceEpoch(0,isUtc:true);

  Future<void> initialize() async{
    _cycleMonth=_cycleFor(DateTime.now());final current=_key(_cycleMonth),stored=await _repository.loadCycleKey();
    _items=await _repository.loadItems()??List.of(_seed);_history=await _repository.loadHistory();
    if(stored!=null&&stored!=current){await syncNow();await _archive(stored,_items);final now=DateTime.now().toUtc();_items=_items.where((e)=>!e.deleted).map((e)=>e.copyWith(paid:false,updatedAt:now)).toList();}
    await _saveLocal();await syncNow();
    _syncTimer=Timer.periodic(const Duration(seconds:20),(_)=>syncNow());
    notifyListeners();
  }

  Future<void> syncNow() async{
    if(!cloudEnabled||_syncing)return;_syncing=true;
    try{
      final cycle=_key(_cycleMonth);final remote=await cloud!.loadMonth(cycle);
      if(remote==null){await cloud!.upsertItems(cycle,_items);}
      else{
        final merged=<String,BudgetItem>{for(final i in _items)i.id:i};
        for(final r in remote){final l=merged[r.id];if(l==null||_stamp(r).isAfter(_stamp(l)))merged[r.id]=r;}
        final localById={for(final i in _items)i.id:i};
        final upload=<BudgetItem>[];
        for(final m in merged.values){final r=remote.where((x)=>x.id==m.id).firstOrNull;if(r==null||_stamp(m).isAfter(_stamp(r)))upload.add(m);}
        if(upload.isNotEmpty)await cloud!.upsertItems(cycle,upload);
        _items=merged.values.toList();
      }
      _history=await cloud!.loadHistoryText();await _saveLocal();_online=true;
    }catch(_){_online=false;}finally{_syncing=false;notifyListeners();}
  }

  Future<void> _archive(String cycle,List<BudgetItem> items) async{
    final live=items.where((e)=>!e.deleted).toList();final total=live.fold<double>(0,(s,e)=>s+e.amount),paid=live.where((e)=>e.paid).fold<double>(0,(s,e)=>s+e.amount);
    final b=StringBuffer()..writeln('Budget history: $cycle')..writeln('--------------------------------');
    for(final i in live){b.writeln('${i.paid?'[PAID]':'[DUE]'} ${i.name}\tR${i.amount.toStringAsFixed(2)}\t${i.note}');}
    b..writeln('Paid: R${paid.toStringAsFixed(2)}')..writeln('Outstanding: R${(total-paid).toStringAsFixed(2)}')..writeln('Total: R${total.toStringAsFixed(2)}')..writeln();
    if(!_history.any((h)=>h.startsWith('Budget history: $cycle'))){_history.add(b.toString());await _repository.saveHistory(_history);}
    try{if(cloudEnabled)await cloud!.archiveMonth(cycle,live);}catch(_){_online=false;}
  }

  Future<void> togglePaid(BudgetItem item,bool paid) async{final now=DateTime.now().toUtc();_items=_items.map((e)=>e.id==item.id?e.copyWith(paid:paid,updatedAt:now):e).toList();await _saveLocal();notifyListeners();unawaited(syncNow());}
  Future<void> addItem(String name,double amount,String note) async{_items.add(BudgetItem(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,amount:amount,note:note,updatedAt:DateTime.now().toUtc()));await _saveLocal();notifyListeners();unawaited(syncNow());}
  Future<void> deleteItem(BudgetItem item) async{final now=DateTime.now().toUtc();_items=_items.map((e)=>e.id==item.id?e.copyWith(deleted:true,updatedAt:now):e).toList();await _saveLocal();notifyListeners();unawaited(syncNow());}
  Future<void> refreshFromCloud()=>syncNow();
  Future<void> _saveLocal() async{await _repository.saveItems(_items);await _repository.saveCycleKey(_key(_cycleMonth));await _repository.saveHistory(_history);}
  @override void dispose(){_syncTimer?.cancel();super.dispose();}
}
