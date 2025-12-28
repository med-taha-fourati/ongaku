import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../models/song_model.dart';
import '../models/queued_song_model.dart';
import '../repositories/room_repository.dart';
import '../repositories/song_repository.dart';

class RoomPlayerState {
  final AudioPlayer player;
  final RoomModel? room;
  final SongModel? currentSong;
  final bool isHost;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isSyncing;
  final DateTime? lastSyncTime;

  RoomPlayerState({
    required this.player,
    this.room,
    this.currentSong,
    this.isHost = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isSyncing = false,
    this.lastSyncTime,
  });

  RoomPlayerState copyWith({
    RoomModel? room,
    SongModel? currentSong,
    bool? isHost,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isSyncing,
    DateTime? lastSyncTime,
  }) {
    return RoomPlayerState(
      player: player,
      room: room ?? this.room,
      currentSong: currentSong ?? this.currentSong,
      isHost: isHost ?? this.isHost,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class RoomPlayerNotifier extends StateNotifier<RoomPlayerState> {
  final String roomId;
  final String userId;
  final RoomRepository _roomRepository;
  final SongRepository _songRepository;

  StreamSubscription? _roomSubscription;
  Timer? _syncCheckTimer;
  Timer? _hostUpdateTimer;

  static const Duration _driftThreshold = Duration(milliseconds: 300);
  static const Duration _syncCheckInterval = Duration(seconds: 10);
  static const Duration _hostUpdateInterval = Duration(seconds: 5);

  RoomPlayerNotifier({
    required this.roomId,
    required this.userId,
    required RoomRepository roomRepository,
    required SongRepository songRepository,
  })  : _roomRepository = roomRepository,
        _songRepository = songRepository,
        super(RoomPlayerState(player: AudioPlayer())) {
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
        if (state.isHost) {
          _playNextInQueue();
        }
      }
    });

    _listenToRoomUpdates();
  }

  void _listenToRoomUpdates() {
    _roomSubscription = _roomRepository.getRoomStream(roomId).listen((room) {
      if (room == null) return;

      final wasHost = state.isHost;
      final isHost = room.hostUid == userId;

      state = state.copyWith(
        room: room,
        isHost: isHost,
      );

      if (isHost && !wasHost) {
        _startHostUpdates();
      } else if (!isHost && wasHost) {
        _stopHostUpdates();
      }

      if (!isHost) {
        _handleRoomUpdate(room);
      }
    });
  }

  Future<void> _handleRoomUpdate(RoomModel room) async {
    if (room.activeSongId == null) {
      if (state.isPlaying) {
        await state.player.stop();
      }
      return;
    }

    if (state.currentSong?.id != room.activeSongId) {
      await _loadAndPlaySong(room.activeSongId!, room);
      return;
    }

    if (room.playbackState == PlaybackState.playing && !state.isPlaying) {
      await _syncAndPlay(room);
    } else if (room.playbackState == PlaybackState.paused && state.isPlaying) {
      await state.player.pause();
      await state.player.seek(Duration(milliseconds: room.playbackPositionMs));
    } else if (room.playbackState == PlaybackState.stopped) {
      await state.player.stop();
    }
  }

