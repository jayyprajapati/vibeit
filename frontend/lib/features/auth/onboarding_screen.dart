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
    // Prime platform access state so cards can reflect live status.
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
        const SnackBar(content: Text('Choose your go-to music app')),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set up your vibe', style: textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'One calm screen and you are in.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    Text('What should we call you?', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: textTheme.titleLarge?.copyWith(letterSpacing: 0.2),
                        decoration: AppDecorations.lineInput(hint: 'Your name'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Your go-to music app?', style: textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'We\'ll use this when opening songs',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        _PlatformRow(
                          label: 'Spotify',
                          brandColor: const Color(0xFF1DB954),
                          selected: _preferredPlatform == PlatformKind.spotify,
                          onTap: () => _selectPlatform(PlatformKind.spotify),
                        ),
                        const SizedBox(height: 12),
                        _PlatformRow(
                          label: 'YouTube Music',
                          brandColor: const Color(0xFFFF2D55),
                          selected: _preferredPlatform == PlatformKind.ytm,
                          onTap: () => _selectPlatform(PlatformKind.ytm),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('Connect your music apps', style: textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Sync and transfer playlists seamlessly',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (accessState.message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        accessState.message!,
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ConnectRow(
                      label: 'Spotify',
                      brandColor: const Color(0xFF1DB954),
                      entry: accessState.access?.spotify,
                      isLoading: accessState.isLoading || accessState.isLaunching,
                      onConnect: () => accessController.requestAuth(
                        PlatformKind.spotify,
                        ScopeLevel.write,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ConnectRow(
                      label: 'YouTube Music',
                      brandColor: const Color(0xFFFF2D55),
                      entry: accessState.access?.ytm,
                      isLoading: accessState.isLoading || accessState.isLaunching,
                      onConnect: () => accessController.requestAuth(
                        PlatformKind.ytm,
                        ScopeLevel.write,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    ElevatedButton(
                      style: AppButtonStyles.primary,
                      onPressed: _saving ? null : _onContinue,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.label,
    required this.brandColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color brandColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: brandColor,
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: textTheme.titleMedium)),
              if (selected) const Icon(Icons.check, color: AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectRow extends StatelessWidget {
  const _ConnectRow({
    required this.label,
    required this.brandColor,
    required this.entry,
    required this.isLoading,
    required this.onConnect,
  });

  final String label;
  final Color brandColor;
  final PlatformAccessEntry? entry;
  final bool isLoading;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final connected = entry?.connected ?? false;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: brandColor,
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: textTheme.titleMedium)),
        Row(
          children: [
            if (connected) ...[
              const Icon(Icons.check, color: AppColors.textPrimary, size: 18),
              const SizedBox(width: 6),
              Text('Connected', style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
            ] else ...[
              TextButton(
                onPressed: isLoading ? null : onConnect,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
