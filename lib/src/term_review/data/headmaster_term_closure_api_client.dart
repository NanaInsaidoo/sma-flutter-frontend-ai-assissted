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
      transitionPreview: m('transitionPreview'),
      transition: m('transition'),
    );
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
