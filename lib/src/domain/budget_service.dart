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
  List<BudgetItem> get dueItems=>_sorted(_items.where((e)=>!e.deleted&&!e.paid));
  List<BudgetItem> get paidItems=>_sorted(_items.where((e)=>!e.deleted&&e.paid));
  List<BudgetItem> _sorted(Iterable<BudgetItem> items){final list=items.toList();list.sort((a,b)=>b.amount.compareTo(a.amount));return list;}
  List<BudgetItem> itemsFor(BudgetCategory category,{required bool paid})=>_sorted(_items.where((e)=>!e.deleted&&e.paid==paid&&e.category==category));
  List<String> get history=>List.unmodifiable(_history);
  String get monthTitle=>DateFormat('MMMM yyyy').format(_cycleMonth);
  DateTime get cycleMonth=>_cycleMonth;
  double get dueTotal=>dueItems.fold(0,(s,e)=>s+e.amount);
  double get paidTotal=>paidItems.fold(0,(s,e)=>s+e.amount);
  bool get cloudEnabled=>cloud?.user!=null; bool get online=>_online;

  DateTime _cycleFor(DateTime n)=>n.day>=22?DateTime(n.year,n.month+1):DateTime(n.year,n.month);
  String _key(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}';
  DateTime _stamp(BudgetItem i)=>i.updatedAt??DateTime.fromMillisecondsSinceEpoch(0,isUtc:true);

  Future<void> initialize() async{
    final target=_cycleFor(DateTime.now());
    final stored=await _repository.loadCycleKey();
    _items=await _repository.loadItems()??<BudgetItem>[];
    _history=await _repository.loadHistory();
    _cycleMonth=stored==null?target:DateTime.tryParse('$stored-01')??target;
    if(_key(_cycleMonth)!=_key(target)){
      await _prepareCycle(target,stored:stored);
    }else if(stored==null&&cloudEnabled){
      await _prepareCycle(target,stored:stored);
    }
    await _saveLocal();
    await syncNow();
    _syncTimer=Timer.periodic(const Duration(seconds:20),(_)=>syncNow());
    notifyListeners();
  }

  // Prefer an existing current cloud cycle over an older device cache.
  // Otherwise restore from the latest cloud month, never resurrecting deleted items.
  Future<void> _prepareCycle(DateTime target,{String? stored}) async{
    final targetKey=_key(target);
    if(cloudEnabled){
      try{
        final existing=await cloud!.loadMonth(targetKey);
        if(existing!=null&&existing.isNotEmpty){
          _cycleMonth=target;
          _items=existing;
          await _saveLocal();
          return;
        }
      }catch(_){_online=false;}
    }

    String? sourceKey=stored;
    if(cloudEnabled){
      for(var monthsBack=1;monthsBack<=24;monthsBack++){
        final previous=DateTime(target.year,target.month-monthsBack);
        final key=_key(previous);
        try{
          final rows=await cloud!.loadMonth(key);
          if(rows!=null&&rows.isNotEmpty){
            if(key==stored&&_items.isNotEmpty){
              await _syncCycle(key);
            }else{
              _items=rows;
            }
            sourceKey=key;
            break;
          }
        }catch(_){_online=false;break;}
      }
    }

    if(sourceKey!=null&&sourceKey!=targetKey&&_items.isNotEmpty){
      // Only archive the actual recorded month; do not invent missing-month activity.
      await _archive(sourceKey,_items);
    }
    _cycleMonth=target;
    final now=DateTime.now().toUtc();
    _items=_items.where((item)=>!item.deleted)
      .map((item)=>item.copyWith(paid:false,updatedAt:now)).toList();
    await _saveLocal();
    if(cloudEnabled){
      try{
        // Another device might have created this cycle while we were recovering.
        final existing=await cloud!.loadMonth(targetKey);
        if(existing!=null&&existing.isNotEmpty){
          _items=existing;
        }else{
          await cloud!.upsertItems(targetKey,_items);
          for(final item in _items){
            await cloud!.logEvent(targetKey,item.id,'ROLLED OVER',details:_details(item));
          }
        }
        _online=true;
        await _saveLocal();
      }catch(_){_online=false;}
    }
  }

  Future<void> syncNow() async{
    if(_syncing)return;_syncing=true;
    try{
      final target=_cycleFor(DateTime.now());
      if(_key(_cycleMonth)!=_key(target))await _prepareCycle(target,stored:_key(_cycleMonth));
      if(!cloudEnabled)return;
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

  Future<void> _syncCycle(String cycle) async{
    if(!cloudEnabled)return;
    final remote=await cloud!.loadMonth(cycle);
    if(remote==null){await cloud!.upsertItems(cycle,_items);return;}
    final merged=<String,BudgetItem>{for(final i in _items)i.id:i};
    for(final r in remote){final l=merged[r.id];if(l==null||_stamp(r).isAfter(_stamp(l)))merged[r.id]=r;}
    final upload=<BudgetItem>[];
    for(final m in merged.values){final r=remote.where((x)=>x.id==m.id).firstOrNull;if(r==null||_stamp(m).isAfter(_stamp(r)))upload.add(m);}
    if(upload.isNotEmpty)await cloud!.upsertItems(cycle,upload);
    _items=merged.values.toList();
  }

  Map<String,dynamic> _details(BudgetItem i)=>{'name':i.name,'amount':i.amount,'category':i.category.name,'month_day':i.monthDay,'note':i.note,'paid':i.paid,'reminder_enabled':i.reminderEnabled,'reminder_days_before':i.reminderDaysBefore};

  Future<void> _audit(String action,BudgetItem item) async{
    if(!cloudEnabled)return;
    try{await cloud!.logEvent(_key(_cycleMonth),item.id,action,details:_details(item));}catch(_){_online=false;}
  }

  Future<void> _archive(String cycle,List<BudgetItem> items) async{
    final live=items.where((e)=>!e.deleted).toList();final total=live.fold<double>(0,(s,e)=>s+e.amount),paid=live.where((e)=>e.paid).fold<double>(0,(s,e)=>s+e.amount);
    final b=StringBuffer()..writeln('Budget history: $cycle')..writeln('--------------------------------');
    for(final i in live){b.writeln('${i.paid?'[PAID]':'[DUE]'} ${i.name}\tR${i.amount.toStringAsFixed(2)}\t${i.note}');}
    b..writeln('Paid: R${paid.toStringAsFixed(2)}')..writeln('Outstanding: R${(total-paid).toStringAsFixed(2)}')..writeln('Total: R${total.toStringAsFixed(2)}')..writeln();
    if(!_history.any((h)=>h.startsWith('Budget history: $cycle'))){_history.add(b.toString());await _repository.saveHistory(_history);}
    try{if(cloudEnabled)await cloud!.archiveMonth(cycle,live);}catch(_){_online=false;}
  }

  Future<void> togglePaid(BudgetItem item,bool paid) async{
    final updated=item.copyWith(paid:paid,updatedAt:DateTime.now().toUtc());
    _replace(updated);await _saveLocal();notifyListeners();
    await _pushItem(updated);await _audit(paid?'MARKED PAID':'MARKED UNPAID',updated);
  }
  Future<void> addItem(String name,double amount,String note,BudgetCategory category,int? monthDay,bool reminderEnabled,int reminderDaysBefore) async{
    final created=BudgetItem(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,amount:amount,note:note,category:category,monthDay:monthDay,reminderEnabled:reminderEnabled,reminderDaysBefore:reminderDaysBefore,updatedAt:DateTime.now().toUtc());
    _items.add(created);await _saveLocal();notifyListeners();
    await _pushItem(created);await _audit('ADDED',created);
  }
  Future<void> editItem(BudgetItem item,String name,double amount,String note,BudgetCategory category,int? monthDay,bool reminderEnabled,int reminderDaysBefore) async{
    final updated=item.copyWith(name:name,amount:amount,note:note,category:category,monthDay:monthDay,clearMonthDay:monthDay==null,reminderEnabled:reminderEnabled,reminderDaysBefore:reminderDaysBefore,updatedAt:DateTime.now().toUtc());
    _replace(updated);await _saveLocal();notifyListeners();
    await _pushItem(updated);await _audit('EDITED',updated);
  }
  void _replace(BudgetItem item){_items=_items.map((e)=>e.id==item.id?item:e).toList();}
  Future<void> _pushItem(BudgetItem item) async{
    if(!cloudEnabled)return;
    try{await cloud!.upsertItems(_key(_cycleMonth),[item]);_online=true;}
    catch(_){_online=false;}
    notifyListeners();
  }
  Future<void> deleteItem(BudgetItem item) async{
    final updated=item.copyWith(deleted:true,updatedAt:DateTime.now().toUtc());
    _replace(updated);await _saveLocal();notifyListeners();
    await _pushItem(updated);await _audit('DELETED',updated);
  }
  Future<void> refreshFromCloud()=>syncNow();
  Future<void> _saveLocal() async{await _repository.saveItems(_items);await _repository.saveCycleKey(_key(_cycleMonth));await _repository.saveHistory(_history);}
  @override void dispose(){_syncTimer?.cancel();super.dispose();}
}
