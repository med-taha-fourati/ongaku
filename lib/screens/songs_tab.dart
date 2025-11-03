import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/song_provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/analytics_repository.dart';
import '../widgets/song_tile.dart';
import 'recommendations_screen.dart';

class SongsTab extends ConsumerWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(approvedSongsProvider);
    final trendingAsync = ref.watch(trendingSongsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(approvedSongsProvider);
        ref.invalidate(trendingSongsProvider);
      },
      child: CustomScrollView(
        slivers: [
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
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No trending songs yet'),
                    ),
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
                      return GestureDetector(
                        onTap: () {
                          ref.read(playerProvider.notifier).playSong(song, songs);
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: song.coverUrl != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 48),
                                  ),
                                )
                                    : const Center(child: Icon(Icons.music_note, size: 48)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
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
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SliverToBoxAdapter(
              child: Center(child: Text('Failed to load trending songs')),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'All Songs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          songsAsync.when(
            data: (songs) {
              if (songs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No songs available')),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final song = songs[index];
                    return SongTile(
                      song: song,
                      onTap: () {
                        ref.read(playerProvider.notifier).playSong(song, songs);
                      },
                    );
                  },
                  childCount: songs.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SliverFillRemaining(
              child: Center(child: Text('Failed to load songs')),
            ),
          ),
        ],
      ),
    );
  }
}