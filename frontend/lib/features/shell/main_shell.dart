import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final accessState = ref.watch(platformAccessControllerProvider);
    final accessController = ref.read(
      platformAccessControllerProvider.notifier,
    );

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

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileValueRow(label: 'Email', value: profile.email),
                    _ProfileValueRow(
                      label: 'Daily limit',
                      value: profile.dailyUsageLimit.toString(),
                    ),
                    _ProfileValueRow(
                      label: 'Usage today',
                      value: profile.usageToday.toString(),
                    ),
                    _ProfileValueRow(
                      label: 'Joined',
                      value: profile.createdAt
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Platform access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (accessState.message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InlineMessage(message: accessState.message!),
                      ),
                    _AccessListRow(
                      label: 'Spotify',
                      entry: accessState.access?.spotify,
                      isLoading:
                          accessState.isLoading || accessState.isLaunching,
                      onGrantRead: () => accessController.requestAuth(
                        PlatformKind.spotify,
                        ScopeLevel.read,
                      ),
                      onGrantWrite: () => accessController.requestAuth(
                        PlatformKind.spotify,
                        ScopeLevel.write,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AccessListRow(
                      label: 'YouTube Music',
                      entry: accessState.access?.ytm,
                      isLoading:
                          accessState.isLoading || accessState.isLaunching,
                      onGrantRead: () => accessController.requestAuth(
                        PlatformKind.ytm,
                        ScopeLevel.read,
                      ),
                      onGrantWrite: () => accessController.requestAuth(
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileValueRow extends StatelessWidget {
  const _ProfileValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AccessListRow extends StatelessWidget {
  const _AccessListRow({
    required this.label,
    required this.entry,
    required this.isLoading,
    required this.onGrantRead,
    required this.onGrantWrite,
  });

  final String label;
  final PlatformAccessEntry? entry;
  final bool isLoading;
  final VoidCallback onGrantRead;
  final VoidCallback onGrantWrite;

  @override
  Widget build(BuildContext context) {
    final connected = entry?.connected ?? false;
    final scope = entry?.scopeLevel ?? ScopeLevel.none;

    Widget trailing;
    if (isLoading) {
      trailing = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (connected && scope == ScopeLevel.write) {
      trailing = _StatusPill(label: 'Connected · Write', color: Colors.green);
    } else if (connected && scope == ScopeLevel.read) {
      trailing = Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusPill(label: 'Connected · Read', color: Colors.blueGrey),
          _TinyButton(
            label: 'Grant write',
            onPressed: onGrantWrite,
            enabled: !isLoading,
          ),
        ],
      );
    } else {
      trailing = _TinyButton(
        label: 'Grant access',
        onPressed: onGrantRead,
        enabled: !isLoading,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('You are signed out.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onLogin, child: const Text('Go to login')),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('Could not load profile: $message'),
        ],
      ),
    );
  }
}
