import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  static const _key = 'favorite_song_ids';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    state = favorites;
  }

  Future<void> toggleFavorite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.contains(songId)) {
      state = state.where((id) => id != songId).toList();
    } else {
      state = [...state, songId];
    }
    await prefs.setStringList(_key, state);
  }

  bool isFavorite(String songId) {
    return state.contains(songId);
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});
