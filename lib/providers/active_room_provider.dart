import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/webrtc_service.dart';
import 'room_player_provider.dart';
import 'auth_provider.dart';

// Tracks the ID of the currently active room
final activeRoomIdProvider = StateProvider<String?>((ref) => null);

// Keeps the room session (Audio + WebRTC) alive as long as activeRoomId is set involved
final activeRoomSessionProvider = Provider<void>((ref) {
  final roomId = ref.watch(activeRoomIdProvider);
  if (roomId != null) {
    // Keep Player Alive
    ref.watch(roomPlayerProvider(roomId));
    
    // Keep WebRTC Alive
    ref.watch(webRTCServiceProvider(roomId));
  }
});

// WebRTC Service Provider (extracted from RoomScreen)
final webRTCServiceProvider = Provider.autoDispose.family<WebRTCService, String>((ref, roomId) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) {
     throw Exception('User must be logged in to initialize WebRTC');
  }
  
  final service = WebRTCService(
    roomId: roomId,
    localUid: user.uid,
  );
  
  // Initialize immediately? Or wait? 
  // Ideally initializing async in a FutureProvider is better, but WebRTCService structure is class-based.
  // We will manage init/dispose in the object itself or via a wrapper.
  // For now, return the instance. It initializes explicitly.
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
