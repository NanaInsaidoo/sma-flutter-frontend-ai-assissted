import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/incident_models.dart';

class IncidentApiException implements Exception {
  const IncidentApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class IncidentApiClient {
  IncidentApiClient({
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String customSchoolId;
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<IncidentTermContext> getCurrentTerm() async {
    final response = await _send('GET', '/api/v1/current-term/$customSchoolId');
    return IncidentTermContext.fromJson(_object(response));
  }

  Future<IncidentDashboardStats> getStats() async {
    final response = await _send(
      'GET',
      _path('/api/v1/incidents/dashboard/stats'),
    );
    return IncidentDashboardStats.fromJson(_object(response));
  }

  Future<IncidentPage> getIncidents({
    int page = 0,
    int size = 10,
    String? status,
    String? severity,
  }) async {
    final response = await _send(
      'GET',
      _path('/api/v1/incidents', {
        'page': '$page',
        'size': '$size',
        'sort': 'incidentDateTime,desc',
        if (status?.isNotEmpty == true) 'status': status!,
        if (severity?.isNotEmpty == true) 'severity': severity!,
      }),
    );
    return IncidentPage.fromJson(_object(response));
  }

  Future<IncidentRecord> getIncident(String incidentId) async {
    final response = await _send('GET', _path('/api/v1/incidents/$incidentId'));
    return IncidentRecord.fromJson(_object(response));
  }

  Future<List<IncidentLookup>> getReference(String type) async {
    final response = await _send(
      'GET',
      '/api/v1/incidents/reference-data/$type',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => IncidentLookup.fromJson(item.cast()))
        .toList();
  }

  Future<IncidentRecord> create(Map<String, dynamic> body) async {
    final response = await _send(
      'POST',
      _path('/api/v1/incidents'),
      body: body,
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> update(
    String incidentId,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      'PUT',
      _path('/api/v1/incidents/$incidentId'),
      body: body,
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> updateStatus(
    String incidentId,
    String status,
    String note,
  ) async {
    final response = await _send(
      'PATCH',
      _path('/api/v1/incidents/$incidentId/status'),
      body: {'newStatus': status, 'note': note},
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> addComment(
    String incidentId,
    String note,
    String type, {
    String? parentUpdateId,
    List<IncidentMention> mentions = const [],
  }) async {
    final response = await _send(
      'POST',
      _path('/api/v1/incidents/$incidentId/comments'),
      body: {
        'note': note,
        'type': type,
        if (parentUpdateId?.isNotEmpty == true)
          'parentUpdateId': parentUpdateId,
        'mentions': mentions
            .map(
              (mention) => {
                'personId': mention.id,
                'personType': mention.personType,
                'name': mention.name,
              },
            )
            .toList(),
      },
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> escalate(
    String incidentId, {
    required String severity,
    required String escalatedBy,
    required String escalatedTo,
    required String reason,
  }) async {
    final response = await _send(
      'PATCH',
      _path('/api/v1/incidents/$incidentId/escalate'),
      body: {
        'newSeverity': severity,
        'escalatedBy': escalatedBy,
        'escalatedTo': escalatedTo,
        'reason': reason,
      },
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> addPerson(
    String incidentId,
    IncidentPerson person,
  ) async {
    final response = await _send(
      'POST',
      _path('/api/v1/incidents/$incidentId/people'),
      body: person.toJson(),
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> removePerson(String incidentId, int id) async {
    final response = await _send(
      'DELETE',
      _path('/api/v1/incidents/$incidentId/people/$id'),
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> addAction(
    String incidentId, {
    required IncidentLookup type,
    required String description,
  }) async {
    final response = await _send(
      'POST',
      _path('/api/v1/incidents/$incidentId/actions'),
      body: {
        'actionTypeId': type.id,
        'actionTypeName': type.name,
        'description': description,
      },
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> removeAction(String incidentId, int id) async {
    final response = await _send(
      'DELETE',
      _path('/api/v1/incidents/$incidentId/actions/$id'),
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<IncidentRecord> updateAction(
    String incidentId, {
    required int actionId,
    required IncidentLookup type,
    required String description,
  }) async {
    final response = await _send(
      'PUT',
      _path('/api/v1/incidents/$incidentId/actions/$actionId'),
      body: {
        'actionTypeId': type.id,
        'actionTypeName': type.name,
        'description': description,
      },
    );
    return IncidentRecord.fromJson(_object(response));
  }

  Future<List<IncidentRecord>> getRelatedIncidents(
    String incidentId,
    String personId,
  ) async {
    if (personId.isEmpty) return const [];
    final page = await getIncidents(size: 100);
    return page.items
        .where(
          (incident) =>
              incident.incidentId != incidentId &&
              incident.people.any((person) => person.personId == personId),
        )
        .take(4)
        .toList(growable: false);
  }

  Future<List<IncidentMention>> searchMentions(String searchTerm) async {
    final query = searchTerm.trim();
    if (query.length < 2) return const [];
    final mentions = <IncidentMention>[];

    try {
      final studentQuery = Uri(
        queryParameters: {
          'customSchoolId': customSchoolId,
          'searchTerm': query,
          'page': '0',
          'size': '8',
        },
      ).query;
      final response = await _send('GET', '/api/students/search?$studentQuery');
      for (final value in _list(response)) {
        final json = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        final name = [
          json['firstName'],
          json['middleName'],
          json['lastName'],
        ].where((part) => part != null && '$part'.trim().isNotEmpty).join(' ');
        if (name.isNotEmpty) {
          mentions.add(
            IncidentMention(
              id: '${json['customStudentId'] ?? ''}',
              name: name,
              personType: 'STUDENT',
              subtitle: [json['class'], json['class_'], json['section']]
                  .where((part) => part != null && '$part'.trim().isNotEmpty)
                  .join(' · '),
            ),
          );
        }
      }
    } on IncidentApiException {
      // Staff results can still be shown when student search is unavailable.
    }

    try {
      final staffQuery = Uri(
        queryParameters: {'page': '0', 'size': '100'},
      ).query;
      final response = await _send(
        'GET',
        '/api/user-management/schools/$customSchoolId/users?$staffQuery',
      );
      for (final value in _list(response)) {
        final json = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        if ('${json['userType'] ?? ''}'.toUpperCase() != 'STAFF') continue;
        final name = [
          json['firstName'],
          json['middleName'],
          json['lastName'],
        ].where((part) => part != null && '$part'.trim().isNotEmpty).join(' ');
        final staffId = '${json['id'] ?? json['userId'] ?? ''}';
        final searchable = [
          name,
          staffId,
          json['userName'],
          json['username'],
          json['email'],
        ].where((value) => value != null).join(' ').toLowerCase();
        if (searchable.contains(query.toLowerCase())) {
          mentions.add(
            IncidentMention(
              id: staffId,
              name: name,
              personType: 'STAFF',
              subtitle: '${json['role'] ?? 'Staff'}',
            ),
          );
        }
      }
    } on IncidentApiException {
      // Student results can still be shown when staff search is unavailable.
    }

    return mentions.take(12).toList(growable: false);
  }

  String _path(String path, [Map<String, String> extra = const {}]) {
    final query = Uri(
      queryParameters: {'customSchoolId': customSchoolId, ...extra},
    ).query;
    return '$path?$query';
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken?.isNotEmpty != true) {
      throw const IncidentApiException('Please sign in again to continue.');
    }
    Future<http.Response> send() {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final refreshed = await onRefreshAccessToken!.call();
        if (refreshed?.isNotEmpty == true) {
          accessToken = refreshed;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw IncidentApiException(_message(response));
    } on TimeoutException {
      throw const IncidentApiException(
        'The incident request took too long. Please try again.',
      );
    } on IncidentApiException {
      rethrow;
    } catch (_) {
      throw const IncidentApiException(
        'Unable to reach the incident service right now.',
      );
    }
  }

  Map<String, dynamic> _object(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const IncidentApiException(
      'The server returned an invalid response.',
    );
  }

  List<dynamic> _list(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final value =
          decoded['content'] ??
          decoded['users'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['results'];
      if (value is List) return value;
      if (value is Map) {
        final nested =
            value['content'] ??
            value['users'] ??
            value['data'] ??
            value['items'] ??
            value['results'];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return '${decoded['message'] ?? decoded['error'] ?? 'Request failed.'}';
      }
    } catch (_) {}
    return 'Incident request failed (${response.statusCode}).';
  }
}

class IncidentTermContext {
  const IncidentTermContext({required this.startDate, required this.endDate});

  factory IncidentTermContext.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic value) {
      if (value is List && value.length >= 3) {
        return DateTime(
          (value[0] as num).toInt(),
          (value[1] as num).toInt(),
          (value[2] as num).toInt(),
        );
      }
      return DateTime.tryParse(value?.toString() ?? '');
    }

    final start = date(json['startDate']);
    final end = date(json['endDate']);
    if (start == null || end == null) {
      throw const IncidentApiException(
        'The current academic term dates are not configured.',
      );
    }
    return IncidentTermContext(startDate: start, endDate: end);
  }

  final DateTime startDate;
  final DateTime endDate;
}
