import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';
import '../models/radio_station.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  final SongModel? song;
  final RadioStation? station;
  final PlaybackSource? playbackSource;
  final String heroTag;

  const FullPlayerScreen({
    super.key,
    this.song,
    this.station,
    this.playbackSource,
    required this.heroTag,
  });

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _livePulseController;
  late final SongModel? initialSong;
  late final RadioStation? initialStation;
  late final PlaybackSource? initialPlaybackSource;

  @override
  void initState() {
    super.initState();
    initialSong = widget.song;
    initialStation = widget.station;
    initialPlaybackSource = widget.playbackSource;

    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _livePulseController.dispose();
    super.dispose();
  }

  Widget _buildArtwork(String heroTag, String? imageUrl, double size) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.music_note, size: 80, color: Colors.white70),
    );

    final image = (imageUrl != null && imageUrl.isNotEmpty)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          )
        : placeholder;

    return Hero(tag: heroTag, child: image);
  }

  Widget _liveIndicator() {
    return AnimatedBuilder(
      animation: _livePulseController,
      builder: (context, child) {
        final t = _livePulseController.value;
        final scale = 0.9 + (t * 0.25);
        final opacity = 0.6 + (t * 0.4);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionSlider(PlayerState state) {
    if (state.playbackSource == PlaybackSource.radio ||
        state.currentSong == null) {
      return const SizedBox(height: 4);
    }

    return StreamBuilder<Duration>(
      stream: state.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? state.position;
        final duration = state.player.duration ?? state.duration;
        final safePosition =
            position.inMilliseconds.toDouble().clamp(0.0, double.infinity);
        final safeDuration = math.max(1.0, duration.inMilliseconds.toDouble());

        return Slider(
          value: safeDuration > 0 ? safePosition.clamp(0.0, safeDuration) : 0.0,
          max: safeDuration,
          onChanged: (value) {
            state.player.seek(Duration(milliseconds: value.toInt()));
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:${seconds}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong ?? initialSong;
    final station = state.currentStation ?? initialStation;
    final playbackSource = state.playbackSource ?? initialPlaybackSource;

    final isRadio = playbackSource == PlaybackSource.radio ||
        (playbackSource == null && station != null && song == null);

    // Precise metadata extraction based on source
    String title = '';
    String subtitle = '';
    String? artworkUrl;

    if (playbackSource == PlaybackSource.radio && station != null) {
      title = station.name;
      subtitle = station.country;
      artworkUrl = station.imageUrl;
    } else if (playbackSource == PlaybackSource.song && song != null) {
      title = song.title;
      subtitle = song.artist;
      artworkUrl = song.coverUrl;
    }

    final bgGradient = LinearGradient(
      colors: [
        Theme.of(context).colorScheme.surface,
        Theme.of(context).colorScheme.background,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: bgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down), // Changed back to arrow down to imply minimize
                      onPressed: () {
                         // Minimize (keep playing)
                         Navigator.of(context).pop();
                      },
                      tooltip: 'Minimize',
                    ),
                    Expanded(child: Container()),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Container(
                      width: math.min(
                          360, MediaQuery.of(context).size.width * 0.85),
                      height: math.min(
                          360, MediaQuery.of(context).size.width * 0.85),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildArtwork(widget.heroTag, artworkUrl, 360),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      if (isRadio)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _liveIndicator(),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildPositionSlider(state),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(state.position),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Text(_formatDuration(state.duration),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 48,
                        onPressed: () {
                          ref.read(playerProvider.notifier).playPrevious();
                        },
                      ),
                      const SizedBox(width: 24),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(state.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled),
                          iconSize: 80,
                          onPressed: () {
                            if (state.isPlaying) {
                              ref.read(playerProvider.notifier).pause();
                            } else {
                              ref.read(playerProvider.notifier).play();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 48,
                        onPressed: () {
                          ref.read(playerProvider.notifier).playNext();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
