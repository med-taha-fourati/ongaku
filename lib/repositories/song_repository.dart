import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'package:path/path.dart' as path;

class SongRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Update this to your server's address and port
  static const String _serverBaseUrl = 'http://localhost:8080';
  
  // Local cache directory for storing downloaded files
  Future<Directory> get _localDir async {
    return await getApplicationDocumentsDirectory();
  }
  
  // Headers for HTTP requests
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Stream<List<SongModel>> getApprovedSongs() {
    return _firestore
        .collection('songs')
        .where('status', isEqualTo: 'approved')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => SongModel.fromJson(doc.id, doc.data()))
        .toList());
  }

  Stream<List<SongModel>> getPendingSongs() {
    return _firestore
        .collection('songs')
        .where('status', isEqualTo: 'pending')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => SongModel.fromJson(doc.id, doc.data()))
        .toList());
  }

  Future<List<SongModel>> getTrendingSongs() async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('status', isEqualTo: 'approved')
          .orderBy('playCount', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => SongModel.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch trending songs: $e');
    }
  }

  Future<List<SongModel>> getRecommendedSongs() async {
    try {
      // TODO: Implement more sophisticated recommendation logic
      // For now, return a mix of trending and recent songs
      final trendingSnapshot = await _firestore
          .collection('songs')
          .where('status', isEqualTo: 'approved')
          .orderBy('playCount', descending: true)
          .limit(10)
          .get();

      final recentSnapshot = await _firestore
          .collection('songs')
          .where('status', isEqualTo: 'approved')
          .orderBy('uploadedAt', descending: true)
          .limit(10)
          .get();

      final Set<String> seenIds = {};
      final List<SongModel> recommendations = [];

      // Add trending songs
      for (var doc in trendingSnapshot.docs) {
        if (seenIds.add(doc.id)) {
          recommendations.add(SongModel.fromJson(doc.id, doc.data()));
        }
      }

      // Add recent songs
      for (var doc in recentSnapshot.docs) {
        if (seenIds.add(doc.id)) {
          recommendations.add(SongModel.fromJson(doc.id, doc.data()));
        }
      }

      // Shuffle the recommendations for variety
      recommendations.shuffle();
      return recommendations;
    } catch (e) {
      throw Exception('Failed to fetch recommended songs: $e');
    }
  }

  Future<List<SongModel>> getRecommendations(List<String> genres, List<String> excludeIds) async {
    try {
      if (genres.isEmpty) {
        final snapshot = await _firestore
            .collection('songs')
            .where('status', isEqualTo: 'approved')
            .limit(10)
            .get();

        return snapshot.docs
            .map((doc) => SongModel.fromJson(doc.id, doc.data()))
            .where((song) => !excludeIds.contains(song.id))
            .toList();
      }

      final snapshot = await _firestore
          .collection('songs')
          .where('status', isEqualTo: 'approved')
          .where('genre', whereIn: genres.take(10).toList())
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => SongModel.fromJson(doc.id, doc.data()))
          .where((song) => !excludeIds.contains(song.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> uploadSong(File file, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final url = Uri.parse('$_serverBaseUrl/upload/song');
      
      var request = http.MultipartRequest('POST', url);
      request.fields['userId'] = userId;
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return '$_serverBaseUrl${jsonResponse['url']}';
      } else {
        throw Exception('Failed to upload song: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to upload song: $e');
    }
  }

  Future<String?> uploadCover(File file, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final url = Uri.parse('$_serverBaseUrl/upload/cover');
      
      var request = http.MultipartRequest('POST', url);
      request.fields['userId'] = userId;
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return '$_serverBaseUrl${jsonResponse['url']}';
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  Future<File> getSongFile(String url) async {
    try {
      final dir = await _localDir;
      final fileName = path.basename(Uri.parse(url).path);
      final file = File('${dir.path}/songs/$fileName');
      
      if (await file.exists()) {
        return file;
      }
      
      await file.parent.create(recursive: true);
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get song file: $e');
    }
  }

  Future<void> createSong(SongModel song) async {
    try {
      await _firestore.collection('songs').add(song.toJson());
    } catch (e) {
      throw Exception('Failed to create song: $e');
    }
  }

  Future<void> updateSongStatus(String songId, SongStatus status) async {
    try {
      await _firestore.collection('songs').doc(songId).update({
        'status': status.name,
      });
    } catch (e) {
      throw Exception('Failed to update song status: $e');
    }
  }

  Future<void> incrementPlayCount(String songId) async {
    try {
      await _firestore.collection('songs').doc(songId).update({
        'playCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> incrementLikeCount(String songId) async {
    try {
      await _firestore.collection('songs').doc(songId).update({
        'likeCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> decrementLikeCount(String songId) async {
    try {
      await _firestore.collection('songs').doc(songId).update({
        'likeCount': FieldValue.increment(-1),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> deleteSong(String songId) async {
    try {
      await _firestore.collection('songs').doc(songId).delete();
    } catch (e) {
      throw Exception('Failed to delete song: $e');
    }
  }
}