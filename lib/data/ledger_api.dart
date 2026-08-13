import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/sub_book.dart';
import '../models/transaction.dart';
import 'ledger_store.dart';

class RemoteResult<T> {
  const RemoteResult({this.value, this.version, required this.changed});

  final T? value;
  final String? version;
  final bool changed;
}

class LedgerApi {
  LedgerApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _cookie;
  static const _secureStorage = FlutterSecureStorage();

  Future<bool> hasSession() async {
    _cookie = await _secureStorage.read(key: 'ledger.session.cookie.v1');
    return _cookie != null && _cookie!.isNotEmpty;
  }

  Future<void> login(String username, String password, {bool register = false}) async {
    final response = await _client.post(
      _uri(register ? '/api/auth/register' : '/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    _requireSuccess(response);
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || !setCookie.contains('ledger_session=')) {
      throw StateError('登录响应未包含会话');
    }
    _cookie = setCookie.split(';').first;
    await _secureStorage.write(key: 'ledger.session.cookie.v1', value: _cookie);
  }

  Future<void> logout() async {
    try {
      await _client.post(_uri('/api/auth/logout'), headers: _sessionHeaders());
    } finally {
      _cookie = null;
      await _secureStorage.delete(key: 'ledger.session.cookie.v1');
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<RemoteResult<List<LedgerTransaction>>> fetchTransactions({String? version}) async {
    final response = await _client.get(_uri('/api/transactions'), headers: {..._sessionHeaders(), ..._etagHeaders(version)});
    if (response.statusCode == 304) return const RemoteResult(changed: false);
    _requireSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return RemoteResult(
      value: list.map((item) => LedgerTransaction.fromJson(item as Map<String, dynamic>)).toList(),
      version: _version(response),
      changed: true,
    );
  }

  Future<RemoteResult<List<LedgerSubBook>>> fetchSubBooks({String? version}) async {
    final response = await _client.get(_uri('/api/sub-books'), headers: {..._sessionHeaders(), ..._etagHeaders(version)});
    if (response.statusCode == 304) return const RemoteResult(changed: false);
    _requireSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return RemoteResult(
      value: list.map((item) => LedgerSubBook.fromJson(item as Map<String, dynamic>)).toList(),
      version: _version(response),
      changed: true,
    );
  }

  Future<http.Response> send(SyncOperation operation) async {
    final request = http.Request(operation.method, _uri(operation.path));
    request.headers.addAll({..._sessionHeaders(), 'Content-Type': 'application/json'});
    if (operation.body != null) request.body = jsonEncode(operation.body);
    final response = await http.Response.fromStream(await _client.send(request));
    // A DELETE of an already-removed resource is idempotent for sync purposes.
    if (response.statusCode == 404 && operation.method == 'DELETE') return response;
    _requireSuccess(response);
    return response;
  }

  String _version(http.Response response) {
    final etag = response.headers['etag'];
    return etag == null ? 'body:${response.body}' : 'etag:$etag';
  }

  Map<String, String> _etagHeaders(String? version) {
    if (version == null || !version.startsWith('etag:')) return {};
    return {'If-None-Match': version.substring(5)};
  }

  Map<String, String> _sessionHeaders() => _cookie == null ? {} : {'Cookie': _cookie!};

  void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw StateError('云端请求失败 (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}');
    }
  }
}
