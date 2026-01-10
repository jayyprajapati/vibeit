import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/sync.dart';
import '../../core/models/spotify.dart';
import '../../core/models/ytm.dart';
import 'spotify_controller.dart';
import 'spotify_import_summary.dart';
import 'sync_controller.dart';
import 'ytm_controller.dart';

String _formatTimestamp(DateTime? dt) {
  if (dt == null) return 'Not synced yet';
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class PlatformsTab extends ConsumerWidget {
  const PlatformsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotifyState = ref.watch(spotifyControllerProvider);
    final spotifyController = ref.read(spotifyControllerProvider.notifier);
    final ytmState = ref.watch(ytmControllerProvider);
    final ytmController = ref.read(ytmControllerProvider.notifier);
    final syncState = ref.watch(syncControllerProvider);
    final syncController = ref.read(syncControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([spotifyController.load(), ytmController.load()]);
      },
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          const _Header(),
          const SizedBox(height: 12),
          _buildSpotifySection(context, spotifyState, spotifyController),
          const SizedBox(height: 20),
          _buildYtmSection(context, ytmState, ytmController),
          const SizedBox(height: 20),
          _buildSyncSection(
            context,
            spotifyState,
            ytmState,
            syncState,
            syncController,
            spotifyController,
            ytmController,
          ),
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

  Widget _buildSyncSection(
    BuildContext context,
    AsyncValue<SpotifyState> spotifyState,
    AsyncValue<YtmState> ytmState,
    SyncState syncState,
    SyncController syncController,
    SpotifyController spotifyController,
    YtmController ytmController,
  ) {
    return _SyncCard(
      spotifyState: spotifyState,
      ytmState: ytmState,
      syncState: syncState,
      syncController: syncController,
      spotifyController: spotifyController,
      ytmController: ytmController,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
          'Connect Spotify or YouTube Music to pull your playlists. Data is cached for 24 hours and refreshed on demand.',
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

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.spotifyState,
    required this.ytmState,
    required this.syncState,
    required this.syncController,
    required this.spotifyController,
    required this.ytmController,
  });

  final AsyncValue<SpotifyState> spotifyState;
  final AsyncValue<YtmState> ytmState;
  final SyncState syncState;
  final SyncController syncController;
  final SpotifyController spotifyController;
  final YtmController ytmController;

  @override
  Widget build(BuildContext context) {
    if (spotifyState.isLoading || ytmState.isLoading) {
      return const _LoadingCard(label: 'Cross-platform sync');
    }

    final spotify = spotifyState.valueOrNull;
    final ytm = ytmState.valueOrNull;

    if (spotify == null || ytm == null) {
      return _InfoCard(
        title: 'Sync unavailable',
        body: 'Load Spotify and YouTube Music first, then retry.',
      );
    }

    if (!spotify.connected || !ytm.connected) {
      return _InfoCard(
        title: 'Connect both platforms',
        body: 'Connect Spotify and YouTube Music to preview and run syncs.',
      );
    }

    final sharedNames = _sharedPlaylistNames(spotify.playlists, ytm.playlists);
    final selectedName = sharedNames.contains(syncState.selectedPlaylist)
        ? syncState.selectedPlaylist
        : null;

    if (sharedNames.isEmpty) {
      return _InfoCard(
        title: 'No matching playlists',
        body: 'Create playlists with the same name on both platforms to sync.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.compare_arrows_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text(
                'Cross-platform sync',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview exact matches before syncing. Only tracks with the same title and primary artist will move.',
            style: TextStyle(color: Colors.grey),
          ),
          if (syncState.message != null) ...[
            const SizedBox(height: 10),
            _InfoBadge(message: syncState.message!),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedName,
            decoration: const InputDecoration(
              labelText: 'Playlist (must exist on both)',
              border: OutlineInputBorder(),
            ),
            items: sharedNames
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: syncState.isPreviewing || syncState.isExecuting
                ? null
                : (value) => syncController.selectPlaylist(value),
          ),
          const SizedBox(height: 12),
          _ChoiceRow(
            label: 'Direction',
            children: [
              ChoiceChip(
                label: const Text('Spotify → YTM'),
                selected: syncState.direction == SyncDirection.spotifyToYtm,
                onSelected: (selected) {
                  if (selected)
                    syncController.setDirection(SyncDirection.spotifyToYtm);
                },
              ),
              ChoiceChip(
                label: const Text('YTM → Spotify'),
                selected: syncState.direction == SyncDirection.ytmToSpotify,
                onSelected: (selected) {
                  if (selected)
                    syncController.setDirection(SyncDirection.ytmToSpotify);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ChoiceRow(
            label: 'Mode',
            children: [
              ChoiceChip(
                label: const Text('Append only'),
                selected: syncState.mode == SyncMode.appendOnly,
                onSelected: (selected) {
                  if (selected) syncController.setMode(SyncMode.appendOnly);
                },
              ),
              ChoiceChip(
                label: const Text('Full sync'),
                selected: syncState.mode == SyncMode.fullSync,
                onSelected: (selected) {
                  if (selected) syncController.setMode(SyncMode.fullSync);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed:
                    selectedName == null ||
                        syncState.isPreviewing ||
                        syncState.isExecuting
                    ? null
                    : () async {
                        await _handlePreview(context);
                      },
                icon: syncState.isPreviewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  syncState.isPreviewing ? 'Previewing...' : 'Preview changes',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    selectedName == null ||
                        syncState.isExecuting ||
                        syncState.isPreviewing
                    ? null
                    : () async {
                        await _handleExecute(context);
                      },
                icon: syncState.isExecuting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  syncState.isExecuting ? 'Running...' : 'Execute sync',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (syncState.preview != null)
            _PreviewPanel(preview: syncState.preview!, mode: syncState.mode),
          if (syncState.result != null) _ResultPanel(result: syncState.result!),
          if (syncState.preview == null && syncState.result == null)
            const Text(
              'Preview first to see what will change. Removes only apply in full sync.',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Future<void> _handlePreview(BuildContext context) async {
    try {
      final ok = await syncController.previewSync();
      if (!context.mounted || !ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview ready. Review before running sync.'),
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
      syncController.resetFlow();
    }
  }

  Future<void> _handleExecute(BuildContext context) async {
    try {
      final outcome = await syncController.executeSync();
      if (!context.mounted) return;

      if (outcome.isSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync complete.')));
        return;
      }

      if (outcome.needsPermission && outcome.permissionTarget != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Write access required. Go to Profile > Platform access to grant it.',
            ),
          ),
        );
        return;
      }

      if (outcome.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(outcome.errorMessage!)));
      }
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
      syncController.resetFlow();
    }
  }

  List<String> _sharedPlaylistNames(
    List<SpotifyPlaylistSummary> spotify,
    List<YtmPlaylistSummary> ytm,
  ) {
    final left = spotify.map((p) => p.name).toSet();
    final right = ytm.map((p) => p.name).toSet();
    final names = left.intersection(right).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.preview, required this.mode});

  final SyncPreviewResult preview;
  final SyncMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(
                label: _caseLabel(preview.caseLabel),
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                '${preview.toAdd.length} to add · ${preview.toRemove.length} to remove (full sync only)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (preview.toAdd.isNotEmpty)
            _TrackList(title: 'Will add', tracks: preview.toAdd),
          if (preview.toRemove.isNotEmpty)
            _TrackList(
              title: mode == SyncMode.fullSync
                  ? 'Will remove'
                  : 'Removals (only in full sync)',
              tracks: preview.toRemove,
            ),
          if (preview.toAdd.isEmpty && preview.toRemove.isEmpty)
            const Text('Playlists already match.'),
        ],
      ),
    );
  }

  String _caseLabel(SyncCaseLabel label) {
    switch (label) {
      case SyncCaseLabel.equal:
        return 'Already in sync';
      case SyncCaseLabel.subset:
        return 'Destination missing tracks';
      case SyncCaseLabel.superset:
        return 'Destination has extras';
      case SyncCaseLabel.partial:
        return 'Differences found';
    }
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final SyncExecuteResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync result',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(
                label: 'Added ${result.addedCount}',
                color: Colors.green.shade600,
              ),
              _StatusChip(
                label: 'Removed ${result.removedCount}',
                color: Colors.red.shade400,
              ),
              _StatusChip(
                label: 'Skipped ${result.skippedCount}',
                color: Colors.orange.shade700,
              ),
            ],
          ),
          if (result.skippedTracks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TrackList(
              title: 'Skipped (no exact match)',
              tracks: result.skippedTracks,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.title, required this.tracks});

  final String title;
  final List<SyncTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final display = tracks.take(4).toList();
    final remaining = tracks.length - display.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...display.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.music_note, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${t.title} — ${t.artist}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (remaining > 0)
          Text('+$remaining more', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.grey)),
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
