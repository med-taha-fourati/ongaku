import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ongaku/providers/auth_provider.dart';
import '../repositories/song_repository.dart';

class FavoritesNotifier extends StateNotifier<List<String>> {
  final SongRepository _songRepository;
  final String? _userId;
  static const _key = 'favorite_song_ids';

  FavoritesNotifier(this._songRepository, this._userId) : super([]) {
    _syncFavorites();
  }

  Future<void> _syncFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final localFavorites = prefs.getStringList(_key) ?? [];
    
    state = localFavorites;

    if (_userId != null) {
      try {
        final remoteFavorites = await _songRepository.fetchUserFavorites(_userId!);
        
        final localSet = localFavorites.toSet();
        final remoteSet = remoteFavorites.toSet();
        
        final toUpload = localSet.difference(remoteSet);
        for (final songId in toUpload) {
          await _songRepository.addUserFavorite(_userId!, songId);
        }

        final merged = {...remoteSet, ...localSet}.toList();
        
        if (merged.length != localFavorites.length || !localSet.containsAll(remoteSet)) {
          await prefs.setStringList(_key, merged);
          state = merged;
        }
      } catch (e) {
        debugPrint("$e");
      }
    }
  }

  Future<void> toggleFavorite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (state.contains(songId)) {
      state = state.where((id) => id != songId).toList();
      await prefs.setStringList(_key, state);
      if (_userId != null) {
        await _songRepository.removeUserFavorite(_userId!, songId);
      }
    } else {
      state = [...state, songId];
      await prefs.setStringList(_key, state);
      if (_userId != null) {
        await _songRepository.addUserFavorite(_userId!, songId);
      }
    }
  }

  bool isFavorite(String songId) {
    return state.contains(songId);
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  return FavoritesNotifier(SongRepository(), userId);
});
