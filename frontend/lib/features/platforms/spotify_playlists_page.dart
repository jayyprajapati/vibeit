import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_playlist_detail_page.dart';
import 'platform_playlist_models.dart';
import 'spotify_controller.dart';
import '../../core/design_system.dart';

class SpotifyPlaylistsPage extends ConsumerWidget {
  const SpotifyPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotifyControllerProvider);
    final controller = ref.read(spotifyControllerProvider.notifier);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HeroBanner(
              title: 'Spotify Playlists',
              gradient: AppHeroGradients.spotify,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: state.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: _ListMessage(
                    message: err.toString(),
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  ),
                ),
                data: (data) {
                  if (!data.connected) {
                    return SliverToBoxAdapter(
                      child: _ListMessage(
                        message: 'Connect Spotify to browse playlists here.',
                        actionLabel: 'Grant access',
                        onAction: () async {
                          try {
                            await controller.startConnectFlow();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Complete Spotify login, then refresh.',
                                  ),
                                ),
                              );
                            }
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err.toString())),
                              );
                            }
                          }
                        },
                      ),
                    );
                  }

                  final items = data.playlists
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

                  if (items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _ListMessage(
                        message:
                            'No Spotify playlists found yet. Try syncing again.',
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final playlist = items[index];
                      return _PlaylistRow(
                        playlist: playlist,
                        iconColor: AppColors.spotifyGreen,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PlatformPlaylistDetailPage(playlist: playlist),
                          ),
                        ),
                        onSync: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sync coming soon')),
                          );
                        },
                        onTransfer: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transfer coming soon')),
                          );
                        },
                      );
                    }, childCount: items.length),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Banner (15% of screen height)
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.title, required this.gradient});

  final String title;
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
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playlist Row (with sync/transfer icons)
// ---------------------------------------------------------------------------

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.iconColor,
    required this.onTap,
    this.onSync,
    this.onTransfer,
  });

  final PlatformPlaylistSnapshot playlist;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback? onSync;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final updated = playlist.lastFetchedAt.toLocal().toString().split(' ').first;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: AppCardDecorations.row(context),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.itemCount} tracks · Updated $updated',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (onSync != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onSync,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.sync_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              if (onTransfer != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onTransfer,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List Message
// ---------------------------------------------------------------------------

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppCardDecorations.row(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            AppTextButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}
