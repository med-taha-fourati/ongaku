import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/song_repository.dart';
import '../models/song_model.dart';

final songRepositoryProvider = Provider((ref) => SongRepository());

final recommendedSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  return await repository.getRecommendedSongs();
});

final approvedSongsProvider = StreamProvider<List<SongModel>>((ref) {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getApprovedSongs();
});

final pendingSongsProvider = StreamProvider<List<SongModel>>((ref) {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getPendingSongs();
});

final trendingSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  return await repository.getTrendingSongs();
});

final userSongsProvider =
    FutureProvider.family<List<SongModel>, String>((ref, userId) async {
  final repository = ref.watch(songRepositoryProvider);
  return await repository.getSongsByUserId(userId);
});