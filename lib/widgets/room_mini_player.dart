import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_player_provider.dart';

class RoomMiniPlayer extends ConsumerWidget {
  final String roomId;
  final bool isHost;

  const RoomMiniPlayer({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomPlayerProvider(roomId));
    final song = state.currentSong;

    if (song == null) return const SizedBox.shrink();

    final heroTag = 'room-artwork-${song.id}';

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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                    ? Hero(
                        tag: heroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            song.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.music_note),
                          ),
                        ),
                      )
                    : Hero(
                        tag: heroTag,
                        child: const Icon(Icons.music_note),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isHost)
                IconButton(
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  iconSize: 48,
                  onPressed: () {
                    if (state.isPlaying) {
                      ref.read(roomPlayerProvider(roomId).notifier).hostPause();
                    } else {
                      ref.read(roomPlayerProvider(roomId).notifier).hostResume();
                    }
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: state.duration.inMilliseconds > 0
                      ? state.position.inMilliseconds / state.duration.inMilliseconds
                      : 0,
                  borderRadius: BorderRadius.circular(2),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(state.position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(state.duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isHost)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                 IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () {
                     ref.read(roomPlayerProvider(roomId).notifier).playNext();
                  },
                ),
              ],
            )
        ],
      ),
    );
  }
}
