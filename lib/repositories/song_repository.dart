import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'package:path/path.dart' as path;
import '../constants.dart';

class SongRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String get _serverBaseUrl => AppConstants.mediaServerUrl;

  Future<Directory> get _localDir async {
    return await getApplicationDocumentsDirectory();
  }

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

      for (var doc in trendingSnapshot.docs) {
        if (seenIds.add(doc.id)) {
          recommendations.add(SongModel.fromJson(doc.id, doc.data()));
        }
      }

      for (var doc in recentSnapshot.docs) {
        if (seenIds.add(doc.id)) {
          recommendations.add(SongModel.fromJson(doc.id, doc.data()));
        }
      }

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

  Future<Map<String, dynamic>> uploadSongWithMetadata({
    required File audioFile,
    File? coverFile,
    required String userId,
    required String title,
    required String artist,
    String? album,
    String? genre,
  }) async {
    try {
      if (!await audioFile.exists()) {
        throw Exception('The selected audio file does not exist');
      }

      final filePath = audioFile.path;
      if (filePath.isEmpty) {
        throw Exception('Invalid file path');
      }

      final url = Uri.parse('$_serverBaseUrl/upload/song');
      final request = http.MultipartRequest('POST', url);
      request.fields['userId'] = userId;
      request.fields['title'] = title;
      request.fields['artist'] = artist;
      request.fields['album'] = album ?? '';
      request.fields['genre'] = genre ?? '';

      final audioPart = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}',
      );
      request.files.add(audioPart);

      if (coverFile != null && await coverFile.exists()) {
        final coverPart = await http.MultipartFile.fromPath(
          'cover',
          coverFile.path,
          filename: '${DateTime.now().millisecondsSinceEpoch}_${path.basename(coverFile.path)}',
        );
        request.files.add(coverPart);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final metadata = (jsonResponse['metadata'] ?? {}) as Map<String, dynamic>;
        return {
          'audioUrl': jsonResponse['url'] != null ? '$_serverBaseUrl${jsonResponse['url']}' : '',
          'coverUrl': jsonResponse['coverUrl'] != null ? '$_serverBaseUrl${jsonResponse['coverUrl']}' : null,
          'metadata': metadata,
        };
      } else {
        throw Exception('Failed to upload song: ${response.reasonPhrase} (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to upload song at $_serverBaseUrl: ${e.toString()}');
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
    print("im here");
    try {
      await _firestore.collection('songs').add(song.toJson());
    } catch (e) {
      throw Exception('Failed to create song: $e');
    }
  }

  Future<void> updateSong(String songId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('songs').doc(songId).update(data);
    } catch (e) {
      throw Exception('Failed to update song: $e');
    }
  }

  Future<void> deleteSongMedia(String audioUrl) async {
    if (audioUrl.isEmpty) {
      return;
    }
    try {
      final uri = Uri.parse(audioUrl);
      final response = await http.delete(uri, headers: _headers);
      if (response.statusCode >= 400 && response.statusCode != 404) {
        throw Exception('Failed to delete song file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete song file at $_serverBaseUrl: ${e.toString()}');
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
    }
  }

  Future<List<String>> fetchUserFavorites(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return List<String>.from(data['likedSongs'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Stream<List<String>> watchUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <String>[];
      }
      final data = snapshot.data()!;
      return List<String>.from(data['likedSongs'] ?? []);
    });
  }

  Future<void> addUserFavorite(String userId, String songId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final songRef = _firestore.collection('songs').doc(songId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final likedSongs = List<String>.from(data['likedSongs'] ?? []);
          if (!likedSongs.contains(songId)) {
            likedSongs.add(songId);
            transaction.update(userRef, {
              'likedSongs': likedSongs,
            });
            transaction.update(songRef, {
              'likeCount': FieldValue.increment(1),
            });
          }
        }
      });
    } catch (e) {
    }
  }

  Future<void> removeUserFavorite(String userId, String songId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final songRef = _firestore.collection('songs').doc(songId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final likedSongs = List<String>.from(data['likedSongs'] ?? []);
          if (likedSongs.contains(songId)) {
            likedSongs.remove(songId);
            transaction.update(userRef, {
              'likedSongs': likedSongs,
            });
            transaction.update(songRef, {
              'likeCount': FieldValue.increment(-1),
            });
          }
        }
      });
    } catch (e) {
      print("Unable to remove favorite: $e");
    }
  }

  Future<List<SongModel>> getSongsByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection('songs')
          .where('uploadedBy', isEqualTo: userId)
          .get();

      var result = query.docs;
      List<SongModel> songs =
          result.map((doc) => SongModel.fromJson(doc.id, doc.data())).toList();
      return songs;

    } catch (e) {
      print("Unable to fetch Songs by User ID: $e");
      return [];
    }
  }

  Future<SongModel> getSong(String songId) async {
    try {
      final doc = await _firestore.collection('songs').doc(songId).get();
      if (!doc.exists) {
        throw Exception('Song not found');
      }
      final data = doc.data()!;
      final song = SongModel.fromJson(doc.id, data);
      print('SongRepository: Fetched song ${song.title}, Audio URL: ${song.audioUrl}');
      return song;
    } catch (e) {
      print('SongRepository Error: $e');
      throw Exception('Failed to fetch song: $e');
    }
  }

  Future<void> deleteSong(String songId) async {
    try {
      await _firestore.collection('songs').doc(songId).delete();
    } catch (e) {
      throw Exception('Failed to delete song: $e');
    }
  }

  Stream<List<String>> watchUserRadioFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <String>[];
      }
      final data = snapshot.data()!;
      return List<String>.from(data['likedRadios'] ?? []);
    });
  }

  Future<void> addUserRadioFavorite(String userId, String streamUrl) async {
    final userRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final likedRadios = List<String>.from(data['likedRadios'] ?? []);
          if (!likedRadios.contains(streamUrl)) {
            likedRadios.add(streamUrl);
            transaction.update(userRef, {
              'likedRadios': likedRadios,
            });
          }
        }
      });
    } catch (e) {
    }
  }

  Future<void> removeUserRadioFavorite(String userId, String streamUrl) async {
    final userRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final likedRadios = List<String>.from(data['likedRadios'] ?? []);
          if (likedRadios.contains(streamUrl)) {
            likedRadios.remove(streamUrl);
            transaction.update(userRef, {
              'likedRadios': likedRadios,
            });
          }
        }
      });
    } catch (e) {
    }
  }
}