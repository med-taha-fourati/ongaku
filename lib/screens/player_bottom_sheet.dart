import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/radio_station.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';

class PlayerBottomSheet extends ConsumerWidget {
  const PlayerBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

    final song = state.currentSong;
    final station = state.currentStation;
    final playbackSource = state.playbackSource;
    final bool isRadio = playbackSource == PlaybackSource.radio ||
        (playbackSource == null && station != null && song == null);
    final bool isSong = playbackSource == PlaybackSource.song ||
        (playbackSource == null && song != null);

    final String title = playbackSource == PlaybackSource.radio
        ? (station?.name ?? '')
        : (playbackSource == PlaybackSource.song
            ? (song?.title ?? '')
            : ((song != null && song.title.isNotEmpty)
                ? song.title
                : (station?.name ?? '')));
    final String subtitle = playbackSource == PlaybackSource.radio
        ? (station?.country ?? '')
        : (playbackSource == PlaybackSource.song
            ? (song?.artist ?? '')
            : ((song != null && song.artist.isNotEmpty)
                ? song.artist
                : (station?.country ?? '')));
    final String? imageUrl = playbackSource == PlaybackSource.radio
        ? station?.imageUrl
        : song?.coverUrl;

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
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
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
                    if (subtitle.isNotEmpty)
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: (playbackSource == PlaybackSource.radio ||
                    (playbackSource == null && station != null && song == null))
                ? (station != null
                    ? KeyedSubtree(
                        key: ValueKey(
                            "radio-${playbackSource ?? 'none'}-${station.id}"),
                        child: _buildRadioDetails(context, station),
                      )
                    : const SizedBox.shrink())
                : KeyedSubtree(
                    key: ValueKey(
                        "song-${playbackSource ?? 'none'}-${song?.id ?? 'none'}"),
                    child: _buildSongProgress(context, state),
                  ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildRadioDetails(BuildContext context, RadioStation station) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(Icons.public, station.country),
              _buildDetailItem(Icons.category, station.genre),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Streaming live radio",
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSongProgress(BuildContext context, PlayerState state) {
    return KeyedSubtree(
      key: ValueKey('song-progress-${state.currentSong?.id ?? 'none'}'),
      child: StreamBuilder<Duration>(
        stream: state.player.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = state.player.duration ?? Duration.zero;

          final safePosition = position.inMilliseconds.toDouble();
          final safeDuration = duration.inMilliseconds.toDouble();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: safeDuration > 0
                    ? safePosition.clamp(0.0, safeDuration).toDouble()
                    : 0.0,
                max: safeDuration > 0 ? safeDuration : 1.0,
                onChanged: safeDuration <= 0
                    ? null
                    : (value) {
                        state.player
                            .seek(Duration(milliseconds: value.toInt()));
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    Text(_formatDuration(duration)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
