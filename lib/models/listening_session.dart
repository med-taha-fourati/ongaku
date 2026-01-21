class ListeningSession {
  final String userId;
  final String? songId;
  final String? radioUrl;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationListened;
  final bool completed;
  final bool liked;
  final bool skipped;

  ListeningSession({
    required this.userId,
    this.songId,
    this.radioUrl,
    required this.startTime,
    this.endTime,
    required this.durationListened,
    this.completed = false,
    this.liked = false,
    this.skipped = false,
  });

  factory ListeningSession.fromJson(Map<String, dynamic> json) {
    return ListeningSession(
      userId: json['userId'] as String,
      songId: json['songId'] as String?,
      radioUrl: json['radioUrl'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      durationListened: json['durationListened'] as int,
      completed: json['completed'] as bool? ?? false,
      liked: json['liked'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'songId': songId,
      'radioUrl': radioUrl,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationListened': durationListened,
      'completed': completed,
      'liked': liked,
      'skipped': skipped,
    };
  }
}