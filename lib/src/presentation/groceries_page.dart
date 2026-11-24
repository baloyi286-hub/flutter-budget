
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const groceryCategories=['Fruit & Vegetables','Meat & Poultry','Dairy & Eggs','Bakery','Pantry','Frozen','Drinks','Snacks','Cleaning','Personal Care','Other'];

class GroceryItem {
  GroceryItem({required this.id,required this.name,required this.price,required this.quantity,required this.category,required this.note,required this.bought,required this.deleted,required this.updatedAt,this.shoppingDate,this.thumbnailData});
  final String id,name,category,note;
  final double price,quantity;
  final bool bought,deleted;
  final DateTime updatedAt;
  final DateTime? shoppingDate;
  final String? thumbnailData;
  double get total=>price*quantity;
  factory GroceryItem.fromJson(Map<String,dynamic> m)=>GroceryItem(
    id:m['id'].toString(),name:m['name'] as String? ?? '',price:(m['amount'] as num?)?.toDouble()??0,
    quantity:(m['quantity'] as num?)?.toDouble()??1,category:m['category'] as String? ?? 'Other',
    note:m['note'] as String? ?? '',bought:m['purchased'] as bool? ??false,deleted:m['deleted'] as bool? ??false,
    updatedAt:DateTime.tryParse(m['updated_at']?.toString()??'')?.toUtc()??DateTime.fromMillisecondsSinceEpoch(0,isUtc:true),
    shoppingDate:DateTime.tryParse(m['shopping_date']?.toString()??''),
    thumbnailData:m['thumbnail_data'] as String?,
  );
  Map<String,dynamic> toJson()=>{
    'id':id,'name':name,'amount':price,'quantity':quantity,'category':category,
    'note':note,'purchased':bought,'deleted':deleted,
    'updated_at':updatedAt.toUtc().toIso8601String(),
    'shopping_date':shoppingDate==null?null:DateFormat('yyyy-MM-dd').format(shoppingDate!),
    'thumbnail_data':thumbnailData,
  };
  GroceryItem edit({String? name,double? price,double? quantity,String? category,String? note,bool? bought,bool? deleted,DateTime? shoppingDate,bool clearDate=false,String? thumbnailData,bool clearThumbnail=false})=>
    GroceryItem(id:id,name:name??this.name,price:price??this.price,quantity:quantity??this.quantity,
      category:category??this.category,note:note??this.note,bought:bought??this.bought,deleted:deleted??this.deleted,
      updatedAt:DateTime.now().toUtc(),shoppingDate:clearDate?null:shoppingDate??this.shoppingDate,
      thumbnailData:clearThumbnail?null:thumbnailData??this.thumbnailData);
}

class GroceriesPage extends StatefulWidget {
  const GroceriesPage({super.key});
  @override State<GroceriesPage> createState()=>_GroceriesPageState();
}

class _GroceriesPageState extends State<GroceriesPage> {
  final client=Supabase.instance.client;
  final money=NumberFormat.currency(locale:'en_ZA',symbol:'R',decimalDigits:2);
  List<GroceryItem> items=[];
  Timer? timer;
  bool loading=true,syncing=false,online=true;
  String get uid=>client.auth.currentUser?.id??'';
  String get localKey=>'groceries_v1_'+uid;

  @override void initState(){
    super.initState();
    initialize();
    timer=Timer.periodic(const Duration(seconds:30),(_)=>sync());
  }
  @override void dispose(){timer?.cancel();super.dispose();}

