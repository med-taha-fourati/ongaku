import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/song_provider.dart';
import '../providers/player_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/radio_provider.dart';
import '../providers/active_room_provider.dart';
import '../models/song_model.dart';
import '../widgets/full_player_screen.dart';
import 'recommendations_screen.dart';

class SongsTab extends ConsumerStatefulWidget {
  const SongsTab({super.key});

  @override
  ConsumerState<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<SongsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      }
    });
  }

  List<SongModel> _filterSongs(List<SongModel> songs) {
    if (_searchQuery.isEmpty) return songs;
    return songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery) ||
          song.artist.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        
        // Removed TabBar and _FavoritesList
        Expanded(
           child: _AllSongsList(
             searchQuery: _searchQuery, 
             filterSongs: _filterSongs,
           ),
        ),
      ],
    );
  }
}

class _AllSongsList extends ConsumerWidget {
  final String searchQuery;
  final List<SongModel> Function(List<SongModel>) filterSongs;

  const _AllSongsList({
    required this.searchQuery,
    required this.filterSongs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(approvedSongsProvider);
    final trendingAsync = ref.watch(trendingSongsProvider);
    final recentlyPlayedRadios = ref.watch(recentlyPlayedRadiosProvider);
    final activeRoomId = ref.watch(activeRoomIdProvider);
    final isInRoom = activeRoomId != null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(approvedSongsProvider);
        ref.invalidate(trendingSongsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Only show Trending/Recommended/Radio if not searching
          if (searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trending Songs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RecommendationsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.recommend),
                      label: const Text('For You'),
                    ),
                  ],
                ),
              ),
            ),
            trendingAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No trending songs yet'),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return _TrendingSongCard(song: song, allSongs: songs);
                      },
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SliverToBoxAdapter(
                  child: Center(child: Text('Error loading trending'))),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            if (recentlyPlayedRadios.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recently Played Radios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    itemCount: recentlyPlayedRadios.length,
                    itemBuilder: (context, index) {
                      final radio = recentlyPlayedRadios[index];
                      return GestureDetector(
                        onTap: isInRoom
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Cannot play music while in a voice room'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            : () {
                                ref.read(playerProvider.notifier).playRadio(
                                      radio,
                                      fromRecentlyPlayed: true,
                                    );
                                // Open player
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullPlayerScreen(
                                      station: radio,
                                      heroTag: 'radio-${radio.id}',
                                    ),
                                  ),
                                );
                              },
                        child: Opacity(
                          opacity: isInRoom ? 0.5 : 1.0,
                          child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(40),
                                  image: radio.imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(radio.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: radio.imageUrl == null
                                    ? const Icon(Icons.radio, size: 40)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                radio.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

             SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'All Songs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
         
          songsAsync.when(
            data: (songs) {
              final filtered = filterSongs(songs);
              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No songs found')),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = filtered[index];
                    return _SongListItem(song: song, playlist: filtered);
                  },
                  childCount: filtered.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SliverFillRemaining(
                child: Center(child: Text('Failed to load songs'))),
          ),
        ],
      ),
    );
  }
}


class _SongListItem extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> playlist;

  const _SongListItem({required this.song, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(song.id);
    final activeRoomId = ref.watch(activeRoomIdProvider);
    final isInRoom = activeRoomId != null;

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          image: song.coverUrl != null
              ? DecorationImage(
                  image: NetworkImage(song.coverUrl!), fit: BoxFit.cover)
              : null,
          color: Colors.grey[300],
        ),
        child: song.coverUrl == null ? const Icon(Icons.music_note) : null,
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
        color: isFavorite ? Colors.red : null,
        onPressed: () {
          ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
        },
      ),
      enabled: !isInRoom,
      onTap: isInRoom
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot play music while in a voice room'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : () {
              ref.read(playerProvider.notifier).playSong(song, playlist);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullPlayerScreen(
                    song: song,
                    heroTag: 'song-${song.id}',
                  ),
                ),
              );
            },
    );
  }
}

class _TrendingSongCard extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> allSongs;

  const _TrendingSongCard({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoomId = ref.watch(activeRoomIdProvider);
    final isInRoom = activeRoomId != null;

    return GestureDetector(
      onTap: isInRoom
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot play music while in a voice room'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : () {
        ref.read(playerProvider.notifier).playSong(song, allSongs);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(
              song: song,
              heroTag: 'trending-${song.id}',
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isInRoom ? 0.5 : 1.0,
        child: Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'trending-${song.id}',
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: song.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.music_note, size: 48),
                        ),
                      )
                    : const Center(child: Icon(Icons.music_note, size: 48)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
