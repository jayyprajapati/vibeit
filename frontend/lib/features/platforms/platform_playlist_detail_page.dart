import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../providers.dart';
import 'platform_playlist_models.dart';
import 'playlist_hero_banner.dart' as hero;
import 'spotify_controller.dart';
import 'ytm_controller.dart';

class PlatformPlaylistDetailPage extends ConsumerStatefulWidget {
  const PlatformPlaylistDetailPage({required this.playlist, super.key});

  final PlatformPlaylistSnapshot playlist;

  @override
  ConsumerState<PlatformPlaylistDetailPage> createState() =>
      _PlatformPlaylistDetailPageState();
}

class _PlatformPlaylistDetailPageState
    extends ConsumerState<PlatformPlaylistDetailPage> {
  AsyncValue<PlatformPlaylistDetail>? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = ref.read(authControllerProvider).valueOrNull?.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in again to view this playlist.';
      });
      return;
    }

    try {
      PlatformPlaylistDetail detail;
      if (widget.playlist.source == PlatformPlaylistSource.spotify) {
        final repo = ref.read(spotifyRepositoryProvider);
        detail = await repo.getPlaylistDetail(token, widget.playlist.id);
      } else {
        final repo = ref.read(ytmRepositoryProvider);
        detail = await repo.getPlaylistDetail(token, widget.playlist.id);
      }

      if (!mounted) return;
      setState(() {
        _detail = AsyncValue.data(detail);
        _loading = false;
      });
    } catch (err, st) {
      // Keep trace visible if needed via AsyncError.
      if (!mounted) return;
      setState(() {
        _detail = AsyncValue.error(err, st);
        _error = err.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          final detail = _detail?.valueOrNull;
          final gradient = widget.playlist.source.gradient
              .map((color) => Color.lerp(color, Colors.white, 0.55)!)
              .toList(growable: false);
          final itemLabel = widget.playlist.source == PlatformPlaylistSource.ytm
              ? 'items'
              : 'tracks';
          final updated =
              (detail?.lastFetchedAt ?? widget.playlist.lastFetchedAt)
                  .toLocal()
                  .toString()
                  .split(' ')
                  .first;
          final count = detail?.itemCount ?? widget.playlist.itemCount;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeroHeader(
                  height: 140,
                  child: hero.PlaylistHeroBanner(
                    title: detail?.name ?? widget.playlist.name,
                    colors: gradient,
                    showBack: true,
                    textColor: Colors.white,
                    helperText: 'Last synced $updated',
                    badgeLabel: detail?.fromCache == true ? 'Cached' : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        '$count $itemLabel · Updated $updated',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (detail?.fromCache == true)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Cached',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _buildBody(detail, itemLabel),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(PlatformPlaylistDetail? detail, String itemLabel) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [_ErrorState(message: _error!, onRetry: _load)],
      );
    }

    if (detail == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: const [Text('No data available.')],
      );
    }

    if (detail.tracks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'No $itemLabel found for this playlist yet.',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try refreshing to pull the latest tracks from the source.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemBuilder: (context, index) {
        final track = detail.tracks[index];
        final duration = track.durationSeconds;
        final durationLabel = duration != null && duration > 0
            ? _formatDuration(Duration(seconds: duration))
            : null;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.playlist.source.accentColor.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: widget.playlist.source.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: const TextStyle(color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (durationLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    durationLabel,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
                const SizedBox(width: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    tooltip: 'Play',
                    onPressed: () => _playTrack(track),
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      color: widget.playlist.source.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    tooltip: 'More options',
                    onPressed: () => _showMoreOptions(context),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: detail.tracks.length,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _playTrack(PlatformPlaylistTrack track) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Playing ${track.title}...')));
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load this playlist.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinnedHeroHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeroHeader({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeroHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
