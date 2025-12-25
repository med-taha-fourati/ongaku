import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../models/participant_model.dart';
import '../models/queued_song_model.dart';
import '../repositories/room_repository.dart';

final roomRepositoryProvider = Provider((ref) => RoomRepository());

final publicRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.getPublicRooms();
});

final roomStreamProvider = StreamProvider.family<RoomModel?, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.getRoomStream(roomId);
});

final participantsProvider = StreamProvider.family<List<ParticipantModel>, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.getParticipants(roomId);
});

final masterQueueProvider = StreamProvider.family<List<QueuedSong>, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.getMasterQueue(roomId);
});

final songRequestsProvider = StreamProvider.family<List<SongRequest>, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.getSongRequests(roomId);
});
