import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/participant_model.dart';
import '../repositories/room_repository.dart';

class RoomLifecycleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RoomRepository _roomRepository;
  
  Timer? _heartbeatTimer;
  StreamSubscription? _participantsSubscription;

  RoomLifecycleService(this._roomRepository);

  void startHeartbeat(String roomId, String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await _roomRepository.updateParticipantHeartbeat(
          roomId: roomId,
          uid: uid,
        );
      } catch (e) {
        debugPrint('Heartbeat failed: $e');
      }
    });
  }

  void monitorRoomHealth(String roomId, String currentUid) {
    // Only used by non-hosts to detect if host has left/disconnected
    _participantsSubscription?.cancel();
    _participantsSubscription = _roomRepository.getParticipants(roomId).listen((participants) {
      _checkHostStatus(roomId, currentUid, participants);
    });
  }

  Future<void> _checkHostStatus(String roomId, String currentUid, List<ParticipantModel> participants) async {
    final host = participants.firstWhere((p) => p.isHost, orElse: () => 
      ParticipantModel(
        uid: '', 
        displayName: '', 
        joinedAt: DateTime.now(), 
        lastSeen: DateTime.now().subtract(const Duration(days: 1))
      )
    );

    if (host.uid.isEmpty) return; // Should not happen if room valid

    final now = DateTime.now();
    final hostLastSeen = host.lastSeen;
    final timeSinceLastSeen = now.difference(hostLastSeen);

    // If host is gone for > 20 seconds, trigger migration
    if (timeSinceLastSeen.inSeconds > 20) {
      await _attemptHostMigration(roomId, currentUid, participants);
    }
  }

  Future<void> _attemptHostMigration(String roomId, String currentUid, List<ParticipantModel> participants) async {
    // Sort by join time (oldest member becomes new host)
    // Filter out the dead host
    final candidates = participants
        .where((p) => !p.isHost && p.isConnected)
        .toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

    if (candidates.isEmpty) {
      // No valid candidates, room might be dead
      return;
    }

    final newHost = candidates.first;

    // Only the new host candidate attempts the write to avoid contention
    // (Though transaction handles it safely, this reduces load)
    if (newHost.uid == currentUid) {
      debugPrint('Attempting to become new host...');
      try {
        await _firestore.runTransaction((transaction) async {
          final roomRef = _firestore.collection('rooms').doc(roomId);
          final roomDoc = await transaction.get(roomRef);

          if (!roomDoc.exists) return;

          // Double check host is still same (dead) one
          // In real implementation we'd probably check hostUid
          
          transaction.update(roomRef, {
            'hostUid': currentUid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          final participantRef = roomRef.collection('participants').doc(currentUid);
          transaction.update(participantRef, {'isHost': true});
          
          // Demote old host? Or just let them be removed by separate cleaner
          // For now, we just promote new one. 
          // Ideally we iterate participants to unset isHost for others if needed, but 'hostUid' on room is source of truth.
        });
      } catch (e) {
        debugPrint('Host migration failed: $e');
      }
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _participantsSubscription?.cancel();
  }
}
