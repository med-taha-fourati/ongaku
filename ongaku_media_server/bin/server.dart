import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import './ffmpeg_interop.dart';

import 'package:dotenv/dotenv.dart';

final _uploadsDir = Directory('uploads');

void main(List<String> args) async {
  final env = DotEnv(includePlatformEnvironment: true);
  if (File('.env').existsSync()) env.load();

  String ipStr = env['ADDRESS'] ?? Platform.environment['ADDRESS'] ?? '127.0.0.1';
  int port = int.tryParse(env['PORT'] ?? Platform.environment['PORT'] ?? '') ?? 8080;

  await ensureUploadsDirectory();

  final app = Router();

  app.options('/<ignored|.*>', (Request request) {
    return Response.ok('', headers: _corsHeaders);
  });

  app.post('/upload/song', handleSongUpload);
  app.post('/upload/cover', handleCoverUpload);
  app.get('/health', (Request request) {
    return Response.ok('Server is running', headers: _corsHeaders);
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addHandler(app);

  final staticHandler = createStaticHandler(_uploadsDir.path);
  app.mount('/files/', staticHandler);

  final ip = ipStr == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(ipStr);

  try {
    final server = await io.serve(handler, ip, port);
    print('Server running on http://${server.address.host}:${server.port}');
  } catch (e) {
    print('Failed to start server: $e');
    exit(1);
  }
}

Middleware _corsMiddleware = (inner) {
  return (request) async {
    final res = await inner(request);
    return res.change(headers: _corsHeaders);
  };
};

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};