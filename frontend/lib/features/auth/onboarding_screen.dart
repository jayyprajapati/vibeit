import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/models/platform_access.dart';
import '../../providers.dart';
import '../shell/main_shell.dart';
import 'platform_access_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.profileId, required this.email});

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
        const SnackBar(content: Text('Please select your preferred music platform')),
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
    final accessController = ref.read(platformAccessControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Help us make your experience better',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quick insights to know you better',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Question 1: Name
                    Text(
                      'What should we call you?',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: AppDecorations.lineInput(hint: 'Your name'),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 28),

                    // Question 2: Preferred platform
                    Text(
                      "What's your go-to music platform?",
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
                            isSelected: _preferredPlatform == PlatformKind.spotify,
                            onTap: () => _selectPlatform(PlatformKind.spotify),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlatTile(
                            label: 'YouTube Music',
                            icon: Icons.play_circle_filled_rounded,
                            brandColor: AppColors.ytmRed,
                            isSelected: _preferredPlatform == PlatformKind.ytm,
                            onTap: () => _selectPlatform(PlatformKind.ytm),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 28),

                    // Question 3: Connect apps
                    Text(
                      'Want to connect and sync everything seamlessly?',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
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
                            isConnected: accessState.access?.spotify.connected ?? false,
                            isLoading: accessState.isLoading || accessState.isLaunching,
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
                            isConnected: accessState.access?.ytm.connected ?? false,
                            isLoading: accessState.isLoading || accessState.isLaunching,
                            onTap: () => accessController.requestAuth(
                              PlatformKind.ytm,
                              ScopeLevel.write,
                            ),
                          ),
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
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color brandColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: brandColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, color: brandColor, size: 16),
            ],
          ],
        ),
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
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isConnected ? brandColor.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConnected ? brandColor : AppColors.border,
            width: isConnected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: brandColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: brandColor,
                ),
              )
            else if (isConnected)
              Icon(Icons.check_rounded, color: brandColor, size: 16)
            else
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}
