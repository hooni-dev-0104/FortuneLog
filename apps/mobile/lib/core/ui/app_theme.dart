import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF12715E);
  static const surface = Color(0xFFF6F8F7);
  static const surfaceRaised = Colors.white;
  static const textStrong = Color(0xFF16211D);
  static const textWeak = Color(0xFF5B6A64);
  static const border = Color(0xFFD8E0DC);
  static const danger = Color(0xFFB9382A);
  static const warning = Color(0xFFB26C00);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Pretendard',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2, color: textStrong),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, color: textStrong),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: textStrong),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: textStrong),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: textStrong),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: textStrong),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: textWeak),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: textWeak),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
        color: surfaceRaised,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: border),
        ),
        color: WidgetStateProperty.resolveWith((_) => surfaceRaised),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
