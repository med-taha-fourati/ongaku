enum SongStatus {
  pending, approved, rejected
}

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String audioUrl;
  final String? coverUrl;
  final int duration;
  final String uploadedBy;
  final DateTime uploadedAt;
  final SongStatus status;
  final int playCount;
  final int likeCount;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.audioUrl,
    this.coverUrl,
    required this.duration,
    required this.uploadedBy,
    required this.uploadedAt,
    this.status = SongStatus.pending,
    this.playCount = 0,
    this.likeCount = 0,
  });

  factory SongModel.fromJson(String id, Map<String, dynamic> json) {
    return SongModel(
      id: id,
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      genre: json['genre'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      coverUrl: json['coverUrl'],
      duration: json['duration'] ?? 0,
      uploadedBy: json['uploadedBy'] ?? '',
      uploadedAt: DateTime.parse(json['uploadedAt']),
      status: SongStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => SongStatus.pending,
      ),
      playCount: json['playCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl,
      'duration': duration,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'status': status.name,
      'playCount': playCount,
      'likeCount': likeCount,
    };
  }
}