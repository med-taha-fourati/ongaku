class RadioStation {
  final String id;
  final String name;
  final String streamUrl;
  final String? imageUrl;
  final String genre;
  final String country;

  RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.imageUrl,
    required this.genre,
    required this.country,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['stationuuid'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      streamUrl: json['url_resolved'] ?? json['url'] ?? json['streamUrl'] ?? '',
      imageUrl: json['favicon'] ?? json['imageUrl'],
      genre: json['tags'] ?? json['genre'] ?? '',
      country: json['country'] ?? '',
    );
  }
}