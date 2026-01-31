import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light mode base colors
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF9FAFB);
  static const accent = Color(0xFF2867ED);
  static const accentActive = Color(0xFF1E54C6);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFEF4444);

  // Pastel card backgrounds
  static const spotifyCardBg = Color(0xFFECFDF5);
  static const ytmCardBg = Color(0xFFFEF7ED);

  // Brand colors
  static const spotifyGreen = Color(0xFF1DB954);
  static const ytmRed = Color(0xFFFF2D55);
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
    titleMedium: GoogleFonts.spaceGrotesk(
      fontSize: 18,
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
      const base = Colors.white;
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

  static ButtonStyle neutral = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(AppColors.surface),
    foregroundColor: WidgetStateProperty.all(AppColors.textPrimary),
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: WidgetStatePropertyAll(
      GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );

  /// White background button with dark text and subtle shadow - for light mode action buttons
  static ButtonStyle lightAction = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.white.withValues(alpha: 0.7);
      }
      if (states.contains(WidgetState.pressed)) {
        return AppColors.surface;
      }
      return Colors.white;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.disabled)
          ? AppColors.textPrimary.withValues(alpha: 0.4)
          : AppColors.textPrimary;
    }),
    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    ),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return 0;
      return 2;
    }),
    shadowColor: WidgetStatePropertyAll(
      Colors.black.withValues(alpha: 0.08),
    ),
    textStyle: WidgetStatePropertyAll(
      GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  /// Wider neutral button for logout
  static ButtonStyle neutralWide = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(AppColors.surface),
    foregroundColor: WidgetStateProperty.all(AppColors.textPrimary),
    minimumSize: const WidgetStatePropertyAll(Size(160, 48)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 40, vertical: 12),
    ),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: WidgetStatePropertyAll(
      GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];
}

