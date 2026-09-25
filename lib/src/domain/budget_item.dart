enum BudgetCategory { debitOrders, responsibilities, subscriptions, thisMonthOnly }

extension BudgetCategoryLabel on BudgetCategory {
  String get label=>switch(this){
    BudgetCategory.debitOrders=>'Debit Orders',
    BudgetCategory.responsibilities=>'Responsibilities',
    BudgetCategory.subscriptions=>'Subscriptions',
    BudgetCategory.thisMonthOnly=>'This Month Only',
  };
  bool get needsDay=>this==BudgetCategory.debitOrders||this==BudgetCategory.subscriptions;
  static BudgetCategory parse(String? value)=>BudgetCategory.values.firstWhere(
    (e)=>e.name==value,orElse:()=>BudgetCategory.responsibilities);
}

class BudgetItem {
  const BudgetItem({
    required this.id,required this.name,required this.amount,
    this.note='',this.paid=false,this.deleted=false,this.updatedAt,
    this.category=BudgetCategory.responsibilities,this.monthDay,
  });
  final String id,name,note;
  final double amount;
  final bool paid,deleted;
  final DateTime? updatedAt;
  final BudgetCategory category;
  final int? monthDay;

  BudgetItem copyWith({
    String? name,double? amount,String? note,bool? paid,bool? deleted,
    DateTime? updatedAt,BudgetCategory? category,int? monthDay,bool clearMonthDay=false,
  })=>BudgetItem(
    id:id,name:name??this.name,amount:amount??this.amount,note:note??this.note,
    paid:paid??this.paid,deleted:deleted??this.deleted,updatedAt:updatedAt??this.updatedAt,
    category:category??this.category,monthDay:clearMonthDay?null:(monthDay??this.monthDay));

  Map<String,dynamic> toJson()=>{
    'id':id,'name':name,'amount':amount,'note':note,'paid':paid,'deleted':deleted,
    'category':category.name,'month_day':monthDay,
    'updated_at':updatedAt?.toUtc().toIso8601String(),
  };

  factory BudgetItem.fromJson(Map<String,dynamic> json)=>BudgetItem(
    id:json['id'] as String,name:json['name'] as String,
    amount:(json['amount'] as num).toDouble(),note:(json['note'] as String?)??'',
    paid:(json['paid'] as bool?)??false,deleted:(json['deleted'] as bool?)??false,
    category:BudgetCategoryLabel.parse(json['category'] as String?),
    monthDay:(json['month_day'] as num?)?.toInt(),
    updatedAt:json['updated_at']==null?null:DateTime.tryParse(json['updated_at'] as String),
  );
}
