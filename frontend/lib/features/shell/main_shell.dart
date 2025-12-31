import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../auth/email_screen.dart';
import '../playlists/playlist_home.dart';
import '../auth/auth_controller.dart';

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
      const _PlatformsTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Platforms',
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

class _PlatformsTab extends StatelessWidget {
  const _PlatformsTab();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platforms',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Platform integrations will appear here. This screen is static for now.',
            style: TextStyle(color: Colors.grey),
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
        return Padding(
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
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .refreshProfile(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
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
