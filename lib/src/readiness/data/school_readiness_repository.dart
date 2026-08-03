import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/school_readiness.dart';

abstract interface class SchoolReadinessRepository {
  Future<SchoolReadiness> getReadiness(String customSchoolId);
}

class ApiSchoolReadinessRepository implements SchoolReadinessRepository {
  ApiSchoolReadinessRepository({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<SchoolReadiness> getReadiness(String customSchoolId) async {
    Future<http.Response> send() => _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/schools/$customSchoolId/readiness'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${accessToken?.trim() ?? ''}',
      },
    );

    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshed = await onRefreshAccessToken!();
      if (refreshed?.trim().isNotEmpty == true) {
        accessToken = refreshed!.trim();
        response = await send();
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SchoolReadinessException(
        'Readiness could not be loaded (${response.statusCode}).',
      );
    }
    return SchoolReadiness.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
}

class SchoolReadinessException implements Exception {
  const SchoolReadinessException(this.message);
  final String message;
  @override
  String toString() => message;
}
