import 'package:flutter/material.dart';

/// تم اصلی برنامه — مدرن، آرام و منسجم با لهجهٔ بنفش و پس‌زمینهٔ روشن.
class AppTheme {
  // پالت اصلی (بنفش ارغوانی ملایم + فیروزه‌ای).
  static const primary = Color(0xFF6750A4); // بنفش ارغوانی M3
  static const primaryDark = Color(0xFF4F3B8A);
  static const secondary = Color(0xFF00897B); // فیروزه‌ای
  static const accent = Color(0xFFFB8C00); // نارنجی (برای نکات/هشدار)
  static const error = Color(0xFFD32F2F);
  static const background = Color(0xFFFAF8FF);
  static const surface = Color(0xFFFFFFFF);

  /// گرادیان هدر دستیار.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CBF), Color(0xFF6750A4), Color(0xFF4F3B8A)],
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x14000000)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: primary, width: 1.3),
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.08),
        selectedColor: primary,
        labelStyle: const TextStyle(
            fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.black87),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1A000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1A000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(
            fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 19),
        titleMedium: TextStyle(
            fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, height: 1.5),
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
        elevation: 5,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x12000000),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static ThemeData get theme => light;
}
