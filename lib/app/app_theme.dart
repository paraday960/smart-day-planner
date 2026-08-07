import 'package:flutter/material.dart';

/// تم اصلی برنامه — مدرن، نرم و جذاب با لهجه‌ی بنفش-فیروزه‌ای.
class AppTheme {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4A3FBF);
  static const secondary = Color(0xFF00BFA6);
  static const accent = Color(0xFFFF8A65);
  static const error = Color(0xFFFF6B6B);
  static const background = Color(0xFFF6F5FF);
  static const surface = Colors.white;

  /// گرادیان هدر دستیار.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark, Color(0xFF8B5CF6)],
  );

  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: error,
        brightness: Brightness.light,
        surface: surface,
      ),
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: primary, width: 1.4),
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.08),
        selectedColor: primary,
        labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.black87),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14),
        bodyMedium: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
        bodySmall: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.black54),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }

  static ThemeData get theme => light;
}
