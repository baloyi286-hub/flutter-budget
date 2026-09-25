import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/budget_item.dart';
import '../domain/budget_service.dart';

const _blue = Color(0xFF1976D2);
const _deepBlue = Color(0xFF145FA8);
const _orange = Color(0xFFFF654E);

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.service, required this.onSignedOut});
  final BudgetService service;
  final VoidCallback onSignedOut;
  @override State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final _money = NumberFormat.currency(locale:'en_ZA',symbol:'R',decimalDigits:0);
  @override void initState(){super.initState();widget.service.addListener(_refresh);}
  @override void dispose(){widget.service.removeListener(_refresh);super.dispose();}
  void _refresh()=>setState((){});

  @override Widget build(BuildContext context){
    final s=widget.service;
    return Scaffold(
      appBar:AppBar(
        title:const Text('MONTHLY BUDGET',style:TextStyle(fontWeight:FontWeight.w700,letterSpacing:2)),
        actions:[
          IconButton(tooltip:'History',onPressed:_showHistory,icon:const Icon(Icons.history)),
          PopupMenuButton<String>(
            tooltip:'Account',
            icon:const Icon(Icons.account_circle_outlined),
            onSelected:(value){if(value=='logout')_signOut();},
            itemBuilder:(context)=>const [PopupMenuItem(value:'logout',child:Row(children:[Icon(Icons.logout),SizedBox(width:10),Text('Sign out')]))],
          ),
          const SizedBox(width:6),
        ],
      ),
      floatingActionButton:FloatingActionButton(
        backgroundColor:_orange,foregroundColor:Colors.white,
        onPressed:_addItem,child:const Icon(Icons.add),
      ),
      body:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:900),
        child:ListView(padding:const EdgeInsets.fromLTRB(16,22,16,90),children:[
          _Hero(month:s.monthTitle,total:s.dueTotal+ s.paidTotal,money:_money),
          const SizedBox(height:18),
          _BudgetCard(title:'TO PAY',items:s.dueItems,total:s.dueTotal,money:_money,checked:false,onChanged:(i,v)=>s.togglePaid(i,v),onDelete:s.deleteItem),
          if(s.paidItems.isNotEmpty)...[
            const SizedBox(height:18),
            _BudgetCard(title:'PAID',items:s.paidItems,total:s.paidTotal,money:_money,checked:true,onChanged:(i,v)=>s.togglePaid(i,v),onDelete:s.deleteItem),
          ],
        ]),
      )),
    );
  }

  Future<void> _signOut() async{
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Sign out?'),
      content:const Text('Your budget is saved to your account. You can sign in again on this or another device.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Sign out'))],
    ));
    if(confirmed!=true)return;
    await widget.service.syncNow();
    await Supabase.instance.client.auth.signOut();
    widget.onSignedOut();
  }

  Future<void> _addItem() async{
    final name=TextEditingController(),amount=TextEditingController(),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Add budget item'),
      content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Item')),
        const SizedBox(height:12),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount (R)')),
        const SizedBox(height:12),
        TextField(controller:note,decoration:const InputDecoration(labelText:'Note (optional)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Add'))],
    ));
    final value=double.tryParse(amount.text);
    if(ok==true&&name.text.trim().isNotEmpty&&value!=null){await widget.service.addItem(name.text,value,note.text);}
  }

  void _showHistory()=>showDialog<void>(context:context,builder:(context)=>AlertDialog(
    title:const Text('Budget history'),
    content:SizedBox(width:600,height:420,child:widget.service.history.isEmpty
      ?const Center(child:Text('No archived months yet.'))
      :ListView(children:widget.service.history.reversed.map((e)=>SelectableText(e)).toList())),
    actions:[
      if(widget.service.history.isNotEmpty)TextButton.icon(onPressed:_exportHistory,icon:const Icon(Icons.download),label:const Text('Export .txt')),
      TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close')),
    ],
  ));

  void _exportHistory(){
    final blob=html.Blob([utf8.encode(widget.service.history.join('\n'))],'text/plain');
    final url=html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href:url)..setAttribute('download','budget_history.txt')..click();
    html.Url.revokeObjectUrl(url);
  }
}

class _Hero extends StatelessWidget{
  const _Hero({required this.month,required this.total,required this.money});
  final String month;final double total;final NumberFormat money;
  @override Widget build(BuildContext context)=>Container(
    decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[_blue,_deepBlue],begin:Alignment.topLeft,end:Alignment.bottomRight),
      borderRadius:BorderRadius.circular(8),
      boxShadow:const [BoxShadow(blurRadius:10,offset:Offset(0,4),color:Color(0x22000000))],
    ),
    padding:const EdgeInsets.symmetric(horizontal:22,vertical:26),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(month.toUpperCase(),style:const TextStyle(color:Colors.white70,fontSize:14,fontWeight:FontWeight.w700,letterSpacing:2)),
      const SizedBox(height:8),
      Text(money.format(total),style:const TextStyle(color:Colors.white,fontSize:38,fontWeight:FontWeight.w300)),
      const SizedBox(height:3),
      const Text('MONTHLY BUDGET',style:TextStyle(color:Colors.white70,fontSize:12,letterSpacing:2)),
    ]),
  );
}

class _BudgetCard extends StatelessWidget{
  const _BudgetCard({required this.title,required this.items,required this.total,required this.money,required this.checked,required this.onChanged,required this.onDelete});
  final String title;final List<BudgetItem> items;final double total;final NumberFormat money;final bool checked;
  final Future<void> Function(BudgetItem,bool) onChanged;final Future<void> Function(BudgetItem) onDelete;

  @override Widget build(BuildContext context)=>Card(
    clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,
    child:Column(children:[
      Container(
        color:_blue,padding:const EdgeInsets.symmetric(horizontal:18,vertical:15),
        child:Row(children:[
          Expanded(child:Text(title,style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w700,letterSpacing:1.5))),
          Text('${items.length} ITEMS',style:const TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w600)),
        ]),
      ),
      if(items.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Text('No items'))
      else ...items.map(_row),
      Container(
        color:const Color(0xFFF2F7FC),padding:const EdgeInsets.all(18),
        child:Row(children:[
          const Expanded(child:Text('TOTAL',style:TextStyle(color:_deepBlue,fontWeight:FontWeight.w800,letterSpacing:1.5))),
          Text(money.format(total),style:const TextStyle(color:_deepBlue,fontSize:19,fontWeight:FontWeight.w800)),
        ]),
      ),
    ]),
  );

  Widget _row(BudgetItem item)=>Container(
    decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0xFFE3EAF1)))),
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),
    child:Row(children:[
      Checkbox(activeColor:_orange,value:checked,onChanged:(v)=>onChanged(item,v??false)),
      Expanded(flex:5,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(item.name,style:TextStyle(color:checked?const Color(0xFF718096):const Color(0xFF263746),fontWeight:FontWeight.w600,decoration:checked?TextDecoration.lineThrough:null)),
        if(item.note.isNotEmpty)Text(item.note,style:const TextStyle(color:Color(0xFF8A9BAD),fontSize:12)),
      ])),
      Expanded(flex:2,child:Text(money.format(item.amount),textAlign:TextAlign.right,style:const TextStyle(color:Color(0xFF263746),fontWeight:FontWeight.w600))),
      IconButton(tooltip:checked?'Move back':'Delete',color:checked?_blue:const Color(0xFF8A9BAD),icon:Icon(checked?Icons.undo:Icons.delete_outline,size:20),onPressed:()=>checked?onChanged(item,false):onDelete(item)),
    ]),
  );
}
