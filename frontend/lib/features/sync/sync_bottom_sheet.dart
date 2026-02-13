import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/models/sync.dart';
import '../../providers.dart';
import '../platforms/sync_controller.dart';
import '../platforms/spotify_controller.dart';
import '../platforms/ytm_controller.dart';

/// Source platform for sync operation
enum SyncSourcePlatform { spotify, ytm }

/// Bottom sheet for sync operations with clean minimal design.
/// 
/// Shows preview with sections: ADDED, REMOVED, KEPT, SKIPPED
/// Uses left color bars instead of boxy cards for visual clarity.
class SyncBottomSheet extends ConsumerStatefulWidget {
  const SyncBottomSheet({
    super.key,
    required this.playlistName,
    required this.sourcePlatform,
  });

  final String playlistName;
  final SyncSourcePlatform sourcePlatform;

  @override
  ConsumerState<SyncBottomSheet> createState() => _SyncBottomSheetState();
}

class _SyncBottomSheetState extends ConsumerState<SyncBottomSheet> {
  bool _isPreviewing = false;
  bool _isExecuting = false;
  SyncPreviewResult? _preview;
  String? _error;

  String? get _token => ref.read(authControllerProvider).valueOrNull?.token;

  String get _sourceName =>
      widget.sourcePlatform == SyncSourcePlatform.spotify ? 'Spotify' : 'YouTube Music';
  
  String get _destName =>
      widget.sourcePlatform == SyncSourcePlatform.spotify ? 'YouTube Music' : 'Spotify';

  SyncDirection get _direction =>
      widget.sourcePlatform == SyncSourcePlatform.spotify
          ? SyncDirection.spotifyToYtm
          : SyncDirection.ytmToSpotify;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final token = _token;
    if (token == null) {
      setState(() => _error = 'Sign in to preview sync.');
      return;
    }

    setState(() {
      _isPreviewing = true;
      _error = null;
    });

    try {
      final syncController = ref.read(syncControllerProvider.notifier);
      syncController.selectPlaylist(widget.playlistName);
      syncController.setDirection(_direction);
      
      final ok = await syncController.previewSync();
      if (!mounted) return;
      
      if (ok) {
        final state = ref.read(syncControllerProvider);
        setState(() {
          _preview = state.preview;
          _isPreviewing = false;
        });
      } else {
        final state = ref.read(syncControllerProvider);
        setState(() {
          _error = state.message ?? 'Preview failed';
          _isPreviewing = false;
        });
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isPreviewing = false;
      });
    }
  }

  Future<void> _executeSync() async {
    final token = _token;
    if (token == null) {
      setState(() => _error = 'Sign in to run sync.');
      return;
    }

    setState(() {
      _isExecuting = true;
      _error = null;
    });

    try {
      final syncController = ref.read(syncControllerProvider.notifier);
      final outcome = await syncController.executeSync();
      
      if (!mounted) return;

      if (outcome.isSuccess) {
        // Refresh platform caches
        await Future.wait([
          ref.read(spotifyControllerProvider.notifier).load(),
          ref.read(ytmControllerProvider.notifier).load(),
        ]);
        
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced! Added ${outcome.result!.addedCount}, removed ${outcome.result!.removedCount}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _error = outcome.errorMessage ?? 'Sync failed';
          _isExecuting = false;
        });
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isExecuting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sync Playlist',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Context text
              Text(
                'You are syncing your $_sourceName playlist "${widget.playlistName}" to $_destName',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Loading state
              if (_isPreviewing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading preview...'),
                      ],
                    ),
                  ),
                ),

              // Preview content
              if (_preview != null && !_isPreviewing) ...[
                _buildPreviewContent(_preview!),
                const SizedBox(height: 16),
              ],

              // Action buttons
              if (_preview != null && !_isPreviewing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isExecuting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isExecuting ? null : _executeSync,
                        child: _isExecuting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sync playlist'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent(SyncPreviewResult preview) {
    final hasChanges = preview.toAdd.isNotEmpty || preview.toRemove.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              _buildStatChip('Added', preview.toAdd.length, Colors.green),
              const SizedBox(width: 8),
              _buildStatChip('Removed', preview.toRemove.length, Colors.red),
              const SizedBox(width: 8),
              _buildStatChip('Skipped', preview.skipped.length, Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!hasChanges) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Playlists are already in sync!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ADDED section
        if (preview.toAdd.isNotEmpty)
          _buildTrackSection(
            title: 'Will be added',
            tracks: preview.toAdd,
            color: Colors.green,
            icon: Icons.add_circle_outline,
          ),

        // REMOVED section
        if (preview.toRemove.isNotEmpty)
          _buildTrackSection(
            title: 'Will be removed',
            tracks: preview.toRemove,
            color: Colors.red,
            icon: Icons.remove_circle_outline,
          ),

        // SKIPPED section
        if (preview.skipped.isNotEmpty)
          _buildTrackSection(
            title: 'Could not be matched',
            tracks: preview.skipped,
            color: Colors.grey,
            icon: Icons.warning_amber_rounded,
          ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTrackSection({
    required String title,
    required List<SyncTrack> tracks,
    required Color color,
    required IconData icon,
  }) {
    final displayTracks = tracks.take(5).toList();
    final remaining = tracks.length - displayTracks.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${tracks.length})',
                  style: TextStyle(color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...displayTracks.map(
              (track) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${track.title} — ${track.artist}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (remaining > 0)
              Text(
                '+$remaining more',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
