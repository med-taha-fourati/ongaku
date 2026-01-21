import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listening_session.dart';
import '../models/song_model.dart';
import '../models/radio_station.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/song_repository.dart';
import '../repositories/radio_repository.dart';
import 'auth_provider.dart';

// --- Data Models ---

class WeeklyActivityData {
  final List<DailyActivity> days;
  final int totalMinutes;

  WeeklyActivityData({required this.days, required this.totalMinutes});
}

class DailyActivity {
  final String label; // "Mon", "Tue"
  final DateTime date;
  final int minutes;
  final int songCount;

  DailyActivity({
    required this.label,
    required this.date,
    required this.minutes,
    required this.songCount,
  });
}

class TopTrackData {
  final SongModel song;
  final int playCount;

  TopTrackData({required this.song, required this.playCount});
}

class TopRadioData {
  final RadioStation station;
  final int playCount;

  TopRadioData({required this.station, required this.playCount});
}

class SessionRatioData {
  final int songSessions;
  final int radioSessions;
  final double songPercentage;
  final double radioPercentage;

  SessionRatioData({
    required this.songSessions,
    required this.radioSessions,
    required this.songPercentage,
    required this.radioPercentage,
  });
}

// --- Repositories ---

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());
final songRepositoryProvider = Provider((ref) => SongRepository());
final radioRepositoryProvider = Provider((ref) => RadioRepository());

// --- Providers ---

// Tracks the selected week offset (0 = current week, -1 = last week, etc.)
final weekOffsetProvider = StateProvider<int>((ref) => 0);

final weeklyActivityProvider = FutureProvider<WeeklyActivityData>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) throw Exception('User not logged in');

  final analyticsRepo = ref.read(analyticsRepositoryProvider);
  final offset = ref.watch(weekOffsetProvider);

  final now = DateTime.now();
  // Calculate start of current week (Monday)
  // subtract (weekday - 1) to get to Monday
  final currentWeekStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  
  final startOfWeek = currentWeekStart.add(Duration(days: offset * 7));
  final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

  final sessions = await analyticsRepo.getSessionsForPeriod(user.uid, startOfWeek, endOfWeek);

  final days = <DailyActivity>[];
  int totalMinutes = 0;

  for (int i = 0; i < 7; i++) {
    final dayDate = startOfWeek.add(Duration(days: i));
    final daySessions = sessions.where((s) => 
      s.startTime.year == dayDate.year &&
      s.startTime.month == dayDate.month &&
      s.startTime.day == dayDate.day
    );

    final minutes = daySessions.fold(0, (sum, s) => sum + (s.durationListened ~/ 60));
    final count = daySessions.length;
    totalMinutes += minutes;

    days.add(DailyActivity(
      // Get short weekday name manually or use intl if needed, but keeping it simple for now
      label: _getWeekdayLabel(dayDate.weekday), 
      date: dayDate,
      minutes: minutes,
      songCount: count,
    ));
  }

  return WeeklyActivityData(days: days, totalMinutes: totalMinutes);
});

String _getWeekdayLabel(int weekday) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[weekday - 1];
}

final topTracksProvider = FutureProvider<List<TopTrackData>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) throw Exception('User not logged in');

  final analyticsRepo = ref.read(analyticsRepositoryProvider);
  final sessions = await analyticsRepo.getRecentSessions(user.uid);

  final playCounts = <String, int>{};
  for (final session in sessions) {
    if (session.songId != null && session.songId!.isNotEmpty) {
      playCounts[session.songId!] = (playCounts[session.songId!] ?? 0) + 1;
    }
  }

  final sortedEntries = playCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topEntries = sortedEntries.take(20).toList();

  if (topEntries.isEmpty) return [];

  final songRepo = ref.read(songRepositoryProvider);
  final songs = <TopTrackData>[];

  for (final entry in topEntries) {
    try {
      final song = await songRepo.getSong(entry.key);
      songs.add(TopTrackData(song: song, playCount: entry.value));
    } catch (e) {
    }
  }

  return songs;
});

final topRadiosProvider = FutureProvider<List<TopRadioData>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) throw Exception('User not logged in');

  final analyticsRepo = ref.read(analyticsRepositoryProvider);
  final sessions = await analyticsRepo.getRecentSessions(user.uid);

  final playCounts = <String, int>{};
  for (final session in sessions) {
    if (session.radioUrl != null && session.radioUrl!.isNotEmpty) {
      playCounts[session.radioUrl!] = (playCounts[session.radioUrl!] ?? 0) + 1;
    }
  }

  final sortedEntries = playCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topEntries = sortedEntries.take(20).toList();

  if (topEntries.isEmpty) return [];

  final radioRepo = ref.read(radioRepositoryProvider);
  final radios = <TopRadioData>[];
  for (final entry in topEntries) {
    final url = entry.key;
    final station = await radioRepo.getStationByStreamUrl(url) ??
        RadioStation(
          id: url,
          name: 'Unknown Station',
          streamUrl: url,
          genre: '',
          country: '',
        );
    radios.add(TopRadioData(station: station, playCount: entry.value));
  }

  return radios;
});

final sessionRatioProvider = FutureProvider<SessionRatioData>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) throw Exception('User not logged in');

  final analyticsRepo = ref.read(analyticsRepositoryProvider);
  final sessions = await analyticsRepo.getRecentSessions(user.uid);

  int songSessions = 0;
  int radioSessions = 0;

  for (final session in sessions) {
    if (session.songId != null && session.songId!.isNotEmpty) {
      songSessions++;
    } else if (session.radioUrl != null && session.radioUrl!.isNotEmpty) {
      radioSessions++;
    }
  }

  final total = songSessions + radioSessions;
  final songPercentage = total > 0 ? (songSessions / total) * 100 : 0.0;
  final radioPercentage = total > 0 ? (radioSessions / total) * 100 : 0.0;

  return SessionRatioData(
    songSessions: songSessions,
    radioSessions: radioSessions,
    songPercentage: songPercentage,
    radioPercentage: radioPercentage,
  );
});
