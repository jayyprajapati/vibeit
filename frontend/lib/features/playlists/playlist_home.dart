import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'playlist_detail_screen.dart';
import '../../core/models/playlist.dart';
import '../../core/models/transfer.dart';
import '../../core/design_system.dart';
import '../platforms/platform_playlist_models.dart';
import '../platforms/platform_playlist_detail_page.dart';
import '../platforms/spotify_controller.dart';
import '../platforms/spotify_playlists_page.dart';
import '../platforms/ytm_controller.dart';
import '../platforms/ytm_playlists_page.dart';
import '../sync/sync_tab.dart';
import '../platforms/sync_controller.dart';
import '../transfer/transfer_sheet.dart';

class PlaylistHomeTab extends ConsumerStatefulWidget {
  const PlaylistHomeTab({super.key});

  @override
  ConsumerState<PlaylistHomeTab> createState() => _PlaylistHomeTabState();
}

class _PlaylistHomeTabState extends ConsumerState<PlaylistHomeTab> {
  bool _creating = false;

  String _normalizeName(String value) => value.trim().toLowerCase();

  Future<void> _refreshPlatformCaches() async {
    try {
      await Future.wait([
        ref.read(spotifyControllerProvider.notifier).load(),
        ref.read(ytmControllerProvider.notifier).load(),
      ]);
    } catch (_) {
      // Keep showing existing cache if refresh fails; user can retry manually.
    }
  }

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

