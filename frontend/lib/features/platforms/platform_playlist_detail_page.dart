import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../core/design_system.dart';
import 'platform_playlist_models.dart';
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
      if (!mounted) return;
      setState(() {
        _detail = AsyncValue.error(err, st);
        _error = err.toString();
        _loading = false;
      });
    }
  }

  LinearGradient get _heroGradient {
    return widget.playlist.source == PlatformPlaylistSource.spotify
        ? AppHeroGradients.spotify
        : AppHeroGradients.ytm;
  }

  Color get _accentColor {
    return widget.playlist.source == PlatformPlaylistSource.spotify
        ? AppColors.spotifyGreen
        : AppColors.ytmRed;
  }

  void _showTrackOptions(String title) {
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
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    final itemLabel = widget.playlist.source == PlatformPlaylistSource.ytm
        ? 'items'
        : 'tracks';

    final detail = _detail?.valueOrNull;
    final updated = (detail?.lastFetchedAt ?? widget.playlist.lastFetchedAt)
        .toLocal()
        .toString()
        .split(' ')
        .first;
    final count = detail?.itemCount ?? widget.playlist.itemCount;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HeroBanner(
              title: detail?.name ?? widget.playlist.name,
              subtitle: '$count $itemLabel · Updated $updated',
              gradient: _heroGradient,
              fromCache: detail?.fromCache == true,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: _buildBody(detail, itemLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PlatformPlaylistDetail? detail, String itemLabel) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: _ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (detail == null) {
      return const SliverToBoxAdapter(
        child: Text('No data available.'),
      );
    }

    if (detail.tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
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
                'No $itemLabel found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try refreshing to pull the latest tracks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = detail.tracks[index];
          final duration = track.durationSeconds;
          final durationLabel = duration != null && duration > 0
              ? _formatDuration(Duration(seconds: duration))
              : '';

          return _SongRow(
            title: track.title,
            subtitle: '${track.artist}${durationLabel.isNotEmpty ? ' · $durationLabel' : ''}',
            iconColor: _accentColor,
            onPlay: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connect a music app to play')),
              );
            },
            onOptions: () => _showTrackOptions(track.title),
          );
        },
        childCount: detail.tracks.length,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
    this.fromCache = false,
  });

  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final bool fromCache;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (fromCache)
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cached',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
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
    required this.iconColor,
    required this.onPlay,
    required this.onOptions,
  });

  final String title;
  final String subtitle;
  final Color iconColor;
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
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: iconColor,
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
// Error State
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppCardDecorations.row(context),
      child: Column(
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
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppTextButton(label: 'Retry', onTap: onRetry),
        ],
      ),
    );
  }
}
