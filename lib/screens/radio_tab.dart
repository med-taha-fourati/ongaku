import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/radio_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/full_player_screen.dart';
import '../providers/player_provider.dart';
import '../repositories/radio_repository.dart';
import '../models/radio_station.dart';

class RadioTab extends ConsumerStatefulWidget {
  const RadioTab({super.key});

  @override
  ConsumerState<RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends ConsumerState<RadioTab> {
  final _searchController = TextEditingController();
  List<RadioStation>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final repository = ref.read(radioRepositoryProvider);
      final results = await repository.searchStations(_searchController.text.trim());
      setState(() => _searchResults = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topStationsAsync = ref.watch(topRadioStationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search radio stations...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.send),
                onPressed: _search,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(
          child: _searchResults != null
              ? _buildStationList(_searchResults!)
              : topStationsAsync.when(
            data: (stations) => _buildStationList(stations),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('Failed to load radio stations'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationList(List<RadioStation> stations) {
    if (stations.isEmpty) {
      return const Center(child: Text('No stations found'));
    }

    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        final isFavorite = ref.watch(favoritesProvider).contains(station.id);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: station.imageUrl != null
                ? NetworkImage(station.imageUrl!)
                : null,
            child: station.imageUrl == null
                ? const Icon(Icons.radio)
                : null,
          ),
          title: Text(station.name),
          subtitle: Text('${station.genre} • ${station.country}'),
          trailing: SizedBox(
             width: 100,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 IconButton(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    color: isFavorite ? Colors.red : null,
                    onPressed: () {
                       ref.read(favoritesProvider.notifier).toggleFavorite(station.id);
                    },
                 ),
                 const Icon(Icons.play_arrow),
               ],
             ),
          ),
          onTap: () async {
            try {
              ref.read(playerProvider.notifier).playRadio(station);
               Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullPlayerScreen(
                        station: station,
                        heroTag: 'radio-${station.id}',
                        playbackSource: PlaybackSource.radio,
                      ),
                    ),
               );

            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to play radio station')),
                );
              }
            }
          },
        );
      },
    );
  }
}