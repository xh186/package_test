import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_mobile/models/sub_book.dart';
import 'package:ledger_mobile/models/transaction.dart';

void main() {
  test('transaction JSON round trip keeps money and date', () {
    final original = LedgerTransaction(
      id: 7,
      type: 'expense',
      amount: 35.5,
      note: '午饭',
      category: '餐饮',
      transactionDate: DateTime(2026, 8, 12),
    );
    final restored = LedgerTransaction.fromJson(original.toJson());
    expect(restored.id, 7);
    expect(restored.amount, 35.5);
    expect(restored.transactionDate, DateTime(2026, 8, 12));
  });

  test('sub book totals split income and expense', () {
    final book = LedgerSubBook(
      id: 1,
      name: '旅行',
      eventDate: DateTime(2026, 8, 12),
      transactions: [
        LedgerTransaction(id: 1, type: 'income', amount: 100, note: '', category: '红包', transactionDate: DateTime(2026, 8, 12)),
        LedgerTransaction(id: 2, type: 'expense', amount: 40, note: '', category: '交通', transactionDate: DateTime(2026, 8, 12)),
      ],
    );
    expect(book.income, 100);
    expect(book.expense, 40);
    expect(book.balance, 60);
  });

  test('sub book overview uses server totals without detail transactions', () {
    final book = LedgerSubBook.fromJson({
      'id': 3,
      'name': '装修',
      'eventDate': '2026-08-12',
      'income': 5000,
      'expense': 1200,
      'transactionCount': 8,
    });
    expect(book.income, 5000);
    expect(book.expense, 1200);
    expect(book.transactionCount, 8);
  });
}
