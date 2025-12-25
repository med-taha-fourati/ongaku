import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class AudioDuckingService {
  final AudioPlayer _player;
  final Map<String, bool> _speakingStates = {};
  
  Timer? _restoreTimer;
  bool _isDucked = false;
  
  static const double _duckedVolume = 0.3;
  static const double _normalVolume = 1.0;
  static const Duration _duckDuration = Duration(milliseconds: 200);
  static const Duration _restoreDuration = Duration(milliseconds: 500);
  static const Duration _speechEndDelay = Duration(milliseconds: 1000);

  AudioDuckingService(this._player);

  void updateSpeakingState(String participantId, bool isSpeaking) {
    _speakingStates[participantId] = isSpeaking;
    _evaluateDucking();
  }

  void removeSpeaker(String participantId) {
    _speakingStates.remove(participantId);
    _evaluateDucking();
  }

  void _evaluateDucking() {
    final anyoneSpeaking = _speakingStates.values.any((speaking) => speaking);

    if (anyoneSpeaking && !_isDucked) {
      _duck();
    } else if (!anyoneSpeaking && _isDucked) {
      _restoreTimer?.cancel();
      _restoreTimer = Timer(_speechEndDelay, () {
        if (!_speakingStates.values.any((speaking) => speaking)) {
          _restore();
        }
      });
    }
  }

  Future<void> _duck() async {
    if (_isDucked) return;
    
    _isDucked = true;
    _restoreTimer?.cancel();
    
    await _animateVolume(_duckedVolume, _duckDuration);
    debugPrint('AudioDucking: Ducked to ${(_duckedVolume * 100).toInt()}%');
  }

  Future<void> _restore() async {
    if (!_isDucked) return;
    
    _isDucked = false;
    
    await _animateVolume(_normalVolume, _restoreDuration);
    debugPrint('AudioDucking: Restored to ${(_normalVolume * 100).toInt()}%');
  }

  Future<void> _animateVolume(double targetVolume, Duration duration) async {
    final currentVolume = await _player.volume;
    final steps = 10;
    final stepDuration = duration.inMilliseconds ~/ steps;
    final volumeStep = (targetVolume - currentVolume) / steps;

    for (var i = 0; i < steps; i++) {
      final newVolume = currentVolume + (volumeStep * (i + 1));
      await _player.setVolume(newVolume.clamp(0.0, 1.0));
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    await _player.setVolume(targetVolume);
  }

  void dispose() {
    _restoreTimer?.cancel();
    _speakingStates.clear();
  }
}
