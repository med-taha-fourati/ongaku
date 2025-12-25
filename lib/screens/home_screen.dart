import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import 'songs_tab.dart';
import 'radio_tab.dart';
import 'upload_screen.dart';
import 'rooms_tab.dart';
import 'admin_tab.dart';
import 'player_bottom_sheet.dart';
import '../providers/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isConnected = ref.watch(connectivityProvider).value ?? true;
    final playerState = ref.watch(playerProvider);

    final tabs = [
      const SongsTab(),
      const RadioTab(),
      const RoomsTab(),
      const UploadScreen(),
      if (currentUser.value?.isAdmin ?? false) const AdminTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongaku'),
        actions: [
          if (!isConnected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.cloud_off, color: Colors.red),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authRepository = ref.read(authRepositoryProvider);
              await authRepository.signOut();
            },
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (playerState.currentSong != null || playerState.currentStation != null)
            const PlayerBottomSheet(),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.library_music),
                label: 'Songs',
              ),
              const NavigationDestination(
                icon: Icon(Icons.radio),
                label: 'Radio',
              ),
              const NavigationDestination(
                icon: Icon(Icons.groups),
                label: 'Rooms',
              ),
              const NavigationDestination(
                icon: Icon(Icons.upload),
                label: 'Upload',
              ),
              if (currentUser.value?.isAdmin ?? false)
                const NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
            ],
          ),
        ],
      ),
    );
  }
}