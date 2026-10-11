import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/management_report_models.dart';

class ManagementReportApiClient implements ManagementReportRepository {
  ManagementReportApiClient({
    this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<List<ManagementReport>> list(String schoolId) async {
    final response = await _get(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}',
    );
    final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return (json['reports'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ManagementReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<int>> downloadPdf(
    String schoolId,
    int termId,
    String type,
  ) async {
    final response = await _get(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/term/$termId/${Uri.encodeComponent(type)}.pdf',
    );
    return response.bodyBytes;
  }

  Future<http.Response> _get(String path) async {
    Future<http.Response> go() => _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Accept': 'application/json, application/pdf',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      },
    );
    var response = await go();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      response = await go();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Reports could not be loaded.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = '${body['message']}';
        }
      } catch (_) {}
      throw Exception(message);
    }
    return response;
  }
}