  Future<void> _loadAndPlaySong(String songId, RoomModel room) async {
    try {
      state = state.copyWith(isSyncing: true);

      final songs = await _songRepository.getTrendingSongs();
      final song = songs.firstWhere((s) => s.id == songId);

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

      state = state.copyWith(currentSong: song);

      if (room.playbackState == PlaybackState.playing) {
        await _syncAndPlay(room);
      } else {
        await state.player.seek(Duration(milliseconds: room.playbackPositionMs));
      }

      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false);
      throw Exception('Failed to load song: $e');
    }
  }

  Future<void> _syncAndPlay(RoomModel room) async {
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(room.lastUpdated).inMilliseconds;
    final expectedPosition = room.playbackPositionMs + timeSinceUpdate;

    await state.player.seek(Duration(milliseconds: expectedPosition));
    await state.player.play();

    state = state.copyWith(lastSyncTime: now);

    if (_syncCheckTimer == null || !_syncCheckTimer!.isActive) {
      _startSyncCheck();
    }
  }

  void _startSyncCheck() {
    _syncCheckTimer?.cancel();
    _syncCheckTimer = Timer.periodic(_syncCheckInterval, (timer) {
      if (state.room == null || state.isHost) {
        timer.cancel();
        return;
      }

      _checkAndCorrectDrift();
    });
  }

  Future<void> _checkAndCorrectDrift() async {
    if (state.room == null || state.room!.playbackState != PlaybackState.playing) {
      return;
    }

    final room = state.room!;
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(room.lastUpdated).inMilliseconds;
    final expectedPosition = room.playbackPositionMs + timeSinceUpdate;
    final actualPosition = state.position.inMilliseconds;
    final drift = (expectedPosition - actualPosition).abs();

    if (drift > _driftThreshold.inMilliseconds) {
      state = state.copyWith(isSyncing: true);
      await state.player.seek(Duration(milliseconds: expectedPosition));
      state = state.copyWith(isSyncing: false, lastSyncTime: now);
    }
  }

  void _startHostUpdates() {
    _hostUpdateTimer?.cancel();
    _hostUpdateTimer = Timer.periodic(_hostUpdateInterval, (timer) async {
      if (!state.isHost || state.room == null) {
        timer.cancel();
        return;
      }

      await _updateRoomPlayback();
    });
  }

  void _stopHostUpdates() {
    _hostUpdateTimer?.cancel();
  }

  Future<void> _updateRoomPlayback() async {
    if (state.room == null) return;

    try {
      await _roomRepository.updateRoomPlayback(
        roomId: roomId,
        playbackPositionMs: state.position.inMilliseconds,
        playbackState: state.isPlaying
            ? PlaybackState.playing
            : PlaybackState.paused,
      );
    } catch (e) {
    }
  }

  Future<void> hostPlaySong(SongModel song) async {
    if (!state.isHost) {
      throw Exception('Only host can control playback');
    }

    try {
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

      state = state.copyWith(currentSong: song);

      await _roomRepository.updateRoomPlayback(
        roomId: roomId,
        activeSongId: song.id,
        playbackPositionMs: 0,
        playbackState: PlaybackState.playing,
      );

      await state.player.play();
    } catch (e) {
      throw Exception('Failed to play song: $e');
    }
  }

  Future<void> hostPause() async {
    if (!state.isHost) {
      throw Exception('Only host can control playback');
    }

    await state.player.pause();
    await _roomRepository.updateRoomPlayback(
      roomId: roomId,
      playbackPositionMs: state.position.inMilliseconds,
      playbackState: PlaybackState.paused,
    );
  }

  Future<void> hostResume() async {
    if (!state.isHost) {
      throw Exception('Only host can control playback');
    }

    await state.player.play();
    await _roomRepository.updateRoomPlayback(
      roomId: roomId,
      playbackPositionMs: state.position.inMilliseconds,
      playbackState: PlaybackState.playing,
    );
  }

  Future<void> hostSeek(Duration position) async {
    if (!state.isHost) {
      throw Exception('Only host can control playback');
    }

    await state.player.seek(position);
    await _roomRepository.updateRoomPlayback(
      roomId: roomId,
      playbackPositionMs: position.inMilliseconds,
    );
  }

  Future<void> playNext() async {
    print('RoomPlayerNotifier: playNext() called. isHost: ${state.isHost}');
    if (!state.isHost) return;

    try {
      final queueStream = _roomRepository.getMasterQueue(roomId);
      final queue = await queueStream.first;
      print('RoomPlayerNotifier: Queue length: ${queue.length}');

      if (queue.isEmpty) {
         print('RoomPlayerNotifier: Queue is empty. Stopping.');
         await state.player.stop();
         await _roomRepository.updateRoomPlayback(
           roomId: roomId,
           playbackState: PlaybackState.stopped,
           activeSongId: null,
         );
         return;
      }

      final nextQueuedSong = queue.first;
      print('RoomPlayerNotifier: Fetching song details for ${nextQueuedSong.songId}');
      
      final song = await _songRepository.getSong(nextQueuedSong.songId);
      print('RoomPlayerNotifier: Fetched song ${song.title} with URL ${song.audioUrl}');
      
      final updatedQueue = List<QueuedSong>.from(queue)..removeAt(0);
      
      await _roomRepository.updateMasterQueue(roomId: roomId, songs: updatedQueue);
      
      print('RoomPlayerNotifier: Calling hostPlaySong');
      await hostPlaySong(song);
    } catch (e, stack) {
       print('RoomPlayerNotifier Error playing next song: $e');
       print(stack);
    }
  }
  
  Future<void> _playNextInQueue() async {
    await playNext();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _syncCheckTimer?.cancel();
    _hostUpdateTimer?.cancel();
    state.player.dispose();
    super.dispose();
  }
}

final roomPlayerProvider = StateNotifierProvider.autoDispose.family<RoomPlayerNotifier, RoomPlayerState, String>(
  (ref, roomId) {
    final user = ref.watch(authStateProvider).value;
    final userId = user?.uid ?? '';
    
    return RoomPlayerNotifier(
      roomId: roomId,
      userId: userId,
      roomRepository: RoomRepository(),
      songRepository: SongRepository(),
    );
  },
);
