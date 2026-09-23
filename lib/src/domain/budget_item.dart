class BudgetItem {
  const BudgetItem({
    required this.id, required this.name, required this.amount,
    this.note='', this.paid=false, this.deleted=false, this.updatedAt,
  });
  final String id,name,note;
  final double amount;
  final bool paid,deleted;
  final DateTime? updatedAt;

  BudgetItem copyWith({bool? paid,bool? deleted,DateTime? updatedAt})=>BudgetItem(
    id:id,name:name,amount:amount,note:note,paid:paid??this.paid,
    deleted:deleted??this.deleted,updatedAt:updatedAt??this.updatedAt);

  Map<String,dynamic> toJson()=>{
    'id':id,'name':name,'amount':amount,'note':note,'paid':paid,'deleted':deleted,
    'updated_at':updatedAt?.toUtc().toIso8601String(),
  };

  factory BudgetItem.fromJson(Map<String,dynamic> json)=>BudgetItem(
    id:json['id'] as String,name:json['name'] as String,
    amount:(json['amount'] as num).toDouble(),note:(json['note'] as String?)??'',
    paid:(json['paid'] as bool?)??false,deleted:(json['deleted'] as bool?)??false,
    updatedAt:json['updated_at']==null?null:DateTime.tryParse(json['updated_at'] as String),
  );
}
