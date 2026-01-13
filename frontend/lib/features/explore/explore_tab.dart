import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/explore.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../playlists/playlist_controller.dart';
import 'explore_controller.dart';

class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key});

  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  final TextEditingController _searchController = TextEditingController();
  AsyncValue<List<Song>> _searchResults = const AsyncValue.data([]);
  String? _addingSongId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = const AsyncValue.data([]));
      return;
    }

    setState(() => _searchResults = const AsyncValue.loading());
    try {
      final songs = await ref.read(playlistControllerProvider.notifier).searchSongs(trimmed);
      if (!mounted) return;
      setState(() => _searchResults = AsyncValue.data(songs));
    } catch (err, st) {
      if (!mounted) return;
      setState(() => _searchResults = AsyncValue.error(err, st));
    }
  }

  Future<String?> _promptPlaylistName() async {
    final controller = TextEditingController();
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
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                hintText: 'Late night mix',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Enter a name';
                if (trimmed.length > 120) return 'Keep it under 120 characters';
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
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<Playlist?> _pickPlaylist(Song song) async {
    final playlists = ref.read(playlistControllerProvider).valueOrNull ?? [];
    final playlistController = ref.read(playlistControllerProvider.notifier);

    return showModalBottomSheet<Playlist>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new playlist'),
                  onTap: () async {
                    final name = await _promptPlaylistName();
                    if (name == null) return;
                    try {
                      final playlist = await playlistController.createPlaylist(name);
                      if (context.mounted) Navigator.pop(context, playlist);
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err.toString())),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No playlists yet. Create one to add this song.'),
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
  }

  Future<void> _addSongToPlaylist(Song song) async {
    final selected = await _pickPlaylist(song);
    if (selected == null) return;

    final controller = ref.read(playlistControllerProvider.notifier);
    setState(() => _addingSongId = song.id);
    try {
      await controller.addTrack(
        selected.id,
        TrackPayload(
          title: song.title,
          artist: song.primaryArtist,
          album: song.album ?? 'Unknown Album',
          duration: ((song.durationSeconds ?? 180).clamp(1, 3600)).toInt(),
          musicBrainzRecordingId: song.musicBrainzRecordingId,
          source: song.source,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to ${selected.name}')),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _addingSongId = null);
    }
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search songs (MusicBrainz)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                width: 110,
                child: ElevatedButton.icon(
                  onPressed: () => _runSearch(_searchController.text),
                  icon: const Icon(Icons.arrow_outward_rounded),
                  label: const Text('Search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _searchResults.when(
              loading: () => const LinearProgressIndicator(minHeight: 4),
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
                    onPressed: () => _runSearch(_searchController.text),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (songs) {
                if (songs.isEmpty) {
                  return const Text(
                    'Search for any song globally. Results are ranked by MusicBrainz.',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top results',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...songs.map((song) => _SongResultRow(
                          song: song,
                          isAdding: _addingSongId == song.id,
                          onAdd: () => _addSongToPlaylist(song),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(ExplorePayload payload) {
    final blocks = <Widget>[];

    void addSection(ExploreSection? section) {
      if (section == null || section.songs.isEmpty) return;
      blocks.add(_SectionBlock(
        title: section.title,
        subtitle: section.subtitle,
        songs: section.songs,
        addingSongId: _addingSongId,
        onAdd: _addSongToPlaylist,
      ));
    }

    addSection(payload.popular);
    addSection(payload.recent);
    addSection(payload.trendingWorldwide);

    for (final pick in payload.languagePicks) {
      if (pick.songs.isEmpty) continue;
      blocks.add(_SectionBlock(
        title: pick.title,
        subtitle: '${pick.subtitle ?? ''}${pick.confidence > 0 ? ' (confidence ${pick.confidence})' : ''}',
        songs: pick.songs,
        addingSongId: _addingSongId,
        onAdd: _addSongToPlaylist,
      ));
    }

    if (blocks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No discovery data yet. Try searching above or add songs to your playlists.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        ...blocks.expand((widget) => [widget, const SizedBox(height: 20)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exploreState = ref.watch(exploreControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(exploreControllerProvider.notifier).load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Text(
            'Explore',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Global search and discovery powered by MusicBrainz + Last.fm',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildSearchCard(),
          const SizedBox(height: 20),
          exploreState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(err.toString())),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: () => ref.read(exploreControllerProvider.notifier).load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
            data: _buildSections,
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    this.subtitle,
    required this.songs,
    required this.addingSongId,
    required this.onAdd,
  });

  final String title;
  final String? subtitle;
  final List<Song> songs;
  final String? addingSongId;
  final void Function(Song) onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final song = songs[index];
              final isAdding = addingSongId == song.id;
              return _SongCard(
                song: song,
                isAdding: isAdding,
                onAdd: () => onAdd(song),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onAdd, required this.isAdding});

  final Song song;
  final VoidCallback onAdd;
  final bool isAdding;

  @override
  Widget build(BuildContext context) {
    final meta = [
      song.primaryArtist,
      if (song.album != null) song.album,
      if (song.year != null) song.year.toString(),
    ].whereType<String>().join(' · ');

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.music_note, color: Colors.white70, size: 30),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: isAdding ? null : onAdd,
              child: isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongResultRow extends StatelessWidget {
  const _SongResultRow({
    required this.song,
    required this.isAdding,
    required this.onAdd,
  });

  final Song song;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final meta = [
      song.primaryArtist,
      if (song.album != null) song.album,
      if (song.year != null) song.year.toString(),
    ].whereType<String>().join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: isAdding ? null : onAdd,
              child: isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
