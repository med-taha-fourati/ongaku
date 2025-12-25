import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class WebRTCService {
  final String roomId;
  final String localUid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, StreamSubscription> _signalingSubscriptions = {};
  
  MediaStream? _localStream;
  final _remoteStreamsController = StreamController<Map<String, MediaStream>>.broadcast();
  final _audioLevelsController = StreamController<Map<String, double>>.broadcast();
  
  bool _isInitialized = false;
  Timer? _audioLevelTimer;

  Stream<Map<String, MediaStream>> get remoteStreamsStream => _remoteStreamsController.stream;
  Stream<Map<String, double>> get audioLevelsStream => _audioLevelsController.stream;

  WebRTCService({
    required this.roomId,
    required this.localUid,
  });

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('WebRTC: Already initialized');
      return;
    }

    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      _startAudioLevelMonitoring();
      
      _isInitialized = true;
      debugPrint('WebRTC: Initialized with local stream');
    } catch (e) {
      debugPrint('WebRTC: Failed to initialize: $e');
      rethrow;
    }
  }

  Future<void> connectToParticipants(List<String> participantUids) async {
    if (!_isInitialized) {
      throw Exception('WebRTC not initialized');
    }

    for (final remoteUid in participantUids) {
      if (remoteUid == localUid) continue;
      
      if (_peerConnections.containsKey(remoteUid)) {
        debugPrint('WebRTC: Already connected to $remoteUid');
        continue;
      }

      final shouldCreateOffer = localUid.compareTo(remoteUid) < 0;
      
      if (shouldCreateOffer) {
        await _createPeerConnection(remoteUid, isOfferer: true);
      } else {
        await _listenForOffer(remoteUid);
      }
    }
  }

  Future<void> _createPeerConnection(String remoteUid, {required bool isOfferer}) async {
    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'iceCandidatePoolSize': 10,
      };

      final pc = await createPeerConnection(configuration);
      _peerConnections[remoteUid] = pc;

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
      }

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(remoteUid, candidate);
      };

      pc.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          debugPrint('WebRTC: Received remote stream from $remoteUid');
          _updateRemoteStream(remoteUid, event.streams[0]);
        }
      };

      pc.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('WebRTC: ICE connection state with $remoteUid: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          _handleConnectionFailure(remoteUid);
        }
      };

      if (isOfferer) {
        await _createAndSendOffer(remoteUid, pc);
        await _listenForAnswer(remoteUid, pc);
      }

      _listenForIceCandidates(remoteUid, pc);

      debugPrint('WebRTC: Peer connection created for $remoteUid (offerer: $isOfferer)');
    } catch (e) {
      debugPrint('WebRTC: Failed to create peer connection for $remoteUid: $e');
      rethrow;
    }
  }

  Future<void> _createAndSendOffer(String remoteUid, RTCPeerConnection pc) async {
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('signaling')
          .doc('${localUid}_$remoteUid')
          .set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'from': localUid,
        'to': remoteUid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('WebRTC: Sent offer to $remoteUid');
    } catch (e) {
      debugPrint('WebRTC: Failed to create/send offer: $e');
      rethrow;
    }
  }

  Future<void> _listenForOffer(String remoteUid) async {
    final subscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('signaling')
        .doc('${remoteUid}_$localUid')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return;
      
      final data = snapshot.data()!;
      if (data['offer'] == null) return;

      if (_peerConnections.containsKey(remoteUid)) {
        debugPrint('WebRTC: Already have connection with $remoteUid');
        return;
      }

      debugPrint('WebRTC: Received offer from $remoteUid');
      
      final pc = await _createPeerConnectionForAnswer(remoteUid);
      
      final offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      
      await pc.setRemoteDescription(offer);
      
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('signaling')
          .doc('${remoteUid}_$localUid')
          .update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });

      debugPrint('WebRTC: Sent answer to $remoteUid');
    });

    _signalingSubscriptions[remoteUid] = subscription;
  }

  Future<RTCPeerConnection> _createPeerConnectionForAnswer(String remoteUid) async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'iceCandidatePoolSize': 10,
    };

    final pc = await createPeerConnection(configuration);
    _peerConnections[remoteUid] = pc;

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(remoteUid, candidate);
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        debugPrint('WebRTC: Received remote stream from $remoteUid');
        _updateRemoteStream(remoteUid, event.streams[0]);
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRTC: ICE connection state with $remoteUid: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _handleConnectionFailure(remoteUid);
      }
    };

    _listenForIceCandidates(remoteUid, pc);

    return pc;
  }

  Future<void> _listenForAnswer(String remoteUid, RTCPeerConnection pc) async {
    final subscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('signaling')
        .doc('${localUid}_$remoteUid')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return;
      
      final data = snapshot.data()!;
      if (data['answer'] == null) return;

      if (pc.signalingState == RTCSignalingState.RTCSignalingStateStable) {
        return;
      }

      debugPrint('WebRTC: Received answer from $remoteUid');
      
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      
      await pc.setRemoteDescription(answer);
    });

    _signalingSubscriptions['${remoteUid}_answer'] = subscription;
  }

  void _listenForIceCandidates(String remoteUid, RTCPeerConnection pc) {
    final candidatesPath = localUid.compareTo(remoteUid) < 0
        ? '${localUid}_$remoteUid'
        : '${remoteUid}_$localUid';

    final subscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('signaling')
        .doc(candidatesPath)
        .collection('iceCandidates')
        .where('to', isEqualTo: localUid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          
          pc.addCandidate(candidate);
          debugPrint('WebRTC: Added ICE candidate from $remoteUid');
        }
      }
    });

    _signalingSubscriptions['${remoteUid}_ice'] = subscription;
  }

  Future<void> _sendIceCandidate(String remoteUid, RTCIceCandidate candidate) async {
    try {
      final candidatesPath = localUid.compareTo(remoteUid) < 0
          ? '${localUid}_$remoteUid'
          : '${remoteUid}_$localUid';

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('signaling')
          .doc(candidatesPath)
          .collection('iceCandidates')
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'from': localUid,
        'to': remoteUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('WebRTC: Failed to send ICE candidate: $e');
    }
  }

  void _updateRemoteStream(String remoteUid, MediaStream stream) {
    final currentStreams = <String, MediaStream>{};
    _peerConnections.forEach((uid, pc) {
      if (uid == remoteUid) {
        currentStreams[uid] = stream;
      }
    });
    _remoteStreamsController.add(currentStreams);
  }

  void _handleConnectionFailure(String remoteUid) {
    debugPrint('WebRTC: Connection failed with $remoteUid, attempting reconnect');
    disconnectFromParticipant(remoteUid);
    
    Future.delayed(const Duration(seconds: 2), () {
      _createPeerConnection(remoteUid, isOfferer: localUid.compareTo(remoteUid) < 0);
    });
  }

  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final levels = <String, double>{};
      
      levels[localUid] = _getAudioLevel(_localStream);
      
      _audioLevelsController.add(levels);
    });
  }

  double _getAudioLevel(MediaStream? stream) {
    if (stream == null) return 0.0;
    
    return 0.0;
  }

  Future<void> disconnectFromParticipant(String remoteUid) async {
    final pc = _peerConnections.remove(remoteUid);
    if (pc != null) {
      await pc.close();
      debugPrint('WebRTC: Disconnected from $remoteUid');
    }

    _signalingSubscriptions[remoteUid]?.cancel();
    _signalingSubscriptions.remove(remoteUid);
    _signalingSubscriptions['${remoteUid}_answer']?.cancel();
    _signalingSubscriptions.remove('${remoteUid}_answer');
    _signalingSubscriptions['${remoteUid}_ice']?.cancel();
    _signalingSubscriptions.remove('${remoteUid}_ice');
  }

  Future<void> dispose() async {
    _audioLevelTimer?.cancel();
    
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    for (var subscription in _signalingSubscriptions.values) {
      await subscription.cancel();
    }
    _signalingSubscriptions.clear();

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStreamsController.close();
    await _audioLevelsController.close();

    _isInitialized = false;
    debugPrint('WebRTC: Disposed');
  }

  bool get isInitialized => _isInitialized;
  int get connectionCount => _peerConnections.length;
}
