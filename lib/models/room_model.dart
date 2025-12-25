enum PlaybackState {
  playing,
  paused,
  stopped,
}

class RoomModel {
  final String id;
  final String hostUid;
  final String roomName;
  final String? activeSongId;
  final int playbackPositionMs;
  final PlaybackState playbackState;
  final DateTime lastUpdated;
  final DateTime createdAt;
  final int participantCount;
  final int maxParticipants;
  final bool isPublic;

  RoomModel({
    required this.id,
    required this.hostUid,
    required this.roomName,
    this.activeSongId,
    this.playbackPositionMs = 0,
    this.playbackState = PlaybackState.stopped,
    required this.lastUpdated,
    required this.createdAt,
    this.participantCount = 1,
    this.maxParticipants = 8,
    this.isPublic = true,
  });

  factory RoomModel.fromJson(String id, Map<String, dynamic> json) {
    return RoomModel(
      id: id,
      hostUid: json['hostUid'] ?? '',
      roomName: json['roomName'] ?? '',
      activeSongId: json['activeSongId'],
      playbackPositionMs: json['playbackPositionMs'] ?? 0,
      playbackState: PlaybackState.values.firstWhere(
        (e) => e.name == json['playbackState'],
        orElse: () => PlaybackState.stopped,
      ),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      createdAt: DateTime.parse(json['createdAt']),
      participantCount: json['participantCount'] ?? 1,
      maxParticipants: json['maxParticipants'] ?? 8,
      isPublic: json['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hostUid': hostUid,
      'roomName': roomName,
      'activeSongId': activeSongId,
      'playbackPositionMs': playbackPositionMs,
      'playbackState': playbackState.name,
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'participantCount': participantCount,
      'maxParticipants': maxParticipants,
      'isPublic': isPublic,
    };
  }

  RoomModel copyWith({
    String? activeSongId,
    int? playbackPositionMs,
    PlaybackState? playbackState,
    DateTime? lastUpdated,
    int? participantCount,
    int? maxParticipants,
    bool? isPublic,
  }) {
    return RoomModel(
      id: id,
      hostUid: hostUid,
      roomName: roomName,
      activeSongId: activeSongId ?? this.activeSongId,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      playbackState: playbackState ?? this.playbackState,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  bool get isFull => participantCount >= maxParticipants;
  bool get isActive => playbackState != PlaybackState.stopped;
}
