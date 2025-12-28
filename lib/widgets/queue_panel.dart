import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/queued_song_model.dart';
import '../models/song_model.dart';
import '../providers/room_provider.dart';
import '../repositories/song_repository.dart';
import '../repositories/room_repository.dart';

class QueuePanel extends ConsumerStatefulWidget {
  final String roomId;
  final bool isHost;

  const QueuePanel({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<SongModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    // Using existing SongRepository (assuming it has search or we fetch trending)
    // For now filtering trending songs as a simple search implementation
    // Ideally update SongRepository with a proper search method
    try {
      final repository = SongRepository();
      final songs = await repository.getTrendingSongs(); 
      setState(() {
        _searchResults = songs.where((s) => 
          s.title.toLowerCase().contains(query.toLowerCase()) || 
          s.artist.toLowerCase().contains(query.toLowerCase())
        ).toList();
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _requestSong(SongModel song) {
    if (widget.isHost) {
      ref.read(roomRepositoryProvider).addSongToQueue(
        roomId: widget.roomId,
        songId: song.id,
        title: song.title,
        artist: song.artist,
        durationMs: 0, // Should be actual duration
        addedBy: 'Host', // Should get current user name
      );
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song added to queue')),
      );
    } else {
      ref.read(roomRepositoryProvider).requestSong(
        roomId: widget.roomId,
        songId: song.id,
        title: song.title,
        artist: song.artist,
        durationMs: 0, // Should be actual duration
        requestedBy: 'User', // Should get current user name
      );
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song requested')),
      );
    }
    
    _searchController.clear();
    setState(() => _searchResults = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Up Next'),
            Tab(text: 'Requests'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQueueList(),
              _buildRequestTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQueueList() {
    final queueAsync = ref.watch(masterQueueProvider(widget.roomId));

    return queueAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(child: Text('Queue is empty'));
        }

        if (widget.isHost) {
          return ReorderableListView.builder(
            itemCount: songs.length,
            onReorder: (oldIndex, newIndex) {
               // Update queue order via repository
               if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = songs.removeAt(oldIndex);
              songs.insert(newIndex, item);
              
              // Update positions locally then save
              for (var i = 0; i < songs.length; i++) {
                // clone with new position
              }
              // Call repo update
              ref.read(roomRepositoryProvider).updateMasterQueue(
                roomId: widget.roomId,
                songs: songs, // Need to update positions first
              );
            },
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                key: ValueKey(song.songId),
                title: Text(song.title),
                subtitle: Text(song.artist),
                trailing: const Icon(Icons.drag_handle),
              );
            },
          );
        } else {
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load queue')),
    );
  }

  Widget _buildRequestTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search songs to request...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  )
                : null,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final song = _searchResults[index];
                return ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(song.title),
                  subtitle: Text(song.artist),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _requestSong(song),
                  ),
                );
              },
            ),
          )
        else
          Expanded(
            child: _buildRequestsList(),
          ),
      ],
    );
  }

  Widget _buildRequestsList() {
    final requestsAsync = ref.watch(songRequestsProvider(widget.roomId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No pending requests.\nSearch above to request a song!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return ListTile(
              title: Text(request.title),
              subtitle: Text('${request.artist} • Requested by ${request.requestedBy}'),
              trailing: widget.isHost
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            ref.read(roomRepositoryProvider).approveRequest(
                              roomId: widget.roomId,
                              requestId: request.id,
                              request: request,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            ref.read(roomRepositoryProvider).rejectRequest(
                              roomId: widget.roomId,
                              requestId: request.id,
                            );
                          },
                        ),
                      ],
                    )
                  : const Chip(label: Text('Pending')),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load requests')),
    );
  }
}
