import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/song_provider.dart';
import '../providers/player_provider.dart';
import '../providers/radio_provider.dart';
import '../models/song_model.dart';
import '../models/radio_station.dart';
import '../widgets/full_player_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Radios'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _FavoriteSongsList(),
              _FavoriteRadiosList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteSongsList extends ConsumerWidget {
  const _FavoriteSongsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider);
    final allSongsAsync = ref.watch(approvedSongsProvider);

    return allSongsAsync.when(
      data: (allSongs) {
        final favoriteSongs = allSongs.where((s) => favoriteIds.contains(s.id)).toList();

        if (favoriteSongs.isEmpty) {
          return const Center(child: Text('No favorite songs yet'));
        }

        return ListView.builder(
          itemCount: favoriteSongs.length,
          itemBuilder: (context, index) {
            final song = favoriteSongs[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: song.coverUrl != null
                    ? Image.network(song.coverUrl!, width: 48, height: 48, fit: BoxFit.cover)
                    : Container(width: 48, height: 48, color: Colors.grey),
              ),
              title: Text(song.title),
              subtitle: Text(song.artist),
              trailing: SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
                      },
                    ),
                    const Icon(Icons.play_arrow),
                  ],
                ),
              ),
              onTap: () {
                ref.read(playerProvider.notifier).playSong(song, favoriteSongs);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FullPlayerScreen(
                      song: song,
                      heroTag: 'fav-song-${song.id}',
                      playbackSource: PlaybackSource.song,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading songs')),
    );
  }
}

class _FavoriteRadiosList extends ConsumerWidget {
  const _FavoriteRadiosList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteStreamUrls = ref.watch(radioFavoritesProvider);
    final topStationsAsync = ref.watch(topRadioStationsProvider);
    final recentlyPlayedRadios = ref.watch(recentlyPlayedRadiosProvider);

    List<RadioStation> availableRadios = [...recentlyPlayedRadios];
    topStationsAsync.whenData((stations) => availableRadios.addAll(stations));

    final uniqueRadios = <String, RadioStation>{};
    for (var r in availableRadios) uniqueRadios[r.streamUrl] = r;

    final favoriteRadios = uniqueRadios.values.where((r) => favoriteStreamUrls.contains(r.streamUrl)).toList();

    if (favoriteRadios.isEmpty) {
      return const Center(child: Text('No favorite radios found'));
    }

    return ListView.builder(
      itemCount: favoriteRadios.length,
      itemBuilder: (context, index) {
        final station = favoriteRadios[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: station.imageUrl != null ? NetworkImage(station.imageUrl!) : null,
            child: station.imageUrl == null ? const Icon(Icons.radio) : null,
          ),
          title: Text(station.name),
          subtitle: Text(station.country),
          trailing: SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () {
                    ref.read(radioFavoritesProvider.notifier).toggleFavorite(station.streamUrl);
                  },
                ),
                const Icon(Icons.play_arrow),
              ],
            ),
          ),
          onTap: () {
            ref.read(playerProvider.notifier).playRadio(station);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FullPlayerScreen(
                  station: station,
                  heroTag: 'fav-radio-${station.id}',
                  playbackSource: PlaybackSource.radio,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
