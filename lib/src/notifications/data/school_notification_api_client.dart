import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/school_notification_models.dart';

class SchoolNotificationApiClient {
  SchoolNotificationApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<SchoolNotificationInbox> getInbox(String schoolId) async {
    final response = await _send('GET', '/api/schools/$schoolId/notifications');
    return SchoolNotificationInbox.fromJson(_map(response));
  }

  Future<SchoolNotificationItem> markRead({
    required String schoolId,
    required int notificationId,
  }) async {
    final response = await _send(
      'POST',
      '/api/schools/$schoolId/notifications/$notificationId/read',
    );
    return SchoolNotificationItem.fromJson(_map(response));
  }

  Future<http.Response> _send(String method, String path) async {
    if (accessToken?.isNotEmpty != true) {
      throw const SchoolNotificationApiException(
        'Please sign in again to continue.',
      );
    }
    Future<http.Response> send() {
      final headers = {'Authorization': 'Bearer $accessToken'};
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      return (method == 'POST'
              ? _client.post(uri, headers: headers)
              : _client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 15));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final token = await onRefreshAccessToken!.call();
        if (token?.isNotEmpty == true) {
          accessToken = token;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw SchoolNotificationApiException(_message(response));
    } on TimeoutException {
      throw const SchoolNotificationApiException(
        'Notifications took too long to load. Please try again.',
      );
    } on SchoolNotificationApiException {
      rethrow;
    } catch (_) {
      throw const SchoolNotificationApiException(
        'Unable to load notifications right now.',
      );
    }
  }

  Map<String, dynamic> _map(http.Response response) {
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  String _message(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map) {
        return '${value['message'] ?? value['error'] ?? 'Request failed.'}';
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode}).';
  }
}

class SchoolNotificationApiException implements Exception {
  const SchoolNotificationApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
