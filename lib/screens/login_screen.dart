import 'package:flutter/material.dart';

import '../data/ledger_controller.dart';
import '../theme/ledger_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller, required this.onAuthenticated, required this.onContinueOffline});
  final LedgerController controller;
  final VoidCallback onAuthenticated;
  final VoidCallback onContinueOffline;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() { _username.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final username = _username.text.trim();
    if (username.length < 3 || _password.text.length < 8) { setState(() => _error = '用户名至少 3 个字符，密码至少 8 个字符。'); return; }
    setState(() { _busy = true; _error = null; });
    try { await widget.controller.login(username, _password.text, register: _register); widget.onAuthenticated(); }
    catch (error) { setState(() => _error = error.toString().replaceFirst('Bad state: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: LedgerTheme.paper, body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ledger', style: TextStyle(fontFamily: 'serif', fontSize: 42, fontWeight: FontWeight.w700)), const Text('PERSONAL FINANCE', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: LedgerTheme.muted)), const SizedBox(height: 42), Text(_register ? '创建你的账本' : '欢迎回来', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 22), TextField(controller: _username, decoration: const InputDecoration(labelText: '用户名')), const SizedBox(height: 14), TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: '密码')), const SizedBox(height: 12), if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFBD543F))), const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '处理中…' : (_register ? '注册' : '登录')))), TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? '已有账号？登录' : '还没有账号？注册')), const Divider(height: 28), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: widget.onContinueOffline, icon: const Icon(Icons.wifi_off_outlined), label: const Text('离线使用缓存'))]))))));
}
