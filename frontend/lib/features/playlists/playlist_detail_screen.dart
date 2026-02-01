import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'track_search_screen.dart';
import '../../core/design_system.dart';

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

  void _showTrackOptions(String trackId, String trackTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                    title: Text(
                      'Remove from playlist',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _removeTrack(trackId);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'More controls coming soon',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeTrack(String trackId) async {
    final controller = ref.read(playlistControllerProvider.notifier);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(playlistDetailProvider(widget.playlistId));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            error: err.toString(),
            onRetry: () =>
                ref.refresh(playlistDetailProvider(widget.playlistId)),
          ),
          data: (playlist) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playlistDetailProvider(widget.playlistId));
              await ref.read(playlistDetailProvider(widget.playlistId).future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _HeroBanner(
                  title: playlist.name,
                  subtitle:
                      '${playlist.tracks.length} tracks · Created ${playlist.createdAt.toLocal().toString().split(' ').first}',
                  gradient: AppHeroGradients.app,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add tracks button
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openSearch,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('Add tracks'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Track list or empty state
                        if (playlist.tracks.isEmpty)
                          _EmptyTrackList()
                        else
                          Column(
                            children: playlist.tracks.map((track) {
                              return _SongRow(
                                title: track.title,
                                subtitle:
                                    '${track.artist} · ${_formatDuration(track.duration)}',
                                onPlay: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Connect a music app to play',
                                      ),
                                    ),
                                  );
                                },
                                onOptions: () =>
                                    _showTrackOptions(track.id, track.title),
                              );
                            }).toList(),
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

// ---------------------------------------------------------------------------
// Hero Banner (15% of screen height)
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.15;

    return SliverToBoxAdapter(
      child: Container(
        height: height + MediaQuery.of(context).padding.top,
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 16,
        ),
        decoration: BoxDecoration(gradient: gradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song Row (with play and options icons)
// ---------------------------------------------------------------------------

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.title,
    required this.subtitle,
    required this.onPlay,
    required this.onOptions,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: AppCardDecorations.row(context),
        child: Row(
          children: [
            // Album art placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.album_rounded,
                color: AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPlay,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 28,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            // Options menu
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onOptions,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 24,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty Track List
// ---------------------------------------------------------------------------

class _EmptyTrackList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppCardDecorations.row(context),
      child: Column(
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No tracks yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add tracks using the button above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error View
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Could not load playlist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
