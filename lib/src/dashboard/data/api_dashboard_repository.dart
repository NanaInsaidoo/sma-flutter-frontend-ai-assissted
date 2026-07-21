import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../admissions/data/admissions_api_client.dart';
import '../../config/api_config.dart';
import '../../fees/data/fee_api_client.dart';
import '../../fees/domain/fee_models.dart' as fee_models;
import '../../theme/app_theme.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_repository.dart';

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository({
    required this.accessToken,
    required this.administratorName,
    this.schoolName,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final String administratorName;
  final String? schoolName;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Authorization': 'Bearer ${accessToken!.trim()}',
  };

  Map<String, String> get _jsonHeaders => {
    ..._headers,
    'Content-Type': 'application/json',
  };

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() send,
  ) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const DashboardApiException('Please sign in again to continue.');
    }
    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshed = await onRefreshAccessToken!();
      if (refreshed?.trim().isNotEmpty == true) {
        accessToken = refreshed!.trim();
        response = await send();
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> _jsonRequest(
    Future<http.Response> Function() send,
  ) async {
    final response = await _sendWithRefresh(send);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DashboardApiException(_responseMessage(response));
    }
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  Future<List<dynamic>> _jsonListRequest(
    Future<http.Response> Function() send,
  ) async {
    final response = await _sendWithRefresh(send);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DashboardApiException(_responseMessage(response));
    }
    if (response.body.trim().isEmpty) return const [];
    final decoded = jsonDecode(response.body);
    return decoded is List ? decoded : const [];
  }

  String _isoDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _calendarEventBody(CalendarEventPayload event) {
    return {
      'name': event.name.trim(),
      'description': event.description.trim(),
      'startDate': _isoDate(event.startDate),
      'endDate': _isoDate(event.endDate),
      'eventType': {'id': event.eventTypeId},
      if (event.academicTermId != null && event.academicTermId! > 0)
        'academicTerm': {'id': event.academicTermId},
      'isSchoolDay': event.isSchoolDay,
    };
  }

  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    if (schoolId.trim().isEmpty) {
      throw const DashboardApiException(
        'Your account is not linked to a school yet.',
      );
    }

    final feeApi = FeeApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
      client: _client,
    );
    final attendanceApi = AttendanceApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
      client: _client,
    );
    final admissionsApi = AdmissionsApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
      client: _client,
    );

    try {
      final results = await Future.wait<Object>([
        _getSchoolStatistics(schoolId),
        feeApi.getCurrentTerm(schoolId),
        feeApi.getFeeManagementOverview(customSchoolId: schoolId),
        attendanceApi.getOverview(schoolId),
      ]);
      accessToken =
          feeApi.accessToken ??
          attendanceApi.accessToken ??
          admissionsApi.accessToken;

      final statistics = results[0] as Map<String, dynamic>;
      final term = results[1] as fee_models.CurrentAcademicTerm;
      final feeOverview = results[2] as fee_models.FeeManagementOverview;
      final attendance = results[3] as AttendanceDashboardOverview;
      final admissionTerm = await _optional<AdmissionTermContext>(
        () => admissionsApi.getCurrentTerm(schoolId),
      );
      accessToken = admissionsApi.accessToken ?? accessToken;
      final termParts = term.name
          .split('·')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      final termName = termParts.isEmpty ? 'Current term' : termParts.first;
      final academicYear = termParts.length > 1 ? termParts.last : '';
      final admissions = admissionTerm == null
          ? <AdmissionListItem>[]
          : await _optional<List<AdmissionListItem>>(
                  () => admissionsApi.getAdmissions(
                    customSchoolId: schoolId,
                    startDate: admissionTerm.startDate,
                    endDate: admissionTerm.endDate,
                    size: 100,
                  ),
                ) ??
                <AdmissionListItem>[];
      accessToken = admissionsApi.accessToken ?? accessToken;
      final termEvents =
          await _optional<List<Map<String, dynamic>>>(
            () => _getTermEvents(schoolId),
          ) ??
          <Map<String, dynamic>>[];
      final schoolEvents = _buildSchoolEvents(termEvents);
      final totalStudents = _integer(statistics['totalStudents']);
      final activeClasses = _integer(statistics['totalActiveClasses']);
      final totalClasses = _integer(statistics['totalClasses']);
      final attendanceRate = attendance.today.attendanceRate;

      return DashboardSnapshot(
        schoolName: schoolName?.trim().isNotEmpty == true
            ? schoolName!.trim()
            : schoolId,
        administratorName: administratorName.trim().isEmpty
            ? 'School administrator'
            : administratorName.trim(),
        term: termName,
        academicTermId: term.id > 0 ? term.id : null,
        academicYear: academicYear,
        termStartDate: _formatDate(admissionTerm?.startDate),
        termEndDate: _formatDate(admissionTerm?.endDate),
        lastUpdated: DateTime.now(),
        metrics: [
          DashboardMetric(
            label: 'Students enrolled',
            value: '$totalStudents',
            caption: 'Current enrolled students',
            change: '${_integer(statistics['totalActiveStudents'])} active',
            icon: Icons.groups_rounded,
            color: AppColors.green,
          ),
          DashboardMetric(
            label: 'Active classes',
            value: '$activeClasses',
            caption: '$totalClasses classes configured',
            change: '${_integer(statistics['totalGradeLevels'])} grade levels',
            icon: Icons.class_rounded,
            color: AppColors.purple,
          ),
          DashboardMetric(
            label: 'Attendance today',
            value: '${attendanceRate.toStringAsFixed(1)}%',
            caption:
                '${attendance.today.present} of ${attendance.today.totalStudents} present',
            change: '${attendance.streamsPending} streams pending',
            icon: Icons.fact_check_rounded,
            color: AppColors.blue,
          ),
          DashboardMetric(
            label: 'Fees collected',
            value: _money(feeOverview.totalCollected),
            caption: termName,
            change:
                '${feeOverview.collectionRate.toStringAsFixed(1)}% collected',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.amber,
          ),
        ],
        admissions: _buildAdmissionGroups(admissions),
        alerts: attendance.alerts
            .map(
              (alert) => SchoolAlert(
                title: alert.title,
                message: alert.message,
                context: 'Attendance',
                level: _alertLevel(alert.severity),
              ),
            )
            .toList(),
        events: _buildUpcomingEvents(schoolEvents),
        calendarEvents: schoolEvents,
        activities: const [],
        attendance: AttendanceSummary(
          total: attendance.today.totalStudents,
          present: attendance.today.present,
          absent: attendance.today.absent,
          late: attendance.today.late,
        ),
        fees: FeeSummary(
          collected: feeOverview.totalCollected,
          outstanding: feeOverview.outstanding,
          waivers: 0,
        ),
      );
    } on DashboardApiException {
      rethrow;
    } on FeeApiException catch (error) {
      throw DashboardApiException(error.message);
    } on AttendanceApiException catch (error) {
      throw DashboardApiException(error.message);
    } catch (_) {
      throw const DashboardApiException(
        'Unable to load the school dashboard from the server.',
      );
    }
  }

  @override
  Future<List<CalendarEventType>> getCalendarEventTypes() async {
    final items = await _jsonListRequest(
      () => _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/lookup/event-types'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20)),
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final id = _integer(item['id']);
          final name = _firstText(item, const ['name', 'label'], fallback: '');
          if (id <= 0 || name.isEmpty) return null;
          return CalendarEventType(id: id, name: name);
        })
        .whereType<CalendarEventType>()
        .toList();
  }

  @override
  Future<SchoolEvent> createCalendarEvent({
    required String schoolId,
    required CalendarEventPayload event,
  }) async {
    final school = Uri.encodeQueryComponent(schoolId);
    final response = await _jsonRequest(
      () => _client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/term-events?customSchoolId=$school',
            ),
            headers: _jsonHeaders,
            body: jsonEncode(_calendarEventBody(event)),
          )
          .timeout(const Duration(seconds: 20)),
    );
    return _buildSchoolEvents([response]).first;
  }

  @override
  Future<SchoolEvent> updateCalendarEvent({
    required String schoolId,
    required String eventId,
    required CalendarEventPayload event,
  }) async {
    final school = Uri.encodeQueryComponent(schoolId);
    final id = Uri.encodeComponent(eventId);
    final response = await _jsonRequest(
      () => _client
          .put(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/term-events/$id?customSchoolId=$school',
            ),
            headers: _jsonHeaders,
            body: jsonEncode(_calendarEventBody(event)),
          )
          .timeout(const Duration(seconds: 20)),
    );
    return _buildSchoolEvents([response]).first;
  }

  @override
  Future<void> deleteCalendarEvent({
    required String schoolId,
    required String eventId,
  }) async {
    final school = Uri.encodeQueryComponent(schoolId);
    final id = Uri.encodeComponent(eventId);
    final response = await _sendWithRefresh(
      () => _client
          .delete(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/term-events/$id?customSchoolId=$school',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DashboardApiException(_responseMessage(response));
    }
  }

  Future<T?> _optional<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getSchoolStatistics(String schoolId) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const DashboardApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      return _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/schools/$schoolId/dashboard/statistics',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${accessToken!.trim()}',
            },
          )
          .timeout(const Duration(seconds: 20));
    }

    try {
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
        throw DashboardApiException(_responseMessage(response));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const DashboardApiException(
          'The school statistics response was invalid.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const DashboardApiException(
        'The school dashboard took too long to load. Please try again.',
      );
    } on DashboardApiException {
      rethrow;
    } catch (_) {
      throw const DashboardApiException(
        'Unable to reach the school dashboard service.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getTermEvents(String schoolId) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const DashboardApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      return _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/term-events/search?customSchoolId=$schoolId',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${accessToken!.trim()}',
            },
          )
          .timeout(const Duration(seconds: 20));
    }

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
      throw DashboardApiException(_responseMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final events = _extractEventMaps(decoded);
    if (events.isNotEmpty) return events;
    return _getSchoolCurrentTermEvents(schoolId);
  }

  Future<List<Map<String, dynamic>>> _getSchoolCurrentTermEvents(
    String schoolId,
  ) async {
    Future<http.Response> send() {
      return _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/schools/$schoolId'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${accessToken!.trim()}',
            },
          )
          .timeout(const Duration(seconds: 20));
    }

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
      throw DashboardApiException(_responseMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final school = _asMap(_unwrapSchool(decoded));
    final term = _firstMapOf(school, const [
      'currentAcademicTerm',
      'academicTerm',
      'termCalendar',
      'termDetails',
      'currentTerm',
    ]);
    return _extractEventMaps(term['events'] ?? school['events']);
  }

  String _responseMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'details']) {
          final value = '${decoded[key] ?? ''}'.trim();
          if (value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return 'Dashboard request failed (${response.statusCode}).';
  }

  int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  List<AdmissionGroup> _buildAdmissionGroups(List<AdmissionListItem> items) {
    if (items.isEmpty) return const [];

    final counts = <String, int>{
      'KG': 0,
      'B1-3': 0,
      'B4-6': 0,
      'JHS 1': 0,
      'JHS 2': 0,
      'JHS 3': 0,
    };
    for (final item in items) {
      final status = item.status.trim().toUpperCase();
      if (status == 'REJECTED' || status == 'DELETED') continue;
      final group = _admissionGradeGroup(item.gradeLevelName);
      if (group == null) continue;
      counts[group] = (counts[group] ?? 0) + 1;
    }
    if (counts.values.every((value) => value == 0)) return const [];
    return counts.entries
        .map((entry) => AdmissionGroup(entry.key, entry.value))
        .toList();
  }

  String? _admissionGradeGroup(String gradeLevelName) {
    final text = gradeLevelName.trim().toUpperCase();
    if (text.isEmpty) return null;
    if (text.contains('KG') ||
        text.contains('KINDER') ||
        text.contains('NURSERY') ||
        text.contains('CRECHE')) {
      return 'KG';
    }

    final basicMatch = RegExp(
      r'(?:BASIC|PRIMARY|GRADE|CLASS|B)\s*([1-6])',
    ).firstMatch(text);
    final basicLevel = basicMatch == null
        ? null
        : int.tryParse(basicMatch.group(1) ?? '');
    if (basicLevel != null) {
      if (basicLevel >= 1 && basicLevel <= 3) return 'B1-3';
      if (basicLevel >= 4 && basicLevel <= 6) return 'B4-6';
    }

    final jhsMatch = RegExp(r'JHS\s*([1-3])').firstMatch(text);
    final jhsLevel = jhsMatch == null
        ? null
        : int.tryParse(jhsMatch.group(1) ?? '');
    if (jhsLevel != null) return 'JHS $jhsLevel';

    return null;
  }

  List<SchoolEvent> _buildSchoolEvents(List<Map<String, dynamic>> events) {
    final parsed =
        events
            .map((event) {
              final start = _dateValue(
                event['startDate'] ?? event['eventDate'] ?? event['date'],
              );
              if (start == null) return null;
              final end =
                  _dateValue(event['endDate'] ?? event['eventDate']) ?? start;
              return _DashboardEventEntry(event, start, end);
            })
            .whereType<_DashboardEventEntry>()
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return parsed.map((entry) {
      final event = entry.event;
      final type = event['eventType'];
      final academicTerm = event['academicTerm'];
      final category = type is Map<String, dynamic>
          ? _firstText(type, const [
              'name',
              'eventTypeName',
              'label',
            ], fallback: 'Event')
          : _firstText(event, const [
              'eventTypeName',
              'type',
              'category',
            ], fallback: 'Event');
      return SchoolEvent(
        id: _firstText(event, const [
          'id',
          'eventId',
          'termEventId',
        ], fallback: ''),
        startDate: entry.startDate,
        endDate: entry.endDate,
        title: _firstText(event, const [
          'name',
          'eventName',
          'title',
        ], fallback: 'School event'),
        category: category,
        eventTypeId: type is Map<String, dynamic> ? _integer(type['id']) : null,
        academicTermId: academicTerm is Map<String, dynamic>
            ? _integer(academicTerm['id'])
            : _integer(event['academicTermId']),
        description: _firstText(event, const [
          'description',
          'notes',
          'detail',
        ], fallback: ''),
        isSchoolDay:
            event['isSchoolDay'] == null || event['isSchoolDay'] == true,
      );
    }).toList();
  }

  List<SchoolEvent> _buildUpcomingEvents(List<SchoolEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events
        .where((event) => !event.endDate.isBefore(today))
        .take(5)
        .toList();
  }

  String _formatDate(String? value) {
    final date = _dateValue(value);
    if (date == null) return '';
    return '${date.day} ${_shortMonth(date.month)} ${date.year}';
  }

  dynamic _unwrapSchool(dynamic value) {
    if (value is Map<String, dynamic>) {
      for (final key in ['school', 'data', 'result', 'content']) {
        final nested = value[key];
        if (nested is Map<String, dynamic>) return nested;
      }
    }
    return value;
  }

  List<Map<String, dynamic>> _extractEventMaps(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is Map<String, dynamic>) {
      for (final key in ['content', 'data', 'events', 'items', 'results']) {
        final nested = value[key];
        final events = _extractEventMaps(nested);
        if (events.isNotEmpty) return events;
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  Map<String, dynamic> _firstMapOf(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
    }
    return const {};
  }

  DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is List && value.length >= 3) {
      final year = _integer(value[0]);
      final month = _integer(value[1]);
      final day = _integer(value[2]);
      if (year > 0 && month > 0 && day > 0) {
        return DateTime(year, month, day);
      }
    }
    if (value is Map<String, dynamic>) {
      final year = _integer(value['year']);
      final month = _integer(value['monthValue'] ?? value['month']);
      final day = _integer(value['dayOfMonth'] ?? value['day']);
      if (year > 0 && month > 0 && day > 0) {
        return DateTime(year, month, day);
      }
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    final normalized = text.contains('T') ? text : text.split(' ').first;
    return DateTime.tryParse(normalized);
  }

  String _firstText(
    Map<String, dynamic> source,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return fallback;
  }

  String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  AlertLevel _alertLevel(String severity) {
    return switch (severity.trim().toUpperCase()) {
      'CRITICAL' || 'HIGH' || 'ERROR' => AlertLevel.critical,
      'WARNING' || 'MEDIUM' => AlertLevel.warning,
      _ => AlertLevel.info,
    };
  }

  String _money(double amount) {
    final value = amount.toStringAsFixed(0);
    return 'GH₵$value';
  }
}

class DashboardApiException implements Exception {
  const DashboardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DashboardEventEntry {
  const _DashboardEventEntry(this.event, this.startDate, this.endDate);

  final Map<String, dynamic> event;
  final DateTime startDate;
  final DateTime endDate;
}
