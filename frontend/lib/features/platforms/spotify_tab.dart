import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spotify_controller.dart';
import 'spotify_import_summary.dart';
import 'ytm_controller.dart';

enum _PlatformView { spotify, ytm }

String _formatTimestamp(DateTime? dt) {
  if (dt == null) return 'Not synced yet';
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class PlatformsTab extends ConsumerStatefulWidget {
  const PlatformsTab({super.key});

  @override
  ConsumerState<PlatformsTab> createState() => _PlatformsTabState();
}

class _PlatformsTabState extends ConsumerState<PlatformsTab> {
  _PlatformView _active = _PlatformView.spotify;

  @override
  void initState() {
    super.initState();
    // Lazy-load playlists only when user navigates to this tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spotifyControllerProvider.notifier).load();
      ref.read(ytmControllerProvider.notifier).load();
    });
  }

  Future<void> _refreshPlatformCaches() async {
    try {
      await Future.wait([
        ref.read(spotifyControllerProvider.notifier).load(),
        ref.read(ytmControllerProvider.notifier).load(),
      ]);
    } catch (_) {
      // Keep cache as-is on refresh errors; UI already shows prior data.
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotifyState = ref.watch(spotifyControllerProvider);
    final ytmState = ref.watch(ytmControllerProvider);
    final spotifyController = ref.read(spotifyControllerProvider.notifier);
    final ytmController = ref.read(ytmControllerProvider.notifier);

    final section = _active == _PlatformView.spotify
        ? _buildSpotifySection(spotifyState, spotifyController)
        : _buildYtmSection(ytmState, ytmController);

    return RefreshIndicator(
      onRefresh: () async {
        if (_active == _PlatformView.spotify) {
          await spotifyController.load();
        } else {
          await ytmController.load();
        }
      },
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          _Header(active: _active),
          const SizedBox(height: 12),
          _PlatformSwitcher(
            active: _active,
            onSelect: (next) => setState(() => _active = next),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_active), child: section),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifySection(
    AsyncValue<SpotifyState> state,
    SpotifyController controller,
  ) {
    return state.when(
      loading: () => const _LoadingCard(label: 'Spotify'),
      error: (err, _) => _ErrorView(
        label: 'Spotify',
        message: err.toString(),
        onRetry: controller.load,
      ),
      data: (data) => data.connected
          ? _SpotifyConnectedContent(
              state: data,
              controller: controller,
              onAfterSync: _refreshPlatformCaches,
            )
          : _SpotifyDisconnectedContent(state: data, controller: controller),
    );
  }

  Widget _buildYtmSection(
    AsyncValue<YtmState> state,
    YtmController controller,
  ) {
    return state.when(
      loading: () => const _LoadingCard(label: 'YouTube Music'),
      error: (err, _) => _ErrorView(
        label: 'YouTube Music',
        message: err.toString(),
        onRetry: controller.load,
      ),
      data: (data) => data.connected
          ? _YtmConnectedContent(
              state: data,
              controller: controller,
              onAfterSync: _refreshPlatformCaches,
            )
          : _YtmDisconnectedContent(state: data, controller: controller),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.active});

  final _PlatformView active;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Platforms',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'Browse your connected libraries. Cross-platform sync now lives in the Sync tab.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _PlatformSwitcher extends StatelessWidget {
  const _PlatformSwitcher({required this.active, required this.onSelect});

  final _PlatformView active;
  final ValueChanged<_PlatformView> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    Widget pill({
      required _PlatformView view,
      required String label,
      required IconData icon,
    }) {
      final selected = active == view;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : Colors.grey.shade800,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(view),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? primary : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            pill(
              view: _PlatformView.spotify,
              label: 'Spotify',
              icon: Icons.music_note,
            ),
            const SizedBox(width: 10),
            pill(
              view: _PlatformView.ytm,
              label: 'YouTube Music',
              icon: Icons.play_circle_fill,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Read-only browsing. Use Sync tab to copy playlists across platforms.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _SpotifyDisconnectedContent extends StatelessWidget {
  const _SpotifyDisconnectedContent({
    required this.state,
    required this.controller,
  });

  final SpotifyState state;
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.link_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text(
                'Spotify not connected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap connect to open Spotify. After approving, return here and tap "Sync now" to pull your playlists.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: state.isAuthorizing
                ? null
                : () async {
                    try {
                      await controller.startConnectFlow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Complete Spotify login, then come back to sync.',
                            ),
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err.toString())));
                      }
                    }
                  },
            icon: state.isAuthorizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new_rounded),
            label: const Text('Connect Spotify'),
          ),
        ],
      ),
    );
  }
}

class _SpotifyConnectedContent extends StatelessWidget {
  const _SpotifyConnectedContent({
    required this.state,
    required this.controller,
    this.onAfterSync,
  });

