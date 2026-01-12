import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/spotify.dart';
import '../../core/models/sync.dart';
import '../../core/models/ytm.dart';
import '../platforms/spotify_controller.dart';
import '../platforms/sync_controller.dart';
import '../platforms/ytm_controller.dart';

String _formatTimestamp(DateTime? dt) {
  if (dt == null) return 'Not synced yet';
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class SyncTab extends ConsumerWidget {
  const SyncTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotifyState = ref.watch(spotifyControllerProvider);
    final ytmState = ref.watch(ytmControllerProvider);
    final syncState = ref.watch(syncControllerProvider);
    final spotifyController = ref.read(spotifyControllerProvider.notifier);
    final ytmController = ref.read(ytmControllerProvider.notifier);
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
          const Text(
            'Sync',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Preview diffs, choose direction, and run cross-platform syncs without scrolling.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _ConnectionStrip(spotifyState: spotifyState, ytmState: ytmState),
          const SizedBox(height: 16),
          _SyncPanel(
            spotifyState: spotifyState,
            ytmState: ytmState,
            syncState: syncState,
            syncController: syncController,
          ),
        ],
      ),
    );
  }
}

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.spotifyState, required this.ytmState});

  final AsyncValue<SpotifyState> spotifyState;
  final AsyncValue<YtmState> ytmState;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _platformCard(
            context,
            'Spotify',
            Icons.music_note,
            spotifyState.valueOrNull?.connected ?? false,
            spotifyState.valueOrNull?.lastSyncedAt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _platformCard(
            context,
            'YouTube Music',
            Icons.play_circle_fill,
            ytmState.valueOrNull?.connected ?? false,
            ytmState.valueOrNull?.lastSyncedAt,
          ),
        ),
      ],
    );
  }

  Widget _platformCard(
    BuildContext context,
    String label,
    IconData icon,
    bool connected,
    DateTime? lastSync,
  ) {
    final color = connected ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              _StatusChip(
                label: connected ? 'Connected' : 'Not connected',
                color: connected ? Colors.green.shade700 : Colors.red.shade400,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Last sync: ${_formatTimestamp(lastSync)}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    required this.spotifyState,
    required this.ytmState,
    required this.syncState,
    required this.syncController,
  });

  final AsyncValue<SpotifyState> spotifyState;
  final AsyncValue<YtmState> ytmState;
  final SyncState syncState;
  final SyncController syncController;

  @override
  Widget build(BuildContext context) {
    if (spotifyState.isLoading || ytmState.isLoading) {
      return const _InfoCard(
        title: 'Loading platform data',
        body: 'Fetching Spotify and YouTube Music libraries...',
      );
    }

    final spotify = spotifyState.valueOrNull;
    final ytm = ytmState.valueOrNull;

    if (spotify == null || ytm == null) {
      return const _InfoCard(
        title: 'Sync unavailable',
        body: 'Load Spotify and YouTube Music first, then retry.',
      );
    }

    if (!spotify.connected || !ytm.connected) {
      return const _InfoCard(
        title: 'Connect both platforms',
        body: 'Connect Spotify and YouTube Music to preview and run syncs.',
      );
    }

    final sharedNames = _sharedPlaylistNames(spotify.playlists, ytm.playlists);
    final selectedName = sharedNames.contains(syncState.selectedPlaylist)
        ? syncState.selectedPlaylist
        : null;

    if (sharedNames.isEmpty) {
      return const _InfoCard(
        title: 'No matching playlists',
        body: 'Create playlists with the same name on both platforms to sync.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
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
                  if (selected) {
                    syncController.setDirection(SyncDirection.spotifyToYtm);
                  }
                },
              ),
              ChoiceChip(
                label: const Text('YTM → Spotify'),
                selected: syncState.direction == SyncDirection.ytmToSpotify,
                onSelected: (selected) {
                  if (selected) {
                    syncController.setDirection(SyncDirection.ytmToSpotify);
                  }
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
                        syncState.preview == null ||
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
    if (syncState.preview == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview first to confirm changes.')),
      );
      return;
    }

    final preview = syncState.preview!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ready to sync?'),
          content: Text(
            'This will add ${preview.toAdd.length}, remove ${preview.toRemove.length} (only in full sync), and skip ${preview.skipped.length} tracks. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;

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
                '${preview.toAdd.length} to add · ${preview.toRemove.length} to remove (full sync only) · ${preview.skipped.length} to skip',
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
          if (preview.skipped.isNotEmpty)
            _TrackList(
              title: 'Will skip (no exact match)',
              tracks: preview.skipped,
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
        border: Border.all(color: Colors.grey.shade800),
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
