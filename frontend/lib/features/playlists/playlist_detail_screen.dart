import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'track_search_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.initialName,
  });

  final String playlistId;
  final String initialName;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  String? _removingTrackId;

  Future<void> _removeTrack(String trackId) async {
    final controller = ref.read(playlistControllerProvider.notifier);
    setState(() => _removingTrackId = trackId);
    try {
      await controller.removeTrack(widget.playlistId, trackId);
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Track removed from playlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _removingTrackId = null);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackSearchScreen(playlistId: widget.playlistId),
      ),
    );
    ref.invalidate(playlistDetailProvider(widget.playlistId));
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final padded = secs.toString().padLeft(2, '0');
    return '$minutes:$padded';
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(playlistDetailProvider(widget.playlistId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialName)),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Playlist',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('Could not load playlist: $err'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.refresh(playlistDetailProvider(widget.playlistId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (playlist) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playlistDetailProvider(widget.playlistId));
              await ref.read(playlistDetailProvider(widget.playlistId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  playlist.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${playlist.tracks.length} tracks · Created ${playlist.createdAt.toLocal().toString().split(' ').first}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Add tracks'),
                ),
                const SizedBox(height: 20),
                if (playlist.tracks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No tracks yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Add a track using the search above.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...playlist.tracks.map(
                    (track) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Tooltip(
                            message: 'Connect a music app to play',
                            child: IconButton(
                              onPressed: null,
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                                Text(
                                  '${track.artist} · ${track.album}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(track.duration),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          IconButton(
                            onPressed: _removingTrackId == track.id
                                ? null
                                : () => _removeTrack(track.id),
                            icon: _removingTrackId == track.id
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
