import 'package:flutter/material.dart';

abstract final class AppColors {
  static const postmanOrange = Color(0xFFFF6C37);
  static const postmanOrangeDark = Color(0xFFD94A18);
  static const postmanOrangeSoft = Color(0xFFFFEEE8);

  static const white = Color(0xFFFFFFFF);
  static const whiteSmoke = Color(0xFFF7F7F7);
  static const ink = Color(0xFF202124);
  static const mutedInk = Color(0xFF697077);
  static const border = Color(0xFFE3E4E6);

  static const success = Color(0xFF168344);
  static const successSoft = Color(0xFFEAF6EE);
  static const info = Color(0xFF2563D9);
  static const infoSoft = Color(0xFFEAF1FF);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFDECEB);

  // Compatibility aliases for the existing, unmodified onboarding widgets.
  static const warning = postmanOrangeDark;
  static const warningSoft = postmanOrangeSoft;
  static const navy = ink;
  static const warmSurface = whiteSmoke;
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.postmanOrange,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.postmanOrange,
          onPrimary: Colors.white,
          secondary: AppColors.ink,
          onSecondary: Colors.white,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          outline: AppColors.border,
          error: AppColors.error,
          onError: Colors.white,
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.whiteSmoke,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: AppColors.ink,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.15,
        ),
        headlineMedium: const TextStyle(
          color: AppColors.ink,
          fontSize: 27,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.18,
        ),
        titleLarge: const TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleMedium: const TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: AppColors.mutedInk,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteSmoke,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.postmanOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.mutedInk,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.postmanOrangeDark,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.postmanOrangeDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.square(48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9A9EA3)),
        labelStyle: const TextStyle(color: AppColors.mutedInk),
        prefixIconColor: AppColors.mutedInk,
        suffixIconColor: AppColors.mutedInk,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.postmanOrange,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.postmanOrange
                : AppColors.mutedInk,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.postmanOrange
                : AppColors.mutedInk,
            size: 25,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
