import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

typedef ShopJson = Map<String, dynamic>;

class ShopApiClient {
  ShopApiClient({
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
      '${ApiConfig.baseUrl}/api/schools/${Uri.encodeComponent(schoolId)}/shop';

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    Future<http.Response> run() async {
      final request = http.Request(method, Uri.parse('$_base$path'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (accessToken?.isNotEmpty == true)
            'Authorization': 'Bearer $accessToken',
        });
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
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['message'] ?? decoded['detail'] ?? decoded['error']
          : null;
      throw ShopApiException(
        message?.toString() ??
            'The shop could not complete this action (${response.statusCode}).',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<ShopJson> context() async =>
      Map<String, dynamic>.from(await _send('GET', '/context'));
  Future<ShopJson> dashboard() async =>
      Map<String, dynamic>.from(await _send('GET', '/dashboard'));
  Future<List<ShopJson>> students(String query) async =>
      (await _send('GET', '/students?q=${Uri.encodeQueryComponent(query)}')
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<ShopJson>> items({bool includeInactive = false}) async =>
      (await _send('GET', '/items?includeInactive=$includeInactive') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> saveItem(ShopJson body, {int? id}) async =>
      Map<String, dynamic>.from(
        await _send(
          id == null ? 'POST' : 'PUT',
          id == null ? '/items' : '/items/$id',
          body: body,
        ),
      );
  Future<List<ShopJson>> purchases() async =>
      (await _send('GET', '/purchases') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> recordPurchase(ShopJson body) async =>
      Map<String, dynamic>.from(await _send('POST', '/purchases', body: body));
  Future<ShopJson> recordStock(ShopJson body) async =>
      Map<String, dynamic>.from(await _send('POST', '/stock', body: body));
  Future<List<ShopJson>> stockMovements() async =>
      (await _send('GET', '/stock-movements') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<ShopJson>> roles() async => (await _send('GET', '/roles') as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<List<ShopJson>> saveRoles(List<ShopJson> body) async =>
      (await _send('PUT', '/roles', body: body) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<ShopJson>> consignments({bool mine = false}) async =>
      (await _send('GET', '/consignments?mine=$mine') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<ShopJson>> availableCustody() async =>
      (await _send('GET', '/custody/available') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> createConsignment(ShopJson body) async =>
      Map<String, dynamic>.from(
        await _send('POST', '/consignments', body: body),
      );
  Future<ShopJson> answerStockIssue(
    ShopJson row,
    String action, {
    String? reason,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/consignments/${row['id']}/acceptance',
      body: {'action': action, 'reason': reason, 'version': row['version']},
    ),
  );
  Future<ShopJson> returnStock(
    ShopJson row,
    int quantity,
    String reason,
  ) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/consignments/${row['id']}/returns',
      body: {'quantity': quantity, 'reason': reason, 'version': row['version']},
    ),
  );
  Future<List<ShopJson>> staffReturns() async =>
      (await _send('GET', '/staff-returns') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> receiveStaffReturn(
    ShopJson row, {
    required String action,
    int? receivedQuantity,
    String? condition,
    String? note,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/staff-returns/${row['id']}/receive',
      body: {
        'action': action,
        'receivedQuantity': receivedQuantity,
        'condition': condition,
        'note': note,
        'version': row['version'],
      },
    ),
  );
  Future<List<ShopJson>> inventoryAdjustments() async =>
      (await _send('GET', '/inventory-adjustments') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> requestInventoryAdjustment(ShopJson body) async =>
      Map<String, dynamic>.from(
        await _send('POST', '/inventory-adjustments', body: body),
      );
  Future<ShopJson> sellerSale(ShopJson body) async => Map<String, dynamic>.from(
    await _send('POST', '/sales/consignment', body: body),
  );
  Future<List<ShopJson>> sales({String? from, String? to}) async {
    final query = Uri(
      queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ).query;
    return (await _send('GET', '/sales${query.isEmpty ? '' : '?$query'}')
            as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<ShopJson>> customerReturns() async =>
      (await _send('GET', '/returns') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> requestCustomerReturn(ShopJson body) async =>
      Map<String, dynamic>.from(await _send('POST', '/returns', body: body));
  Future<ShopJson> decideCustomerReturn(
    ShopJson row,
    String action, {
    String? reason,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/returns/${row['id']}/decision',
      body: {'action': action, 'reason': reason, 'version': row['version']},
    ),
  );
  Future<ShopJson> issueRefund(
    ShopJson row, {
    required String method,
    String? reference,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/returns/${row['id']}/refund',
      body: {
        'method': method,
        'reference': reference,
        'version': row['version'],
      },
    ),
  );

  Future<ShopJson> issueReceipt(ShopJson body) async =>
      Map<String, dynamic>.from(await _send('POST', '/receipts', body: body));
  Future<List<ShopJson>> receipts({String? status, String? query}) async {
    final q = Uri(
      queryParameters: {
        if (status?.isNotEmpty == true) 'status': status,
        if (query?.isNotEmpty == true) 'q': query,
      },
    ).query;
    return (await _send('GET', '/receipts${q.isEmpty ? '' : '?$q'}') as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<ShopJson> redeem(ShopJson receipt) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/receipts/${receipt['reference']}/redeem',
      body: {'version': receipt['version']},
    ),
  );
  Future<ShopJson> cancelReceipt(ShopJson receipt, String reason) async =>
      Map<String, dynamic>.from(
        await _send(
          'POST',
          '/receipts/${receipt['reference']}/cancel',
          body: {'version': receipt['version'], 'reason': reason},
        ),
      );
  Future<ShopJson> requestCollectionCancellation(
    ShopJson receipt, {
    required int approverId,
    required String reason,
  }) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/receipts/${receipt['reference']}/cancellation-requests',
      body: {
        'approverId': approverId,
        'reason': reason,
        'version': receipt['version'],
      },
    ),
  );
  Future<List<ShopJson>> reconciliations() async =>
      (await _send('GET', '/reconciliations') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<ShopJson> reconcile(int consignmentId, ShopJson body) async =>
      Map<String, dynamic>.from(
        await _send(
          'POST',
          '/consignments/$consignmentId/reconciliations',
          body: body,
        ),
      );
  Future<ShopJson> reviewReconciliation(
    int id,
    bool approve,
    String note,
  ) async => Map<String, dynamic>.from(
    await _send(
      'POST',
      '/reconciliations/$id/review',
      body: {'approve': approve, 'note': note},
    ),
  );
  Future<List<ShopJson>> audit() async => (await _send('GET', '/audit') as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

class ShopApiException implements Exception {
  ShopApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
