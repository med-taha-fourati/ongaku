class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin;
  final DateTime createdAt;
  final List<String> likedSongs;
  final List<String> playHistory;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isAdmin = false,
    required this.createdAt,
    this.likedSongs = const [],
    this.playHistory = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      likedSongs: List<String>.from(json['likedSongs'] ?? []),
      playHistory: List<String>.from(json['playHistory'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
      'likedSongs': likedSongs,
      'playHistory': playHistory,
    };
  }

  UserModel copyWith({
    String? displayName,
    bool? isAdmin,
    List<String>? likedSongs,
    List<String>? playHistory,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
      likedSongs: likedSongs ?? this.likedSongs,
      playHistory: playHistory ?? this.playHistory,
    );
  }
}