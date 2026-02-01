import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light mode base colors
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF9FAFB);
  static const accent = Color(0xFF1E4ED8);
  static const accentActive = Color(0xFF163DAF);
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

  // Success toast base
  static const success = Color(0xFF22C55E);
}

class AppGradients {
  static const blue = LinearGradient(
    colors: [Color(0xFF1E4ED8), Color(0xFF5B8CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const spotify = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ytm = LinearGradient(
    colors: [Color(0xFFFF4D4D), Color(0xFFFF8B5F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const success = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
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
      return states.contains(WidgetState.disabled)
          ? base.withValues(alpha: 0.4)
          : base;
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
    textStyle: GoogleFonts.spaceGrotesk(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
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
    shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
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

/// Light gradient backgrounds for platform hero sections
class AppHeroGradients {
  static const spotify = LinearGradient(
    colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ytm = LinearGradient(
    colors: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Playful neutral — warm purple-lavender tint (NOT blue)
  static const app = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Playful soft gradients for card title areas
class AppCardTitleGradients {
  static const playful = LinearGradient(
    colors: [Color(0xFFFDF4FF), Color(0xFFFAE8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const spotify = LinearGradient(
    colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ytm = LinearGradient(
    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Clean card container for dashboard playlist cards
class AppCardDecorations {
  static BoxDecoration clean(BuildContext context) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Playlist row decoration with subtle shadow
  static BoxDecoration row(BuildContext context) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

/// Text button with hover background reveal (no underline)
class AppTextButton extends StatefulWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<AppTextButton> createState() => _AppTextButtonState();
}

class _AppTextButtonState extends State<AppTextButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backwards compatibility alias
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTextButton(label: label, onTap: onTap);
  }
}

