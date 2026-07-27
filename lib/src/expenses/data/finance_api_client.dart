import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// HTTP boundary for the finance workflow service.
///
/// The workflow controller consistently returns an `ApiResponse` envelope.
/// This client unwraps its `data` value so presentation code only deals with
/// the domain payload returned by the server.
class FinanceApiClient {
  FinanceApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    return _send('POST', path, body: body, query: query);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    return _send('PUT', path, body: body, query: query);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) {
    return _send('DELETE', path, query: query);
  }

  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': contentType},
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FinanceApiException(
          'The receipt file could not be uploaded.',
        );
      }
    } on TimeoutException {
      throw const FinanceApiException(
        'The receipt upload took too long. Please try again.',
      );
    } on FinanceApiException {
      rethrow;
    } catch (_) {
      throw const FinanceApiException(
        'The receipt file could not be uploaded.',
      );
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const FinanceApiException('Please sign in again to continue.');
    }

    Future<http.Response> request() {
      final base = Uri.parse('${ApiConfig.baseUrl}$path');
      final uri = query == null || query.isEmpty
          ? base
          : base.replace(queryParameters: {...base.queryParameters, ...query});
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    }

    try {
      var response = await request();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final token = await onRefreshAccessToken!.call();
        if (token != null && token.isNotEmpty) {
          accessToken = token;
          response = await request();
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FinanceApiException(_message(response));
      }

      final raw = response.body.trim();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['success'] == false) {
          throw FinanceApiException(
            '${decoded['message'] ?? 'The finance request was not accepted.'}',
          );
        }
        if (decoded.containsKey('data')) return decoded['data'];
      }
      return decoded;
    } on TimeoutException {
      throw const FinanceApiException(
        'The finance service took too long to respond. Please try again.',
      );
    } on FinanceApiException {
      rethrow;
    } catch (_) {
      throw const FinanceApiException(
        'Unable to reach the finance service right now.',
      );
    }
  }

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Use the status-specific message below.
    }
    return switch (response.statusCode) {
      401 || 403 => 'Your session has expired. Please sign in again.',
      404 => 'The requested finance record could not be found.',
      >= 500 => 'The finance service is having trouble. Please try again.',
      _ => 'Could not complete the finance request.',
    };
  }
}

class FinanceApiException implements Exception {
  const FinanceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
