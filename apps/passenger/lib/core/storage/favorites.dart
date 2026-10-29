import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  final String label;
  final String address;
  final double lat;
  final double lng;
  const SavedPlace({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        label: j['label'] as String? ?? '',
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

class FavoritesStorage {
  static const _key = 'qadam_favorites_v1';
  static const _recent = 'qadam_recent_v1';

  Future<List<SavedPlace>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map>()
        .map((e) => SavedPlace.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> saveFavorite(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getFavorites();
    final filtered = current.where((p) => p.address != place.address).toList();
    filtered.insert(0, place);
    await prefs.setString(
        _key, jsonEncode(filtered.take(10).map((e) => e.toJson()).toList()));
  }

  Future<List<SavedPlace>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recent);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map>()
        .map((e) => SavedPlace.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> addRecent(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecent();
    final filtered = current
        .where((p) => p.address != place.address && p.label != place.label)
        .toList();
    filtered.insert(0, place);
    await prefs.setString(
        _recent, jsonEncode(filtered.take(8).map((e) => e.toJson()).toList()));
  }
}
