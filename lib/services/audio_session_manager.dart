import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioSessionManager {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('AudioSessionManager: Already initialized');
      return;
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers |
                AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      _initialized = true;
      debugPrint('AudioSessionManager: Initialized successfully');
      debugPrint('  Category: playback (music through loudspeaker)');
      debugPrint('  Mode: default');
      debugPrint('  Android usage: media');
      debugPrint('  Will pause when ducked: false');
    } catch (e) {
      debugPrint('AudioSessionManager: Initialization failed: $e');
      rethrow;
    }
  }

  static bool get isInitialized => _initialized;

  static Future<void> handleInterruptions() async {
    final session = await AudioSession.instance;
    session.interruptionEventStream.listen((event) {
      debugPrint('AudioSessionManager: Interruption event: ${event.type}');
      if (event.begin) {
        debugPrint('  Interruption began');
      } else {
        debugPrint('  Interruption ended, should resume: ${event.type == AudioInterruptionType.pause}');
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      debugPrint('AudioSessionManager: Becoming noisy (headphones unplugged)');
    });
  }
}
