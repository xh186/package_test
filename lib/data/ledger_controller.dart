import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/sub_book.dart';
import '../models/transaction.dart';
import 'ledger_api.dart';
import 'ledger_store.dart';

class LedgerController extends ChangeNotifier {
  LedgerController({required LedgerStore store, required LedgerApi api}) : _store = store, _api = api;

  final LedgerStore _store;
  final LedgerApi _api;
  List<LedgerTransaction> _allTransactions = [];
  List<LedgerTransaction> get transactions => _allTransactions.where((item) => !item.isDeleted).toList();
  List<LedgerSubBook> subBooks = [];
  String? _transactionsEtag;
  String? _subBooksEtag;
  bool isLoading = true;
  bool isSyncing = false;
  String? syncMessage;
  DateTime? lastSyncAt;
  bool get hasSyncConflict => syncConflict != null;
  SyncConflict? syncConflict;

  double get income => transactions.where((item) => item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get expense => transactions.where((item) => !item.isIncome).fold(0, (sum, item) => sum + item.amount);
  double get balance => income - expense;

  Future<bool> restoreSession() => _api.hasSession();
  Future<void> login(String username, String password, {bool register = false}) => _api.login(username, password, register: register);
  Future<void> logout() => _api.logout();

  Future<void> initialize() async {
    final cached = await _store.load();
    _allTransactions = _sort(cached.transactions);
    subBooks = cached.subBooks;
    _refreshSubBookSummaries();
    _transactionsEtag = cached.transactionsEtag;
    _subBooksEtag = cached.subBooksEtag;
    lastSyncAt = cached.lastSyncAt;
    isLoading = false;
    notifyListeners();
  }

  Future<void> sync({bool? preferLocal}) async {
    if (isSyncing) return;
    isSyncing = true;
    syncMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchTransactions(version: _transactionsEtag),
        _api.fetchSubBooks(version: _subBooksEtag),
      ]);
      final remoteTransactions = results[0] as RemoteResult<List<LedgerTransaction>>;
      final remoteSubBooks = results[1] as RemoteResult<List<LedgerSubBook>>;
      final transactionsChanged = remoteTransactions.changed && remoteTransactions.version != _transactionsEtag;
      final subBooksChanged = remoteSubBooks.changed && remoteSubBooks.version != _subBooksEtag;
      final pending = await _store.pendingOperations();
      if (preferLocal == null && pending.isNotEmpty && (transactionsChanged || subBooksChanged)) {
        syncConflict = SyncConflict(
          remoteTransactions: remoteTransactions.value ?? [],
          remoteSubBooks: remoteSubBooks.value ?? [],
          transactionsVersion: remoteTransactions.version,
          subBooksVersion: remoteSubBooks.version,
        );
        syncMessage = '检测到本地与云端都有变更，请选择覆盖方向';
        return;
      }
      if (preferLocal == true) {
        await _flushPending();
        syncConflict = null;
        final refreshed = await Future.wait([
          _api.fetchTransactions(),
          _api.fetchSubBooks(),
        ]);
        final refreshedTransactions = refreshed[0] as RemoteResult<List<LedgerTransaction>>;
        final refreshedSubBooks = refreshed[1] as RemoteResult<List<LedgerSubBook>>;
        _allTransactions = _sort(refreshedTransactions.value ?? _allTransactions);
        subBooks = refreshedSubBooks.value ?? subBooks;
        _refreshSubBookSummaries();
        _transactionsEtag = refreshedTransactions.version;
        _subBooksEtag = refreshedSubBooks.version;
        await _store.saveTransactions(_allTransactions, etag: _transactionsEtag);
        await _store.saveSubBooks(subBooks, etag: _subBooksEtag);
        syncMessage = '已用客户端数据覆盖云端';
      } else if (preferLocal == false) {
        await _store.clearPending();
        syncConflict = null;
        _allTransactions = _sort(remoteTransactions.value ?? _allTransactions);
        subBooks = remoteSubBooks.value ?? subBooks;
        _refreshSubBookSummaries();
        _transactionsEtag = remoteTransactions.version;
        _subBooksEtag = remoteSubBooks.version;
        await _store.saveTransactions(_allTransactions, etag: _transactionsEtag);
        await _store.saveSubBooks(subBooks, etag: _subBooksEtag);
        syncMessage = '已用云端数据覆盖客户端';
      } else {
        await _flushPending();
        if (transactionsChanged) {
          _allTransactions = _sort(remoteTransactions.value!);
          _refreshSubBookSummaries();
          _transactionsEtag = remoteTransactions.version;
          await _store.saveTransactions(_allTransactions, etag: _transactionsEtag);
        }
        if (subBooksChanged) {
          subBooks = remoteSubBooks.value!;
          _subBooksEtag = remoteSubBooks.version;
          await _store.saveSubBooks(subBooks, etag: _subBooksEtag);
        }
        syncMessage = transactionsChanged || subBooksChanged ? '已同步云端更新' : '已是最新数据';
      }
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
    _allTransactions = _sort([..._allTransactions, transaction]);
    _refreshSubBookSummaries();
    await _store.saveTransactions(_allTransactions);
    await _store.enqueue(SyncOperation(method: 'POST', path: '/api/transactions', body: _payload(transaction), localId: temporaryId));
    notifyListeners();
  }

  Future<void> updateTransaction(LedgerTransaction updated) async {
    _allTransactions = _sort(_allTransactions.map((item) => item.id == updated.id ? updated : item).toList());
    _refreshSubBookSummaries();
    await _store.saveTransactions(_allTransactions);
    if (updated.id > 0) {
      final payload = _payload(updated)..['id'] = updated.id;
      await _store.enqueue(SyncOperation(method: 'POST', path: '/api/transactions/sync', body: payload, localId: updated.id));
    } else {
      await _store.replacePendingForLocalId(updated.id, SyncOperation(method: 'POST', path: '/api/transactions', body: _payload(updated), localId: updated.id));
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(LedgerTransaction transaction) async {
    final tombstone = LedgerTransaction(
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      category: transaction.category,
      note: transaction.note,
      transactionDate: transaction.transactionDate,
      createdAt: transaction.createdAt,
      subBookId: transaction.subBookId,
      status: 'deleted',
    );
    _allTransactions = _allTransactions.map((item) => item.id == transaction.id ? tombstone : item).toList();
    _refreshSubBookSummaries();
    await _store.saveTransactions(_allTransactions);
    if (transaction.id > 0) {
      await _store.enqueue(SyncOperation(method: 'POST', path: '/api/transactions/sync', body: {
        ..._payload(tombstone),
        'id': transaction.id,
        'status': 'deleted',
      }, localId: transaction.id));
    } else {
      await _store.removePendingForLocalId(transaction.id);
    }
    notifyListeners();
  }

  Future<void> deleteSubBook(LedgerSubBook book) async {
    final relatedTransactions = _allTransactions.where((item) => item.subBookId == book.id && !item.isDeleted).toList();
    for (final transaction in relatedTransactions) {
      final tombstone = LedgerTransaction(
        id: transaction.id,
        type: transaction.type,
        amount: transaction.amount,
        category: transaction.category,
        note: transaction.note,
        transactionDate: transaction.transactionDate,
        createdAt: transaction.createdAt,
        subBookId: transaction.subBookId,
        status: 'deleted',
      );
      _allTransactions = _allTransactions.map((item) => item.id == transaction.id ? tombstone : item).toList();
      if (transaction.id > 0) {
        await _store.enqueue(SyncOperation(
          method: 'POST',
          path: '/api/transactions/sync',
          body: {
            ..._payload(tombstone),
            'id': transaction.id,
            'status': 'deleted',
          },
          localId: transaction.id,
        ));
      } else {
        await _store.removePendingForLocalId(transaction.id);
      }
    }
    _refreshSubBookSummaries();
    await _store.saveTransactions(_allTransactions);
    subBooks = subBooks.where((item) => item.id != book.id).toList();
    await _store.saveSubBooks(subBooks);
    if (book.id > 0) {
      await _store.enqueue(SyncOperation(method: 'DELETE', path: '/api/sub-books/${book.id}', body: null));
    } else {
      await _store.removePendingForLocalId(book.id);
      await _store.removePendingForSubBookId(book.id);
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
      var operation = pending.first;
      if (operation.method == 'DELETE' && operation.path.startsWith('/api/transactions/')) {
        final id = int.tryParse(operation.path.split('/').last);
        LedgerTransaction? tombstone;
        if (id != null) {
          for (final item in _allTransactions) {
            if (item.id == id) {
              tombstone = item;
              break;
            }
          }
        }
        if (tombstone != null) {
          operation = SyncOperation(
            method: 'POST',
            path: '/api/transactions/sync',
            body: {
              ..._payload(tombstone),
              'id': id,
              'status': 'deleted',
            },
            localId: id,
          );
        }
      }
      final response = await _api.send(operation);
      if (operation.method == 'POST' && operation.path == '/api/transactions' && operation.localId != null) {
        final decoded = jsonDecode(response.body);
        final remoteId = decoded is Map<String, dynamic> ? (decoded['id'] as num?)?.toInt() : null;
        if (remoteId != null && operation.localId! < 0) {
          final oldId = operation.localId!;
          _allTransactions = _allTransactions
              .map((item) => item.id == oldId ? LedgerTransaction(id: remoteId, type: item.type, amount: item.amount, category: item.category, note: item.note, transactionDate: item.transactionDate, createdAt: item.createdAt, subBookId: item.subBookId, status: item.status) : item)
              .toList();
          await _store.replaceTransactionId(oldId, remoteId);
          await _store.saveTransactions(_allTransactions);
          notifyListeners();
        }
      }
      if (operation.method == 'POST' && operation.path == '/api/sub-books' && operation.localId != null) {
        final decoded = jsonDecode(response.body);
        final remoteId = decoded is Map<String, dynamic> ? (decoded['id'] as num?)?.toInt() : null;
        if (remoteId != null && operation.localId! < 0) {
          final oldId = operation.localId!;
          subBooks = subBooks
              .map((book) => book.id == oldId ? LedgerSubBook(id: remoteId, name: book.name, eventDate: book.eventDate, transactions: book.transactions, remoteIncome: book.remoteIncome, remoteExpense: book.remoteExpense, remoteTransactionCount: book.remoteTransactionCount) : book)
              .toList();
          _allTransactions = _allTransactions
              .map((item) => item.subBookId == oldId ? LedgerTransaction(id: item.id, type: item.type, amount: item.amount, category: item.category, note: item.note, transactionDate: item.transactionDate, createdAt: item.createdAt, subBookId: remoteId, status: item.status) : item)
              .toList();
          await _store.replaceSubBookId(oldId, remoteId);
          _refreshSubBookSummaries();
          await _store.saveSubBooks(subBooks);
          await _store.saveTransactions(_allTransactions);
          notifyListeners();
        }
      }
      await _store.removeFirstPending();
    }
  }

  int _nextTemporaryId() => -DateTime.now().microsecondsSinceEpoch;
  List<LedgerTransaction> _sort(List<LedgerTransaction> source) => [...source]..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

  void _refreshSubBookSummaries() {
    final active = transactions;
    subBooks = subBooks.map((book) {
      final hasCachedItems = _allTransactions.any((item) => item.subBookId == book.id);
      if (!hasCachedItems && book.remoteIncome != null && book.remoteExpense != null && book.remoteTransactionCount != null) {
        return book;
      }
      final items = active.where((item) => item.subBookId == book.id).toList();
      final income = items.where((item) => item.isIncome).fold<double>(0, (sum, item) => sum + item.amount);
      final expense = items.where((item) => !item.isIncome).fold<double>(0, (sum, item) => sum + item.amount);
      return LedgerSubBook(
        id: book.id,
        name: book.name,
        eventDate: book.eventDate,
        transactions: items,
        remoteIncome: income,
        remoteExpense: expense,
        remoteTransactionCount: items.length,
      );
    }).toList();
  }
  Map<String, dynamic> _payload(LedgerTransaction item) => {
        'type': item.type,
        'amount': item.amount,
        'category': item.category,
        'categorySource': 'system',
        'note': item.note,
        'transactionDate': _date(item.transactionDate),
        if (item.subBookId != null) 'subBookId': item.subBookId,
      };
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class SyncConflict {
  const SyncConflict({required this.remoteTransactions, required this.remoteSubBooks, this.transactionsVersion, this.subBooksVersion});
  final List<LedgerTransaction> remoteTransactions;
  final List<LedgerSubBook> remoteSubBooks;
  final String? transactionsVersion;
  final String? subBooksVersion;
}
