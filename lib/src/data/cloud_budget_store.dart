import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/budget_item.dart';

class CloudBudgetStore {
  CloudBudgetStore(this.client);
  final SupabaseClient client;

  User? get user => client.auth.currentUser;

  Future<List<BudgetItem>?> loadMonth(String cycle) async {
    final uid=user?.id; if(uid==null) return null;
    final budget=await client.from('budgets').select('id').eq('user_id',uid).eq('cycle_month','$cycle-01').maybeSingle();
    if(budget==null) return null;
    final rows=await client.from('budget_items').select().eq('budget_id',budget['id']).order('name');
    return (rows as List).map((e)=>BudgetItem(
      id:e['id'] as String,name:e['name'] as String,
      amount:(e['amount'] as num).toDouble(),note:(e['note'] as String?)??'',
      paid:(e['paid'] as bool?)??false)).toList();
  }

  Future<void> saveMonth(String cycle,List<BudgetItem> items) async {
    final uid=user?.id; if(uid==null) return;
    final budget=await client.from('budgets').upsert({
      'user_id':uid,'cycle_month':'$cycle-01','updated_at':DateTime.now().toUtc().toIso8601String(),
    },onConflict:'user_id,cycle_month').select('id').single();
    final budgetId=budget['id'];
    await client.from('budget_items').delete().eq('budget_id',budgetId);
    if(items.isNotEmpty){
      await client.from('budget_items').insert(items.map((e)=>({
        'id':e.id,'budget_id':budgetId,'user_id':uid,'name':e.name,
        'amount':e.amount,'note':e.note,'paid':e.paid,
        'updated_at':DateTime.now().toUtc().toIso8601String(),
      })).toList());
    }
  }

  Future<void> archiveMonth(String cycle,List<BudgetItem> items) async {
    final uid=user?.id; if(uid==null) return;
    final total=items.fold<double>(0,(s,e)=>s+e.amount);
    final paid=items.where((e)=>e.paid).fold<double>(0,(s,e)=>s+e.amount);
    await client.from('budget_history').upsert({
      'user_id':uid,'cycle_month':'$cycle-01',
      'snapshot':items.map((e)=>e.toJson()).toList(),
      'total':total,'paid_total':paid,'unpaid_total':total-paid,
    },onConflict:'user_id,cycle_month',ignoreDuplicates:true);
  }

  Future<List<String>> loadHistoryText() async {
    final uid=user?.id; if(uid==null) return [];
    final rows=await client.from('budget_history').select().eq('user_id',uid).order('cycle_month',ascending:false);
    return (rows as List).map((row){
      final cycle=(row['cycle_month'] as String).substring(0,7);
      final items=(row['snapshot'] as List).map((e)=>BudgetItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final b=StringBuffer()..writeln('Budget history: $cycle')..writeln('--------------------------------');
      for(final item in items){b.writeln('${item.paid?'[PAID]':'[DUE]'} ${item.name}\tR${item.amount.toStringAsFixed(2)}\t${item.note}');}
      b..writeln('Paid: R${(row['paid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Outstanding: R${(row['unpaid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Total: R${(row['total'] as num).toStringAsFixed(2)}')..writeln();
      return b.toString();
    }).toList();
  }
}
