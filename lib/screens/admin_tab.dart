import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/song_provider.dart';
import '../models/song_model.dart';
import '../widgets/song_tile.dart';

class AdminTab extends ConsumerWidget {
  const AdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSongsAsync = ref.watch(pendingSongsProvider);

    return pendingSongsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(
            child: Text('No pending songs to review'),
          );
        }

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongTile(
              song: song,
              onTap: () {
                _showReviewDialog(context, ref, song);
              },
              trailing: const Icon(Icons.pending),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Failed to load pending songs'),
      ),
    );
  }

  Future<void> _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    SongModel song,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${song.title}'),
            const SizedBox(height: 8),
            Text('Artist: ${song.artist}'),
            if (song.genre.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Genre: ${song.genre}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final repository = ref.read(songRepositoryProvider);
              await repository.updateSongStatus(song.id, SongStatus.rejected);
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final repository = ref.read(songRepositoryProvider);
              await repository.updateSongStatus(song.id, SongStatus.approved);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}