  Widget _buildVibeitSection(
    AsyncValue<List<Playlist>> state,
    PlaylistController controller,
    AsyncValue<SpotifyState> spotifyState,
    AsyncValue<YtmState> ytmState,
  ) {
    return state.when(
      loading: () =>
          const _SectionCard(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => _SectionCard(
        child: _InlineError(
          message: err.toString(),
          actionLabel: 'Retry',
          onTap: controller.loadPlaylists,
        ),
      ),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _SectionCard(
            child: _EmptyVibeitState(
              onCreate: _creating ? null : _createPlaylistFromButton,
            ),
          );
        }

        final spotifyNames = (spotifyState.valueOrNull?.connected ?? false)
            ? spotifyState.value!.playlists
                  .map((p) => _normalizeName(p.name))
                  .toSet()
            : <String>{};
        final ytmNames = (ytmState.valueOrNull?.connected ?? false)
            ? ytmState.value!.playlists
                  .map((p) => _normalizeName(p.name))
                  .toSet()
            : <String>{};

        return SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final normalized = _normalizeName(playlist.name);
              final inSpotify = spotifyNames.contains(normalized);
              final inYtm = ytmNames.contains(normalized);

              VoidCallback? syncAction;
              VoidCallback? transferAction;
              TransferPlatform? forcedDestination;
              String? transferLabel;

              if (inSpotify && inYtm) {
                syncAction = () => _openSyncTab(playlist.name);
              } else if (inSpotify && !inYtm) {
                forcedDestination = TransferPlatform.ytm;
                transferAction = () => _openTransferSheet(
                  playlist.id,
                  playlist.name,
                  forcedDestination: forcedDestination,
                );
                transferLabel = 'Transfer to YTM';
              } else if (inYtm && !inSpotify) {
                forcedDestination = TransferPlatform.spotify;
                transferAction = () => _openTransferSheet(
                  playlist.id,
                  playlist.name,
                  forcedDestination: forcedDestination,
                );
                transferLabel = 'Transfer to Spotify';
              }

              return _VibeitPlaylistCard(
                playlist: playlist,
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(
                        playlistId: playlist.id,
                        initialName: playlist.name,
                      ),
                    ),
                  );
                },
                onTransfer: transferAction,
                onSync: syncAction,
                transferLabel: transferLabel,
                onDelete: () => _confirmDelete(playlist.id, playlist.name),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: playlists.length,
          ),
        );
      },
    );
  }

  Widget _buildSpotifySection(AsyncValue<SpotifyState> state) {
    final controller = ref.read(spotifyControllerProvider.notifier);

    return state.when(
      loading: () =>
          const _SectionCard(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => _SectionCard(
        child: _InlineError(
          message: err.toString(),
          actionLabel: 'Retry',
          onTap: controller.load,
        ),
      ),
      data: (data) {
        if (!data.connected) {
          return _SectionCard(
            child: _ConnectPrompt(
              label: 'Connect Spotify',
              description: 'Grant read access to view your playlists here.',
              onTap: () async {
                try {
                  await controller.startConnectFlow();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Finish Spotify login in your browser, then refresh.',
                        ),
                      ),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                }
              },
            ),
          );
        }

        final items = data.playlists
            .take(3)
            .map(
              (p) => PlatformPlaylistSnapshot(
                id: p.id,
                name: p.name,
                itemCount: p.trackCount,
                lastFetchedAt: p.lastFetchedAt,
                source: PlatformPlaylistSource.spotify,
              ),
            )
            .toList();

        return _PlatformCarousel(
          items: items,
          source: PlatformPlaylistSource.spotify,
          onShowMore: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SpotifyPlaylistsPage()),
          ),
          onOpen: _openPlatformPlaylist,
          emptyLabel: 'No playlists yet. Sync from Spotify to bring them in.',
        );
      },
    );
  }

  Widget _buildYtmSection(AsyncValue<YtmState> state) {
    final controller = ref.read(ytmControllerProvider.notifier);

    return state.when(
      loading: () =>
          const _SectionCard(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => _SectionCard(
        child: _InlineError(
          message: err.toString(),
          actionLabel: 'Retry',
          onTap: controller.load,
        ),
      ),
      data: (data) {
        if (!data.connected) {
          return _SectionCard(
            child: _ConnectPrompt(
              label: 'Connect YouTube Music',
              description:
                  'Grant read access to browse YouTube Music playlists.',
              onTap: () async {
                try {
                  await controller.startConnectFlow();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Finish YouTube Music login, then refresh here.',
                        ),
                      ),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                }
              },
            ),
          );
        }

        final items = data.playlists
            .take(3)
            .map(
              (p) => PlatformPlaylistSnapshot(
                id: p.id,
                name: p.name,
                itemCount: p.itemCount,
                lastFetchedAt: p.lastFetchedAt,
                source: PlatformPlaylistSource.ytm,
              ),
            )
            .toList();

        return _PlatformCarousel(
          items: items,
          source: PlatformPlaylistSource.ytm,
          onShowMore: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const YtmPlaylistsPage())),
          onOpen: _openPlatformPlaylist,
          emptyLabel: 'No playlists yet. Sync from YouTube Music to see them.',
        );
      },
    );
  }

  void _openPlatformPlaylist(PlatformPlaylistSnapshot playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlatformPlaylistDetailPage(playlist: playlist),
      ),
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

  Future<void> _createPlaylistFromButton() => _createPlaylist(openDetail: true);

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

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _DashboardHeader(
            onCreate: _creating ? null : _createPlaylistFromButton,
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Vibeit playlists',
            subtitle: 'Keep building your own mixes.',
          ),
          const SizedBox(height: 10),
          _buildVibeitSection(
            playlistsState,
            playlistController,
            spotifyState,
            ytmState,
          ),
          const SizedBox(height: 30),
          const _SectionHeading(
            title: 'Spotify playlists',
            subtitle: 'Browse without switching apps.',
          ),
          const SizedBox(height: 12),
          _buildSpotifySection(spotifyState),
          const SizedBox(height: 30),
          const _SectionHeading(
            title: 'YouTube Music playlists',
            subtitle: 'Stay close to your YTM library.',
          ),
          const SizedBox(height: 12),
          _buildYtmSection(ytmState),
        ],
      ),
    );
  }

  Future<void> _openTransferSheet(
    String playlistId,
    String playlistName, {
    TransferPlatform? forcedDestination,
  }) async {
    final result = await showModalBottomSheet<TransferExecuteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => TransferBottomSheet(
        playlistId: playlistId,
        playlistName: playlistName,
        forcedDestination: forcedDestination,
      ),
    );

    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transfer complete: added ${result.addedCount}/${result.totalTracks} tracks.',
        ),
      ),
    );

    await _refreshPlatformCaches();
  }

  void _openSyncTab(String playlistName) {
    ref.read(syncControllerProvider.notifier).selectPlaylist(playlistName);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncTab()));
  }

  Future<void> _confirmDelete(String playlistId, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete playlist'),
          content: Text('Remove "$name" from Vibeit? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await ref
          .read(playlistControllerProvider.notifier)
          .deletePlaylist(playlistId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.toString())));
      }
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Playlists plus connected libraries in one place.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create playlist'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 6),
              TextButton(onPressed: onTap, child: Text(actionLabel)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyVibeitState extends StatelessWidget {
  const _EmptyVibeitState({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_music_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first playlist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Build a mix and start adding tracks.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: AppColors.textPrimary,
                  overlayColor: AppColors.textPrimary.withValues(alpha: 0.06),
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VibeitPlaylistCard extends StatelessWidget {
  const _VibeitPlaylistCard({
    required this.playlist,
    required this.onOpen,
    this.onTransfer,
    this.transferLabel,
    this.onSync,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onOpen;
  final VoidCallback? onTransfer;
  final String? transferLabel;
  final VoidCallback? onSync;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final updated = playlist.updatedAt.toLocal().toString().split(' ').first;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 240,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDF4FF), Color(0xFFE3F2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${playlist.tracks.length} tracks · Updated $updated',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onSync != null)
                    OutlinedButton.icon(
                      onPressed: onSync,
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
                      label: const Text('Sync'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                      ),
                    ),
                  if (onTransfer != null)
                    ElevatedButton.icon(
                      onPressed: onTransfer,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(transferLabel ?? 'Transfer'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                      ),
                    ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Delete playlist',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCarousel extends StatelessWidget {
  const _PlatformCarousel({
    required this.items,
    required this.source,
    required this.onShowMore,
    required this.onOpen,
    required this.emptyLabel,
  });

  final List<PlatformPlaylistSnapshot> items;
  final PlatformPlaylistSource source;
  final VoidCallback onShowMore;
  final ValueChanged<PlatformPlaylistSnapshot> onOpen;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SectionCard(
        child: Row(
          children: [
            Icon(Icons.queue_music, color: source.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                emptyLabel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: onShowMore,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  foregroundColor: AppColors.textPrimary,
                  overlayColor: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
                child: const Text('Show more'),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _ShowMoreCard(onTap: onShowMore);
          }

          final playlist = items[index];
          return _PlatformPlaylistCard(
            playlist: playlist,
            onTap: () => onOpen(playlist),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemCount: items.length + 1,
      ),
    );
  }
}

class _PlatformPlaylistCard extends StatelessWidget {
  const _PlatformPlaylistCard({required this.playlist, required this.onTap});

  final PlatformPlaylistSnapshot playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = playlist.source.gradient;
    final itemLabel = playlist.source == PlatformPlaylistSource.ytm
        ? 'items'
        : 'tracks';
    final updated = playlist.lastFetchedAt
        .toLocal()
        .toString()
        .split(' ')
        .first;

    final softGradient = gradient
        .map((color) => color.withValues(alpha: 0.22))
        .toList(growable: false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: softGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      playlist.source == PlatformPlaylistSource.spotify
                          ? Icons.music_note
                          : Icons.play_circle_fill,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        playlist.source.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${playlist.itemCount} $itemLabel',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Updated $updated',
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowMoreCard extends StatelessWidget {
  const _ShowMoreCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward, color: Colors.grey),
                SizedBox(height: 6),
                Text('Show more'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({
    required this.label,
    required this.description,
    required this.onTap,
  });

  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.link_rounded, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: onTap, child: const Text('Grant access')),
      ],
    );
  }
}
