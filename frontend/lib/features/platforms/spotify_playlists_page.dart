import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_playlist_detail_page.dart';
import 'platform_playlist_models.dart';
import 'spotify_controller.dart';
import 'playlist_hero_banner.dart' as hero;
import '../../core/design_system.dart';
import '../../core/services/playlist_action_resolver.dart';
import '../sync/sync_bottom_sheet.dart';
import '../transfer/transfer_sheet.dart';
import '../../core/models/transfer.dart';
import 'ytm_controller.dart';

class SpotifyPlaylistsPage extends ConsumerWidget {
  const SpotifyPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotifyControllerProvider);
    final controller = ref.read(spotifyControllerProvider.notifier);
    final ytmState = ref.watch(ytmControllerProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeroHeader(
                height: 140,
                child: hero.PlaylistHeroBanner(
                  title: 'Spotify Playlists',
                  colors: const [Color(0xFF1DB954), Color(0xFF1ED760)],
                  showBack: true,
                  textColor: Colors.white,
                  helperText: state.maybeWhen(
                    data: (data) {
                      final first = data.playlists.isNotEmpty
                          ? data.playlists.first.lastFetchedAt
                          : null;
                      if (first == null) return null;
                      final label = first.toLocal().toString().split(' ').first;
                      return 'Last synced $label';
                    },
                    orElse: () => null,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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

                  // Get YTM playlists for action resolution
                  final ytmPlaylists = ytmState.valueOrNull?.playlists ?? [];
                  final actionResolver = PlaylistActionResolver();

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final playlist = items[index];
                      final itemLabel =
                          playlist.source == PlatformPlaylistSource.ytm
                          ? 'items'
                          : 'tracks';
                      
                      // Determine which action is available (at most one)
                      final ytmConnected = ytmState.valueOrNull?.connected == true;
                      final action = ytmConnected
                          ? actionResolver.resolveForSpotify(playlist.name, ytmPlaylists)
                          : PlaylistAction.none;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlatformPlaylistDetailPage(
                                playlist: playlist,
                              ),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
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
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: playlist.source.accentColor
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${playlist.itemCount} $itemLabel',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // SYNC button - only if playlist exists on BOTH platforms
                                if (action == PlaylistAction.sync)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      tooltip: 'Sync playlist',
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          builder: (_) => SyncBottomSheet(
                                            playlistName: playlist.name,
                                            sourcePlatform: SyncSourcePlatform.spotify,
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.autorenew_rounded,
                                        color: playlist.source.accentColor,
                                      ),
                                    ),
                                  ),
                                // TRANSFER button - only if playlist exists on ONE platform  
                                if (action == PlaylistAction.transfer)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      tooltip: 'Transfer to YouTube Music',
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          builder: (_) => TransferBottomSheet(
                                            playlistId: playlist.id,
                                            playlistName: playlist.name,
                                            forcedDestination: TransferPlatform.ytm,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.arrow_outward_rounded,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                const MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.grey)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
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
