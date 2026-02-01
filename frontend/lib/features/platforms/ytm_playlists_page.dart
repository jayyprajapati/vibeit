import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_playlist_detail_page.dart';
import 'platform_playlist_models.dart';
import 'ytm_controller.dart';
import 'playlist_hero_banner.dart';
import 'spotify_controller.dart';
import '../../core/design_system.dart';

class YtmPlaylistsPage extends ConsumerWidget {
  const YtmPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ytmControllerProvider);
    final controller = ref.read(ytmControllerProvider.notifier);
    final spotifyState = ref.watch(spotifyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: PlaylistHeroBanner(
                title: 'YouTube Music Playlists',
                colors: [Color(0xFFEA4335), Color(0xFFF28B82)],
                icon: Icons.play_circle_fill,
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
                        message:
                            'Connect YouTube Music to browse playlists here.',
                        actionLabel: 'Grant access',
                        onAction: () async {
                          try {
                            await controller.startConnectFlow();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Finish YouTube Music login, then refresh.',
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
                          itemCount: p.itemCount,
                          lastFetchedAt: p.lastFetchedAt,
                          source: PlatformPlaylistSource.ytm,
                        ),
                      )
                      .toList();

                  if (items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _ListMessage(
                        message:
                            'No YouTube Music playlists found yet. Try syncing again.',
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final playlist = items[index];
                      final itemLabel =
                          playlist.source == PlatformPlaylistSource.ytm
                          ? 'items'
                          : 'tracks';
                      final updated = playlist.lastFetchedAt
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first;
                      final canTransfer =
                          spotifyState.valueOrNull?.connected == true;
                      final canSync = canTransfer;

                      void showToast(String message) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }

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
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppShadows.card,
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
                                    Icons.play_circle_fill,
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
                                        '${playlist.itemCount} $itemLabel · Updated $updated',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canSync)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      tooltip: 'Sync playlist',
                                      onPressed: () =>
                                          showToast('Sync coming soon'),
                                      icon: Icon(
                                        Icons.sync_alt,
                                        color: playlist.source.accentColor,
                                      ),
                                    ),
                                  ),
                                if (canTransfer)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      tooltip: 'Transfer playlist',
                                      onPressed: () =>
                                          showToast('Transfer coming soon'),
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
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
