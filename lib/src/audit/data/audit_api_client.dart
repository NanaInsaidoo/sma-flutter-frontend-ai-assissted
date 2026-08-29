import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/audit_models.dart';

class AuditApiClient {
  AuditApiClient({
    this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<AuditLogPage> getAuditLogs({
    int page = 0,
    int size = 20,
    String? search,
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
    String? scopeKey,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (actionType?.trim().isNotEmpty == true)
        'actionType': actionType!.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (scopeKey?.trim().isNotEmpty == true) 'scopeKey': scopeKey!.trim(),
    };
    final response = await _get('/api/audit-logs', query);
    return AuditLogPage.fromJson(_map(response));
  }

  Future<AuditStatistics> getStatistics({
    String? scopeKey,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _get('/api/audit-logs/statistics', {
      if (scopeKey?.trim().isNotEmpty == true) 'scopeKey': scopeKey!.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    });
    return AuditStatistics.fromJson(_map(response));
  }

  Future<List<AuditScopeOption>> getScopes() async {
    final response = await _get('/api/audit-logs/scopes', const {});
    if (response.body.trim().isEmpty) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((value) => AuditScopeOption.fromJson(value.cast()))
        .where((value) => value.value.isNotEmpty)
        .toList();
  }

  Future<http.Response> _get(String path, Map<String, String> query) async {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final uri = base.replace(queryParameters: query.isEmpty ? null : query);
    var response = await _client.get(uri, headers: _headers);
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshed = await onRefreshAccessToken!();
      if (refreshed?.trim().isNotEmpty == true) {
        accessToken = refreshed!.trim();
        response = await _client.get(uri, headers: _headers);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuditApiException(_responseMessage(response));
    }
    return response;
  }

  Map<String, String> get _headers {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const AuditApiException('Please sign in again to continue.');
    }
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _map(http.Response response) {
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  String _responseMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        for (final key in ['message', 'error', 'detail']) {
          final value = body[key]?.toString().trim();
          if (value?.isNotEmpty == true) return value!;
        }
      }
    } catch (_) {
      // Fall through to the stable message below.
    }
    return 'Audit activity could not be loaded (${response.statusCode}).';
  }
}

class AuditApiException implements Exception {
  const AuditApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
