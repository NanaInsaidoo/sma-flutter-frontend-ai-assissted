import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/data_export_models.dart';
import '../domain/management_report_models.dart';

class ManagementReportApiClient
    implements ManagementReportRepository, DataExportRepository {
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

  @override
  Future<DataExportOptions> dataExportOptions(String schoolId) async {
    final response = await _get(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/data-exports/options',
    );
    return DataExportOptions.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  @override
  Future<List<DataExportHistoryItem>> dataExportHistory(String schoolId) async {
    final response = await _get(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/data-exports',
    );
    return (jsonDecode(response.body) as List? ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              DataExportHistoryItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<DataExportPreview> previewDataExport(
    String schoolId,
    DataExportRequest request,
  ) async {
    final response = await _post(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/data-exports/preview',
      request.toJson(),
    );
    return DataExportPreview.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  @override
  Future<DataExportDownload> createDataExport(
    String schoolId,
    DataExportRequest request,
  ) async {
    final response = await _post(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/data-exports',
      request.toJson(),
      accept: 'application/zip',
    );
    return DataExportDownload(
      fileName: _fileName(response, 'school-analysis-data.zip'),
      bytes: response.bodyBytes,
    );
  }

  @override
  Future<DataExportDownload> downloadDataExport(
    String schoolId,
    int exportId,
    String fileName,
  ) async {
    final response = await _get(
      '/api/v2/management-reports/school/${Uri.encodeComponent(schoolId)}/data-exports/$exportId.zip',
      accept: 'application/zip',
    );
    return DataExportDownload(
      fileName: _fileName(response, fileName),
      bytes: response.bodyBytes,
    );
  }

  Future<http.Response> _get(
    String path, {
    String accept = 'application/json, application/pdf',
  }) async {
    Future<http.Response> go() => _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Accept': accept,
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

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String accept = 'application/json',
  }) async {
    Future<http.Response> go() => _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Accept': accept,
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    var response = await go();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      response = await go();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'The data export could not be prepared.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = '${decoded['message']}';
        }
      } catch (_) {}
      throw Exception(message);
    }
    return response;
  }

  String _fileName(http.Response response, String fallback) {
    final disposition = response.headers['content-disposition'] ?? '';
    final quoted = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    if (quoted != null) return quoted.group(1)!;
    final plain = RegExp(r'filename=([^;]+)').firstMatch(disposition);
    return plain?.group(1)?.trim() ?? fallback;
  }
}
