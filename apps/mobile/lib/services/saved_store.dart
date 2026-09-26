import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/discovery_models.dart';

/// Local library of saved analyses. Persisted on-device; when the saved item
/// came from the discovery feed, Save also records a backend `save`
/// interaction (genuine user signal, never inflated).
class SavedStore extends ChangeNotifier {
  static const _key = 'virello_saved_analyses';
  List<PostAnalysisResult> items = [];

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        items = (jsonDecode(raw) as List)
            .map((e) => PostAnalysisResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      items = [];
    }
    notifyListeners();
  }

  bool contains(String url) => items.any((e) => e.url == url);

  Future<void> save(PostAnalysisResult r) async {
    items.removeWhere((e) => e.url == r.url);
    items.insert(0, r);
    if (items.length > 100) items = items.sublist(0, 100);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> remove(String url) async {
    items.removeWhere((e) => e.url == url);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}