  final SpotifyState state;
  final SpotifyController controller;
  final Future<void> Function()? onAfterSync;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (state.fromCache) {
      chips.add(_StatusChip(label: 'Cached', color: Colors.blueGrey.shade700));
    }
    if (state.refreshFailed) {
      chips.add(
        _StatusChip(label: 'Refresh failed', color: Colors.orange.shade700),
      );
    }
    if (state.reauthRequired) {
      chips.add(
        _StatusChip(
          label: 'Reconnect needed',
          color: Colors.redAccent.shade200,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.library_music,
                    color: Colors.black,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Spotify connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (chips.isNotEmpty)
                    Flexible(
                      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Last updated from Spotify at ${_formatTimestamp(state.lastSyncedAt)}',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 6),
              const Text(
                'No background timers. Cache stays until you sync again.',
                style: TextStyle(color: Colors.black87),
              ),
              if (state.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.message!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: state.isSyncing
                        ? null
                        : () async {
                            try {
                              await controller.syncNow();
                              await onAfterSync?.call();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Synced with Spotify. Cache updated.',
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
                    icon: state.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Sync now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.isAuthorizing
                        ? null
                        : () async {
                            try {
                              await controller.startConnectFlow();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Reconnect in the browser, then return to refresh.',
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
                    icon: state.isAuthorizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.hasPlaylists)
          ...state.playlists.map(
            (playlist) => _PlaylistRow(
              name: playlist.name,
              count: playlist.trackCount,
              lastFetched: _formatTimestamp(playlist.lastFetchedAt),
              isImporting: state.importingIds.contains(playlist.id),
              onImport: () async {
                try {
                  final summary = await controller.importPlaylist(playlist.id);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ImportSummaryScreen(
                          playlistName: summary.playlistName,
                          totalTracks: summary.totalTracks,
                          importedCount: summary.importedCount,
                          skippedCount: summary.skippedCount,
                          skippedTracks: summary.skippedTracks
                              .map(
                                (t) => ImportSkippedTrack(
                                  name: t.name,
                                  reason: t.reason,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                }
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No playlists yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'We did not find any playlists for this account. Create one in Spotify and sync again.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _YtmDisconnectedContent extends StatelessWidget {
  const _YtmDisconnectedContent({
    required this.state,
    required this.controller,
  });

  final YtmState state;
  final YtmController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.link_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'YouTube Music not connected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap connect to open YouTube Music. Approve access, then return to refresh playlists.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: state.isAuthorizing
                ? null
                : () async {
                    try {
                      await controller.startConnectFlow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Complete YouTube Music login, then come back to sync.',
                            ),
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err.toString())));
                      }
                    }
                  },
            icon: state.isAuthorizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new_rounded),
            label: const Text('Connect YouTube Music'),
          ),
        ],
      ),
    );
  }
}

class _YtmConnectedContent extends StatelessWidget {
  const _YtmConnectedContent({
    required this.state,
    required this.controller,
    this.onAfterSync,
  });

  final YtmState state;
  final YtmController controller;
  final Future<void> Function()? onAfterSync;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (state.fromCache) {
      chips.add(_StatusChip(label: 'Cached', color: Colors.blueGrey.shade700));
    }
    if (state.refreshFailed) {
      chips.add(
        _StatusChip(label: 'Refresh failed', color: Colors.orange.shade700),
      );
    }
    if (state.reauthRequired) {
      chips.add(
        _StatusChip(
          label: 'Reconnect needed',
          color: Colors.redAccent.shade200,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFEA4335), Color(0xFFF28B82)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.black,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'YouTube Music connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (chips.isNotEmpty)
                    Flexible(
                      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Last updated from YouTube Music at ${_formatTimestamp(state.lastSyncedAt)}',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 6),
              const Text(
                'No background timers. Cache stays until you sync again.',
                style: TextStyle(color: Colors.black87),
              ),
              if (state.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.message!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: state.isSyncing
                        ? null
                        : () async {
                            try {
                              await controller.syncNow();
                              await onAfterSync?.call();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Synced with YouTube Music. Cache updated.',
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
                    icon: state.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Sync now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.isAuthorizing
                        ? null
                        : () async {
                            try {
                              await controller.startConnectFlow();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Reconnect in the browser, then return to refresh.',
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
                    icon: state.isAuthorizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Music playlists you created',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (state.hasPlaylists)
          ...state.playlists.map(
            (playlist) => _YtmPlaylistRow(
              name: playlist.name,
              count: playlist.itemCount,
              lastFetched: _formatTimestamp(playlist.lastFetchedAt),
              isImporting: state.importingIds.contains(playlist.id),
              onImport: () async {
                try {
                  final summary = await controller.importPlaylist(playlist.id);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ImportSummaryScreen(
                          playlistName: summary.playlistName,
                          totalTracks: summary.totalTracks,
                          importedCount: summary.importedCount,
                          skippedCount: summary.skippedCount,
                          skippedTracks: summary.skippedTracks
                              .map(
                                (t) => ImportSkippedTrack(
                                  name: t.name,
                                  reason: t.reason,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                }
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No playlists yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'We did not find any playlists for this account. Create one in YouTube Music and sync again.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.name,
    required this.count,
    required this.lastFetched,
    required this.isImporting,
    required this.onImport,
  });

  final String name;
  final int count;
  final String lastFetched;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music_rounded, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count tracks · Updated $lastFetched',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(isImporting ? 'Importing...' : 'Import to Vibeit'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _YtmPlaylistRow extends StatelessWidget {
  const _YtmPlaylistRow({
    required this.name,
    required this.count,
    required this.lastFetched,
    required this.isImporting,
    required this.onImport,
  });

  final String name;
  final int count;
  final String lastFetched;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.playlist_play_rounded, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count items · Updated $lastFetched',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(isImporting ? 'Importing...' : 'Import to Vibeit'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(width: 12),
          Text(
            'Loading $label...',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.label,
    required this.message,
    required this.onRetry,
  });

  final String label;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          Text(
            'Could not load $label',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}
