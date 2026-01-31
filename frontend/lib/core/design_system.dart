import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF121826);
  static const accent = Color(0xFF2867ED);
  static const accentActive = Color(0xFF1E54C6);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFF1E293B);
  static const error = Color(0xFFEF4444);
}

class AppTypography {
  static TextTheme textTheme = GoogleFonts.spaceGroteskTextTheme().copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(
      fontSize: 42,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.2,
    ),
    titleLarge: GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: GoogleFonts.spaceGrotesk(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: 0.1,
    ),
    bodyMedium: GoogleFonts.spaceGrotesk(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelLarge: GoogleFonts.spaceGrotesk(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: 0.2,
    ),
  );
}

class AppDecorations {
  static InputDecoration lineInput({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      filled: false,
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 1.6),
      ),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  static InputDecoration input({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class AppButtonStyles {
  static ButtonStyle primary = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.accent.withValues(alpha: 0.4);
      }
      if (states.contains(WidgetState.pressed)) {
        return AppColors.accentActive;
      }
      return AppColors.accent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final base = AppColors.textPrimary;
      return states.contains(WidgetState.disabled) ? base.withValues(alpha: 0.4) : base;
    }),
    minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    textStyle: WidgetStatePropertyAll(
      GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    overlayColor: const WidgetStatePropertyAll(AppColors.accentActive),
  );

  static ButtonStyle subtle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textSecondary,
    side: const BorderSide(color: AppColors.border),
    minimumSize: const Size(0, 52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
  );
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 18,
      spreadRadius: 0,
      offset: const Offset(0, 12),
    ),
  ];
}
