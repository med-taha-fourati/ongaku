import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listening_session.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logSession(ListeningSession session) async {
    try {
      await _firestore.collection('listening_sessions').add(session.toJson());
    } catch (e) {
      // Silently fail
    }
  }


  Future<List<ListeningSession>> getSessionsForPeriod(String userId, DateTime start, DateTime end) async {
    try {
      final querySnapshot = await _firestore
          .collection('listening_sessions')
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('startTime', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      return querySnapshot.docs
          .map((doc) => ListeningSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      // In production, log error
      return [];
    }
  }

  // Fetch recent sessions for top tracks calculation (limit 500 for MVP performance)
  Future<List<ListeningSession>> getRecentSessions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('listening_sessions')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: true)
          .orderBy('startTime', descending: true)
          .limit(500) 
          .get();

      return querySnapshot.docs
          .map((doc) => ListeningSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getUserGenres(String userId) async {
    try {
      final sessions = await _firestore
          .collection('listening_sessions')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: true)
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      final songIds = sessions.docs.map((doc) => doc.data()['songId'] as String).toSet();

      final genres = <String>{};
      for (final songId in songIds) {
        final songDoc = await _firestore.collection('songs').doc(songId).get();
        if (songDoc.exists) {
          genres.add(songDoc.data()!['genre'] as String);
        }
      }

      return genres.toList();
    } catch (e) {
      return [];
    }
  }
}