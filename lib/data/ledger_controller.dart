import 'package:flutter/foundation.dart';

import '../models/sub_book.dart';
import '../models/transaction.dart';
import 'ledger_api.dart';
import 'ledger_store.dart';

class LedgerController extends ChangeNotifier {
  LedgerController({required LedgerStore store, required LedgerApi api}) : _store = store, _api = api;

  final LedgerStore _store;
  final LedgerApi _api;
  List<LedgerTransaction> transactions = [];
  List<LedgerSubBook> subBooks = [];
  String? _transactionsEtag;
  String? _subBooksEtag;
  bool isLoading = true;
  bool isSyncing = false;
  String? syncMessage;
  DateTime? lastSyncAt;

  double get income => transactions.where((item) => item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get expense => transactions.where((item) => !item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get balance => income - expense;

  Future<bool> restoreSession() => _api.hasSession();
  Future<void> login(String username, String password, {bool register = false}) => _api.login(username, password, register: register);
  Future<void> logout() => _api.logout();

  Future<void> initialize() async {
    final cached = await _store.load();
    transactions = _sort(cached.transactions);
    subBooks = cached.subBooks;
    _transactionsEtag = cached.transactionsEtag;
    _subBooksEtag = cached.subBooksEtag;
    lastSyncAt = cached.lastSyncAt;
    isLoading = false;
    notifyListeners();
  }

  Future<void> sync() async {
    if (isSyncing) return;
    isSyncing = true;
    syncMessage = null;
    notifyListeners();
    try {
      await _flushPending();
      final results = await Future.wait([
        _api.fetchTransactions(version: _transactionsEtag),
        _api.fetchSubBooks(version: _subBooksEtag),
      ]);
      final remoteTransactions = results[0] as RemoteResult<List<LedgerTransaction>>;
      final remoteSubBooks = results[1] as RemoteResult<List<LedgerSubBook>>;
      final transactionsChanged = remoteTransactions.changed && remoteTransactions.version != _transactionsEtag;
      final subBooksChanged = remoteSubBooks.changed && remoteSubBooks.version != _subBooksEtag;
      if (transactionsChanged) {
        transactions = _sort(remoteTransactions.value!);
        _transactionsEtag = remoteTransactions.version;
        await _store.saveTransactions(transactions, etag: _transactionsEtag);
      }
      if (subBooksChanged) {
        subBooks = remoteSubBooks.value!;
        _subBooksEtag = remoteSubBooks.version;
        await _store.saveSubBooks(subBooks, etag: _subBooksEtag);
      }
      syncMessage = transactionsChanged || subBooksChanged ? '已同步云端更新' : '已是最新数据';
      lastSyncAt = DateTime.now();
      await _store.saveLastSyncAt(lastSyncAt!);
    } catch (_) {
      syncMessage = '离线模式：正在使用本地缓存';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
    int? subBookId,
  }) async {
    final temporaryId = _nextTemporaryId();
    final transaction = LedgerTransaction(
      id: temporaryId,
      type: type,
      amount: amount,
      category: category,
      note: note,
      transactionDate: date,
      subBookId: subBookId,
    );
    transactions = _sort([...transactions, transaction]);
    await _store.saveTransactions(transactions);
    await _store.enqueue(SyncOperation(method: 'POST', path: '/api/transactions', body: _payload(transaction), localId: temporaryId));
    notifyListeners();
  }

  Future<void> updateTransaction(LedgerTransaction updated) async {
    transactions = _sort(transactions.map((item) => item.id == updated.id ? updated : item).toList());
    await _store.saveTransactions(transactions);
    if (updated.id > 0) {
      await _store.enqueue(SyncOperation(method: 'PUT', path: '/api/transactions/${updated.id}', body: _payload(updated)));
    } else {
      await _store.replacePendingForLocalId(updated.id, SyncOperation(method: 'POST', path: '/api/transactions', body: _payload(updated), localId: updated.id));
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(LedgerTransaction transaction) async {
    transactions = transactions.where((item) => item.id != transaction.id).toList();
    await _store.saveTransactions(transactions);
    if (transaction.id > 0) {
      await _store.enqueue(SyncOperation(method: 'DELETE', path: '/api/transactions/${transaction.id}', body: null));
    } else {
      await _store.removePendingForLocalId(transaction.id);
    }
    notifyListeners();
  }

  Future<void> deleteSubBook(LedgerSubBook book) async {
    subBooks = subBooks.where((item) => item.id != book.id).toList();
    await _store.saveSubBooks(subBooks);
    if (book.id > 0) {
      await _store.enqueue(SyncOperation(method: 'DELETE', path: '/api/sub-books/${book.id}', body: null));
    } else {
      await _store.removePendingForLocalId(book.id);
    }
    notifyListeners();
  }

  Future<void> createSubBook(String name, DateTime eventDate) async {
    final book = LedgerSubBook(id: _nextTemporaryId(), name: name, eventDate: eventDate);
    subBooks = [...subBooks, book];
    await _store.saveSubBooks(subBooks);
    await _store.enqueue(SyncOperation(method: 'POST', path: '/api/sub-books', body: {
      'name': name,
      'eventDate': _date(eventDate),
    }, localId: book.id));
    notifyListeners();
  }

  Future<void> _flushPending() async {
    while (true) {
      final pending = await _store.pendingOperations();
      if (pending.isEmpty) return;
      await _api.send(pending.first);
      await _store.removeFirstPending();
    }
  }

  int _nextTemporaryId() => -DateTime.now().microsecondsSinceEpoch;
  List<LedgerTransaction> _sort(List<LedgerTransaction> source) => [...source]..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  Map<String, dynamic> _payload(LedgerTransaction item) => {
        'type': item.type,
        'amount': item.amount,
        'category': item.category,
        'categorySource': 'system',
        'note': item.note,
        'transactionDate': _date(item.transactionDate),
        if (item.subBookId != null && item.subBookId! > 0) 'subBookId': item.subBookId,
      };
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
