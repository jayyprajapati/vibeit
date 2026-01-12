import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../auth/email_screen.dart';
import '../playlists/playlist_home.dart';
import '../auth/auth_controller.dart';
import '../auth/platform_access_controller.dart';
import '../../core/models/platform_access.dart';
import '../platforms/spotify_tab.dart';
import '../sync/sync_tab.dart';

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
      const PlatformsTab(),
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
            icon: Icon(Icons.grid_view_rounded),
            label: 'Platforms',
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
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Could not load profile: $err'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).refreshProfile(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (auth) {
        if (!auth.isAuthenticated) {
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const EmailScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Go to login'),
                ),
              ],
            ),
          );
        }

        final profile = auth.profile!;
        if (!accessState.isLoading && accessState.access == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            accessController.load();
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _ProfileRow(label: 'Email', value: profile.email),
              _ProfileRow(
                label: 'Daily limit',
                value: profile.dailyUsageLimit.toString(),
              ),
              _ProfileRow(
                label: 'Usage today',
                value: profile.usageToday.toString(),
              ),
              _ProfileRow(
                label: 'Joined',
                value: profile.createdAt.toLocal().toString().split(' ').first,
              ),
              const SizedBox(height: 24),
              _AccessCard(
                state: accessState,
                onRefresh: accessController.load,
                onRequestSpotifyRead: () => accessController.requestAuth(
                  PlatformKind.spotify,
                  ScopeLevel.read,
                ),
                onRequestSpotifyWrite: () => accessController.requestAuth(
                  PlatformKind.spotify,
                  ScopeLevel.write,
                ),
                onRequestYtmRead: () => accessController.requestAuth(
                  PlatformKind.ytm,
                  ScopeLevel.read,
                ),
                onRequestYtmWrite: () => accessController.requestAuth(
                  PlatformKind.ytm,
                  ScopeLevel.write,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .refreshProfile(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh profile'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.state,
    required this.onRefresh,
    required this.onRequestSpotifyRead,
    required this.onRequestSpotifyWrite,
    required this.onRequestYtmRead,
    required this.onRequestYtmWrite,
  });

  final PlatformAccessState state;
  final VoidCallback onRefresh;
  final VoidCallback onRequestSpotifyRead;
  final VoidCallback onRequestSpotifyWrite;
  final VoidCallback onRequestYtmRead;
  final VoidCallback onRequestYtmWrite;

  @override
  Widget build(BuildContext context) {
    final access = state.access;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text(
                'Platform access',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: state.isLoading ? null : onRefresh,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Manage read/write access here. Sync actions will not open OAuth automatically.',
            style: TextStyle(color: Colors.grey),
          ),
          if (state.message != null) ...[
            const SizedBox(height: 10),
            _ProfileRow(label: 'Status', value: state.message!),
          ],
          const SizedBox(height: 12),
          _AccessRow(
            label: 'Spotify',
            entry: access?.spotify,
            isLoading: state.isLoading || state.isLaunching,
            onRequestRead: onRequestSpotifyRead,
            onRequestWrite: onRequestSpotifyWrite,
          ),
          const SizedBox(height: 8),
          _AccessRow(
            label: 'YouTube Music',
            entry: access?.ytm,
            isLoading: state.isLoading || state.isLaunching,
            onRequestRead: onRequestYtmRead,
            onRequestWrite: onRequestYtmWrite,
          ),
          if (!state.isLaunching) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.label,
    required this.entry,
    required this.isLoading,
    required this.onRequestRead,
    required this.onRequestWrite,
  });

  final String label;
  final PlatformAccessEntry? entry;
  final bool isLoading;
  final VoidCallback onRequestRead;
  final VoidCallback onRequestWrite;

  @override
  Widget build(BuildContext context) {
    final connected = entry?.connected ?? false;
    final scope = entry?.scopeLevel ?? ScopeLevel.none;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _ScopeChip(scope: scope, connected: connected),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildButtons(scope, connected),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildButtons(ScopeLevel scope, bool connected) {
    final buttons = <Widget>[];
    final showWrite = connected && scope == ScopeLevel.read;
    final showRead = !connected || scope == ScopeLevel.none;

    if (showRead) {
      buttons.add(
        ElevatedButton(
          onPressed: isLoading ? null : onRequestRead,
          child: const Text('Connect (Read Access)'),
        ),
      );
    }

    if (showWrite) {
      buttons.add(
        OutlinedButton(
          onPressed: isLoading ? null : onRequestWrite,
          child: const Text('Grant Write Access'),
        ),
      );
    }

    if (scope == ScopeLevel.write && connected) {
      buttons.add(
        OutlinedButton(
          onPressed: null,
          child: const Text('Write access granted'),
        ),
      );
    }

    return buttons;
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.scope, required this.connected});

  final ScopeLevel scope;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final label = connected
        ? switch (scope) {
            ScopeLevel.write => 'Write access',
            ScopeLevel.read => 'Read access',
            _ => 'Connected (scope unknown)',
          }
        : 'Not connected';
    final color = connected
        ? (scope == ScopeLevel.write
              ? Colors.green.shade600
              : Colors.blueGrey.shade600)
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
