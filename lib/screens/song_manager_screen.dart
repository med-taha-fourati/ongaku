import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_model.dart';
import '../providers/song_provider.dart';
import '../repositories/song_repository.dart';
import '../widgets/upload_song_form.dart';

enum _SongSortField { likes, plays }

class SongManagementScreen extends ConsumerStatefulWidget {
  const SongManagementScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<SongManagementScreen> createState() => _SongManagementScreenState();
}

class _SongManagementScreenState extends ConsumerState<SongManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  _SongSortField _sortField = _SongSortField.likes;
  bool _ascending = false;
  String? _processingSongId;
  Timer? _debounce;
  String _searchQuery = '';

  List<SongModel> _sortedSongs(List<SongModel> songs) {
    final list = List<SongModel>.from(songs);
    list.sort((a, b) {
      int compare;
      switch (_sortField) {
        case _SongSortField.likes:
          compare = a.likeCount.compareTo(b.likeCount);
          break;
        case _SongSortField.plays:
          compare = a.playCount.compareTo(b.playCount);
          break;
      }
      return _ascending ? compare : -compare;
    });
    return list;
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

  Future<void> _openCreateSongSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: UploadSongForm(
            mode: UploadSongFormMode.create,
            onCompleted: () {
              Navigator.of(ctx).pop();
              ref.invalidate(userSongsProvider(widget.userId));
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditSongSheet(SongModel song) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: UploadSongForm(
            mode: UploadSongFormMode.edit,
            initialSong: song,
            onCompleted: () {
              Navigator.of(ctx).pop();
              ref.invalidate(userSongsProvider(widget.userId));
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSong(SongModel song) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete song'),
          content: Text(
            'Are you sure you want to delete "${song.title}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteSong(song);
    }
  }

  Future<void> _deleteSong(SongModel song) async {
    if (_processingSongId != null) {
      return;
    }

    setState(() {
      _processingSongId = song.id;
    });

    try {
      final repository = ref.read(songRepositoryProvider);
      await repository.deleteSong(song.id);

      try {
        await repository.deleteSongMedia(song.audioUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Song removed, but failed to delete file: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      ref.invalidate(userSongsProvider(widget.userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song deleted successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingSongId = null;
        });
      }
    }
  }

  Widget _buildSortControls() {
    String label;
    switch (_sortField) {
      case _SongSortField.likes:
        label = 'Sort by likes';
        break;
      case _SongSortField.plays:
        label = 'Sort by plays';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PopupMenuButton<_SongSortField>(
            initialValue: _sortField,
            onSelected: (value) {
              setState(() {
                _sortField = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _SongSortField.likes,
                child: Text('Likes'),
              ),
              const PopupMenuItem(
                value: _SongSortField.plays,
                child: Text('Plays'),
              ),
            ],
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.sort),
              label: Text(label),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: () {
              setState(() {
                _ascending = !_ascending;
              });
            },
            icon: Icon(
              _ascending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(SongModel song, bool isWide) {
    final isProcessing = _processingSongId == song.id;

    final trailing = isProcessing
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () {
                  _openEditSongSheet(song);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: () {
                  _confirmDeleteSong(song);
                },
              ),
            ],
          );

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (song.album.isNotEmpty)
          Text(
            song.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 16),
                const SizedBox(width: 4),
                Text('${song.likeCount}'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow, size: 16),
                const SizedBox(width: 4),
                Text('${song.playCount}'),
              ],
            ),
          ],
        ),
      ],
    );

    if (!isWide) {
      return ListTile(
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle,
        trailing: trailing,
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 8),
            subtitle,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(userSongsProvider(widget.userId));

    return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Song Management'),
    //   ),
      body: SafeArea(
        child: songsAsync.when(
          data: (songs) {
            if (songs.isEmpty) {
              return Column(
                children: [
                  _buildSortControls(),
                  const Expanded(
                    child: Center(
                      child: Text('No songs uploaded yet'),
                    ),
                  ),
                ],
              );
            }

            final sorted = _filterSongs(_sortedSongs(songs));

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isWide = width >= 600;
                final crossAxisCount = width >= 1024
                    ? 4
                    : width >= 800
                        ? 3
                        : 2;

                if (!isWide) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child:TextField(
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
                        ),
                      ),
                      ),
                      _buildSortControls(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final song = sorted[index];
                            return _buildSongItem(song, false);
                          },
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildSortControls(),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 4 / 3,
                        ),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final song = sorted[index];
                          return _buildSongItem(song, true);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load songs'),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(userSongsProvider(widget.userId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSongSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
