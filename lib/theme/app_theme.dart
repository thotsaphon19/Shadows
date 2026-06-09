// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Colors ──────────────────────────────────────────────────
class AppColors {
  static const primary      = Color(0xFF2E7D32);
  static const primaryDark  = Color(0xFF1B5E20);
  static const primaryMid   = Color(0xFF388E3C);
  static const primaryLight = Color(0xFF4CAF50);
  static const surface50    = Color(0xFFE8F5E9);
  static const surface100   = Color(0xFFC8E6C9);
  static const surface200   = Color(0xFFA5D6A7);
  static const gold         = Color(0xFFF5A623);
  static const goldLight    = Color(0xFFFFF3E0);
  static const bg           = Color(0xFFF5F5F5);
  static const white        = Color(0xFFFFFFFF);
  static const border       = Color(0xFFE0E0E0);
  static const text         = Color(0xFF1A1A1A);
  static const textSub      = Color(0xFF555555);
  static const textHint     = Color(0xFF999999);
  static const error        = Color(0xFFE53935);
  static const scoreGreen   = Color(0xFF4CAF50);
  static const waveOrange   = Color(0xFFFF6B35);
  static const waveGreen    = Color(0xFF66BB6A);
}

// ─── Theme ────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: false,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'NotoSans',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: AppColors.white,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 17, fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSans', fontSize: 15, fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'NotoSans'),
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 0),
  );
}

// ─── Text Styles ─────────────────────────────────────────────
class AppText {
  static const h1 = TextStyle(fontFamily: 'NotoSans', fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark, height: 1.25);
  static const h2 = TextStyle(fontFamily: 'NotoSans', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.3);
  static const h3 = TextStyle(fontFamily: 'NotoSans', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text);
  static const body = TextStyle(fontFamily: 'NotoSans', fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.text, height: 1.6);
  static const small = TextStyle(fontFamily: 'NotoSans', fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSub);
  static const tiny = TextStyle(fontFamily: 'NotoSans', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textHint);
  static const label = TextStyle(fontFamily: 'NotoSans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text);
  static const btn = TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white);
}
