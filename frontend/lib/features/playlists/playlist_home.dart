import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playlist_controller.dart';
import 'playlist_detail_screen.dart';
import '../../core/models/transfer.dart';
import '../sync/sync_tab.dart';
import '../platforms/sync_controller.dart';
import '../transfer/transfer_sheet.dart';

class PlaylistHomeTab extends ConsumerStatefulWidget {
  const PlaylistHomeTab({super.key});

  @override
  ConsumerState<PlaylistHomeTab> createState() => _PlaylistHomeTabState();
}

class _PlaylistHomeTabState extends ConsumerState<PlaylistHomeTab> {
  bool _creating = false;

  Future<void> _createPlaylist() async {
    final controller = ref.read(playlistControllerProvider.notifier);
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Create playlist'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                hintText: 'Road trip tunes',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name';
                }
                if (value.trim().length > 120) {
                  return 'Keep it under 120 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  setState(() => _creating = true);
                  final playlist = await controller.createPlaylist(
                    nameController.text.trim(),
                  );
                  if (!mounted) return;
                  navigator.pop(true);
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(
                        playlistId: playlist.id,
                        initialName: playlist.name,
                      ),
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    scaffold.showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _creating = false);
                }
              },
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist created')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsState = ref.watch(playlistControllerProvider);
    final controller = ref.read(playlistControllerProvider.notifier);

    Widget header() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playlists',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Build and manage your own mixes without external platforms.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createPlaylist,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadPlaylists,
      child: playlistsState.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header(),
            const SizedBox(height: 120),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (err, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _ErrorState(
                message: err.toString(),
                onRetry: controller.loadPlaylists,
              ),
            ),
          ],
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                header(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: _EmptyState(
                    onCreate: _creating ? null : _createPlaylist,
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            itemCount: playlists.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) return header();
              final playlist = playlists[index - 1];
              return _PlaylistCard(
                title: playlist.name,
                subtitle:
                    '${playlist.tracks.length} tracks · Updated ${playlist.updatedAt.toLocal().toString().split(' ').first}',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(
                        playlistId: playlist.id,
                        initialName: playlist.name,
                      ),
                    ),
                  );
                },
                onTransfer: () =>
                    _openTransferSheet(playlist.id, playlist.name),
                onSync: () => _openSyncTab(playlist.name),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openTransferSheet(
    String playlistId,
    String playlistName,
  ) async {
    final result = await showModalBottomSheet<TransferExecuteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => TransferBottomSheet(
        playlistId: playlistId,
        playlistName: playlistName,
      ),
    );

    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transfer complete: added ${result.addedCount}/${result.totalTracks} tracks.',
        ),
      ),
    );
  }

  void _openSyncTab(String playlistName) {
    ref.read(syncControllerProvider.notifier).selectPlaylist(playlistName);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncTab()));
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onTransfer,
    required this.onSync,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: const Text('Sync'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onTransfer,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Transfer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.library_music_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Text(
            'No playlists yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first playlist to start adding tracks.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create playlist'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 10),
          Text(
            'Could not load playlists',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
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
