import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/radio_station.dart';

class RadioRepository {
  // if any of these fail, we're fucked
  static const List<String> _baseUrls = [
    'https://de1.api.radio-browser.info/json',
    'https://de2.api.radio-browser.info/json',
    'https://all.api.radio-browser.info/json',
  ];

  Future<dynamic> _fetchWithFallback(String endpoint) async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl$endpoint');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
      } catch (e) {
        continue;
      }
    }
    throw Exception('All radio API mirrors failed');
  }

  Future<List<RadioStation>> searchStations(String query) async {
    try {
      final List<dynamic> data = await _fetchWithFallback('/stations/byname/$query?limit=20');
      
      return data
          .map((json) => RadioStation.fromJson(json))
          .where((station) => station.streamUrl.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<RadioStation>> getTopStations() async {
    try {
      final List<dynamic> data = await _fetchWithFallback('/stations/topvote/20');

      return data
          .map((json) => RadioStation.fromJson(json))
          .where((station) => station.streamUrl.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<RadioStation?> getStationByStreamUrl(String streamUrl) async {
    if (streamUrl.trim().isEmpty) return null;
    try {
      final encoded = Uri.encodeComponent(streamUrl.trim());
      final List<dynamic> data = await _fetchWithFallback('/stations/byurl/$encoded');
      final stations = data
          .map((json) => RadioStation.fromJson(json))
          .where((s) => s.streamUrl.isNotEmpty)
          .toList();
      if (stations.isEmpty) return null;
      final exact = stations.where((s) => s.streamUrl == streamUrl).toList();
      return exact.isNotEmpty ? exact.first : stations.first;
    } catch (e) {
      return null;
    }
  }
}