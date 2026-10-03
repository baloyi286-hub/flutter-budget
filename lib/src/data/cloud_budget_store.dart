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
      'note':e.note,'paid':e.paid,'deleted':e.deleted,'category':e.category.name,'month_day':e.monthDay,'reminder_enabled':e.reminderEnabled,'reminder_days_before':e.reminderDaysBefore,
      'updated_at':(e.updatedAt??DateTime.now()).toUtc().toIso8601String(),
    }).toList(),onConflict:'budget_id,id');
  }

  Future<void> logEvent(String cycle,String itemId,String action,{Map<String,dynamic>? details}) async{
    final uid=user?.id;if(uid==null)return;
    await client.from('budget_audit').insert({
      'user_id':uid,'cycle_month':'$cycle-01','item_id':itemId,'action':action,
      'details':details??<String,dynamic>{},
    });
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
      for(final i in items){
        b.writeln('${i.paid?'[PAID]':'[DUE]'} ${i.name}\tR${i.amount.toStringAsFixed(2)}\t${i.category.label}${i.monthDay==null?'':'\tDay ${i.monthDay}'}\t${i.note}');
      }
      final auditRows=await client.from('budget_audit').select().eq('user_id',uid).eq('cycle_month',row['cycle_month']).order('created_at');
      if((auditRows as List).isNotEmpty){
        b.writeln()..writeln('AUDIT TRAIL')..writeln('--------------------------------');
        for(final event in auditRows){
          final details=Map<String,dynamic>.from((event['details'] as Map?)??{});
          final at=DateTime.tryParse(event['created_at'] as String? ?? '');
          final when=at==null?(event['created_at']??'').toString():at.toLocal().toString().substring(0,19);
          b.writeln('$when  ${event['action']}  ${details['name']??event['item_id']}  ${details['amount']==null?'':'R${details['amount']}'}');
        }
      }
      b..writeln()..writeln('Paid: R${(row['paid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Outstanding: R${(row['unpaid_total'] as num).toStringAsFixed(2)}')
       ..writeln('Total: R${(row['total'] as num).toStringAsFixed(2)}')..writeln();
      return b.toString();
    }).toList();
  }
}
