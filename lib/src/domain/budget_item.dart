class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.name,
    required this.amount,
    this.note = '',
    this.paid = false,
  });

  final String id;
  final String name;
  final double amount;
  final String note;
  final bool paid;

  BudgetItem copyWith({bool? paid}) => BudgetItem(
        id: id,
        name: name,
        amount: amount,
        note: note,
        paid: paid ?? this.paid,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'note': note,
        'paid': paid,
      };

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: (json['note'] as String?) ?? '',
        paid: (json['paid'] as bool?) ?? false,
      );
}
