import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:ongaku/providers/auth_provider.dart';
import 'package:ongaku/providers/radio_provider.dart';
import '../models/song_model.dart';
import '../models/radio_station.dart';
import '../repositories/analytics_repository.dart';
import '../models/listening_session.dart';

enum PlaybackSource {
  song,
  radio,
}

class PlayerState {
  final AudioPlayer player;
  final SongModel? currentSong;
  final RadioStation? currentStation;
  final PlaybackSource? playbackSource;
  final List<SongModel> playlist;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final DateTime? sessionStart;

  PlayerState({
    required this.player,
    this.currentSong,
    this.currentStation,
    this.playbackSource,
    this.playlist = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.sessionStart,
  });

  PlayerState copyWith({
    SongModel? currentSong,
    RadioStation? currentStation,
    PlaybackSource? playbackSource,
    List<SongModel>? playlist,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    DateTime? sessionStart,
  }) {
    return PlayerState(
      player: player,
      currentSong: currentSong ?? this.currentSong,
      currentStation: currentStation ?? this.currentStation,
      playbackSource: playbackSource ?? this.playbackSource,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      sessionStart: sessionStart ?? this.sessionStart,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AnalyticsRepository _analyticsRepository;
  final String userId;

  PlayerNotifier(this.userId, this._analyticsRepository)
      : super(PlayerState(player: AudioPlayer())) {
    _init();
  }

  void _init() {
    state.player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    state.player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    state.player.playingStream.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    });

    state.player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _logSession(completed: true);
        playNext();
      }
    });
  }

  Future<void> playSong(SongModel song, List<SongModel> playlist) async {
    
    
    
    final previousSong = state.currentSong;
    final previousStation = state.currentStation;
    final previousSource = state.playbackSource;

    final index = playlist.indexWhere((s) => s.id == song.id);

    try {
      _logSession(completed: false);

      
      await state.player.stop();
      
      
      state = state.copyWith(
        position: Duration.zero,
        duration: Duration.zero,
        currentSong: song,
        
        playbackSource: PlaybackSource.song,
        playlist: playlist,
        currentIndex: index >= 0 ? index : 0,
        sessionStart: DateTime.now(),
      );

      
      await state.player.setAudioSource(
        AudioSource.uri(
          Uri.parse(song.audioUrl),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artUri: song.coverUrl != null ? Uri.parse(song.coverUrl!) : null,
          ),
        ),
      );

      
      await state.player.play();
    } catch (e) {
      
      state = state.copyWith(
        currentSong: previousSong,
        currentStation: previousStation,
        playbackSource: previousSource,
        position: Duration.zero,
        duration: Duration.zero,
      );
      throw Exception('Failed to play song: $e');
    }
  }

  Future<void> playRadio(RadioStation station, {bool fromRecentlyPlayed = false}) async {
    final previousSong = state.currentSong;
    final previousStation = state.currentStation;
    final previousSource = state.playbackSource;

    try {
      _logSession(completed: true);

      
      await state.player.stop();
      state = state.copyWith(position: Duration.zero, duration: Duration.zero, playlist: const [], currentIndex: 0);
      state = state.copyWith(
        currentStation: station,
        
        playbackSource: PlaybackSource.radio,
        isPlaying: true,
        sessionStart: DateTime.now(),
        position: Duration.zero,
        duration: Duration.zero,
      );

      
      await state.player.setAudioSource(
        AudioSource.uri(
          Uri.parse(station.streamUrl),
          tag: MediaItem(
            id: station.id,
            title: station.name,
            artist: station.country,
            artUri: station.imageUrl != null ? Uri.parse(station.imageUrl!) : null,
          ),
        ),
      );

      
      if (!fromRecentlyPlayed) {
        final ref = ProviderContainer();
        final notifier = ref.read(recentlyPlayedRadiosProvider.notifier);
        notifier.addToRecentlyPlayed(station);
      }

      await state.player.play();
    } catch (e) {
      
      state = state.copyWith(
        currentSong: previousSong,
        currentStation: previousStation,
        playbackSource: previousSource,
        position: Duration.zero,
        duration: Duration.zero,
      );
      print('Error playing radio: $e');
      rethrow;
    }
  }

  void pause() {
    if (state.player.playing) {
      state.player.pause();
      state = state.copyWith(isPlaying: false);
    }
  }

  void play() {
    if (!state.player.playing) {
      state.player.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> resume() async {
    await state.player.play();
  }

  Future<void> seek(Duration position) async {
    await state.player.seek(position);
  }

  Future<void> playNext() async {
    if (state.playlist.isEmpty || state.currentIndex >= state.playlist.length - 1) {
      return;
    }

    _logSession(skipped: true);
    final nextIndex = state.currentIndex + 1;
    await playSong(state.playlist[nextIndex], state.playlist);
  }

  Future<void> playPrevious() async {
    if (state.playlist.isEmpty || state.currentIndex <= 0) {
      return;
    }

    _logSession(skipped: true);
    final prevIndex = state.currentIndex - 1;
    await playSong(state.playlist[prevIndex], state.playlist);
  }

  void _logSession({bool completed = false, bool skipped = false}) {
    if (state.currentSong != null && state.sessionStart != null) {
      final session = ListeningSession(
        userId: userId,
        songId: state.currentSong!.id,
        startTime: state.sessionStart!,
        endTime: DateTime.now(),
        durationListened: state.position.inSeconds,
        completed: completed,
        skipped: skipped,
      );
      _analyticsRepository.logSession(session);
    }
  }

  @override
  void dispose() {
    _logSession();
    state.player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid ?? '';
  return PlayerNotifier(userId, AnalyticsRepository());
});
