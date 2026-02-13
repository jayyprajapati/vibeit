import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/theme_provider.dart';
import '../../core/services/logout_service.dart';
import '../../providers.dart';
import '../auth/email_screen.dart';
import '../playlists/playlist_home.dart';
import '../auth/auth_controller.dart';
import '../auth/platform_access_controller.dart';
import '../../core/models/platform_access.dart';
import '../sync/sync_tab.dart';
import '../explore/explore_tab.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  late final ProviderSubscription<AsyncValue<AuthState>> _authListener;

  @override
  void initState() {
    super.initState();
    _authListener = ref.listenManual<AsyncValue<AuthState>>(
      authControllerProvider,
      (prev, next) {
        final wasAuthed = prev?.valueOrNull?.isAuthenticated ?? false;
        final isAuthed = next.valueOrNull?.isAuthenticated ?? false;

        if (wasAuthed && !isAuthed && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmailScreen()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _authListener.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const PlaylistHomeTab(),
      const ExploreTab(),
      const SyncTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt_rounded),
            label: 'Sync',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  String _formatJoinedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  void _showChangePlatformSheet(
    BuildContext context,
    WidgetRef ref,
    PlatformKind newPlatform,
  ) {
    final newName = newPlatform == PlatformKind.spotify
        ? 'Spotify'
        : 'YouTube Music';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Change preferred platform?',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Switch to $newName as your default music app?',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: AppButtonStyles.subtle,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final authState = ref
                          .read(authControllerProvider)
                          .valueOrNull;
                      if (authState?.profile != null) {
                        final repo = ref.read(onboardingRepositoryProvider);
                        await repo.markComplete(
                          userId: authState!.profile!.id,
                          name: repo.getSavedName(authState.profile!.id) ?? '',
                          preferredPlatform: newPlatform,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: AppButtonStyles.primary,
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Are you sure you want to logout?',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: AppButtonStyles.subtle,
                    child: const Text('Stay logged in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Use LogoutService for complete state clearing
                      await ref.read(logoutServiceProvider).logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Yes, logout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final accessState = ref.watch(platformAccessControllerProvider);
    final accessController = ref.read(
      platformAccessControllerProvider.notifier,
    );
    final themeMode = ref.watch(themeModeProvider);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ProfileError(message: err.toString()),
      data: (auth) {
        if (!auth.isAuthenticated) {
          return _SignedOutView(
            onLogin: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EmailScreen()),
                (route) => false,
              );
            },
          );
        }

        final profile = auth.profile!;
        if (!accessState.isLoading && accessState.access == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            accessController.load();
          });
        }

        // Get preferred platform
        final onboardingRepo = ref.read(onboardingRepositoryProvider);
        final preferredPlatform = onboardingRepo.getSavedPlatform(profile.id);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and name - centered
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A1F26)
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2D3541)
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: isDark
                            ? const Color(0xFF6B7A8C)
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      onboardingRepo.getSavedName(profile.id) ??
                          profile.email.split('@').first,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(profile.email, style: textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    // Stats row wraps to avoid tiny overflows on narrow layouts
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          '${profile.usageToday} / ${profile.dailyUsageLimit} today',
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF6B7A8C)
                                : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          _formatJoinedDate(profile.createdAt),
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Divider(
                color: isDark ? const Color(0xFF2D3541) : AppColors.border,
              ),
              const SizedBox(height: 24),

              // Preferred Platform Section
              Text(
                'Preferred platform',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PlatformTile(
                      label: 'Spotify',
                      icon: Icons.music_note_rounded,
                      brandColor: AppColors.spotifyGreen,
                      gradient: AppGradients.spotify,
                      isSelected: preferredPlatform == PlatformKind.spotify,
                      onTap: preferredPlatform == PlatformKind.spotify
                          ? null
                          : () => _showChangePlatformSheet(
                              context,
                              ref,
                              PlatformKind.spotify,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlatformTile(
                      label: 'YouTube Music',
                      icon: Icons.play_circle_filled_rounded,
                      brandColor: AppColors.ytmRed,
                      gradient: AppGradients.ytm,
                      isSelected: preferredPlatform == PlatformKind.ytm,
                      onTap: preferredPlatform == PlatformKind.ytm
                          ? null
                          : () => _showChangePlatformSheet(
                              context,
                              ref,
                              PlatformKind.ytm,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Connected Apps Section
              Text(
                'Connected apps',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (accessState.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  accessState.message!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
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
                          accessState.isLoading || accessState.isLaunching,
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
                      isLoading:
                          accessState.isLoading || accessState.isLaunching,
                      onTap: () => accessController.requestAuth(
                        PlatformKind.ytm,
                        ScopeLevel.write,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(
                color: isDark ? const Color(0xFF2D3541) : AppColors.border,
              ),
              const SizedBox(height: 24),

              // Appearance Section
              Text(
                'Appearance',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F26) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D3541) : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ThemeButton(
                        icon: Icons.light_mode_rounded,
                        label: 'Light',
                        isSelected: themeMode == AppThemeMode.light,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .setMode(AppThemeMode.light),
                      ),
                    ),
                    Expanded(
                      child: _ThemeButton(
                        icon: Icons.dark_mode_rounded,
                        label: 'Dark',
                        isSelected: themeMode == AppThemeMode.dark,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .setMode(AppThemeMode.dark),
                      ),
                    ),
                    Expanded(
                      child: _ThemeButton(
                        icon: Icons.settings_suggest_rounded,
                        label: 'Auto',
                        isSelected: themeMode == AppThemeMode.system,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .setMode(AppThemeMode.system),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement feedback flow
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                  child: const Text('Give feedback'),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Button - RED
              Center(
                child: ElevatedButton(
                  onPressed: () => _showLogoutSheet(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 16),

              // Delete Account
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Wire delete account flow
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? const Color(0xFF6B7A8C)
                        : AppColors.textMuted,
                  ),
                  child: const Text('Delete account'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Flat tile for platform selection in profile
class _PlatformTile extends StatelessWidget {
  const _PlatformTile({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isSelected
                  ? null
                  : (isDark ? const Color(0xFF1A1F26) : AppColors.surface),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? brandColor.withValues(alpha: 0.9)
                    : (isDark ? const Color(0xFF2D3541) : AppColors.border),
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
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.textPrimary),
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

/// Flat connect tile
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 118,
        decoration: BoxDecoration(
          gradient: isConnected ? gradient : null,
          color: isConnected
              ? null
              : (isDark ? const Color(0xFF1A1F26) : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected
                ? brandColor.withValues(alpha: 0.9)
                : (isDark ? const Color(0xFF2D3541) : AppColors.border),
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
                      color: isConnected
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isConnected)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isConnected ? 'Connected' : 'Not connected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isConnected
                    ? Colors.white.withValues(alpha: 0.9)
                    : (isDark
                          ? const Color(0xFF6B7A8C)
                          : AppColors.textSecondary),
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

/// Theme toggle button
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF6B7A8C) : AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFFA8B4C4)
                          : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'You are signed out',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onLogin,
            style: AppButtonStyles.primary,
            child: const Text('Go to login'),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
