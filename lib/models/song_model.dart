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
    required String title,
    required String artist,
    String? album,
    required String genre,
    required String audioUrl,
    this.coverUrl,
    required int duration,
    required String uploadedBy,
    required DateTime uploadedAt,
    this.status = SongStatus.pending,
    int? playCount,
    int? likeCount,
  }) : title = title.trim(),
       artist = artist.trim(),
       album = album?.trim() ?? '',
       genre = genre.trim(),
       audioUrl = audioUrl.trim(),
       duration = duration,
       uploadedBy = uploadedBy,
       uploadedAt = uploadedAt,
       playCount = playCount ?? 0,
       likeCount = likeCount ?? 0;

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
    final map = <String, dynamic>{
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'audioUrl': audioUrl,
      'duration': duration,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'status': status.name,
      'playCount': playCount,
      'likeCount': likeCount,
    };
    
    // Only include coverUrl if it's not null
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      map['coverUrl'] = coverUrl;
    }
    
    return map;
  }
}