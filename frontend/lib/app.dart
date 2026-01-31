import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/design_system.dart';
import 'core/theme_provider.dart';
import 'features/auth/auth_gate.dart';

class VibeitApp extends ConsumerWidget {
  const VibeitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: toFlutterThemeMode(themeMode),
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const AuthGate(),
    );
  }

  ThemeData _buildLightTheme() {
    final textTheme = AppTypography.textTheme;
    
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: ColorScheme.light(
        surface: AppColors.background,
        primary: AppColors.accent,
        secondary: AppColors.accent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    // Dark mode colors
    const darkBg = Color(0xFF0F1419);
    const darkSurface = Color(0xFF1A1F26);
    const darkBorder = Color(0xFF2D3541);
    const darkTextPrimary = Color(0xFFF1F5F9);
    const darkTextSecondary = Color(0xFFA8B4C4);
    const darkTextMuted = Color(0xFF6B7A8C);
    
    final textTheme = GoogleFonts.spaceGroteskTextTheme().copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: darkTextPrimary,
        letterSpacing: 0.1,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: darkTextSecondary,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
        letterSpacing: 0.2,
      ),
    );
    
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,
      textTheme: textTheme,
      colorScheme: ColorScheme.dark(
        surface: darkBg,
        primary: AppColors.accent,
        secondary: AppColors.accent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        foregroundColor: darkTextPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: AppButtonStyles.primary),
      outlinedButtonTheme: OutlinedButtonThemeData(style: AppButtonStyles.subtle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextMuted),
      ),
      dividerColor: darkBorder,
      cardColor: darkSurface,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: darkTextMuted,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
