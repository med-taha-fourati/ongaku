import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/participant_model.dart';
import '../models/queued_song_model.dart';

class RoomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<RoomModel>> getPublicRooms({int limit = 50}) {
    return _firestore
        .collection('rooms')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RoomModel.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<RoomModel?> getRoomStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return RoomModel.fromJson(doc.id, doc.data()!);
    });
  }

  Future<RoomModel?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return RoomModel.fromJson(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to fetch room: $e');
    }
  }

  Future<String> createRoom({
    required String hostUid,
    required String roomName,
    int maxParticipants = 8,
    bool isPublic = true,
  }) async {
    try {
      if (maxParticipants > 8) {
        throw Exception('Maximum 8 participants allowed (mesh topology limit)');
      }

      final now = DateTime.now();
      final room = RoomModel(
        id: '',
        hostUid: hostUid,
        roomName: roomName,
        lastUpdated: now,
        createdAt: now,
        maxParticipants: maxParticipants,
        isPublic: isPublic,
      );

      final docRef = await _firestore.collection('rooms').add(room.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  Future<void> updateRoomPlayback({
    required String roomId,
    String? activeSongId,
    int? playbackPositionMs,
    PlaybackState? playbackState,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (activeSongId != null) updates['activeSongId'] = activeSongId;
      if (playbackPositionMs != null) {
        updates['playbackPositionMs'] = playbackPositionMs;
      }
      if (playbackState != null) {
        updates['playbackState'] = playbackState.name;
      }

      await _firestore.collection('rooms').doc(roomId).update(updates);
    } catch (e) {
      throw Exception('Failed to update room playback: $e');
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      final batch = _firestore.batch();

      batch.delete(_firestore.collection('rooms').doc(roomId));

      final participantsSnapshot = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .get();
      for (var doc in participantsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final requestsSnapshot = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .doc('requests')
          .collection('items')
          .get();
      for (var doc in requestsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  Stream<List<ParticipantModel>> getParticipants(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParticipantModel.fromJson(doc.data()))
            .toList());
  }

  Future<void> joinRoom({
    required String roomId,
    required String uid,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (room.isFull) {
        throw Exception('Room is full (${room.participantCount}/${room.maxParticipants})');
      }

      final now = DateTime.now();
      final participant = ParticipantModel(
        uid: uid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isHost: uid == room.hostUid,
        joinedAt: now,
        lastSeen: now,
      );

      await _firestore.runTransaction((transaction) async {
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final roomDoc = await transaction.get(roomRef);

        if (!roomDoc.exists) {
          throw Exception('Room no longer exists');
        }

        final currentCount = roomDoc.data()!['participantCount'] as int;
        final maxCount = roomDoc.data()!['maxParticipants'] as int;

        if (currentCount >= maxCount) {
          throw Exception('Room is full');
        }

        transaction.set(
          roomRef.collection('participants').doc(uid),
          participant.toJson(),
        );

        transaction.update(roomRef, {
          'participantCount': FieldValue.increment(1),
          'participantIds': FieldValue.arrayUnion([uid]),
        });
      });
    } catch (e) {
      throw Exception('Failed to join room: $e');
    }
  }

  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final participantRef = roomRef.collection('participants').doc(uid);

        transaction.delete(participantRef);
        transaction.update(roomRef, {
          'participantCount': FieldValue.increment(-1),
          'participantIds': FieldValue.arrayRemove([uid]),
        });
      });

      final room = await getRoom(roomId);
      if (room != null && room.participantCount == 0) {
        await deleteRoom(roomId);
      }
    } catch (e) {
      throw Exception('Failed to leave room: $e');
    }
  }

  Future<void> updateParticipantHeartbeat({
    required String roomId,
    required String uid,
    bool? isSpeaking,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastSeen': DateTime.now().toIso8601String(),
      };

      if (isSpeaking != null) {
        updates['isSpeaking'] = isSpeaking;
      }

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(uid)
          .update(updates);
    } catch (e) {
    }
  }

  Stream<List<QueuedSong>> getMasterQueue(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('queue')
        .doc('master')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <QueuedSong>[];
      final data = doc.data()!;
      final songsData = data['songs'] as List<dynamic>? ?? [];
      return songsData
          .map((json) => QueuedSong.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    });
  }

  Future<void> updateMasterQueue({
    required String roomId,
    required List<QueuedSong> songs,
  }) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .doc('master')
          .set({
        'songs': songs.map((s) => s.toJson()).toList(),
        'lastModified': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update master queue: $e');
    }
  }

  Stream<List<SongRequest>> getSongRequests(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('queue')
        .doc('requests')
        .collection('items')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SongRequest.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> requestSong({
    required String roomId,
    required String songId,
    required String title,
    required String artist,
    required int durationMs,
    required String requestedBy,
  }) async {
    try {
      final request = SongRequest(
        id: '',
        songId: songId,
        title: title,
        artist: artist,
        durationMs: durationMs,
        requestedBy: requestedBy,
        requestedAt: DateTime.now(),
      );

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .doc('requests')
          .collection('items')
          .add(request.toJson());
    } catch (e) {
      throw Exception('Failed to request song: $e');
    }
  }

  Future<void> approveRequest({
    required String roomId,
    required String requestId,
    required SongRequest request,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final requestRef = _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('queue')
            .doc('requests')
            .collection('items')
            .doc(requestId);

        final masterRef = _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('queue')
            .doc('master');

        final masterDoc = await transaction.get(masterRef);
        final currentQueue = <QueuedSong>[];

        if (masterDoc.exists && masterDoc.data() != null) {
          final songsData = masterDoc.data()!['songs'] as List<dynamic>? ?? [];
          currentQueue.addAll(
            songsData.map((json) => QueuedSong.fromJson(json as Map<String, dynamic>)),
          );
        }

        final newSong = request.toQueuedSong(currentQueue.length);
        currentQueue.add(newSong);

        transaction.update(requestRef, {'status': RequestStatus.approved.name});
        transaction.set(masterRef, {
          'songs': currentQueue.map((s) => s.toJson()).toList(),
          'lastModified': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  Future<void> rejectRequest({
    required String roomId,
    required String requestId,
  }) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('queue')
          .doc('requests')
          .collection('items')
          .doc(requestId)
          .update({'status': RequestStatus.rejected.name});
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }
}
