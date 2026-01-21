import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

final _uploadsDir = Directory('uploads');

Future<void> ensureUploadsDirectory() async {
  if (!await _uploadsDir.exists()) {
    await _uploadsDir.create(recursive: true);
  }
  final songsDir = Directory('${_uploadsDir.path}/songs');
  final coversDir = Directory('${_uploadsDir.path}/covers');
  if (!await songsDir.exists()) await songsDir.create(recursive: true);
  if (!await coversDir.exists()) await coversDir.create(recursive: true);
}

Future<Map<String, dynamic>> _extractAudioMetadata(File file) async {
  try {
    final result = await Process.run('ffprobe', [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      file.path,
    ]);
    if (result.exitCode != 0) {
      return {'duration': 0, 'title': '', 'artist': '', 'album': '', 'genre': ''};
    }
    final data = jsonDecode(result.stdout as String);
    final format = data['format'] as Map<String, dynamic>? ?? {};
    final tags = format['tags'] as Map<String, dynamic>? ?? {};
    final duration = double.tryParse(format['duration']?.toString() ?? '') ?? 0;
    return {
      'duration': duration.round(),
      'title': tags['title'] ?? '',
      'artist': tags['artist'] ?? '',
      'album': tags['album'] ?? '',
      'genre': tags['genre'] ?? '',
    };
  } catch (_) {
    return {'duration': 0, 'title': '', 'artist': '', 'album': '', 'genre': ''};
  }
}

String _firstNonEmpty(dynamic a, String? b, dynamic c) {
  final aStr = (a ?? '').toString().trim();
  final bStr = (b ?? '').toString().trim();
  final cStr = (c ?? '').toString().trim();
  if (cStr.isNotEmpty) return cStr;
  if (bStr.isNotEmpty) return bStr;
  return aStr;
}

// void main(List<String> args) async {
//   final env = DotEnv(includePlatformEnvironment: true);
//   if (File('.env').existsSync()) env.load();

//   String ipStr = env['ADDRESS'] ?? Platform.environment['ADDRESS'] ?? '127.0.0.1';
//   int port = int.tryParse(env['PORT'] ?? Platform.environment['PORT'] ?? '') ?? 8080;

//   await ensureUploadsDirectory();

//   final app = Router();

//   app.options('/<ignored|.*>', (Request request) {
//     return Response.ok('', headers: _corsHeaders);
//   });

//   app.post('/upload/song', _handleSongUpload);
//   app.post('/upload/cover', _handleCoverUpload);
//   app.get('/health', (Request request) {
//     return Response.ok('Server is running', headers: _corsHeaders);
//   });

//   final handler = const Pipeline()
//       .addMiddleware(logRequests())
//       .addMiddleware(_corsMiddleware)
//       .addHandler(app);

//   final staticHandler = createStaticHandler(_uploadsDir.path);
//   app.mount('/files/', staticHandler);

//   final ip = ipStr == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(ipStr);

//   try {
//     final server = await io.serve(handler, ip, port);
//     print('Server running on http://${server.address.host}:${server.port}');
//   } catch (e) {
//     print('Failed to start server: $e');
//     exit(1);
//   }
// }



Future<File> _moveFile(File source, String destination) async {
  try {
    return await source.rename(destination);
  } on FileSystemException {
    final destFile = await source.copy(destination);
    await source.delete();
    return destFile;
  }
}

