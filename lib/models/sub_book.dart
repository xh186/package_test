import 'transaction.dart';

class LedgerSubBook {
  const LedgerSubBook({
    required this.id,
    required this.name,
    required this.eventDate,
    this.transactions = const [],
    this.remoteIncome,
    this.remoteExpense,
    this.remoteTransactionCount,
  });

  final int id;
  final String name;
  final DateTime eventDate;
  final List<LedgerTransaction> transactions;
  final double? remoteIncome;
  final double? remoteExpense;
  final int? remoteTransactionCount;

  double get income => remoteIncome ?? transactions.where((item) => item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get expense => remoteExpense ?? transactions.where((item) => !item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get balance => income - expense;
  int get transactionCount => remoteTransactionCount ?? transactions.length;

  factory LedgerSubBook.fromJson(Map<String, dynamic> json) => LedgerSubBook(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '未命名子账本',
        eventDate: DateTime.tryParse(json['eventDate'] as String? ?? '') ?? DateTime.now(),
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((item) => LedgerTransaction.fromJson(item as Map<String, dynamic>))
            .toList(),
        remoteIncome: (json['income'] as num?)?.toDouble(),
        remoteExpense: (json['expense'] as num?)?.toDouble(),
        remoteTransactionCount: (json['transactionCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'eventDate': eventDate.toIso8601String().substring(0, 10),
        'transactions': transactions.map((item) => item.toJson()).toList(),
        if (remoteIncome != null) 'income': remoteIncome,
        if (remoteExpense != null) 'expense': remoteExpense,
        if (remoteTransactionCount != null) 'transactionCount': remoteTransactionCount,
      };
}
