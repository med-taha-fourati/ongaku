import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';

class PlayerBottomSheet extends ConsumerWidget {
  const PlayerBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

    String title = '';
    String subtitle = '';
    String? imageUrl;

    if (state.currentSong != null) {
      title = state.currentSong!.title;
      subtitle = state.currentSong!.artist;
      imageUrl = state.currentSong!.coverUrl;
    } else if (state.currentStation != null) {
      title = state.currentStation!.name;
      subtitle = 'Radio Station';
      imageUrl = state.currentStation!.imageUrl;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.music_note),
                        ),
                      )
                    : const Icon(Icons.music_note),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(state.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
                iconSize: 48,
                onPressed: () {
                  if (state.isPlaying) {
                    ref.read(playerProvider.notifier).pause();
                  } else {
                    ref.read(playerProvider.notifier).play();
                  }
                },
              ),
            ],
          ),
          if (state.currentSong != null)
            StreamBuilder<Duration>(
              stream: state.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = state.player.duration ?? Duration.zero;

                return Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    state.player.seek(Duration(milliseconds: value.toInt()));
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}