import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF12715E);

  static const brand = _seed;
  static const brandHover = Color(0xFF0F7B64);
  static const brandPressed = Color(0xFF11524E);
  static const brandTint = Color(0xFFE8F5F1);
  static const brandTintLine = Color(0xFFBFE2D8);
  static const onBrandTint = Color(0xFF096B52);

  static const gold = Color(0xFFE6A93C);
  static const goldLight = Color(0xFFFFD77A);
  static const goldFill = Color(0xFFFFF6E2);

  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoYellowBorder = Color(0xFFE7D200);
  static const socialTextDark = Color(0xFF111111);

  static const surface = Color(0xFFF6F8F7);
  static const surfaceRaised = Colors.white;
  static const surfaceSunken = Color(0xFFEEF2F0);
  static const skeleton = Color(0xFFE8ECEA);

  static const textStrong = Color(0xFF16211D);
  static const textBody = Color(0xFF2E3A35);
  static const textWeak = Color(0xFF5B6A64);
  static const textFaint = Color(0xFF8A968F);
  static const textOnBrand = Colors.white;

  static const border = Color(0xFFD8E0DC);
  static const borderStrong = Color(0xFFC2CEC8);
  static const divider = Color(0xFFE4EAE7);

  static const success = Color(0xFF096B52);
  static const successFill = Color(0xFFE8F5F1);
  static const successBorder = Color(0xFFBFE2D8);

  static const warning = Color(0xFF8A5A00);
  static const warningStrong = Color(0xFFB26C00);
  static const warningFill = Color(0xFFFFF3DE);
  static const warningBorder = Color(0xFFF0D3A2);

  static const danger = Color(0xFF9A3025);
  static const dangerStrong = Color(0xFFB9382A);
  static const dangerFill = Color(0xFFFCECEB);
  static const dangerBorder = Color(0xFFF3C4C1);

  static const info = Color(0xFF1F5E8A);
  static const infoFill = Color(0xFFE9F2FA);
  static const infoBorder = Color(0xFFBBD6EC);

  static const neutral = Color(0xFF42514B);
  static const neutralFill = Colors.white;
  static const neutralBorder = border;

  static const pagePadding = 20.0;
  static const sectionGap = 10.0;
  static const cardPadding = 16.0;

  static const radiusSm = 10.0;
  static const radiusMd = 12.0;
  static const radiusLg = 14.0;
  static const radiusXl = 16.0;
  static const radius2xl = 18.0;
  static const radiusPill = 999.0;

  static const controlHeight = 52.0;
  static const controlHeightSmall = 40.0;
  static const tapTargetMin = 44.0;

  static const elementWood = Color(0xFF1F8A5B);
  static const elementWoodFill = Color(0xFFE4F3EC);
  static const elementWoodLine = Color(0xFFBCE0CD);
  static const elementFire = Color(0xFFE14C3A);
  static const elementFireFill = Color(0xFFFCE9E6);
  static const elementFireLine = Color(0xFFF5C7C0);
  static const elementEarth = Color(0xFFF0C24A);
  static const elementEarthFill = Color(0xFFFDF4DE);
  static const elementEarthLine = Color(0xFFF0DCA6);
  static const elementMetal = Color(0xFF9CA3AF);
  static const elementMetalFill = Color(0xFFF1F3F5);
  static const elementMetalLine = Color(0xFFD9DEE3);
  static const elementWater = Color(0xFF0F172A);
  static const elementWaterFill = Color(0xFFE7EAF0);
  static const elementWaterLine = Color(0xFFC3CAD8);

  static Color elementColor(String key) {
    switch (key) {
      case 'wood':
        return elementWood;
      case 'fire':
        return elementFire;
      case 'earth':
        return elementEarth;
      case 'metal':
        return elementMetal;
      case 'water':
        return elementWater;
    }
    return surfaceSunken;
  }

  static Color elementFill(String key) {
    switch (key) {
      case 'wood':
        return elementWoodFill;
      case 'fire':
        return elementFireFill;
      case 'earth':
        return elementEarthFill;
      case 'metal':
        return elementMetalFill;
      case 'water':
        return elementWaterFill;
    }
    return surfaceSunken;
  }

  static String elementLabel(String key) {
    switch (key) {
      case 'wood':
        return '목';
      case 'fire':
        return '화';
      case 'earth':
        return '토';
      case 'metal':
        return '금';
      case 'water':
        return '수';
    }
    return '';
  }

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
      dividerColor: divider,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: textStrong),
        headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: textStrong),
        headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: textStrong),
        titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: textStrong),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: textStrong),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: textBody),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: textWeak),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: textWeak),
        labelLarge:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, controlHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, controlHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg)),
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          side: const BorderSide(color: border),
        ),
        color: WidgetStateProperty.resolveWith((_) => surfaceRaised),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceRaised,
        indicatorColor: brandTint,
        height: 74,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? onBrandTint : textWeak,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? textStrong : textWeak,
          );
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: brand,
        labelColor: textStrong,
        unselectedLabelColor: textWeak,
        dividerColor: divider,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textStrong,
        contentTextStyle: const TextStyle(
          color: textOnBrand,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        side: const BorderSide(color: borderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return surfaceRaised;
        }),
        checkColor: WidgetStateProperty.all(textOnBrand),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return surfaceRaised;
          return textFaint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return borderStrong;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return brandTint;
            return surfaceRaised;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return onBrandTint;
            return textWeak;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: brandTintLine);
            }
            return const BorderSide(color: border);
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 14,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            );
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg),
            ),
          ),
        ),
      ),
    );
  }
}
