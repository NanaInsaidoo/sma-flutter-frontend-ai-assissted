import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../domain/bursar_term_closure_models.dart';

class BursarTermClosureApiClient implements BursarTermClosureRepository {
  BursarTermClosureApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  @override
  Future<BursarTermClosure> get(String s) => _call('GET', s);
  @override
  Future<BursarTermClosure> saveDraft(String s, BursarTermClosureInput i) =>
      _call('PUT', s, action: 'draft', body: _input(i));
  @override
  Future<BursarTermClosure> submit(String s, BursarTermClosureInput i) =>
      _call('PUT', s, action: 'submit', body: _input(i));
  @override
  Future<BursarTermClosure> approve(
    String s, {
    required int? actorUserId,
    String? reason,
  }) => _call(
    'POST',
    s,
    action: 'approve',
    body: {'actorUserId': actorUserId, 'reason': reason},
  );
  @override
  Future<BursarTermClosure> reopen(
    String s, {
    required int? actorUserId,
    required String reason,
  }) => _call(
    'POST',
    s,
    action: 'reopen',
    body: {'actorUserId': actorUserId, 'reason': reason},
  );
  @override
  Future<BursarTermClosure> returnToBursar(
    String s, {
    required int? actorUserId,
    required String reason,
  }) => _call(
    'POST',
    s,
    action: 'return',
    body: {'actorUserId': actorUserId, 'reason': reason},
  );
  Map<String, Object?> _input(BursarTermClosureInput i) => {
    'actorUserId': i.actorUserId,
    'bursarUserId': i.actorUserId,
    'feesReviewed': i.feesReviewed,
    'paymentsReconciled': i.paymentsReconciled,
    'pettyCashClosed': i.pettyCashClosed,
    'recommendationsReviewed': i.recommendationsReviewed,
    'cashTotal': i.cashTotal,
    'bankTotal': i.bankTotal,
    'mobileMoneyTotal': i.mobileMoneyTotal,
    'discrepancyExplanation': i.discrepancyExplanation,
    'unresolvedItems': i.unresolvedItems,
    'consolidatedRecommendations': i.consolidatedRecommendations,
  };
  Future<BursarTermClosure> _call(
    String method,
    String s, {
    String? action,
    Object? body,
  }) async {
    Future<http.Response> go() {
      final u = Uri.parse(
        '${ApiConfig.baseUrl}/api/v2/bursar-term-closures/school/$s${action == null ? '' : '/$action'}',
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
    double d(Object? v) => double.tryParse('$v') ?? 0;
    int n(Object? v) => int.tryParse('$v') ?? 0;
    List<Map<String, dynamic>> list(String k) => (j[k] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return BursarTermClosure(
      termId: n(j['termId']),
      status: '${j['status']}',
      expectedFees: d(j['expectedFees']),
      collectedFees: d(j['collectedFees']),
      waivedFees: d(j['waivedFees']),
      approvedAdjustments: d(j['approvedAdjustments']),
      outstandingFees: d(j['outstandingFees']),
      pendingAdjustmentCount: n(j['pendingAdjustmentCount']),
      pendingReversalCount: n(j['pendingReversalCount']),
      teacherRecommendations: list('teacherRecommendations'),
      consolidatedRecommendations: list('consolidatedRecommendations'),
      feesReviewed: j['feesReviewed'] == true,
      paymentsReconciled: j['paymentsReconciled'] == true,
      pettyCashClosed: j['pettyCashClosed'] == true,
      recommendationsReviewed: j['recommendationsReviewed'] == true,
      cashTotal: d(j['cashTotal']),
      bankTotal: d(j['bankTotal']),
      mobileMoneyTotal: d(j['mobileMoneyTotal']),
      discrepancyExplanation: '${j['discrepancyExplanation'] ?? ''}',
      unresolvedItems: '${j['unresolvedItems'] ?? ''}',
      snapshotLocked: j['snapshotLocked'] == true,
      submittedAt: DateTime.tryParse('${j['submittedAt'] ?? ''}'),
      approvedAt: DateTime.tryParse('${j['approvedAt'] ?? ''}'),
      approvedBy: j['approvedBy'] == null ? null : n(j['approvedBy']),
      reviewReason: '${j['reviewReason'] ?? ''}',
    );
  }

  String _error(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      return '${j['message'] ?? j['error'] ?? r.body}';
    } catch (_) {
      return r.body.isEmpty ? 'Request failed (${r.statusCode})' : r.body;
    }
  }
}
