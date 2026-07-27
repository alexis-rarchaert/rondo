import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Storage {
  static const _key = 'tournee_data_v1';

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppData.empty();
    try {
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppData.empty();
    }
  }

  static Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }
}
