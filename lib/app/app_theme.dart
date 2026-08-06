import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF00BFA6);
  static const error = Color(0xFFFF6B6B);
  static const background = Color(0xFFF8F7FF);

  static ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      error: error,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withOpacity(0.1),
      selectedColor: primary,
      labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 22),
      titleLarge: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 18),
      titleMedium: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14),
      bodyMedium: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
      bodySmall: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.black54),
    ),
  );

  static ThemeData get theme => light;
}
