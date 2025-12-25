class ParticipantModel {
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final DateTime joinedAt;
  final bool isSpeaking;
  final DateTime lastSeen;

  ParticipantModel({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.isHost = false,
    required this.joinedAt,
    this.isSpeaking = false,
    required this.lastSeen,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      uid: json['uid'] ?? '',
      displayName: json['displayName'] ?? '',
      avatarUrl: json['avatarUrl'],
      isHost: json['isHost'] ?? false,
      joinedAt: DateTime.parse(json['joinedAt']),
      isSpeaking: json['isSpeaking'] ?? false,
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
      'isSpeaking': isSpeaking,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  ParticipantModel copyWith({
    bool? isSpeaking,
    DateTime? lastSeen,
  }) {
    return ParticipantModel(
      uid: uid,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isHost: isHost,
      joinedAt: joinedAt,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isConnected {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    return difference.inSeconds < 15;
  }
}
