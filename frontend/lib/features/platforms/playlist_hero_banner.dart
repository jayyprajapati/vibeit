import 'package:flutter/material.dart';
import '../../core/design_system.dart';

class PlaylistHeroBanner extends StatelessWidget {
  const PlaylistHeroBanner({
    super.key,
    required this.title,
    required this.colors,
    this.icon,
    this.heightFactor = 0.18,
  });

  final String title;
  final List<Color> colors;
  final IconData? icon;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height * heightFactor).clamp(140.0, 220.0);

    return Container(
      width: double.infinity,
      height: height,
      padding: EdgeInsets.fromLTRB(20, media.padding.top + 12, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (icon != null)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.textPrimary),
              ),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
