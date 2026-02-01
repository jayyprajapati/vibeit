import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system.dart';
import '../platforms/playlist_hero_banner.dart';

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
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PlaylistHeroBanner(
                  title: playlist.name,
                  colors: const [Color(0xFFFFE6F7), Color(0xFFE6FFF4)],
                  icon: Icons.queue_music,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${playlist.tracks.length} tracks · Created ${playlist.createdAt.toLocal().toString().split(' ').first}',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: _openSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Add tracks'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (playlist.tracks.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.inbox_outlined,
                                color: Colors.grey,
                                size: 40,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No tracks yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Add a track using the search above.',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        )
                      else
                        ...playlist.tracks.map(
                          (track) => MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppShadows.card,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Play',
                                    onPressed: () => _playTrack(track.title),
                                    icon: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${track.artist} · ${track.album}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(track.duration),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      tooltip: 'More options',
                                      onPressed: () =>
                                          _showMoreOptions(context),
                                      icon: const Icon(Icons.more_horiz),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playTrack(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Playing $title...')));
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'More controls coming soon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text('We are adding more actions for these tracks.'),
            ],
          ),
        );
      },
    );
  }
}
