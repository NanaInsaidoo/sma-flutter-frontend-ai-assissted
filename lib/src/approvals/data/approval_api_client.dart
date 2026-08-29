import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/approval_models.dart';

class ApprovalApiClient {
  ApprovalApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<ApprovalInbox> getInbox(String schoolId) async {
    final response = await _send('GET', '/api/schools/$schoolId/approvals');
    return ApprovalInbox.fromJson(_map(response));
  }

  Future<ApprovalInbox> performAction({
    required String schoolId,
    required ApprovalItem item,
    required String action,
    String reason = '',
  }) async {
    final response = await _send(
      'POST',
      '/api/schools/$schoolId/approvals/${item.type}/${item.entityId}/actions',
      body: {
        'action': action,
        'reason': reason.trim(),
        'expectedStateToken': item.stateToken,
      },
    );
    return ApprovalInbox.fromJson(_map(response));
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken?.isNotEmpty != true) {
      throw const ApprovalApiException('Please sign in again to continue.');
    }
    Future<http.Response> send() {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      return method == 'POST'
          ? _client
                .post(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 15))
          : _client
                .get(uri, headers: headers)
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
      throw ApprovalApiException(_message(response), response.statusCode);
    } on TimeoutException {
      throw const ApprovalApiException(
        'Approvals took too long to load. Please try again.',
      );
    } on ApprovalApiException {
      rethrow;
    } catch (_) {
      throw const ApprovalApiException(
        'Unable to reach the approvals service right now.',
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
        return (value['message'] ?? value['error'] ?? 'Request failed.')
            .toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode}).';
  }
}

class ApprovalApiException implements Exception {
  const ApprovalApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  bool get isConflict => statusCode == 409;
  @override
  String toString() => message;
}
