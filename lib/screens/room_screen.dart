import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/room_model.dart';
import '../models/participant_model.dart';
import '../models/song_model.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/room_player_provider.dart';
import '../repositories/room_repository.dart';
import '../services/webrtc_service.dart';
import '../services/foreground_service_manager.dart';
import '../services/room_lifecycle_service.dart';
import '../providers/active_room_provider.dart'; 
import '../widgets/participant_grid.dart';
import '../models/user_model.dart';

import '../widgets/queue_panel.dart';
import '../widgets/room_mini_player.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> with WidgetsBindingObserver {
  final RoomLifecycleService _lifecycleService = RoomLifecycleService(RoomRepository());
  // WebRTCService is now managed by provider
  bool _isConnecting = true;
  bool _isMuted = false;
  bool _isDeafened = false;

  RoomRepository? _roomRepository;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    
    _roomRepository = ref.read(roomRepositoryProvider);
    _currentUid = ref.read(currentUserProvider).value?.uid;

    // Set Active Room
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(activeRoomIdProvider.notifier).state = widget.roomId;
       _joinRoom();
    });

    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      _lifecycleService.startHeartbeat(widget.roomId, user.uid);
      _lifecycleService.monitorRoomHealth(widget.roomId, user.uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _lifecycleService.dispose();
    // DO NOT call _leaveRoom() here. Background playback is desired on pop.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _leaveRoom(isFullExit: true);
    }
  }

  Future<void> _joinRoom() async {
    try {
      var user = await ref.read(currentUserProvider.future);
      
      if (user == null) {
        final rawUser = ref.read(authRepositoryProvider).currentUser;
        if (rawUser != null) {
          debugPrint('Using raw Firebase user fallback');
          user = UserModel(
            uid: rawUser.uid,
            email: rawUser.email ?? '',
            displayName: rawUser.displayName ?? 'Unknown',
            createdAt: DateTime.now(),
          );
        }
      }

      if (user == null) {
        debugPrint('Room join failed: User is null after loading and fallback');
        if (mounted) {
           Navigator.pop(context);
        }
        return;
      }
      final repo = ref.read(roomRepositoryProvider);
      
      // Join Firestore room
      await repo.joinRoom(
        roomId: widget.roomId,
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown',
        avatarUrl: null,
      );

      // Initialize WebRTC via Provider
      final webRTC = ref.read(webRTCServiceProvider(widget.roomId));
      await webRTC.initialize();
      
      if (mounted) setState(() => _isConnecting = false);
      
      // If host, start foreground service
      final room = await repo.getRoom(widget.roomId);
      if (room?.hostUid == user.uid) {
        await ForegroundServiceManager.startService(
          roomName: room?.roomName ?? 'Music Room',
          roomId: widget.roomId,
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _leaveRoom({bool isFullExit = false}) async {
    final uid = _currentUid;
    final repo = _roomRepository;
    
    if (uid == null || repo == null) return;

    try {
      // Clear Active Room ID if full exit
      if (isFullExit) {
        ref.read(activeRoomIdProvider.notifier).state = null;
        
        await ForegroundServiceManager.stopService();

        await repo.leaveRoom(
          roomId: widget.roomId,
          uid: uid,
        );
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  void _showQueueSheet(BuildContext context, bool isHost) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: QueuePanel(roomId: widget.roomId, isHost: isHost),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final participantsAsync = ref.watch(participantsProvider(widget.roomId));
    final firestoreUser = ref.watch(currentUserProvider).value;
    final firebaseUser = ref.watch(authStateProvider).value;
    final playerState = ref.watch(roomPlayerProvider(widget.roomId));

    final currentUser = firestoreUser ?? 
        (firebaseUser != null 
            ? UserModel(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? '',
                displayName: firebaseUser.displayName ?? 'Unknown',
                createdAt: DateTime.now(),
              ) 
            : null);

    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return roomAsync.when(
      data: (room) {
        if (room == null) return const Scaffold(body: Center(child: Text('Room ended')));

        final isHost = room.hostUid == currentUser.uid;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.roomName),
                Text(
                  isHost ? 'Host' : 'Listener',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                color: _isMuted ? Colors.red : null,
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    ref.read(webRTCServiceProvider(widget.roomId)).toggleMute();
                  });
                },
              ),
              IconButton(
                icon: Icon(_isDeafened ? Icons.headset_off : Icons.headset),
                color: _isDeafened ? Colors.red : null,
                tooltip: _isDeafened ? 'Undeafen' : 'Deafen',
                onPressed: () {
                  setState(() {
                    _isDeafened = !_isDeafened;
                    ref.read(webRTCServiceProvider(widget.roomId)).toggleDeafen();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                onPressed: () => _showQueueSheet(context, isHost),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Leave Room?'),
                      content: Text(isHost 
                          ? 'As host, leaving will end the room for everyone.' 
                          : 'Are you sure you want to leave?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await _leaveRoom(isFullExit: true);
                    if (mounted) Navigator.pop(context); 
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Now Playing / Start Playback Section
              if (playerState.currentSong != null)
                RoomMiniPlayer(roomId: widget.roomId, isHost: isHost)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Column(
                    children: [
                      Text(
                        isHost ? 'Play a song to start!' : 'Waiting for host...',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      if (isHost && ref.watch(masterQueueProvider(widget.roomId)).valueOrNull?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(roomPlayerProvider(widget.roomId).notifier).playNext();
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Playback'),
                          ),
                        ),
                    ],
                  ),
                ),
              
              const Divider(height: 1),
              
              // Participants Grid
              Expanded(
                  child: participantsAsync.when(
                  data: (participants) {
                    // WebRTC connections managed by service/provider
                    
                    return ParticipantGrid(
                      participants: participants,
                      currentUserId: currentUser.uid,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, stack) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(body: Center(child: Text('Error loading room: $e'))),
    );
  }
}
