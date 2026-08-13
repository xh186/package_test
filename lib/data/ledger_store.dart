import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sub_book.dart';
import '../models/transaction.dart';

class SyncOperation {
  const SyncOperation({required this.method, required this.path, required this.body, this.localId});

  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final int? localId;

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        method: json['method'] as String,
        path: json['path'] as String,
        body: (json['body'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
        localId: (json['localId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {'method': method, 'path': path, 'body': body, if (localId != null) 'localId': localId};
}

class CachedLedger {
  const CachedLedger({
    required this.transactions,
    required this.subBooks,
    this.transactionsEtag,
    this.subBooksEtag,
    this.lastSyncAt,
  });

  final List<LedgerTransaction> transactions;
  final List<LedgerSubBook> subBooks;
  final String? transactionsEtag;
  final String? subBooksEtag;
  final DateTime? lastSyncAt;
}

class LedgerStore {
  static const _transactionsKey = 'ledger.transactions.v1';
  static const _subBooksKey = 'ledger.sub_books.v1';
  static const _transactionsEtagKey = 'ledger.transactions.etag.v1';
  static const _subBooksEtagKey = 'ledger.sub_books.etag.v1';
  static const _pendingKey = 'ledger.pending_sync.v1';
  static const _lastSyncAtKey = 'ledger.last_sync_at.v1';

  Future<CachedLedger> load() async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = _decodeList(prefs.getString(_transactionsKey))
        .map(LedgerTransaction.fromJson)
        .toList();
    final subBooks = _decodeList(prefs.getString(_subBooksKey)).map(LedgerSubBook.fromJson).toList();
    return CachedLedger(
      transactions: transactions,
      subBooks: subBooks,
      transactionsEtag: prefs.getString(_transactionsEtagKey),
      subBooksEtag: prefs.getString(_subBooksEtagKey),
      lastSyncAt: DateTime.tryParse(prefs.getString(_lastSyncAtKey) ?? ''),
    );
  }

  Future<void> saveTransactions(List<LedgerTransaction> values, {String? etag}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transactionsKey, jsonEncode(values.map((item) => item.toJson()).toList()));
    if (etag != null) await prefs.setString(_transactionsEtagKey, etag);
  }

  Future<void> saveSubBooks(List<LedgerSubBook> values, {String? etag}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subBooksKey, jsonEncode(values.map((item) => item.toJson()).toList()));
    if (etag != null) await prefs.setString(_subBooksEtagKey, etag);
  }

  Future<void> saveLastSyncAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncAtKey, value.toIso8601String());
  }

  Future<List<SyncOperation>> pendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(_pendingKey)).map(SyncOperation.fromJson).toList();
  }

  Future<void> enqueue(SyncOperation operation) async {
    final pending = await pendingOperations();
    pending.add(operation);
    await _savePending(pending);
  }

  Future<void> removeFirstPending() async {
    final pending = await pendingOperations();
    if (pending.isNotEmpty) pending.removeAt(0);
    await _savePending(pending);
  }

  Future<void> replacePendingForLocalId(int localId, SyncOperation replacement) async {
    final pending = await pendingOperations();
    final index = pending.indexWhere((item) => item.localId == localId);
    if (index == -1) {
      pending.add(replacement);
    } else {
      pending[index] = replacement;
    }
    await _savePending(pending);
  }

  Future<void> removePendingForLocalId(int localId) async {
    final pending = await pendingOperations();
    pending.removeWhere((item) => item.localId == localId);
    await _savePending(pending);
  }

  Future<void> removePendingForSubBookId(int subBookId) async {
    final pending = await pendingOperations();
    pending.removeWhere((item) => item.body?['subBookId'] == subBookId);
    await _savePending(pending);
  }

  Future<void> replaceSubBookId(int oldId, int newId) async {
    final pending = await pendingOperations();
    for (var index = 0; index < pending.length; index++) {
      final operation = pending[index];
      final body = operation.body == null ? null : <String, dynamic>{...operation.body!};
      if (body != null && body['subBookId'] == oldId) body['subBookId'] = newId;
      pending[index] = SyncOperation(
        method: operation.method,
        path: operation.path,
        body: body,
        localId: operation.localId,
      );
    }
    await _savePending(pending);
  }

  Future<void> replaceTransactionId(int oldId, int newId) async {
    final pending = await pendingOperations();
    for (var index = 0; index < pending.length; index++) {
      final operation = pending[index];
      final body = operation.body == null ? null : <String, dynamic>{...operation.body!};
      if (body != null && body['id'] == oldId) body['id'] = newId;
      pending[index] = SyncOperation(
        method: operation.method,
        path: operation.path,
        body: body,
        localId: operation.localId == oldId ? newId : operation.localId,
      );
    }
    await _savePending(pending);
  }

  Future<void> clearPending() async {
    await _savePending([]);
  }

  Future<void> _savePending(List<SyncOperation> pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(pending.map((item) => item.toJson()).toList()));
  }

  List<Map<String, dynamic>> _decodeList(String? source) {
    if (source == null || source.isEmpty) return [];
    final value = jsonDecode(source) as List<dynamic>;
    return value.map((item) => (item as Map<String, dynamic>).cast<String, dynamic>()).toList();
  }
}
