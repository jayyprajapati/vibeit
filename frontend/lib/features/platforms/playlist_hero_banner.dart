import 'package:flutter/material.dart';

import '../../core/design_system.dart';

class PlaylistHeroBanner extends StatelessWidget {
  const PlaylistHeroBanner({
    super.key,
    required this.title,
    required this.colors,
    this.heightFactor = 0.18,
    this.height,
    this.showBack = true,
    this.onBack,
    this.helperText,
    this.textColor = Colors.white,
    this.badgeLabel,
  });

  final String title;
  final List<Color> colors;
  final double heightFactor;
  final double? height;
  final bool showBack;
  final VoidCallback? onBack;
  final String? helperText;
  final Color textColor;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final resolvedHeight =
        height ?? (media.size.height * heightFactor).clamp(140.0, 220.0);

    return Container(
      width: double.infinity,
      height: resolvedHeight,
      padding: EdgeInsets.fromLTRB(20, media.padding.top + 12, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 32,
            right: -18,
            child: Opacity(
              opacity: 0.08,
              child: Icon(
                Icons.music_note_rounded,
                size: 90,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: -24,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                Icons.headphones_rounded,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
          if (showBack)
            Positioned(
              top: media.padding.top,
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                color: AppColors.textPrimary,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helperText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    helperText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badgeLabel != null)
            Positioned(
              top: media.padding.top + 10,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
