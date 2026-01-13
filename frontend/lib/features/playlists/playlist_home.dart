import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'playlist_detail_screen.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/models/transfer.dart';
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
  final _globalSearchController = TextEditingController();
  AsyncValue<List<Song>> _globalResults = const AsyncValue.data([]);
  String? _addingSongId;

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
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

  Future<void> _searchGlobalSongs(String query) async {
    final controller = ref.read(playlistControllerProvider.notifier);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _globalResults = const AsyncValue.data([]));
      return;
    }

    setState(() => _globalResults = const AsyncValue.loading());
    try {
      final songs = await controller.searchSongs(trimmed);
      setState(() => _globalResults = AsyncValue.data(songs));
    } catch (err, st) {
      setState(() => _globalResults = AsyncValue.error(err, st));
    }
  }

  Future<void> _addSongToPlaylist(Song song) async {
    final playlists = ref.read(playlistControllerProvider).valueOrNull ?? [];
    final controller = ref.read(playlistControllerProvider.notifier);

    final selected = await showModalBottomSheet<Playlist>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add "${song.title}"',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new playlist'),
                  onTap: () async {
                    final playlist = await _createPlaylist(
                      initialName: 'New mix',
                      openDetail: false,
                    );
                    if (playlist != null && context.mounted) {
                      Navigator.pop(context, playlist);
                    }
                  },
                ),
                const Divider(),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No playlists yet. Create one to add songs.'),
                  )
                else
                  ...playlists.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(p.name),
                      subtitle: Text('${p.tracks.length} tracks'),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() => _addingSongId = song.id);
    try {
      await controller.addTrack(
        selected.id,
        TrackPayload(
          title: song.title,
          artist: song.primaryArtist,
          album: song.album ?? 'Unknown Album',
          duration: ((song.durationSeconds ?? 180).clamp(1, 3600)).toInt(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added to ${selected.name}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _addingSongId = null);
    }
  }

  Future<void> _createPlaylistFromButton() => _createPlaylist(openDetail: true);

  @override
  Widget build(BuildContext context) {
    final playlistsState = ref.watch(playlistControllerProvider);
    final controller = ref.read(playlistControllerProvider.notifier);

    Widget header() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playlists',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Build and manage your own mixes without external platforms.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createPlaylistFromButton,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget searchCard() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _globalSearchController,
              decoration: InputDecoration(
                labelText: 'Global song search',
                hintText: 'Search millions of tracks via MusicBrainz',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () =>
                      _searchGlobalSongs(_globalSearchController.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _searchGlobalSongs(value),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _globalResults.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 4),
                ),
                error: (err, _) => Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not search: ${err.toString()}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _searchGlobalSongs(_globalSearchController.text),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                data: (songs) {
                  if (songs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...songs.map((song) {
                        final meta = [
                          song.primaryArtist,
                          if (song.album != null) song.album,
                          if (song.year != null) song.year.toString(),
                        ].whereType<String>().join(' · ');

                        final isAdding = _addingSongId == song.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (meta.isNotEmpty)
                                      Text(
                                        meta,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 38,
                                child: ElevatedButton(
                                  onPressed: isAdding
                                      ? null
                                      : () => _addSongToPlaylist(song),
                                  child: isAdding
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Add'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadPlaylists,
      child: playlistsState.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header(),
            const SizedBox(height: 120),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (err, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _ErrorState(
                message: err.toString(),
                onRetry: controller.loadPlaylists,
              ),
            ),
          ],
        ),
        data: (playlists) {
          final children = <Widget>[header(), searchCard()];

          if (playlists.isEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: _EmptyState(
                  onCreate: _creating ? null : _createPlaylistFromButton,
                ),
              ),
            );
          } else {
            children.add(
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(
                  'Your playlists',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            );

            for (final playlist in playlists) {
              children.add(
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 6,
                  ),
                  child: _PlaylistCard(
                    title: playlist.name,
                    subtitle:
                        '${playlist.tracks.length} tracks · Updated ${playlist.updatedAt.toLocal().toString().split(' ').first}',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(
                            playlistId: playlist.id,
                            initialName: playlist.name,
                          ),
                        ),
                      );
                    },
                    onTransfer: () =>
                        _openTransferSheet(playlist.id, playlist.name),
                    onSync: () => _openSyncTab(playlist.name),
                  ),
                ),
              );
            }
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: children,
          );
        },
      ),
    );
  }

  Future<void> _openTransferSheet(
    String playlistId,
    String playlistName,
  ) async {
    final result = await showModalBottomSheet<TransferExecuteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => TransferBottomSheet(
        playlistId: playlistId,
        playlistName: playlistName,
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
  }

  void _openSyncTab(String playlistName) {
    ref.read(syncControllerProvider.notifier).selectPlaylist(playlistName);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncTab()));
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onTransfer,
    required this.onSync,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: const Text('Sync'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onTransfer,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Transfer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.library_music_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Text(
            'No playlists yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first playlist to start adding tracks.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create playlist'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 10),
          Text(
            'Could not load playlists',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
