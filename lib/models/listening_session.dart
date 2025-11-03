class ListeningSession {
  final String userId;
  final String songId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationListened;
  final bool completed;
  final bool liked;
  final bool skipped;

  ListeningSession({
    required this.userId,
    required this.songId,
    required this.startTime,
    this.endTime,
    required this.durationListened,
    this.completed = false,
    this.liked = false,
    this.skipped = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'songId': songId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationListened': durationListened,
      'completed': completed,
      'liked': liked,
      'skipped': skipped,
    };
  }
}