import 'package:flutter/material.dart';

import 'data/ledger_api.dart';
import 'data/ledger_controller.dart';
import 'data/ledger_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/ledger_theme.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://ledger.example.com');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = LedgerController(store: LedgerStore(), api: LedgerApi(baseUrl: _apiBaseUrl));
  runApp(LedgerApp(controller: controller));
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key, required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ledger',
        theme: LedgerTheme.build(),
        home: _AuthGate(controller: controller),
      );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.controller});
  final LedgerController controller;
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool? _hasSession;
  @override
  void initState() { super.initState(); _check(); }
  Future<void> _check() async { final has = await widget.controller.restoreSession(); if (mounted) setState(() => _hasSession = has); }
  @override
  Widget build(BuildContext context) {
    if (_hasSession == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _hasSession! ? HomeScreen(controller: widget.controller) : LoginScreen(controller: widget.controller, onContinueOffline: () => setState(() => _hasSession = true), onAuthenticated: () => setState(() => _hasSession = true));
  }
}
