import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/spotify.dart';
import '../../core/models/ytm.dart';
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
  Widget build(BuildContext context) {
    final spotifyState = ref.watch(spotifyControllerProvider);
    final spotifyController = ref.read(spotifyControllerProvider.notifier);
    final ytmState = ref.watch(ytmControllerProvider);
    final ytmController = ref.read(ytmControllerProvider.notifier);

    final selectedSection = _active == _PlatformView.spotify
        ? _buildSpotifySection(context, spotifyState, spotifyController)
        : _buildYtmSection(context, ytmState, ytmController);

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
          _Header(
            active: _active,
            onSelect: (next) => setState(() => _active = next),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_active), child: selectedSection),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSpotifySection(
    BuildContext context,
    AsyncValue<SpotifyState> state,
    SpotifyController controller,
  ) {
    return state.when(
      loading: () => const _LoadingCard(label: 'Spotify'),
      error: (err, _) => _ErrorView(
        label: 'Spotify',
        message: err.toString(),
        onRetry: () => controller.load(),
      ),
      data: (data) => data.connected
          ? _ConnectedContent(state: data, controller: controller)
          : _DisconnectedContent(controller: controller, state: data),
    );
  }

  Widget _buildYtmSection(
    BuildContext context,
    AsyncValue<YtmState> state,
    YtmController controller,
  ) {
    return state.when(
      loading: () => const _LoadingCard(label: 'YouTube Music'),
      error: (err, _) => _ErrorView(
        label: 'YouTube Music',
        message: err.toString(),
        onRetry: () => controller.load(),
      ),
      data: (data) => data.connected
          ? _YtmConnectedContent(state: data, controller: controller)
          : _YtmDisconnectedContent(controller: controller, state: data),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.active, required this.onSelect});

  final _PlatformView active;
  final ValueChanged<_PlatformView> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platforms',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Browse your connected libraries. Cross-platform sync now lives in the Sync tab.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _PlatformSwitcher(active: active, onSelect: onSelect),
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
    final muted = Theme.of(context).colorScheme.surface;

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
            color: selected ? primary.withOpacity(0.12) : muted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : Colors.grey.shade800,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
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

class _DisconnectedContent extends StatelessWidget {
  const _DisconnectedContent({required this.controller, required this.state});

  final SpotifyController controller;
  final SpotifyState state;

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
                      // A gentle toast to tell users to return.
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

class _ConnectedContent extends StatelessWidget {
  const _ConnectedContent({required this.state, required this.controller});

  final SpotifyState state;
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final statusChips = <Widget>[];
    if (state.fromCache) {
      statusChips.add(
        _StatusChip(label: 'Cached', color: Colors.blueGrey.shade700),
      );
    }
    if (state.refreshFailed) {
      statusChips.add(
        _StatusChip(label: 'Refresh failed', color: Colors.orange.shade700),
      );
    }
    if (state.reauthRequired) {
      statusChips.add(
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
                  if (statusChips.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: statusChips,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Last updated from Spotify at ${_formatTimestamp(state.lastSyncedAt)}',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Next scheduled update at ${_formatTimestamp(state.nextScheduledSyncAt)}',
                style: const TextStyle(color: Colors.black87),
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
                        builder: (_) =>
                            SpotifyImportSummaryScreen(summary: summary),
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
  });

  final String name;
  final int count;
  final String lastFetched;

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

class _YtmDisconnectedContent extends StatelessWidget {
  const _YtmDisconnectedContent({
    required this.controller,
    required this.state,
  });

  final YtmController controller;
  final YtmState state;

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
  const _YtmConnectedContent({required this.state, required this.controller});

  final YtmState state;
  final YtmController controller;

  @override
  Widget build(BuildContext context) {
    final statusChips = <Widget>[];
    if (state.fromCache) {
      statusChips.add(
        _StatusChip(label: 'Cached', color: Colors.blueGrey.shade700),
      );
    }
    if (state.refreshFailed) {
      statusChips.add(
        _StatusChip(label: 'Refresh failed', color: Colors.orange.shade700),
      );
    }
    if (state.reauthRequired) {
      statusChips.add(
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
                  if (statusChips.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: statusChips,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Last updated from YouTube Music at ${_formatTimestamp(state.lastSyncedAt)}',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Next scheduled update at ${_formatTimestamp(state.nextScheduledSyncAt)}',
                style: const TextStyle(color: Colors.black87),
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
