import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/radio_repository.dart';
import '../models/radio_station.dart';

final radioRepositoryProvider = Provider((ref) => RadioRepository());

final topRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final repository = ref.watch(radioRepositoryProvider);
  return await repository.getTopStations();
});