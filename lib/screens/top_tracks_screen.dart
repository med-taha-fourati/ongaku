import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/statistics_provider.dart';

class TopTracksScreen extends ConsumerWidget {
  const TopTracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topTracksAsync = ref.watch(topTracksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Tracks'),
      ),
      body: topTracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No listening history available.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final rank = index + 1;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank <= 3 
                      ? theme.colorScheme.primaryContainer 
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: rank <= 3 
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  child: Text(
                    '$rank',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(track.song.title),
                subtitle: Text(track.song.artist),
                trailing: Chip(
                  label: Text('${track.playCount} plays'),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading tracks: $e')),
      ),
    );
  }
}
