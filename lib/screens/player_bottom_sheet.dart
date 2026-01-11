import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../widgets/full_player_screen.dart';
import '../models/song_model.dart';
import '../models/radio_station.dart';

class PlayerBottomSheet extends ConsumerWidget {
  const PlayerBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;
    final station = state.currentStation;

    // Don't show if nothing is playing or selected (unless paused but active)
    if (song == null && station == null) return const SizedBox.shrink();

    // Precise metadata extraction based on source
    String title = '';
    String subtitle = '';
    String? imageUrl;

    if (state.playbackSource == PlaybackSource.radio && station != null) {
      title = station.name;
      subtitle = station.country;
      imageUrl = station.imageUrl;
    } else if (state.playbackSource == PlaybackSource.song && song != null) {
      title = song.title;
      subtitle = song.artist;
      imageUrl = song.coverUrl;
    } else {
       // Fallback (shouldn't happen if checking source correctly)
       title = song?.title ?? station?.name ?? '';
       subtitle = song?.artist ?? station?.country ?? '';
       imageUrl = song?.coverUrl ?? station?.imageUrl;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(
              song: song,
              station: station,
              playbackSource: state.playbackSource,
              heroTag: 'mini-player-hero',
            ),
          ),
        );
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Artwork
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Hero(
                tag: 'mini-player-hero',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey,
                            child: const Icon(Icons.music_note),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey,
                          child: const Icon(Icons.music_note),
                        ),
                ),
              ),
            ),
            
            // Title & Artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause
                IconButton(
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    if (state.isPlaying) {
                      ref.read(playerProvider.notifier).pause();
                    } else {
                      ref.read(playerProvider.notifier).play();
                    }
                  },
                ),
                
                // Stop (X) - Ends Session
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Stop Playback',
                  onPressed: () {
                    ref.read(playerProvider.notifier).stop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
