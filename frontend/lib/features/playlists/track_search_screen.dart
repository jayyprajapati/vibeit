import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import 'playlist_controller.dart';

class TrackSearchScreen extends ConsumerStatefulWidget {
  const TrackSearchScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<TrackSearchScreen> createState() => _TrackSearchScreenState();
}

class _TrackSearchScreenState extends ConsumerState<TrackSearchScreen> {
  final _searchController = TextEditingController();
  AsyncValue<List<Song>> _results = const AsyncValue.data([]);
  String? _addingTrackId;

  @override
  void initState() {
    super.initState();
    // initial state stays empty until the user searches
    _load(query: '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required String query}) async {
    final controller = ref.read(playlistControllerProvider.notifier);
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() => _results = const AsyncValue.data([]));
      return;
    }

    setState(() => _results = const AsyncValue.loading());
    try {
      final tracks = await controller.searchSongs(trimmed);
      setState(() => _results = AsyncValue.data(tracks));
    } catch (err, st) {
      setState(() => _results = AsyncValue.error(err, st));
    }
  }

  Future<void> _addTrack(Song track) async {
    final controller = ref.read(playlistControllerProvider.notifier);
    setState(() => _addingTrackId = track.id);
    try {
      await controller.addTrack(
        widget.playlistId,
        TrackPayload(
          title: track.title,
          artist: track.primaryArtist,
          album: track.album ?? 'Unknown Album',
          duration: ((track.durationSeconds ?? 180).clamp(1, 3600)).toInt(),
          musicBrainzRecordingId: track.musicBrainzRecordingId,
          source: track.source,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added "${track.title}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _addingTrackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add tracks')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search songs',
                  hintText: 'Global search via MusicBrainz',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        _load(query: _searchController.text.trim()),
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (value) => _load(query: value.trim()),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.orange),
                      const SizedBox(height: 8),
                      Text('Could not search: $err'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        width: 140,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _load(query: _searchController.text.trim()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                  data: (songs) {
                    if (songs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching songs yet. Try a different keyword.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final track = songs[index];
                        final isAdding = _addingTrackId == track.id;
                        final subtitle = [
                          track.primaryArtist,
                          if (track.album != null) track.album,
                          if (track.year != null) track.year.toString(),
                        ].whereType<String>().join(' · ');
                        return Container(
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
                                      track.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 40,
                                width: 110,
                                child: ElevatedButton(
                                  onPressed: isAdding
                                      ? null
                                      : () => _addTrack(track),
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
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
