import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/song_model.dart';
import '../providers/auth_provider.dart';
import '../providers/song_provider.dart';
import '../repositories/song_repository.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _genreController = TextEditingController();
  File? _audioFile;
  File? _coverFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
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

  Future<void> _uploadSong() async {
    if (_audioFile == null ||
        _titleController.text.isEmpty ||
        _artistController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final repository = ref.read(songRepositoryProvider);
      final user = ref.read(currentUserProvider).value!;

      final audioUrl = await repository.uploadSong(_audioFile!, user.uid);
      final coverUrl = _coverFile != null
          ? await repository.uploadCover(_coverFile!, user.uid)
          : null;

      final song = SongModel(
        id: '',  // Will be set by Firestore
        title: _titleController.text,
        artist: _artistController.text,
        genre: _genreController.text,
        audioUrl: audioUrl,
        coverUrl: coverUrl,
        uploadedBy: user.uid,
        uploadedAt: DateTime.now(),
        status: SongStatus.pending,
        playCount: 0,
        likeCount: 0,
        album: '',  // Optional album field
        duration: 0,  // Will be updated after upload
      );

      await repository.createSong(song);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song uploaded successfully! Waiting for approval.'),
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _artistController.clear();
    _genreController.clear();
    setState(() {
      _audioFile = null;
      _coverFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload Song',
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
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'Genre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isUploading ? null : _pickAudioFile,
            icon: const Icon(Icons.audio_file),
            label: Text(_audioFile != null ? 'Change Audio File' : 'Select Audio File *'),
          ),
          if (_audioFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selected: ${_audioFile!.path.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickCoverImage,
            icon: const Icon(Icons.image),
            label: Text(_coverFile != null ? 'Change Cover Image' : 'Add Cover Image'),
          ),
          if (_coverFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selected: ${_coverFile!.path.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isUploading ? null : _uploadSong,
            child: _isUploading
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
                      Text('Uploading...'),
                    ],
                  )
                : const Text('Upload Song'),
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