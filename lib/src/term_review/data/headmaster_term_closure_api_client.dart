import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../domain/headmaster_term_closure_models.dart';

class HeadmasterTermClosureApiClient
    implements HeadmasterTermClosureRepository {
  HeadmasterTermClosureApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  @override
  Future<HeadmasterTermClosure> get(String s) => _call('GET', s);
  @override
  Future<HeadmasterTermClosure> saveDraft(
    String s,
    HeadmasterTermClosureInput i,
  ) => _call('PUT', s, action: 'draft', body: _body(i));
  @override
  Future<HeadmasterTermClosure> close(String s, HeadmasterTermClosureInput i) =>
      _call('POST', s, action: 'close', body: _body(i));
  @override
  Future<List<int>> downloadReport(String s) async {
    final u = Uri.parse(
      '${ApiConfig.baseUrl}/api/v2/headmaster-term-closures/school/$s/report',
    );
    var r = await _client.get(
      u,
      headers: {
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      },
    );
    if ((r.statusCode == 401 || r.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      r = await _client.get(
        u,
        headers: {
          if (accessToken?.isNotEmpty == true)
            'Authorization': 'Bearer $accessToken',
        },
      );
    }
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_error(r));
    return r.bodyBytes;
  }

  Map<String, Object?> _body(HeadmasterTermClosureInput i) => {
    'actorUserId': i.actorUserId,
    'warningAcknowledgements': i.acknowledgements,
    'facilities': i.facilities,
    'confirmation': i.confirmation,
  };
  Future<HeadmasterTermClosure> _call(
    String method,
    String s, {
    String? action,
    Object? body,
  }) async {
    Future<http.Response> go() {
      final u = Uri.parse(
        '${ApiConfig.baseUrl}/api/v2/headmaster-term-closures/school/$s${action == null ? '' : '/$action'}',
      );
      final h = {
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      };
      return method == 'PUT'
          ? _client.put(u, headers: h, body: jsonEncode(body))
          : method == 'POST'
          ? _client.post(u, headers: h, body: jsonEncode(body))
          : _client.get(u, headers: h);
    }

    var r = await go();
    if ((r.statusCode == 401 || r.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      r = await go();
    }
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_error(r));
    final j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    int n(Object? x) => int.tryParse('$x') ?? 0;
    Map<String, dynamic> m(String k) =>
        j[k] is Map ? Map<String, dynamic>.from(j[k] as Map) : {};
    final transitionPreview = m('transitionPreview');
    await _addTermDates(
      schoolId: s,
      currentTermId: n(j['termId']),
      preview: transitionPreview,
    );
    return HeadmasterTermClosure(
      termId: n(j['termId']),
      status: '${j['closureStatus']}',
      termClosed: j['termClosed'] == true,
      readyToClose: j['readyToClose'] == true,
      items: (j['items'] as List? ?? []).whereType<Map>().map((e) {
        final x = Map<String, dynamic>.from(e);
        return TermClosureItem(
          key: '${x['key']}',
          label: '${x['label']}',
          status: '${x['status']}',
          severity: '${x['severity']}',
          detail: '${x['detail']}',
        );
      }).toList(),
      acknowledgements: m(
        'warningAcknowledgements',
      ).map((k, v) => MapEntry(k, '$v')),
      facilities: m('facilities'),
      summary: m('summary'),
      transitionPreview: transitionPreview,
      transition: m('transition'),
    );
  }

  Future<void> _addTermDates({
    required String schoolId,
    required int currentTermId,
    required Map<String, dynamic> preview,
  }) async {
    if (preview['available'] != true) return;
    final nextTermId = int.tryParse('${preview['nextTermId']}');
    if (currentTermId <= 0 || nextTermId == null || nextTermId <= 0) return;
    try {
      final current = await _term(schoolId, currentTermId);
      final next = await _term(schoolId, nextTermId);
      preview['currentTermClosingDate'] =
          current['closingDate'] ?? current['endDate'];
      preview['operationalStartDate'] =
          next['operationalStartDate'] ?? next['startDate'];
      preview['teachingStartDate'] =
          next['teachingStartDate'] ?? next['startDate'];
      preview['teachingEndDate'] = next['teachingEndDate'] ?? next['endDate'];
      preview['closingDate'] = next['closingDate'] ?? next['endDate'];
    } catch (_) {
      // Keep the closure endpoint's partial preview if term-date hydration fails.
    }
  }

  Future<Map<String, dynamic>> _term(String schoolId, int termId) async {
    Future<http.Response> get() => _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/academic-terms/$termId?customSchoolId=${Uri.encodeQueryComponent(schoolId)}',
      ),
      headers: {
        'Accept': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      },
    );

    var response = await get();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      response = await get();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  String _error(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      return '${j['message'] ?? j['detail'] ?? j['error'] ?? r.body}';
    } catch (_) {
      return r.body;
    }
  }
}
