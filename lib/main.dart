import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'utils/theme.dart';
import 'services/audio_session_manager.dart';
import 'services/foreground_service_manager.dart';
import 'dart:io' show Platform;

Future<void> _initializeAudioSession() async {
  try {
    await AudioSessionManager.initialize();
    await AudioSessionManager.handleInterruptions();
  } catch (e) {
    debugPrint('Audio session initialization error: $e');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}

Future<void> _initializeAudioService() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.musicplayer.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Audio initialization error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await _initializeAudioSession();
  await ForegroundServiceManager.initialize();
  
  await Future.wait([
    _initializeFirebase(),
    _initializeAudioService(),
  ]);

  runApp(const ProviderScope(child: MusicPlayerApp()));
}

class MusicPlayerApp extends ConsumerWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Optional: Fallback seed color (used if dynamic colors unavailable)
        const fallbackSeed = Color.fromARGB(255, 0, 153, 132);

        final lightScheme = lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.light,
            );

        final darkScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Ongaku',
          theme: AppTheme.lightTheme(lightScheme),
          darkTheme: AppTheme.darkTheme(darkScheme),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: authState.when(
            data: (user) =>
            user != null ? const HomeScreen() : const LoginScreen(),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const LoginScreen(),
          ),
        );
      },
    );
  }
}
