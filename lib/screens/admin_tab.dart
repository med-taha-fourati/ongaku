import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/song_provider.dart';
import '../models/song_model.dart';
import '../widgets/song_tile.dart';
import '../widgets/upload_song_form.dart';

class AdminTab extends ConsumerStatefulWidget {
  const AdminTab({super.key});

  @override
  ConsumerState<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends ConsumerState<AdminTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingSongsAsync = ref.watch(pendingSongsProvider);
    final approvedSongsAsync = ref.watch(approvedSongsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              _buildSectionHeader('Pending Songs'),
              pendingSongsAsync.when(
                data: (songs) {
                  final filteredSongs = _filterSongs(songs);
                  if (filteredSongs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('No pending songs matching search')),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSongItem(filteredSongs[index], isPending: true),
                      childCount: filteredSongs.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
              ),
              const SliverToBoxAdapter(child: Divider(height: 32)),
              _buildSectionHeader('All Songs'),
              approvedSongsAsync.when(
                data: (songs) {
                  final filteredSongs = _filterSongs(songs);
                  if (filteredSongs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('No songs matching search')),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSongItem(filteredSongs[index], isPending: false),
                      childCount: filteredSongs.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<SongModel> _filterSongs(List<SongModel> songs) {
    if (_searchQuery.isEmpty) return songs;
    return songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery) ||
          song.artist.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildSongItem(SongModel song, {required bool isPending}) {
    return SongTile(
      song: song,
      onTap: () => _showEditSongDialog(context, ref, song),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () async {
                final repository = ref.read(songRepositoryProvider);
                await repository.updateSongStatus(song.id, SongStatus.approved);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song approved')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            tooltip: 'Edit',
            onPressed: () => _showEditSongDialog(context, ref, song),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _showDeleteConfirmDialog(context, ref, song),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSongDialog(BuildContext context, WidgetRef ref, SongModel song) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: UploadSongForm(
            mode: UploadSongFormMode.edit,
            initialSong: song,
            onCompleted: () {
              Navigator.of(context).pop();
              ref.invalidate(pendingSongsProvider);
              ref.invalidate(approvedSongsProvider);
              ref.invalidate(userSongsProvider(song.uploadedBy));
            },
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, SongModel song) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure you want to delete this song request entirely?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                Navigator.of(context).pop();
                final repository = ref.read(songRepositoryProvider);
                try {
                  await repository.deleteSongMedia(song.audioUrl);
                } catch (_) {}
                await repository.deleteSong(song.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song request deleted')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}