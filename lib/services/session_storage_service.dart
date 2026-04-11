import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class SessionStorageService {
  SessionStorageService._();

  static const _sessionKey = 'saved_user_session';

  static Future<void> saveSession(UserSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<UserSession?> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(_sessionKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }

      return UserSession.fromJson(decoded);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  static Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
