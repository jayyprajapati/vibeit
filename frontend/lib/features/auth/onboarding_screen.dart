import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/models/platform_access.dart';
import '../../providers.dart';
import '../shell/main_shell.dart';
import 'platform_access_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.profileId,
    required this.email,
  });

  final String profileId;
  final String email;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController;
  PlatformKind? _preferredPlatform;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(onboardingRepositoryProvider);
    _nameController = TextEditingController(
      text: repo.getSavedName(widget.profileId) ?? _fallbackName(widget.email),
    );
    _preferredPlatform = repo.getSavedPlatform(widget.profileId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(platformAccessControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _fallbackName(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Friend';
    return local[0].toUpperCase() + local.substring(1);
  }

  void _selectPlatform(PlatformKind platform) {
    setState(() => _preferredPlatform = platform);
  }

  Future<void> _onContinue() async {
    if (_preferredPlatform == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your preferred music platform'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final name = _nameController.text.trim().isEmpty
        ? _fallbackName(widget.email)
        : _nameController.text.trim();

    try {
      final repo = ref.read(onboardingRepositoryProvider);
      await repo.markComplete(
        userId: widget.profileId,
        name: name,
        preferredPlatform: _preferredPlatform!,
      );

      if (!mounted) return;
      ref.invalidate(onboardingStatusProvider(widget.profileId));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accessState = ref.watch(platformAccessControllerProvider);
    final accessController = ref.read(
      platformAccessControllerProvider.notifier,
    );
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.18).clamp(140.0, 200.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E4ED8), Color(0xFF5B8CFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    right: -24,
                    child: Opacity(
                      opacity: 0.08,
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 200,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: -28,
                    child: Opacity(
                      opacity: 0.06,
                      child: Icon(
                        Icons.headphones_rounded,
                        size: 220,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Set up your vibe',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Just two quick steps.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question 1: Name
                    Text(
                      'What should we call you?',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: TextField(
                        controller: _nameController,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: AppDecorations.lineInput(hint: 'Your name')
                            .copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Question 2: Preferred platform
                    Text(
                      "Pick your go-to platform",
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FlatTile(
                            label: 'Spotify',
                            icon: Icons.music_note_rounded,
                            brandColor: AppColors.spotifyGreen,
                            gradient: AppGradients.spotify,
                            isSelected:
                                _preferredPlatform == PlatformKind.spotify,
                            onTap: () => _selectPlatform(PlatformKind.spotify),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlatTile(
                            label: 'YouTube Music',
                            icon: Icons.play_circle_filled_rounded,
                            brandColor: AppColors.ytmRed,
                            gradient: AppGradients.ytm,
                            isSelected: _preferredPlatform == PlatformKind.ytm,
                            onTap: () => _selectPlatform(PlatformKind.ytm),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Question 3: Connect apps
                    Text(
                      'Connect to sync faster',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We use secure access to move your playlists seamlessly.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (accessState.message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        accessState.message!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ConnectTile(
                            label: 'Spotify',
                            icon: Icons.music_note_rounded,
                            brandColor: AppColors.spotifyGreen,
                            isConnected:
                                accessState.access?.spotify.connected ?? false,
                            isLoading:
                                accessState.isLoading ||
                                accessState.isLaunching,
                            onTap: () => accessController.requestAuth(
                              PlatformKind.spotify,
                              ScopeLevel.write,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ConnectTile(
                            label: 'YouTube Music',
                            icon: Icons.play_circle_filled_rounded,
                            brandColor: AppColors.ytmRed,
                            isConnected:
                                accessState.access?.ytm.connected ?? false,
                            isLoading:
                                accessState.isLoading ||
                                accessState.isLaunching,
                            onTap: () => accessController.requestAuth(
                              PlatformKind.ytm,
                              ScopeLevel.write,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            textStyle: textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                            ),
                          ),
                          child: const Text('Privacy policy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Continue button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppButtonStyles.primary,
                    onPressed: _saving ? null : _onContinue,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('Continue'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat compact tile for platform selection (about button height)
class _FlatTile extends StatelessWidget {
  const _FlatTile({
    required this.label,
    required this.icon,
    required this.brandColor,
    required this.gradient,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color brandColor;
  final Gradient gradient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              gradient: isSelected ? gradient : null,
              color: isSelected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? brandColor.withValues(alpha: 0.9)
                    : AppColors.border,
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: isSelected ? AppShadows.soft : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : brandColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.soft,
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flat compact connect tile
class _ConnectTile extends StatelessWidget {
  const _ConnectTile({
    required this.label,
    required this.icon,
    required this.brandColor,
    required this.isConnected,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color brandColor;
  final bool isConnected;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSpotify = brandColor == AppColors.spotifyGreen;
    final gradient = isSpotify ? AppGradients.spotify : AppGradients.ytm;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 118,
        decoration: BoxDecoration(
          gradient: isConnected ? gradient : null,
          color: isConnected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected
                ? brandColor.withValues(alpha: 0.9)
                : AppColors.border,
            width: isConnected ? 1.4 : 1,
          ),
          boxShadow: isConnected ? AppShadows.soft : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isConnected ? Colors.white : brandColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isConnected ? Colors.white : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isConnected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: isConnected ? Colors.black : AppColors.textPrimary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isConnected ? 'Connected' : 'Not connected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isConnected
                    ? Colors.white.withValues(alpha: 0.9)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: isLoading ? null : onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: isConnected ? Colors.white : brandColor,
                    textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isConnected ? Colors.white : brandColor,
                  ),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