Future<String> _readFormDataAsString(FormData formData) async {
  final bytes = <int>[];
  await for (final chunk in formData.part) {
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

Future<File> writeFormDataToFile(FormData formData, String filePath) async {
  final file = File(filePath);
  final sink = file.openWrite();
  await for (final chunk in formData.part) {
    sink.add(chunk);
  }
  await sink.close();
  return file;
}

Future<Response> handleCoverUpload(Request request) async {
  try {
    String? userId;
    String? coverFileName;
    File? tempCoverFile;

    if (request.formData() case var form?) {
      await for (final formData in form.formData) {
        final fieldName = formData.name;

        if (fieldName == 'userId') {
          userId = (await _readFormDataAsString(formData)).trim();
        } else if (fieldName == 'file') {
          coverFileName = formData.filename ?? 'cover_${DateTime.now().millisecondsSinceEpoch}';
          final tempPath = path.join(
              Directory.systemTemp.path, 'upload_cover_${DateTime.now().microsecondsSinceEpoch}');
          tempCoverFile = await writeFormDataToFile(formData, tempPath);
        }
      }
    } else {
      return Response.badRequest(body: 'Expected multipart/form-data');
    }

    if (userId == null || coverFileName == null || tempCoverFile == null) {
      await tempCoverFile?.delete();
      return Response.badRequest(body: 'Missing required fields');
    }

    final userDir = Directory(path.join(_uploadsDir.path, 'covers', userId));
    await userDir.create(recursive: true);

    final outPath = path.join(userDir.path, coverFileName);
    await _moveFile(tempCoverFile, outPath);

    return Response.ok(
      jsonEncode({'coverUrl': '/files/covers/$userId/$coverFileName'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('Cover upload error: $e');
    return Response.internalServerError(body: 'Error processing file upload');
  }
}

Future<Response> handleSongUpload(Request request) async {
  try {
    String? userId;
    String? songFileName;
    File? tempSongFile;
    File? tempCoverFile;
    String? coverFileName;
    String? providedTitle;
    String? providedArtist;
    String? providedAlbum;
    String? providedGenre;

    if (request.formData() case var form?) {
      await for (final formData in form.formData) {
        final fieldName = formData.name;

        if (formData.filename == null) {
          final value = (await _readFormDataAsString(formData)).trim();
          switch (fieldName) {
            case 'userId':
              userId = value;
            case 'title':
              providedTitle = value;
            case 'artist':
              providedArtist = value;
            case 'album':
              providedAlbum = value;
            case 'genre':
              providedGenre = value;
          }
        } else {
          if (fieldName == 'file') {
            songFileName = formData.filename ?? 'song_${DateTime.now().millisecondsSinceEpoch}';
            final tempPath = path.join(
                Directory.systemTemp.path, 'upload_song_${DateTime.now().microsecondsSinceEpoch}');
            tempSongFile = await writeFormDataToFile(formData, tempPath);
          } else if (fieldName == 'cover') {
            coverFileName = formData.filename ?? 'cover_${DateTime.now().millisecondsSinceEpoch}';
            final tempPath = path.join(
                Directory.systemTemp.path, 'upload_cover_${DateTime.now().microsecondsSinceEpoch}');
            tempCoverFile = await writeFormDataToFile(formData, tempPath);
          }
        }
      }
    } else {
      return Response.badRequest(body: 'Expected multipart/form-data');
    }

    if (userId == null || songFileName == null || tempSongFile == null) {
      await tempSongFile?.delete();
      await tempCoverFile?.delete();
      return Response.badRequest(body: 'Missing required fields');
    }

    final userSongsDir = Directory(path.join(_uploadsDir.path, 'songs', userId));
    await userSongsDir.create(recursive: true);

    final finalSongPath = path.join(userSongsDir.path, songFileName);
    await _moveFile(tempSongFile, finalSongPath);
    final songFile = File(finalSongPath);

    String? finalCoverUrl;
    if (tempCoverFile != null && coverFileName != null) {
      final coversDir = Directory(path.join(_uploadsDir.path, 'covers', userId));
      await coversDir.create(recursive: true);
      final finalCoverPath = path.join(coversDir.path, coverFileName);
      await _moveFile(tempCoverFile, finalCoverPath);
      finalCoverUrl = '/files/covers/$userId/$coverFileName';
    }

    final metaFile = File('$finalSongPath.meta.json');
    Map<String, dynamic> existingMeta = {};
    if (await metaFile.exists()) {
      try {
        existingMeta = jsonDecode(await metaFile.readAsString());
      } catch (_) {}
    }

    final extracted = await _extractAudioMetadata(songFile);
    
    final merged = {
      'duration': existingMeta['duration'] ?? extracted['duration'] ?? 0,
      'title': _firstNonEmpty(existingMeta['title'], providedTitle, extracted['title']),
      'artist': _firstNonEmpty(existingMeta['artist'], providedArtist, extracted['artist']),
      'album': _firstNonEmpty(existingMeta['album'], providedAlbum, extracted['album']),
      'genre': _firstNonEmpty(existingMeta['genre'], providedGenre, extracted['genre']),
    };

    print(extracted["title"]);

    await metaFile.writeAsString(jsonEncode(merged));

    return Response.ok(
      jsonEncode({
        'url': '/files/songs/$userId/$songFileName',
        'coverUrl': finalCoverUrl,
        'metadata': merged,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('Song upload error: $e');
    return Response.internalServerError(body: 'Error processing song upload');
  }
}