import 'package:flutter/material.dart';

import 'core/design_system.dart';
import 'features/auth/auth_gate.dart';

class VibeitApp extends StatelessWidget {
  const VibeitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        textTheme: textTheme,
        colorScheme: ColorScheme.dark(
          surface: AppColors.background,
          primary: AppColors.accent,
          secondary: AppColors.accent,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: AppButtonStyles.primary),
        outlinedButtonTheme: OutlinedButtonThemeData(style: AppButtonStyles.subtle),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
            borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
          ),
          hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        dividerColor: AppColors.border,
        cardColor: AppColors.surface,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surface,
          contentTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