  Future<void> initialize() async{
    try{
      final p=await SharedPreferences.getInstance();
      final saved=p.getString(localKey);
      if(saved!=null)items=(jsonDecode(saved) as List).map((e)=>GroceryItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
    }catch(_){}
    if(mounted)setState(()=>loading=false);
    await sync();
  }
  Future<void> saveLocal() async{
    final p=await SharedPreferences.getInstance();
    await p.setString(localKey,jsonEncode(items.map((i)=>i.toJson()).toList()));
  }
  Future<void> sync() async{
    if(syncing||uid.isEmpty)return;
    syncing=true;
    try{
      final data=await client.from('grocery_items').select().eq('user_id',uid);
      final remote=(data as List).map((e)=>GroceryItem.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final merged=<String,GroceryItem>{for(final i in items)i.id:i};
      final cloud=<String,GroceryItem>{for(final i in remote)i.id:i};
      for(final i in remote){
        final prev=merged[i.id];
        if(prev==null||i.updatedAt.isAfter(prev.updatedAt))merged[i.id]=i;
      }
      final pending=<Map<String,dynamic>>[];
      for(final i in merged.values){
        final r=cloud[i.id];
        if(r==null||i.updatedAt.isAfter(r.updatedAt))pending.add({...i.toJson(),'user_id':uid});
      }
      if(pending.isNotEmpty)await client.from('grocery_items').upsert(pending,onConflict:'user_id,id');
      items=merged.values.toList();
      await saveLocal();
      online=true;
    }catch(_){online=false;}
    finally{syncing=false;if(mounted)setState((){});}
  }
  Future<void> update(GroceryItem item) async{
    final index=items.indexWhere((x)=>x.id==item.id);
    if(index<0){items.add(item);}else{items[index]=item;}
    if(mounted)setState((){});
    await saveLocal();
    try{
      await client.from('grocery_items').upsert({...item.toJson(),'user_id':uid},onConflict:'user_id,id');
      online=true;
    }catch(_){online=false;}
    if(mounted)setState((){});
  }

  // Store a small JPEG thumbnail in the grocery_items row, not the original camera photo.
  Future<String?> pickThumbnail() async{
    final picker=html.FileUploadInputElement()..accept='image/*';
    picker.click();
    await picker.onChange.first;
    if(picker.files==null||picker.files!.isEmpty)return null;
    return compressThumbnail(picker.files!.first);
  }

  Future<String> compressThumbnail(html.File file) async{
    if(!file.type.startsWith('image/'))throw const FormatException('Choose an image file.');
    final reader=html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    final data=reader.result as String;
    final image=html.ImageElement(src:data);
    await Future.any([
      image.onLoad.first,
      image.onError.first.then((_)=>throw const FormatException('Cannot open this picture. Please try JPEG or PNG.')),
    ]).timeout(const Duration(seconds:20));
    final width=image.naturalWidth;
    final height=image.naturalHeight;
    if(width==0||height==0)throw const FormatException('Picture has invalid dimensions.');
    const longest=320;
    final ratio=math.min(1.0,longest/math.max(width,height));
    final w=math.max(1,(width*ratio).round());
    final h=math.max(1,(height*ratio).round());
    final canvas=html.CanvasElement(width:w,height:h);
    canvas.context2D
      ..fillStyle='#FFFFFF'
      ..fillRect(0,0,w,h)
      ..drawImageScaled(image,0,0,w.toDouble(),h.toDouble());
    var result=canvas.toDataUrl('image/jpeg',0.7);
    if(result.length>100000)result=canvas.toDataUrl('image/jpeg',0.48);
    if(result.length>100000)throw const FormatException('Picture is too large after compression.');
    return result;
  }

  Widget thumbnail(String? data,{double size=56}){
    if(data==null||data.isEmpty)return Container(
      width:size,height:size,
      decoration:BoxDecoration(color:const Color(0xFFE9EEF4),borderRadius:BorderRadius.circular(8)),
      child:const Icon(Icons.image_outlined,color:Color(0xFF8391A5)),
    );
    try{
      return ClipRRect(borderRadius:BorderRadius.circular(8),
        child:Image.memory(base64Decode(data.split(',').last),
          width:size,height:size,fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)));
    }catch(_){return SizedBox(width:size,height:size,child:const Icon(Icons.broken_image_outlined));}
  }
  Future<void> editItem([GroceryItem? existing]) async{
    final name=TextEditingController(text:existing?.name??'');
    final price=TextEditingController(text:existing==null?'':existing.price.toStringAsFixed(2));
    final quantity=TextEditingController(text:existing?.quantity.toString()??'1');
    final note=TextEditingController(text:existing?.note??'');
    String category=existing?.category??'Other';
    if(!groceryCategories.contains(category))category='Other';
    DateTime? date=existing?.shoppingDate;
    String? photo=existing?.thumbnailData;
    StreamSubscription<html.ClipboardEvent>? pasteListener;
    bool dialogOpen=true;
    final save=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
      // Listen only while this item dialog is open. Image files pasted from
      // screenshots or a copied image are compressed exactly like uploads.
      pasteListener ??=html.document.onPaste.listen((event){
        final files=event.clipboardData?.files;
        if(files==null||files.isEmpty)return;
        html.File? pasted;
        for(final file in files){
          if(file.type.startsWith('image/')){pasted=file;break;}
        }
        if(pasted==null)return;
        event.preventDefault();
        () async{
          try{
            final result=await compressThumbnail(pasted!);
            if(dialogOpen&&ctx.mounted)refresh(()=>photo=result);
          }catch(e){
            if(dialogOpen&&ctx.mounted){
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Unable to paste picture: $e')));
            }
          }
        }();
      });
      return AlertDialog(
      title:Text(existing==null?'Add grocery item':'Edit grocery item'),
      content:SizedBox(width:400,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          thumbnail(photo,size:74),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            TextButton.icon(icon:const Icon(Icons.add_a_photo_outlined),label:Text(photo==null?'Add picture':'Change picture'),onPressed:() async{
              try{
                final selected=await pickThumbnail();
                if(selected!=null)refresh(()=>photo=selected);
              }catch(e){
                if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Could not use picture: $e')));
              }
            }),
            const Text('Or paste an image (Ctrl+V / Cmd+V)',style:TextStyle(fontSize:12,color:Color(0xFF65758A))),
            if(photo!=null)TextButton(onPressed:()=>refresh(()=>photo=null),child:const Text('Remove picture')),
          ])),
        ]),
        const SizedBox(height:10),
        TextField(controller:name,decoration:const InputDecoration(labelText:'Item name')),
        const SizedBox(height:10),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Unit price (R)')),
        const SizedBox(height:10),
        TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:category,isExpanded:true,decoration:const InputDecoration(labelText:'Category'),
          items:groceryCategories.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v){if(v!=null)refresh(()=>category=v);}),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:Text(date==null?'Shopping date (optional)':DateFormat('d MMM yyyy').format(date!))),
          TextButton(onPressed:() async{
            final picked=await showDatePicker(context:ctx,initialDate:date??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));
            if(picked!=null)refresh(()=>date=picked);
          },child:const Text('Choose')),
          if(date!=null)IconButton(icon:const Icon(Icons.close),tooltip:'Clear date',onPressed:()=>refresh(()=>date=null)),
        ]),
        const SizedBox(height:10),
        TextField(controller:note,decoration:const InputDecoration(labelText:'Note (optional)')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save')),
      ],
    );}));
    dialogOpen=false;
    await pasteListener?.cancel();
    if(save!=true)return;
    final p=double.tryParse(price.text.trim()),q=double.tryParse(quantity.text.trim());
    if(name.text.trim().isEmpty||p==null||!p.isFinite||p<0||q==null||!q.isFinite||q<=0){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a name, a valid unit price and quantity greater than zero.')));
      return;
    }
    final item=existing==null
      ?GroceryItem(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text.trim(),price:p,quantity:q,category:category,note:note.text.trim(),bought:false,deleted:false,updatedAt:DateTime.now().toUtc(),shoppingDate:date,thumbnailData:photo)
      :existing.edit(name:name.text.trim(),price:p,quantity:q,category:category,note:note.text.trim(),shoppingDate:date,clearDate:date==null,thumbnailData:photo,clearThumbnail:photo==null);
    await update(item);
  }

  Widget itemRow(GroceryItem item)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),
    child:Row(children:[
      Checkbox(activeColor:Colors.green,value:item.bought,onChanged:(v)=>update(item.edit(bought:v??false))),
      thumbnail(item.thumbnailData,size:52),
      const SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(item.name,style:TextStyle(fontWeight:FontWeight.w600,decoration:item.bought?TextDecoration.lineThrough:null)),
        Text('Qty '+item.quantity.toString()+' × '+money.format(item.price)+
          (item.shoppingDate==null?'':' • '+DateFormat('d MMM').format(item.shoppingDate!)),
          style:const TextStyle(fontSize:12,color:Color(0xFF65758A))),
        if(item.note.isNotEmpty)Text(item.note,style:const TextStyle(fontSize:12,color:Color(0xFF65758A))),
      ])),
      const SizedBox(width:5),
      Text(money.format(item.total),style:const TextStyle(fontWeight:FontWeight.w700)),
      IconButton(tooltip:'Edit',icon:const Icon(Icons.edit_outlined,size:20),onPressed:()=>editItem(item)),
      IconButton(tooltip:'Delete',icon:const Icon(Icons.delete_outline,size:20),onPressed:()=>update(item.edit(deleted:true))),
    ]),
  );

  @override Widget build(BuildContext context){
    final active=items.where((i)=>!i.deleted).toList();
    active.sort((a,b)=>a.bought!=b.bought?(a.bought?1:-1):a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final groups=<String,List<GroceryItem>>{};
    for(final item in active){groups.putIfAbsent(item.category,()=>[]).add(item);}
    final total=active.fold<double>(0,(n,i)=>n+i.total);
    final bought=active.where((i)=>i.bought).fold<double>(0,(n,i)=>n+i.total);
    return Scaffold(
      backgroundColor:const Color(0xFFF4F7FA),
      floatingActionButton:FloatingActionButton(backgroundColor:const Color(0xFFFF654E),foregroundColor:Colors.white,
        onPressed:()=>editItem(),child:const Icon(Icons.add)),
      body:RefreshIndicator(onRefresh:sync,
        child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
          child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,22,16,95),children:[
            Container(
              decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF1976D2),Color(0xFF145FA8)]),borderRadius:BorderRadius.circular(10)),
              padding:const EdgeInsets.all(22),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('GROCERY LIST',style:TextStyle(color:Colors.white70,fontWeight:FontWeight.bold,letterSpacing:2)),
                const SizedBox(height:8),
                Text(money.format(total),style:const TextStyle(fontSize:34,color:Colors.white)),
                Text('Purchased: '+money.format(bought)+' • Remaining: '+money.format(total-bought),style:const TextStyle(color:Colors.white)),
              ]),
            ),
            if(!online)const Padding(padding:EdgeInsets.all(12),child:Text('Offline: changes are saved on this device and will sync later.',style:TextStyle(color:Colors.deepOrange))),
            if(loading)const Center(child:CircularProgressIndicator()),
            if(active.isEmpty&&!loading)const Padding(padding:EdgeInsets.all(32),child:Center(child:Text('No groceries yet. Tap + to add an item.'))),
            for(final group in groups.entries)...[
              const SizedBox(height:14),
              Card(margin:EdgeInsets.zero,clipBehavior:Clip.antiAlias,child:Column(children:[
                Container(color:const Color(0xFF1976D2),padding:const EdgeInsets.all(16),
                  child:Row(children:[
                    Expanded(child:Text(group.key.toUpperCase(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
                    Text(group.value.length.toString()+' ITEMS',style:const TextStyle(color:Colors.white70)),
                  ])),
                for(final item in group.value)itemRow(item),
                Container(color:const Color(0xFFF2F7FC),padding:const EdgeInsets.all(16),
                  child:Row(children:[
                    const Expanded(child:Text('TOTAL',style:TextStyle(fontWeight:FontWeight.bold))),
                    Text(money.format(group.value.fold<double>(0,(n,i)=>n+i.total)),style:const TextStyle(fontWeight:FontWeight.bold)),
                  ])),
              ])),
            ],
          ]),
        )),
      ),
    );
  }
}
