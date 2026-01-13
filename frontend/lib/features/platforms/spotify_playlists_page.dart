import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_playlist_detail_page.dart';
import 'platform_playlist_models.dart';
import 'spotify_controller.dart';

class SpotifyPlaylistsPage extends ConsumerWidget {
  const SpotifyPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotifyControllerProvider);
    final controller = ref.read(spotifyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Spotify playlists')),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const _GradientHeader(
              title: 'Your Spotify playlists',
              colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
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

                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PlatformPlaylistDetailPage(playlist: playlist),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: playlist.source.accentColor.withValues(
                                    alpha: 0.18,
                                  ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${playlist.itemCount} $itemLabel · Updated $updated',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
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

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.title, required this.colors});

  final String title;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 18,
          16,
          24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: kToolbarHeight),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse everything synced from your Spotify account.',
              style: TextStyle(color: Colors.black87),
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
