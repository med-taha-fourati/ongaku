class QueuedSong {
  final String songId;
  final String title;
  final String artist;
  final int durationMs;
  final String requestedBy;
  final DateTime addedAt;
  final int position;

  QueuedSong({
    required this.songId,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.requestedBy,
    required this.addedAt,
    required this.position,
  });

  factory QueuedSong.fromJson(Map<String, dynamic> json) {
    return QueuedSong(
      songId: json['songId'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      durationMs: json['durationMs'] ?? 0,
      requestedBy: json['requestedBy'] ?? '',
      addedAt: DateTime.parse(json['addedAt']),
      position: json['position'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'title': title,
      'artist': artist,
      'durationMs': durationMs,
      'requestedBy': requestedBy,
      'addedAt': addedAt.toIso8601String(),
      'position': position,
    };
  }

  QueuedSong copyWith({
    int? position,
  }) {
    return QueuedSong(
      songId: songId,
      title: title,
      artist: artist,
      durationMs: durationMs,
      requestedBy: requestedBy,
      addedAt: addedAt,
      position: position ?? this.position,
    );
  }
}

enum RequestStatus {
  pending,
  approved,
  rejected,
}

class SongRequest {
  final String id;
  final String songId;
  final String title;
  final String artist;
  final int durationMs;
  final String requestedBy;
  final DateTime requestedAt;
  final RequestStatus status;

  SongRequest({
    required this.id,
    required this.songId,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.requestedBy,
    required this.requestedAt,
    this.status = RequestStatus.pending,
  });

  factory SongRequest.fromJson(String id, Map<String, dynamic> json) {
    return SongRequest(
      id: id,
      songId: json['songId'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      durationMs: json['durationMs'] ?? 0,
      requestedBy: json['requestedBy'] ?? '',
      requestedAt: DateTime.parse(json['requestedAt']),
      status: RequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RequestStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'title': title,
      'artist': artist,
      'durationMs': durationMs,
      'requestedBy': requestedBy,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.name,
    };
  }

  QueuedSong toQueuedSong(int position) {
    return QueuedSong(
      songId: songId,
      title: title,
      artist: artist,
      durationMs: durationMs,
      requestedBy: requestedBy,
      addedAt: DateTime.now(),
      position: position,
    );
  }
}
