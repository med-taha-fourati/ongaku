import 'dart:isolate'; // Added import for SendPort
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  static bool _isRunning = false;
  static String? _currentRoomId;

  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ongaku_room_host',
        channelName: 'Ongaku Room Hosting',
        channelDescription: 'Notification shown when hosting a music room',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // Renamed to match UI usage
  static Future<bool> startService({
    required String roomName,
    String? roomId, // Made optional to match existing call, though usage should ideally pass it
    int participantCount = 1,
  }) async {
    if (_isRunning && _currentRoomId == roomId && roomId != null) {
      debugPrint('ForegroundService: Already running for room $roomId');
      return true;
    }

    _currentRoomId = roomId;

    final bool started = await FlutterForegroundTask.startService(
      notificationTitle: 'Hosting: $roomName',
      notificationText: '$participantCount participant${participantCount != 1 ? 's' : ''}',
      callback: _foregroundTaskCallback,
    );

    if (started) {
      _isRunning = true;
      debugPrint('ForegroundService: Started for room $roomName ($roomId)');
    } else {
      debugPrint('ForegroundService: Failed to start');
    }

    return started;
  }

  static Future<void> updateParticipantCount({
    required String roomName,
    required int count,
  }) async {
    if (!_isRunning) {
      debugPrint('ForegroundService: Not running, cannot update');
      return;
    }

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Hosting: $roomName',
      notificationText: '$count participant${count != 1 ? 's' : ''}',
    );

    debugPrint('ForegroundService: Updated participant count to $count');
  }

  // Renamed to match UI usage
  static Future<bool> stopService() async {
    if (!_isRunning) {
      debugPrint('ForegroundService: Not running, nothing to stop');
      return true;
    }

    final bool stopped = await FlutterForegroundTask.stopService();

    if (stopped) {
      _isRunning = false;
      _currentRoomId = null;
      debugPrint('ForegroundService: Stopped successfully');
    } else {
      debugPrint('ForegroundService: Failed to stop');
    }

    return stopped;
  }

  static bool get isRunning => _isRunning;
  static String? get currentRoomId => _currentRoomId;

  @pragma('vm:entry-point')
  static void _foregroundTaskCallback() {
    FlutterForegroundTask.setTaskHandler(_ForegroundTaskHandler());
  }
}

class _ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('ForegroundTaskHandler: Started at $timestamp');
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('ForegroundTaskHandler: Destroyed at $timestamp');
  }

  @override
  void onButtonPressed(String id) {
  }

  @override
  void onNotificationPressed() {
  }
  
  // Implemented missing override
  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Periodic task callback
  }
}
