import 'package:flutter/material.dart';

abstract final class AppColors {
  static const postmanOrange = Color(0xFFFF6C37);
  static const postmanOrangeDark = Color(0xFFC74414);
  static const postmanOrangeSoft = Color(0xFFFFE3D8);
  static const whiteSmoke = Color(0xFFF5F5F5);
  static const ink = Color(0xFF2B211D);
  static const mutedInk = Color(0xFF6E625D);
  static const border = Color(0xFFE7DDD8);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.postmanOrange,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.postmanOrange,
          onPrimary: AppColors.ink,
          secondary: AppColors.postmanOrangeDark,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: AppColors.ink,
          outline: AppColors.border,
        );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.whiteSmoke,
      useMaterial3: true,
    );

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.postmanOrange,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.postmanOrangeDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.postmanOrangeDark,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    );
  }
}
