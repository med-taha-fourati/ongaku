import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../repositories/radio_repository.dart';
import '../models/radio_station.dart';

final radioRepositoryProvider = Provider((ref) => RadioRepository());

final topRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final repository = ref.watch(radioRepositoryProvider);
  return await repository.getTopStations();
});

final recentlyPlayedRadiosProvider = StateNotifierProvider<RecentlyPlayedRadiosNotifier, List<RadioStation>>((ref) {
  return RecentlyPlayedRadiosNotifier();
});

class RecentlyPlayedRadiosNotifier extends StateNotifier<List<RadioStation>> {
  static const String _key = 'recently_played_radios';
  static const int _maxItems = 10;

  RecentlyPlayedRadiosNotifier() : super([]) {
    _loadRecentlyPlayed();
  }

  Future<void> _loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key) ?? '[]';
    final List<dynamic> jsonList = jsonDecode(jsonString);
    state = jsonList.map((json) => RadioStation.fromJson(json)).toList();
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.map((station) => station.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  void addToRecentlyPlayed(RadioStation station) {
    // Remove if already exists to avoid duplicates
    state = [
      station,
      ...state.where((s) => s.id != station.id),
    ].take(_maxItems).toList();
    _saveRecentlyPlayed();
  }

  void clearRecentlyPlayed() {
    state = [];
    _saveRecentlyPlayed();
  }
}