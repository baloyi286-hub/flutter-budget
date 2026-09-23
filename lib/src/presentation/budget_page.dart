import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/budget_item.dart';
import '../domain/budget_service.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.service});
  final BudgetService service;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final _money = NumberFormat.currency(locale: 'en_ZA', symbol: 'R', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: const Row(children:[
          Icon(Icons.account_balance_wallet_outlined),
          SizedBox(width:10),
          Text('Budget', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(tooltip:'History', onPressed:_showHistory, icon:const Icon(Icons.history)),
          const SizedBox(width:8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('${s.monthTitle} Budget',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              Text('Tick an item when paid. Your next cycle starts automatically on the 22nd.',
                style: const TextStyle(color:Color(0xFFAAAAAA))),
              const SizedBox(height:20),
              _BudgetCard(
                title:'To Pay',
                items:s.dueItems,
                total:s.dueTotal,
                money:_money,
                checked:false,
                onChanged:(i,v)=>s.togglePaid(i, v),
                onDelete:s.deleteItem,
              ),
              if (s.paidItems.isNotEmpty) ...[
                const SizedBox(height:18),
                _BudgetCard(
                  title:'Paid',
                  items:s.paidItems,
                  total:s.paidTotal,
                  money:_money,
                  checked:true,
                  onChanged:(i,v)=>s.togglePaid(i, v),
                  onDelete:s.deleteItem,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context:context,
      builder:(context)=>AlertDialog(
        title:const Text('Add budget item'),
        content:SizedBox(width:380, child:Column(mainAxisSize:MainAxisSize.min, children:[
          TextField(controller:name, decoration:const InputDecoration(labelText:'Item')),
          const SizedBox(height:12),
          TextField(controller:amount, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'Amount (R)')),
          const SizedBox(height:12),
          TextField(controller:note, decoration:const InputDecoration(labelText:'Note (optional)')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false), child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(context,true), child:const Text('Add')),
        ],
      ),
    );
    final value = double.tryParse(amount.text);
    if (ok == true && name.text.trim().isNotEmpty && value != null) {
      await widget.service.addItem(name.text, value, note.text);
    }
  }

  void _showHistory() {
    showDialog<void>(
      context:context,
      builder:(context)=>AlertDialog(
        title:const Text('Budget history'),
        content:SizedBox(
          width:600,
          height:420,
          child:widget.service.history.isEmpty
            ? const Center(child:Text('No archived months yet.'))
            :ListView(children:widget.service.history.reversed.map((e)=>SelectableText(e)).toList()),
        ),
        actions:[
          if(widget.service.history.isNotEmpty)
            TextButton.icon(onPressed:_exportHistory, icon:const Icon(Icons.download), label:const Text('Export .txt')),
          TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Close')),
        ],
      ),
    );
  }

  void _exportHistory() {
    final text = widget.service.history.join('\n');
    final bytes = utf8.encode(text);
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href:url)
      ..setAttribute('download','budget_history.txt')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.title, required this.items, required this.total,
    required this.money, required this.checked, required this.onChanged,
    required this.onDelete,
  });
  final String title;
  final List<BudgetItem> items;
  final double total;
  final NumberFormat money;
  final bool checked;
  final Future<void> Function(BudgetItem,bool) onChanged;
  final Future<void> Function(BudgetItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior:Clip.antiAlias,
      child:Column(children:[
        Container(
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:15),
          color:const Color(0xFF2D2D30),
          child:Row(children:[
            Expanded(child:Text(title, style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600))),
            Text('${items.length} items', style:const TextStyle(color:Color(0xFFAAAAAA))),
          ]),
        ),
        if(items.isEmpty)
          const Padding(padding:EdgeInsets.all(30), child:Text('No items'))
        else
          ...items.map((item)=>_row(context,item)),
        Container(
          padding:const EdgeInsets.all(18),
          decoration:const BoxDecoration(border:Border(top:BorderSide(color:Color(0xFF3C3C3C)))),
          child:Row(children:[
            const Expanded(child:Text('TOTAL',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1))),
            Text(money.format(total),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, BudgetItem item) => Container(
    decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0xFF333333)))),
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
    child:Row(children:[
      Checkbox(value:checked,onChanged:(v)=>onChanged(item,v ?? false)),
      Expanded(flex:5,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(item.name,style:const TextStyle(fontWeight:FontWeight.w500)),
        if(item.note.isNotEmpty) Text(item.note,style:const TextStyle(color:Color(0xFF858585),fontSize:12)),
      ])),
      Expanded(flex:2,child:Text(money.format(item.amount),textAlign:TextAlign.right)),
      IconButton(
        tooltip: checked ? 'Move back' : 'Delete',
        icon:Icon(checked ? Icons.undo : Icons.delete_outline,size:20),
        onPressed:()=>checked ? onChanged(item,false) : onDelete(item),
      ),
    ]),
  );
}
