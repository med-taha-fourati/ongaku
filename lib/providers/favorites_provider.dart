import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ongaku/providers/auth_provider.dart';
import '../repositories/song_repository.dart';
import 'dart:async';

class FavoritesNotifier extends StateNotifier<List<String>> {
  final SongRepository _songRepository;
  final String? _userId;
  StreamSubscription<List<String>>? _favoritesSubscription;

  FavoritesNotifier(this._songRepository, this._userId) : super([]) {
    _initFavorites();
  }

  void _initFavorites() {
    
    _favoritesSubscription?.cancel();
    
    if (_userId != null) {
      
      _favoritesSubscription = _songRepository
          .watchUserFavorites(_userId!)
          .listen(
            (favorites) {
              state = favorites;
            },
            onError: (error) {
              debugPrint('Error watching favorites: $error');
              state = [];
            },
          );
    } else {
      
      state = [];
    }
  }

  Future<void> toggleFavorite(String songId) async {
    if (_userId == null) {
      debugPrint('Cannot toggle favorite: user not logged in');
      return;
    }

    
    final wasFavorite = state.contains(songId);
    if (wasFavorite) {
      state = state.where((id) => id != songId).toList();
    } else {
      state = [...state, songId];
    }

    
    try {
      if (wasFavorite) {
        await _songRepository.removeUserFavorite(_userId!, songId);
      } else {
        await _songRepository.addUserFavorite(_userId!, songId);
      }
    } catch (e) {
      
      if (wasFavorite) {
        state = [...state, songId];
      } else {
        state = state.where((id) => id != songId).toList();
      }
      debugPrint('Error toggling favorite: $e');
    }
  }

  bool isFavorite(String songId) {
    return state.contains(songId);
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  return FavoritesNotifier(SongRepository(), userId);
});

class RadioFavoritesNotifier extends StateNotifier<List<String>> {
  final SongRepository _songRepository;
  final String? _userId;
  StreamSubscription<List<String>>? _favoritesSubscription;

  RadioFavoritesNotifier(this._songRepository, this._userId) : super([]) {
    _initFavorites();
  }

  void _initFavorites() {
    _favoritesSubscription?.cancel();
    
    if (_userId != null) {
      _favoritesSubscription = _songRepository
          .watchUserRadioFavorites(_userId!)
          .listen(
            (favorites) {
              state = favorites;
            },
            onError: (error) {
              debugPrint('Error watching radio favorites: $error');
              state = [];
            },
          );
    } else {
      state = [];
    }
  }

  Future<void> toggleFavorite(String streamUrl) async {
    if (_userId == null) {
      debugPrint('Cannot toggle radio favorite: user not logged in');
      return;
    }

    final wasFavorite = state.contains(streamUrl);
    if (wasFavorite) {
      state = state.where((url) => url != streamUrl).toList();
    } else {
      state = [...state, streamUrl];
    }

    try {
      if (wasFavorite) {
        await _songRepository.removeUserRadioFavorite(_userId!, streamUrl);
      } else {
        await _songRepository.addUserRadioFavorite(_userId!, streamUrl);
      }
    } catch (e) {
      if (wasFavorite) {
        state = [...state, streamUrl];
      } else {
        state = state.where((url) => url != streamUrl).toList();
      }
      debugPrint('Error toggling radio favorite: $e');
    }
  }

  bool isFavorite(String streamUrl) {
    return state.contains(streamUrl);
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}

final radioFavoritesProvider = StateNotifierProvider<RadioFavoritesNotifier, List<String>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;
  return RadioFavoritesNotifier(SongRepository(), userId);
});
