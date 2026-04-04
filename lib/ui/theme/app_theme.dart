import 'package:flutter/material.dart';

/// Dark theme optimized for in-car use (night driving).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: const CardTheme(
          color: Color(0xFF1A1A1A),
          elevation: 2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          elevation: 0,
        ),
      );
}
