import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'playlist_detail_screen.dart';
import 'app_playlists_page.dart';
import '../../core/models/playlist.dart';
import '../../core/design_system.dart';
import '../platforms/platform_playlist_models.dart';
import '../platforms/platform_playlist_detail_page.dart';
import '../platforms/spotify_controller.dart';
import '../platforms/spotify_playlists_page.dart';
import '../platforms/ytm_controller.dart';
import '../platforms/ytm_playlists_page.dart';

class PlaylistHomeTab extends ConsumerStatefulWidget {
  const PlaylistHomeTab({super.key});

  @override
  ConsumerState<PlaylistHomeTab> createState() => _PlaylistHomeTabState();
}

class _PlaylistHomeTabState extends ConsumerState<PlaylistHomeTab> {
  bool _creating = false;

  Future<String?> _promptPlaylistName({String? initialName}) async {
    final nameController = TextEditingController(text: initialName ?? "");
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Create playlist'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                hintText: 'Road trip tunes',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name';
                }
                if (value.trim().length > 120) {
                  return 'Keep it under 120 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, nameController.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<Playlist?> _createPlaylist({
    String? initialName,
    bool openDetail = true,
  }) async {
    final controller = ref.read(playlistControllerProvider.notifier);
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = await _promptPlaylistName(initialName: initialName);
    if (name == null) return null;

    try {
      setState(() => _creating = true);
      final playlist = await controller.createPlaylist(name);
      if (!mounted) return playlist;
      if (openDetail) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(
              playlistId: playlist.id,
              initialName: playlist.name,
            ),
          ),
        );
      }
      scaffold.showSnackBar(const SnackBar(content: Text('Playlist created')));
      return playlist;
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return null;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _navigateToProfile() {
    DefaultTabController.maybeOf(context)?.animateTo(2);
  }

  void _openPlatformPlaylist(PlatformPlaylistSnapshot playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlatformPlaylistDetailPage(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsState = ref.watch(playlistControllerProvider);
    final spotifyState = ref.watch(spotifyControllerProvider);
    final ytmState = ref.watch(ytmControllerProvider);
    final playlistController = ref.read(playlistControllerProvider.notifier);

    Future<void> refreshAll() async {
      await Future.wait([
        playlistController.loadPlaylists(),
        ref.read(spotifyControllerProvider.notifier).load(),
        ref.read(ytmControllerProvider.notifier).load(),
      ]);
    }

    final hasAppPlaylists = playlistsState.valueOrNull?.isNotEmpty ?? false;
    final spotifyConnected = spotifyState.valueOrNull?.connected ?? false;
    final ytmConnected = ytmState.valueOrNull?.connected ?? false;
    final anyPlatformConnected = spotifyConnected || ytmConnected;

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          // Page header
          const _PageHeader(),
          const SizedBox(height: 36),

          // Empty state: nothing at all — centered
          if (!hasAppPlaylists && !anyPlatformConnected) ...[
            _EmptyDashboard(
              onCreate: _creating ? null : () => _createPlaylist(),
              onConnectApps: _navigateToProfile,
            ),
          ] else ...[
            // App playlists section
            _buildAppPlaylistsSection(playlistsState, playlistController),
            const SizedBox(height: 32),

            // Spotify section
            if (spotifyConnected)
              _buildSpotifySection(spotifyState)
            else
              _PlatformConnectPrompt(
                platform: 'Spotify',
                onConnect: _navigateToProfile,
              ),
            const SizedBox(height: 32),

            // YouTube Music section
            if (ytmConnected)
              _buildYtmSection(ytmState)
            else
              _PlatformConnectPrompt(
                platform: 'YouTube Music',
                onConnect: _navigateToProfile,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppPlaylistsSection(
    AsyncValue<List<Playlist>> state,
    PlaylistController controller,
  ) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _InlineError(
        message: err.toString(),
        actionLabel: 'Retry',
        onTap: controller.loadPlaylists,
      ),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _CreatePlaylistPrompt(
            onCreate: _creating ? null : () => _createPlaylist(),
          );
        }

        final showMore = playlists.length > 3;
        final displayPlaylists = playlists.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Your Playlists',
              showMore: showMore,
              onShowMore: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppPlaylistsPage()),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPlaylists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final playlist = displayPlaylists[index];
                  return _PlaylistCard(
                    name: playlist.name,
                    gradient: AppCardTitleGradients.playful,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(
                          playlistId: playlist.id,
                          initialName: playlist.name,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpotifySection(AsyncValue<SpotifyState> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _InlineError(
        message: err.toString(),
        actionLabel: 'Retry',
        onTap: () => ref.read(spotifyControllerProvider.notifier).load(),
      ),
      data: (data) {
        if (!data.connected || data.playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        final showMore = data.playlists.length > 3;
        final displayPlaylists = data.playlists.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Spotify',
              showMore: showMore,
              onShowMore: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpotifyPlaylistsPage()),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPlaylists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final playlist = displayPlaylists[index];
                  final snapshot = PlatformPlaylistSnapshot(
                    id: playlist.id,
                    name: playlist.name,
                    itemCount: playlist.trackCount,
                    lastFetchedAt: playlist.lastFetchedAt,
                    source: PlatformPlaylistSource.spotify,
                  );
                  return _PlaylistCard(
                    name: playlist.name,
                    gradient: AppCardTitleGradients.spotify,
                    onTap: () => _openPlatformPlaylist(snapshot),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYtmSection(AsyncValue<YtmState> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _InlineError(
        message: err.toString(),
        actionLabel: 'Retry',
        onTap: () => ref.read(ytmControllerProvider.notifier).load(),
      ),
      data: (data) {
        if (!data.connected || data.playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        final showMore = data.playlists.length > 3;
        final displayPlaylists = data.playlists.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'YouTube Music',
              showMore: showMore,
              onShowMore: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const YtmPlaylistsPage()),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPlaylists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final playlist = displayPlaylists[index];
                  final snapshot = PlatformPlaylistSnapshot(
                    id: playlist.id,
                    name: playlist.name,
                    itemCount: playlist.itemCount,
                    lastFetchedAt: playlist.lastFetchedAt,
                    source: PlatformPlaylistSource.ytm,
                  );
                  return _PlaylistCard(
                    name: playlist.name,
                    gradient: AppCardTitleGradients.ytm,
                    onTap: () => _openPlatformPlaylist(snapshot),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page Header
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Music',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'All your playlists across platforms, in one place.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header with optional Show More (cursor pointer)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.showMore = false,
    this.onShowMore,
  });

  final String title;
  final bool showMore;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (showMore && onShowMore != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onShowMore,
              child: Text(
                'Show more',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Playlist Card with gradient title area and cursor pointer
// ---------------------------------------------------------------------------

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.name,
    required this.onTap,
    required this.gradient,
  });

  final String name;
  final VoidCallback onTap;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient title area
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Clean body with arrow
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty Dashboard State — centered
// ---------------------------------------------------------------------------

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({
    required this.onCreate,
    required this.onConnectApps,
  });

  final VoidCallback? onCreate;
  final VoidCallback onConnectApps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 20),
              Text(
                'Create your own playlists and sync them across platforms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (onCreate != null)
                AppTextButton(
                  label: 'Create playlist',
                  icon: Icons.add_rounded,
                  onTap: onCreate!,
                ),
              const SizedBox(height: 32),
              Text(
                'No music platforms connected yet.\nConnect them from Profile to sync your music.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              AppTextButton(
                label: 'Connect applications',
                icon: Icons.link_rounded,
                onTap: onConnectApps,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Playlist Prompt
// ---------------------------------------------------------------------------

class _CreatePlaylistPrompt extends StatelessWidget {
  const _CreatePlaylistPrompt({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Your Playlists'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppCardDecorations.row(context),
          child: Row(
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 32,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Create your own playlists and sync them across platforms.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (onCreate != null)
          AppTextButton(
            label: 'Create playlist',
            icon: Icons.add_rounded,
            onTap: onCreate!,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Platform Connect Prompt
// ---------------------------------------------------------------------------

class _PlatformConnectPrompt extends StatelessWidget {
  const _PlatformConnectPrompt({
    required this.platform,
    required this.onConnect,
  });

  final String platform;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: platform),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppCardDecorations.row(context),
          child: Row(
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 28,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '$platform not connected. Connect from Profile to sync.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppTextButton(
          label: 'Connect',
          icon: Icons.open_in_new_rounded,
          onTap: onConnect,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inline Error
// ---------------------------------------------------------------------------

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppCardDecorations.row(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(color: Colors.orange)),
                const SizedBox(height: 8),
                AppTextButton(label: actionLabel, onTap: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
