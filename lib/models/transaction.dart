class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.category,
    required this.transactionDate,
    this.createdAt,
    this.subBookId,
  });

  final int id;
  final String type;
  final double amount;
  final String note;
  final String category;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final int? subBookId;

  bool get isIncome => type == 'income';

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'expense',
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      category: json['category'] as String? ?? '其他',
      transactionDate: DateTime.tryParse(json['transactionDate'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      subBookId: (json['subBookId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'note': note,
        'category': category,
        'transactionDate': _date(transactionDate),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (subBookId != null) 'subBookId': subBookId,
      };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
