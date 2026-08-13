import 'package:flutter/material.dart';

class LedgerTheme {
  static const paper = Color(0xFFF3EFE5);
  static const paperDeep = Color(0xFFE8E1D3);
  static const ink = Color(0xFF202522);
  static const muted = Color(0xFF68706A);
  static const line = Color(0xFFD6D0C4);
  static const white = Color(0xFFFBFAF6);
  static const cobalt = Color(0xFF2455D6);
  static const mint = Color(0xFFCFE4D0);
  static const coral = Color(0xFFF2B29D);
  static const yellow = Color(0xFFF0D36E);

  static ThemeData build() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: cobalt, brightness: Brightness.light).copyWith(
          primary: cobalt,
          onPrimary: Colors.white,
          surface: white,
          onSurface: ink,
          outline: line,
        ),
        fontFamily: 'sans-serif',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600, color: ink),
          titleLarge: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600, color: ink),
          bodyMedium: TextStyle(color: ink, height: 1.45),
          labelMedium: TextStyle(color: muted, letterSpacing: 1.1),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: cobalt, width: 2)),
        ),
        cardTheme: CardThemeData(color: white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: line))),
      );
}
