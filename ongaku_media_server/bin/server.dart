import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:mime/mime.dart';

// Configuration
const _port = 8080;
final _uploadsDir = Directory('uploads');

Future<void> _ensureUploadsDirectory() async {
  if (!await _uploadsDir.exists()) {
    await _uploadsDir.create(recursive: true);
  }

  final songsDir = Directory('${_uploadsDir.path}/songs');
  final coversDir = Directory('${_uploadsDir.path}/covers');
  
  if (!await songsDir.exists()) await songsDir.create(recursive: true);
  if (!await coversDir.exists()) await coversDir.create(recursive: true);
}

void main(List<String> args) async {
  await _ensureUploadsDirectory();

  final app = Router();

  final corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  app.options('/<ignored|.*>', (Request request) {
    return Response.ok('', headers: corsHeaders);
  });

  // Upload song
  app.post('/upload/song', (Request request) async {
    return _handleFileUpload(request, 'songs');
  });

  // Upload cover
  app.post('/upload/cover', (Request request) async {
    return _handleFileUpload(request, 'covers');
  });

  // Health check endpoint
  app.get('/health', (Request request) {
    return Response.ok('Server is running', headers: corsHeaders);
  });

  // CORS headers middleware
  Middleware corsMiddleware = (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
      });
    };
  };

  // Handle all requests with the router
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware)
      .addHandler(app);

  // Serve static files using shelf_static which supports Range requests
  // This is crucial for media playback (seeking/streaming)
  final staticHandler = createStaticHandler(_uploadsDir.path);
  app.mount('/files/', staticHandler);

  final server = await io.serve(handler, InternetAddress.anyIPv4, _port);
  print('Server running on http://${server.address.host}:${server.port}');
  print('Connect using your local IP (e.g. 192.168.1.x)');
}

Future<Response> _handleFileUpload(Request request, String fileType) async {
  try {
    // Parse the multipart request
    final boundary = request.headers['content-type']?.split(';')[1].trim().split('=')[1];
    if (boundary == null) {
      return Response.badRequest(body: 'Invalid content type');
    }

    final stream = MimeMultipartTransformer(boundary).bind(request.read());
    String? userId;
    String? fileName;
    List<int> fileBytes = [];

    await for (final part in stream) {
      final contentDisposition = part.headers['content-disposition'] ?? '';
      
      if (contentDisposition.contains('name="file"') && part is MimeMultipart) {
        fileName = part.headers['filename'] ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
        fileBytes = await part.fold(<int>[], (List<int> previous, List<int> element) => previous..addAll(element));
      } else if (contentDisposition.contains('name="userId"') && part is MimeMultipart) {
        userId = await part.fold('', (String? previous, List<int> element) => (previous ?? '') + String.fromCharCodes(element));
      }
    }

    if (userId == null || fileName == null || fileBytes.isEmpty) {
      return Response.badRequest(body: 'Missing required fields');
    }

    // Create user directory if it doesn't exist
    final userDir = Directory(path.join(_uploadsDir.path, fileType, userId));
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    // Save the file
    final file = File(path.join(userDir.path, fileName));
    await file.writeAsBytes(fileBytes);

    // Return the file URL
    return Response.ok(
      jsonEncode({
        'url': '/files/$fileType/$userId/$fileName',
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    print('Error handling file upload: $e');
    return Response.internalServerError(body: 'Error processing file upload: $e');
  }
}
