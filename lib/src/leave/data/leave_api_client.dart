import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/api_config.dart';

typedef LeaveJson = Map<String, dynamic>;

class LeaveApiClient {
  LeaveApiClient({
    required this.schoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String schoolId;
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  String get _base =>
      '${ApiConfig.baseUrl}/api/schools/${Uri.encodeComponent(schoolId)}/leave';

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Uint8List? bytes,
    String? filename,
    int? version,
  }) async {
    Future<http.Response> run() async {
      final uri = Uri.parse('$_base$path');
      final headers = {
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      };
      if (bytes != null) {
        final ext = filename!.split('.').last.toLowerCase();
        const types = {
          'pdf': 'application/pdf',
          'doc': 'application/msword',
          'docx':
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
        };
        final request = http.MultipartRequest(method, uri)
          ..headers.addAll(headers)
          ..fields['version'] = '$version'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: MediaType.parse(
                types[ext] ?? 'application/octet-stream',
              ),
            ),
          );
        return http.Response.fromStream(await _client.send(request));
      }
      final request = http.Request(method, uri)
        ..headers.addAll({...headers, 'Content-Type': 'application/json'});
      if (body != null) request.body = jsonEncode(body);
      return http.Response.fromStream(await _client.send(request));
    }

    var response = await run().timeout(const Duration(seconds: 35));
    if (response.statusCode == 401 && onRefreshAccessToken != null) {
      final token = await onRefreshAccessToken!();
      if (token != null) {
        accessToken = token;
        response = await run().timeout(const Duration(seconds: 35));
      }
    }
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? null
          : _normaliseDates(jsonDecode(response.body));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['message'] ?? decoded['detail'] ?? decoded['error']
          : null;
      throw LeaveApiException(
        message?.toString() ??
            'Unable to complete the leave request (${response.statusCode}). Please try again.',
        response.statusCode,
      );
    }
    return decoded;
  }

  // Spring can serialize java.time fields as ISO strings or component arrays.
  // Normalize once so list labels, date pickers and the audit timeline agree.
  static dynamic _normaliseDates(dynamic value, [String? field]) {
    const dates = {
      'startDate',
      'endDate',
      'actualEndDate',
      'proposedActualEndDate',
    };
    const timestamps = {
      'createdAt',
      'updatedAt',
      'submittedAt',
      'decidedAt',
      'occurredAt',
    };
    if (value is List &&
        (dates.contains(field) || timestamps.contains(field)) &&
        value.length >= 3 &&
        value.every((part) => part is num)) {
      int part(int index) =>
          index < value.length ? (value[index] as num).toInt() : 0;
      final nanos = part(6);
      final date = DateTime(
        part(0),
        part(1),
        part(2),
        part(3),
        part(4),
        part(5),
        nanos ~/ 1000000,
        (nanos % 1000000) ~/ 1000,
      );
      return dates.contains(field)
          ? date.toIso8601String().split('T').first
          : date.toIso8601String();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _normaliseDates(
            entry.value,
            entry.key.toString(),
          ),
      };
    }
    if (value is List) {
      return value.map((entry) => _normaliseDates(entry)).toList();
    }
    return value;
  }

  Future<LeaveJson> context() async =>
      Map<String, dynamic>.from(await _send('GET', '/context'));
  Future<LeaveJson> list({
    int? staffId,
    String? status,
    String? from,
    String? to,
    int page = 0,
    int size = 25,
    String sortBy = 'createdAt',
    String direction = 'desc',
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'sortBy': sortBy,
        'direction': direction,
        if (staffId != null) 'staffUserId': '$staffId',
        if (status != null) 'status': status,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ).query;
    return Map<String, dynamic>.from(await _send('GET', '?$query'));
  }

  Future<LeaveJson> detail(int id) async =>
      Map<String, dynamic>.from(await _send('GET', '/$id'));

  /// A month includes every overlapping request, not only the table's first page.
  Future<LeaveJson> calendar({
    required DateTime month,
    int? staffId,
    String? status,
  }) async {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final items = <LeaveJson>[];
    LeaveJson result = {};
    for (var page = 0; ; page++) {
      result = await list(
        staffId: staffId,
        status: status,
        from: first.toIso8601String().split('T').first,
        to: last.toIso8601String().split('T').first,
        page: page,
        size: 100,
        sortBy: 'id',
        direction: 'asc',
      );
      final rows = (result['items'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final total = (result['total'] as num).toInt();
      if (rows.isEmpty && items.length < total) {
        throw LeaveApiException(
          'The calendar changed while loading. Please refresh to load all requests.',
        );
      }
      items.addAll(rows);
      if (items.length >= total) break;
    }
    final unique = {for (final row in items) row['id']: row};
    if (unique.length != items.length) {
      throw LeaveApiException(
        'The calendar changed while loading. Please refresh to load all requests.',
      );
    }
    return {...result, 'items': unique.values.toList(), 'total': unique.length};
  }

  Future<LeaveJson> save(LeaveJson body, {int? id}) async =>
      Map<String, dynamic>.from(
        await _send(
          id == null ? 'POST' : 'PUT',
          id == null ? '' : '/$id',
          body: body,
        ),
      );
  Future<LeaveJson> action(
    LeaveJson request,
    String action,
    String comment,
  ) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/${request['id']}/actions',
      body: {
        'action': action,
        'comment': comment,
        'version': request['version'],
      },
    ),
  );
  Future<LeaveJson> requestChange(
    LeaveJson request, {
    required String type,
    DateTime? actualEndDate,
    required String reason,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/${request['id']}/change-requests',
      body: {
        'type': type,
        if (actualEndDate != null)
          'actualEndDate': actualEndDate.toIso8601String().split('T').first,
        'reason': reason,
        'version': request['version'],
      },
    ),
  );
  Future<LeaveJson> attach(
    LeaveJson request,
    String filename,
    Uint8List bytes,
  ) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/${request['id']}/attachment',
      bytes: bytes,
      filename: filename,
      version: request['version'] as int,
    ),
  );
  Future<LeaveJson> removeAttachment(LeaveJson request) async =>
      Map<String, dynamic>.from(
        await _send(
          'DELETE',
          '/${request['id']}/attachment?version=${request['version']}',
        ),
      );
  Future<String> attachmentUrl(int id) async =>
      (await _send('GET', '/$id/attachment'))['url'] as String;
  Future<List<LeaveJson>> balances(int staffId, int year) async =>
      (await _send('GET', '/staff/$staffId/balances?year=$year') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> setAllowance(int staffId, LeaveJson body) async {
    await _send('PUT', '/staff/$staffId/allowance', body: body);
  }
}

class LeaveApiException implements Exception {
  LeaveApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
