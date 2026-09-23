import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/budget_item.dart';

class CloudBudgetStore {
  CloudBudgetStore(this.client);
  final SupabaseClient client;
  User? get user=>client.auth.currentUser;

  Future<String?> _budgetId(String cycle,{bool create=false}) async{
    final uid=user?.id;if(uid==null)return null;
    final found=await client.from('budgets').select('id').eq('user_id',uid).eq('cycle_month','$cycle-01').maybeSingle();
    if(found!=null)return found['id'] as String;
    if(!create)return null;
    final row=await client.from('budgets').insert({'user_id':uid,'cycle_month':'$cycle-01'}).select('id').single();
    return row['id'] as String;
  }

  Future<List<BudgetItem>?> loadMonth(String cycle) async{
    final id=await _budgetId(cycle);if(id==null)return null;
    final rows=await client.from('budget_items').select().eq('budget_id',id);
    return (rows as List).map((e)=>BudgetItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
  }

  Future<void> upsertItems(String cycle,List<BudgetItem> items) async{
    final uid=user?.id;if(uid==null||items.isEmpty)return;
    final id=await _budgetId(cycle,create:true);if(id==null)return;
    await client.from('budget_items').upsert(items.map((e)=>{
      'id':e.id,'budget_id':id,'user_id':uid,'name':e.name,'amount':e.amount,
      'note':e.note,'paid':e.paid,'deleted':e.deleted,
      'updated_at':(e.updatedAt??DateTime.now()).toUtc().toIso8601String(),
    }).toList(),onConflict:'budget_id,id');
  }

  Future<void> archiveMonth(String cycle,List<BudgetItem> items) async{
    final uid=user?.id;if(uid==null)return;
    final live=items.where((e)=>!e.deleted).toList();
    final total=live.fold<double>(0,(s,e)=>s+e.amount);
    final paid=live.where((e)=>e.paid).fold<double>(0,(s,e)=>s+e.amount);
    await client.from('budget_history').upsert({
      'user_id':uid,'cycle_month':'$cycle-01','snapshot':live.map((e)=>e.toJson()).toList(),
      'total':total,'paid_total':paid,'unpaid_total':total-paid,
    },onConflict:'user_id,cycle_month',ignoreDuplicates:true);
  }

  Future<List<String>> loadHistoryText() async{
    final uid=user?.id;if(uid==null)return [];
    final rows=await client.from('budget_history').select().eq('user_id',uid).order('cycle_month',ascending:false);
    return (rows as List).map((row){
      final cycle=(row['cycle_month'] as String).substring(0,7);
      final items=(row['snapshot'] as List).map((e)=>BudgetItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final b=StringBuffer()..writeln('Budget history: $cycle')..writeln('--------------------------------');
      for(final i in items){b.writeln('${i.paid?'[PAID]':'[DUE]'} ${i.name}\tR${i.amount.toStringAsFixed(2)}\t${i.note}');}
      b..writeln('Paid: R${(row['paid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Outstanding: R${(row['unpaid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Total: R${(row['total'] as num).toStringAsFixed(2)}')..writeln();
      return b.toString();
    }).toList();
  }
}
