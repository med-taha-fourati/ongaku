import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get mediaServerIp => dotenv.env['MEDIA_SERVER_IP'] ?? '10.0.2.2';
  static String get mediaServerPort => dotenv.env['MEDIA_SERVER_PORT'] ?? '8080';
  
  static String get mediaServerUrl => 'http://$mediaServerIp:$mediaServerPort';
}
