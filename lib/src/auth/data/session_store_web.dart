// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'auth_api_client.dart';

class SessionStore {
  static const _sessionKey = 'sma.auth.session';

  AuthSession? load() {
    final raw = html.window.localStorage[_sessionKey];
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = AuthSession.fromJson(decoded);
      if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
        return null;
      }
      return session;
    } catch (_) {
      clear();
      return null;
    }
  }

  void save(AuthSession session) {
    html.window.localStorage[_sessionKey] = jsonEncode(session.toJson());
  }

  void clear() {
    html.window.localStorage.remove(_sessionKey);
  }
}
