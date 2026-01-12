import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transfer.dart';
import '../../providers.dart';
import 'transfer_repository.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return TransferRepository(apiClient: api);
});

class TransferBottomSheet extends ConsumerStatefulWidget {
  const TransferBottomSheet({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  final String playlistId;
  final String playlistName;

  @override
  ConsumerState<TransferBottomSheet> createState() => _TransferBottomSheetState();
}

class _TransferBottomSheetState extends ConsumerState<TransferBottomSheet> {
  TransferPlatform _destination = TransferPlatform.spotify;
  TransferPreviewResult? _preview;
  bool _isPreviewing = false;
  bool _isExecuting = false;
  String? _message;

  String? get _token =>
      ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> _runPreview() async {
    final token = _token;
    if (token == null) {
      setState(() => _message = 'Sign in to preview transfer.');
      return;
    }

    setState(() {
      _isPreviewing = true;
      _message = null;
      _preview = null;
    });

    try {
      final repo = ref.read(transferRepositoryProvider);
      final result = await repo.preview(
        token: token,
        sourcePlatform: TransferPlatform.vibeit,
        destinationPlatform: _destination,
        playlistId: widget.playlistId,
      );
      setState(() {
        _preview = result;
      });
    } catch (err) {
      setState(() {
        _message = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isPreviewing = false);
      }
    }
  }

  Future<void> _runExecute() async {
    final token = _token;
    if (token == null) {
      setState(() => _message = 'Sign in to run transfer.');
      return;
    }

    setState(() {
      _isExecuting = true;
      _message = null;
    });

    try {
      final repo = ref.read(transferRepositoryProvider);
      final result = await repo.execute(
        token: token,
        sourcePlatform: TransferPlatform.vibeit,
        destinationPlatform: _destination,
        playlistId: widget.playlistId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (err) {
      setState(() => _message = err.toString());
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

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
              Row(
                children: [
                  const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transfer ${widget.playlistName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a new playlist on the destination platform. Tracks are added if they resolve; unresolvable tracks are skipped.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text('Destination', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Spotify'),
                    selected: _destination == TransferPlatform.spotify,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _destination = TransferPlatform.spotify;
                          _preview = null;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('YouTube Music'),
                    selected: _destination == TransferPlatform.ytm,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _destination = TransferPlatform.ytm;
                          _preview = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_message != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (preview != null) ...[
                _PreviewSummary(preview: preview),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isPreviewing ? null : _runPreview,
                    icon: _isPreviewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility),
                    label: Text(_isPreviewing ? 'Previewing...' : 'Preview transfer'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed:
                        preview == null || _isExecuting || _isPreviewing
                            ? null
                            : _runExecute,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check_rounded),
                    label: Text(
                      _isExecuting ? 'Creating...' : 'Create on ${_destination == TransferPlatform.spotify ? 'Spotify' : 'YTM'}',
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

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview});

  final TransferPreviewResult preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                '${preview.toAdd.length} will be added · ${preview.skipped.length} skipped',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Only adds and skips are shown. No removals during transfer.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          if (preview.toAdd.isNotEmpty) ...[
            const Text('To add', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...preview.toAdd.take(5).map(
              (t) => _PreviewRow(icon: Icons.add, color: Colors.greenAccent, track: t),
            ),
            if (preview.toAdd.length > 5)
              Text('and ${preview.toAdd.length - 5} more...', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
          ],
          if (preview.skipped.isNotEmpty) ...[
            const Text('Skipped', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...preview.skipped.take(5).map(
              (t) => _PreviewRow(icon: Icons.block, color: Colors.orangeAccent, track: t),
            ),
            if (preview.skipped.length > 5)
              Text('and ${preview.skipped.length - 5} more...', style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.color,
    required this.track,
  });

  final IconData icon;
  final Color color;
  final TransferTrack track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${track.title} · ${track.artist}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
