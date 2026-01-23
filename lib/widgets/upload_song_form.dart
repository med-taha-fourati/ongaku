import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_model.dart';
import '../providers/auth_provider.dart';
import '../providers/song_provider.dart';
import '../repositories/song_repository.dart';

enum UploadSongFormMode { create, edit }

class UploadSongForm extends ConsumerStatefulWidget {
  const UploadSongForm({
    super.key,
    required this.mode,
    this.initialSong,
    this.onCompleted,
  });

  final UploadSongFormMode mode;
  final SongModel? initialSong;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<UploadSongForm> createState() => _UploadSongFormState();
}

class _UploadSongFormState extends ConsumerState<UploadSongForm> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();
  File? _audioFile;
  File? _coverFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final song = widget.initialSong;
    if (song != null) {
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _albumController.text = song.album;
      _genreController.text = song.genre;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _coverFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();
    final genre = _genreController.text.trim();

    if (title.isEmpty || artist.isEmpty || genre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
        ),
      );
      return;
    }

    if (widget.mode == UploadSongFormMode.create && _audioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an audio file'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(songRepositoryProvider);

      if (widget.mode == UploadSongFormMode.create) {
        final user = await ref.read(currentUserProvider.future);
        if (user == null) {
          throw Exception('User not available');
        }

        final uploadResult = await repository.uploadSongWithMetadata(
          audioFile: _audioFile!,
          coverFile: _coverFile,
          userId: user.uid,
          title: title,
          artist: artist,
          album: album,
          genre: genre,
        );

        final audioUrl = uploadResult['audioUrl'] as String? ?? '';
        final coverUrl = uploadResult['coverUrl'] as String?;
        final metadata =
            (uploadResult['metadata'] ?? {}) as Map<String, dynamic>;
        final duration = (metadata['duration'] ?? 0) as int;
        final finalTitle = (metadata['title'] ?? title) as String? ?? title;
        final finalArtist =
            (metadata['artist'] ?? artist) as String? ?? artist;
        final finalAlbum = (metadata['album'] ?? album) as String? ?? album;
        final finalGenre = (metadata['genre'] ?? genre) as String? ?? genre;

        final song = SongModel(
          id: '',
          title: finalTitle,
          artist: finalArtist,
          genre: finalGenre,
          audioUrl: audioUrl,
          coverUrl: coverUrl,
          uploadedBy: user.uid,
          uploadedAt: DateTime.now(),
          status: user.isAdmin ? SongStatus.approved : SongStatus.pending,
          duration: duration,
          album: finalAlbum,
        );

        await repository.createSong(song);

        ref.invalidate(userSongsProvider(user.uid));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Song uploaded successfully! Waiting for approval.'),
            ),
          );
          _resetForm();
          widget.onCompleted?.call();
        }
      } else {
        final original = widget.initialSong;
        if (original == null) {
          throw Exception('No song to edit');
        }

        final hasNewAudio = _audioFile != null;

        if (!hasNewAudio &&
            title == original.title &&
            artist == original.artist &&
            album == original.album &&
            genre == original.genre) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No changes to save'),
              ),
            );
          }
          return;
        }

        if (!hasNewAudio) {
          await repository.updateSong(original.id, {
            'title': title,
            'artist': artist,
            'album': album,
            'genre': genre,
          });
        } else {
          final uploadResult = await repository.uploadSongWithMetadata(
            audioFile: _audioFile!,
            coverFile: null,
            userId: original.uploadedBy,
            title: title,
            artist: artist,
            album: album,
            genre: genre,
          );

          final audioUrl = uploadResult['audioUrl'] as String? ?? '';
          final metadata =
              (uploadResult['metadata'] ?? {}) as Map<String, dynamic>;
          final duration =
              (metadata['duration'] ?? original.duration) as int;
          final finalTitle =
              (metadata['title'] ?? title) as String? ?? title;
          final finalArtist =
              (metadata['artist'] ?? artist) as String? ?? artist;
          final finalAlbum =
              (metadata['album'] ?? album) as String? ?? album;
          final finalGenre =
              (metadata['genre'] ?? genre) as String? ?? genre;

          await repository.updateSong(original.id, {
            'title': finalTitle,
            'artist': finalArtist,
            'album': finalAlbum,
            'genre': finalGenre,
            'audioUrl': audioUrl,
            'duration': duration,
          });

          try {
            await repository.deleteSongMedia(original.audioUrl);
          } catch (_) {}
        }

        ref.invalidate(userSongsProvider(original.uploadedBy));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song updated successfully'),
            ),
          );
          widget.onCompleted?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _artistController.clear();
    _albumController.clear();
    _genreController.clear();
    setState(() {
      _audioFile = null;
      _coverFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == UploadSongFormMode.edit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Edit Song' : 'Upload Song',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _artistController,
            decoration: const InputDecoration(
              labelText: 'Artist *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _albumController,
            decoration: const InputDecoration(
              labelText: 'Album',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'Genre *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _pickAudioFile,
            icon: const Icon(Icons.audio_file),
            label: Text(
              _audioFile != null
                  ? 'Change Audio File'
                  : isEdit
                      ? 'Change Audio File'
                      : 'Select Audio File *',
            ),
          ),
          if (_audioFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selected: ${_audioFile!.path.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (!isEdit) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickCoverImage,
              icon: const Icon(Icons.image),
              label: Text(
                _coverFile != null
                    ? 'Change Cover Image'
                    : 'Add Cover Image',
              ),
            ),
            if (_coverFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected: ${_coverFile!.path.split('/').last}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Please wait...'),
                    ],
                  )
                : Text(isEdit ? 'Save Changes' : 'Upload Song'),
          ),
          const SizedBox(height: 8),
          const Text(
            '* Required fields',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
