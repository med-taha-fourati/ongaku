import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/radio_station.dart';

class RadioRepository {
  static const String _baseUrl = 'https://de1.api.radio-browser.info/json';

  Future<List<RadioStation>> searchStations(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stations/byname/$query?limit=20'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => RadioStation.fromJson(json))
            .where((station) => station.streamUrl.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<RadioStation>> getTopStations() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stations/topvote/20'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => RadioStation.fromJson(json))
            .where((station) => station.streamUrl.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}