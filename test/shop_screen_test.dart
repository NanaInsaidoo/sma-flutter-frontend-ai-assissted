import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/shop/data/shop_api_client.dart';
import 'package:school_management_app/src/shop/presentation/school_shop_screen.dart';
import 'package:school_management_app/src/shop/presentation/shop_receipt_pdf.dart';

void main() {
  Widget appWith(
    Map<String, dynamic> context, {
    List<dynamic> consignments = const [],
    List<dynamic> receipts = const [],
    List<dynamic> purchases = const [],
    List<dynamic>? items,
    List<dynamic>? sales,
    List<dynamic> auditEvents = const [],
    List<dynamic> shopRoles = const [],
    List<dynamic> inventoryAdjustments = const [],
    List<dynamic>? stockMovements,
    List<dynamic> customerReturns = const [],
    List<dynamic> staffReturns = const [],
    Map<String, dynamic>? report,
    void Function(Uri uri)? onReportDownload,
    void Function(Map<String, dynamic> input)? onItemSaved,
    String? itemSaveError,
    void Function(Map<String, dynamic> input)? onStockAdded,
    void Function(Map<String, dynamic> input)? onStockIssued,
    void Function(Map<String, dynamic> input)? onSaleSaved,
    void Function(Map<String, dynamic> input)? onSellerChanged,
    List<dynamic> studentDirectory = const [],
  }) {
    final itemRows =
        (items ??
                [
                  {
                    'id': 1,
                    'name': 'Exercise Book',
                    'displayName': 'Exercise Book · 80 pages',
                    'sku': 'EXB-80',
                    'category': 'Books',
                    'unitOfMeasure': 'book',
                    'costPrice': 6,
                    'sellingPrice': 8,
                    'margin': 2,
                    'centralQuantity': 12,
                    'availableQuantity': 12,
                    'totalOnHand': 12,
                    'unassignedQuantity': 12,
                    'heldQuantity': 0,
                    'totalReservedQuantity': 0,
                    'holders': [],
                    'lowStockThreshold': 3,
                    'lowStock': false,
                    'active': true,
                    'createdAt': '2026-09-01T10:00:00',
                    'version': 0,
                  },
                ])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
    final adjustmentRows = inventoryAdjustments
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final movementRows =
        stockMovements ??
        [
          for (final purchase in purchases)
            {
              'id': purchase['id'],
              'entityType': 'STOCK_RECEIPT',
              'entityId': purchase['id'],
              'action': 'RECEIVED',
              'movement': 'Stock received',
              'effect': 'INCREASE',
              'details': '${purchase['supplier'] ?? 'Stock received'}',
              'recordedBy': purchase['buyerName'],
              'reference': 'STOCK_RECEIPT #${purchase['id']}',
              'occurredAt': purchase['purchaseDate'],
            },
        ];
    final shopRoleRows = shopRoles
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final customerReturnRows = customerReturns
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final staffReturnRows = staffReturns
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final reportPayload =
        report ??
        {
          'schoolId': 'SCH-1',
          'schoolName': 'Test School',
          'from': '2026-08-05',
          'to': '2026-09-03',
          'termName': 'First Term',
          'termFrom': '2026-08-25',
          'termTo': '2026-12-11',
          'summary': {
            'transactions': 2,
            'grossSales': 40,
            'refunds': 8,
            'netSales': 32,
            'costOfSales': 20,
            'grossProfit': 12,
            'cashSales': 30,
            'momoSales': 10,
            'cashRefunds': 8,
            'momoRefunds': 0,
            'netCashSales': 22,
            'netMomoSales': 10,
            'confirmedRemittances': 20,
            'pendingRemittances': 0,
            'cashDifferences': -2,
            'momoDifferences': 0,
            'cashStillHeld': 22,
            'unitsSold': 5,
            'unitsReturned': 1,
            'returnRequests': 1,
            'pendingReturns': 0,
            'stockValue': 72,
            'centralUnits': 12,
            'staffHeldUnits': 4,
            'reservedUnits': 1,
            'quarantinedUnits': 2,
            'lowStockItems': 1,
          },
          'dailySales': [
            {
              'date': '2026-09-01',
              'transactions': 2,
              'units': 5,
              'grossSales': 40,
              'refunds': 8,
              'netSales': 32,
            },
          ],
          'accountingSales': [
            {
              'id': 30,
              'createdAt': '2026-09-01T09:30:00',
              'reference': 'SHOP-20260901-000001',
              'buyer': 'Kojo Mensah',
              'buyerType': 'STUDENT',
              'seller': 'Kofi Nketia',
              'paymentMethod': 'CASH',
              'status': 'COLLECTED',
              'units': 5,
              'gross': 40,
              'refund': 8,
              'net': 32,
              'costOfSales': 20,
              'grossProfit': 12,
            },
          ],
          'itemPerformance': [
            {
              'item': 'Exercise Book · 80 pages',
              'category': 'Books',
              'sold': 5,
              'returned': 1,
              'netUnits': 4,
              'netRevenue': 32,
            },
          ],
          'inventory': [
            {
              'id': 1,
              'item': 'Exercise Book · 80 pages',
              'central': 12,
              'withStaff': 4,
              'reserved': 1,
              'quarantined': 2,
              'available': 15,
              'totalOnHand': 18,
              'costValue': 72,
              'lowStock': false,
            },
          ],
          'inventoryAdjustments': [
            {
              'id': 9,
              'submittedAt': '2026-09-01T15:30:00',
              'decidedAt': '2026-09-01T16:00:00',
              'item': 'Exercise Book · 80 pages',
              'unit': 'book',
              'type': 'COUNT_CORRECTION',
              'currentQuantity': 13,
              'proposedQuantity': 12,
              'difference': -1,
              'unitCost': 6,
              'inventoryValueChange': -6,
              'status': 'APPROVED',
              'reason': 'One damaged book confirmed during count',
              'requester': 'Ama Admin',
              'approver': 'Yaw Asante',
            },
          ],
          'staffStock': [
            {
              'id': 1,
              'staff': 'Kofi Nketia',
              'item': 'Exercise Book · 80 pages',
              'held': 4,
              'reserved': 1,
              'available': 3,
              'cashExpected': 16,
            },
          ],
          'returns': [
            {
              'id': 1,
              'requestedAt': '2026-09-01T12:00:00',
              'receipt': 'SHOP-20260901-000001',
              'buyer': 'Kojo Mensah',
              'type': 'CUSTOMER_RETURN',
              'status': 'COMPLETED',
              'refund': 8,
              'refundMethod': 'CASH',
              'refundedAt': '2026-09-01T14:00:00',
              'requestedBy': 'Ama Admin',
              'items': 1,
            },
          ],
          'reconciliations': [
            {
              'id': 1,
              'cutoff': '2026-09-01T17:00:00',
              'decidedAt': '2026-09-01T18:00:00',
              'seller': 'Kofi Nketia',
              'counter': 'Ama Admin',
              'approver': 'Yaw Asante',
              'status': 'CLOSED_WITH_DIFFERENCES',
              'stockDifferenceLines': 1,
              'stockVarianceUnits': -1,
              'cashVariance': -2,
              'momoVariance': 0,
              'decisionNote': 'Confirmed after recount',
            },
          ],
          'remittances': [
            {
              'id': 1,
              'reference': 'REM-1',
              'createdAt': '2026-09-01T18:15:00',
              'confirmedAt': '2026-09-01T18:20:00',
              'sender': 'Kofi Nketia',
              'recipient': 'Ama Admin',
              'amount': 20,
              'status': 'CONFIRMED',
            },
          ],
          'cashHeld': [
            {'staffId': 1, 'person': 'Ama Admin', 'amount': 20},
            {'staffId': 2, 'person': 'Kofi Nketia', 'amount': 2},
          ],
        };
    final client = MockClient((request) async {
      final path = request.url.path;
      dynamic body;
      if (path.endsWith('/context')) {
        body = context;
      } else if (path.endsWith('/dashboard')) {
        body = {
          'centralAvailable': 12,
          'reserved': 1,
          'revenue': 40,
          'profit': 10,
          'pendingPickups': receipts.length,
          'lowStock': 0,
          'flaggedReconciliations': 0,
          'lowStockItems': [],
          'topItems': [],
          'sellerLiability': [],
        };
      } else if (path.endsWith('/students')) {
        body = studentDirectory;
      } else if (path.endsWith('/reports/summary.pdf')) {
        onReportDownload?.call(request.url);
        return http.Response.bytes(
          utf8.encode('%PDF-1.7 test'),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      } else if (path.endsWith('/reports/summary')) {
        body = reportPayload;
      } else if (request.method == 'PUT' && path.contains('/items/')) {
        final id = int.parse(path.split('/').last);
        final update = Map<String, dynamic>.from(jsonDecode(request.body));
        final index = itemRows.indexWhere((row) => row['id'] == id);
        itemRows[index] = {
          ...itemRows[index],
          ...update,
          'id': id,
          'displayName': update['variantLabel'] == null
              ? update['name']
              : '${update['name']} · ${update['variantLabel']}',
          'version': ((itemRows[index]['version'] as num?)?.toInt() ?? 0) + 1,
        };
        body = itemRows[index];
      } else if (path.endsWith('/items') && request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        onItemSaved?.call(input);
        if (itemSaveError != null) {
          return http.Response(
            jsonEncode({'message': itemSaveError}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        body = {
          'id': 99,
          ...input,
          'costPrice': 0,
          'sellingPrice': 0,
          'centralQuantity': 0,
          'availableQuantity': 0,
          'version': 0,
        };
      } else if (path.endsWith('/items')) {
        body = itemRows;
      } else if (path.endsWith('/stock') && request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        onStockAdded?.call(input);
        body = {'id': 99, ...input};
      } else if (path.endsWith('/purchases')) {
        body = purchases;
      } else if (path.endsWith('/inventory-adjustments') &&
          request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final item = itemRows.firstWhere((row) => row['id'] == input['itemId']);
        final approver = (context['inventoryApprovers'] as List).firstWhere(
          (row) => row['id'] == input['approverId'],
        );
        final row = <String, dynamic>{
          'id': adjustmentRows.length + 1,
          ...input,
          'itemName': item['displayName'],
          'unitOfMeasure': item['unitOfMeasure'],
          'currentQuantity': item['unassignedQuantity'],
          'change':
              (input['proposedQuantity'] as int) -
              (item['unassignedQuantity'] as int),
          'requesterId': context['currentUserId'],
          'requesterName': context['currentUserName'],
          'approverName': approver['name'],
          'status': 'PENDING_APPROVAL',
          'submittedAt': [2026, 9, 2, 11, 30, 0],
          'version': 0,
        };
        adjustmentRows.insert(0, row);
        body = row;
      } else if (path.endsWith('/inventory-adjustments')) {
        body = adjustmentRows;
      } else if (path.endsWith('/stock-movements')) {
        body = movementRows;
      } else if (path.endsWith('/staff-returns')) {
        body = staffReturnRows;
      } else if (path.contains('/staff-returns/') &&
          path.endsWith('/receive')) {
        final id = int.parse(path.split('/')[path.split('/').length - 2]);
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final row = staffReturnRows.firstWhere((value) => value['id'] == id);
        row.addAll({
          'status': input['action'] == 'REJECT'
              ? 'REJECTED'
              : (input['receivedQuantity'] == row['requestedQuantity']
                    ? 'COMPLETED'
                    : 'DISCREPANCY'),
          'receivedQuantity': input['receivedQuantity'],
          'condition': input['condition'],
          'receivedByName': context['currentUserName'],
          'version': ((row['version'] as num?)?.toInt() ?? 0) + 1,
        });
        body = row;
      } else if (path.endsWith('/returns') && request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final sale = (sales ?? const []).firstWhere(
          (value) => value['id'] == input['saleId'],
        );
        final approver = (context['returnApprovers'] as List).firstWhere(
          (value) => value['id'] == input['approverId'],
        );
        final row = <String, dynamic>{
          'id': customerReturnRows.length + 1,
          'saleId': sale['id'],
          'receiptReference': sale['receiptReference'] ?? 'SHOP-TEST',
          'buyerName': sale['studentName'] ?? sale['buyerName'],
          'requestType': 'CUSTOMER_RETURN',
          'status': 'PENDING_APPROVAL',
          'reason': input['reason'],
          'requestedBy': context['currentUserId'],
          'requestedByName': context['currentUserName'],
          'approverId': approver['id'],
          'approverName': approver['name'],
          'requestedAt': [2026, 9, 3, 10, 0, 0],
          'refundAmount': 8,
          'version': 0,
          'lines': input['lines'],
        };
        customerReturnRows.insert(0, row);
        body = row;
      } else if (path.endsWith('/returns')) {
        body = customerReturnRows;
      } else if (path.contains('/returns/') && path.endsWith('/decision')) {
        final id = int.parse(path.split('/')[path.split('/').length - 2]);
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final row = customerReturnRows.firstWhere((value) => value['id'] == id);
        row['status'] = input['action'] == 'APPROVE'
            ? 'REFUND_PENDING'
            : 'REJECTED';
        row['version'] = ((row['version'] as num?)?.toInt() ?? 0) + 1;
        body = row;
      } else if (path.contains('/returns/') && path.endsWith('/refund')) {
        final id = int.parse(path.split('/')[path.split('/').length - 2]);
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final row = customerReturnRows.firstWhere((value) => value['id'] == id);
        row.addAll({
          'status': 'COMPLETED',
          'refundMethod': input['method'],
          'refundReference': input['reference'],
          'refundedByName': context['currentUserName'],
          'version': ((row['version'] as num?)?.toInt() ?? 0) + 1,
        });
        body = row;
      } else if (path.endsWith('/cancellation-requests') &&
          request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        final reference = path.split('/')[path.split('/').length - 2];
        final receipt = receipts.firstWhere(
          (value) => value['reference'] == reference,
        );
        final approver = (context['returnApprovers'] as List).firstWhere(
          (value) => value['id'] == input['approverId'],
        );
        final row = <String, dynamic>{
          'id': customerReturnRows.length + 1,
          'saleId': receipt['sale']['id'] ?? 1,
          'receiptReference': reference,
          'buyerName': receipt['sale']['buyerName'] ?? 'Buyer',
          'requestType': 'UNCOLLECTED_CANCELLATION',
          'status': 'PENDING_APPROVAL',
          'reason': input['reason'],
          'requestedBy': context['currentUserId'],
          'requestedByName': context['currentUserName'],
          'approverId': approver['id'],
          'approverName': approver['name'],
          'requestedAt': [2026, 9, 3, 10, 0, 0],
          'refundAmount': receipt['sale']['totalAmount'],
          'version': 0,
          'lines': receipt['sale']['lines'],
        };
        customerReturnRows.insert(0, row);
        body = row;
      } else if (path.endsWith('/sales/consignment') &&
          request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        onSaleSaved?.call(input);
        body = {'reference': 'SHOP-TEST-1', 'status': 'COLLECTED'};
      } else if (path.endsWith('/receipts') && request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        onSaleSaved?.call(input);
        body = {
          'reference': 'SHOP-TEST-1',
          'pickupToken': '123456',
          'status': 'PENDING_COLLECTION',
        };
      } else if (path.endsWith('/sales')) {
        body =
            sales ??
            [
              for (final receipt in receipts)
                {
                  ...Map<String, dynamic>.from(receipt['sale'] as Map),
                  'receiptReference': receipt['reference'],
                  'createdAt': receipt['issuedAt'],
                  'status': receipt['status'],
                  'processedByName': receipt['cashierName'],
                },
            ];
      } else if (path.endsWith('/roles') && request.method == 'PUT') {
        final changes = (jsonDecode(request.body) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        for (final change in changes) {
          onSellerChanged?.call(change);
          final index = shopRoleRows.indexWhere(
            (row) =>
                row['userId'] == change['userId'] &&
                row['roleCode'] == change['roleCode'],
          );
          final staff = (context['staff'] as List? ?? const []).cast<Map>();
          final person = staff.cast<Map<String, dynamic>>().firstWhere(
            (row) => row['id'] == change['userId'],
          );
          final updated = <String, dynamic>{
            if (index >= 0) ...shopRoleRows[index],
            'id': index >= 0
                ? shopRoleRows[index]['id']
                : 100 + shopRoleRows.length,
            'userId': change['userId'],
            'userName': person['name'],
            'roleCode': 'SELLER',
            'active': change['active'],
          };
          if (index >= 0) {
            shopRoleRows[index] = updated;
          } else {
            shopRoleRows.add(updated);
          }
        }
        body = shopRoleRows;
      } else if (path.endsWith('/roles')) {
        body = shopRoleRows;
      } else if (path.endsWith('/reconciliations') ||
          path.endsWith('/period-reconciliations') ||
          path.endsWith('/cash-handovers')) {
        body = [];
      } else if (path.endsWith('/audit')) {
        body = auditEvents;
      } else if (path.endsWith('/custody/available')) {
        body = consignments;
      } else if (path.endsWith('/consignments') && request.method == 'POST') {
        final input = Map<String, dynamic>.from(jsonDecode(request.body));
        onStockIssued?.call(input);
        body = {'id': 90, ...input, 'status': 'PENDING_ACCEPTANCE'};
      } else if (path.endsWith('/consignments')) {
        body = consignments;
      } else if (path.endsWith('/receipts')) {
        body = receipts;
      } else {
        return http.Response(jsonEncode({'message': 'unexpected $path'}), 404);
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return MaterialApp(
      home: Scaffold(
        body: SchoolShopScreen(
          api: ShopApiClient(schoolId: 'SCH-1', client: client),
        ),
      ),
    );
  }

  testWidgets(
    'administrator sees control pages and catalogue editor stays simple',
    (tester) async {
      await tester.pumpWidget(
        appWith({
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [],
          'roleOptions': ['BUYER', 'SELLER', 'CASHIER', 'GOODS_STAFF'],
          'units': ['piece', 'book'],
          'categories': ['Books', 'Stationery'],
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('School Shop'), findsOneWidget);
      expect(find.text('Item types'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Sellers'), findsOneWidget);
      expect(find.text('Reconciliation'), findsOneWidget);
      expect(find.text('Cash remittances'), findsOneWidget);

      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Cash remittances'),
          )
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-remit-cash')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-start-reconciliation')),
        findsNothing,
      );

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Reconciliation'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shop-start-reconciliation')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('shop-remit-cash')), findsNothing);

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shop-item-types-table')),
        findsOneWidget,
      );
      expect(find.text('Add item type'), findsOneWidget);
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('shop-item-type-actions-1')),
          )
          .onSelected!('edit');
      await tester.pumpAndSettle();
      expect(find.text('Edit item type'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-type-category')), findsOneWidget);
      expect(find.text('Parent item (optional)'), findsNothing);
      expect(find.text('Unit cost price (GHS)'), findsNothing);
      expect(find.text('Unit selling price (GHS)'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('shop-item-type-actions-1')),
          )
          .onSelected!('toggle-active');
      await tester.pumpAndSettle();
      expect(find.text('Item type still has stock'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(find.text('Current stock'), findsOneWidget);
      expect(find.text('Stock history'), findsOneWidget);
      expect(find.text('Stock received'), findsNothing);
      expect(find.text('Add item type'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shop-add-stock')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Add stock'),
        ),
        findsOneWidget,
      );
      expect(find.text('Record stock entering the shop'), findsOneWidget);
      expect(find.textContaining('does not create an expense'), findsOneWidget);
      expect(find.text('Quantity received'), findsOneWidget);
      expect(find.text('Select item'), findsOneWidget);
      expect(
        find.text('Search by name or item code, then select a result'),
        findsOneWidget,
      );
      expect(find.text('Unit cost price (GHS)'), findsOneWidget);
      expect(find.text('Unit selling price (GHS)'), findsOneWidget);
      expect(find.text('LINE TOTAL'), findsOneWidget);
      expect(find.text('GHS 0.00'), findsOneWidget);
      expect(find.text('Additional details'), findsOneWidget);
      expect(find.text('Stock source (optional)'), findsNothing);
      expect(find.text('Source name (optional)'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('stock-additional-details')),
      );
      await tester.tap(find.byKey(const ValueKey('stock-additional-details')));
      await tester.pumpAndSettle();
      expect(find.text('Stock source (optional)'), findsNothing);
      expect(find.text('Source name (optional)'), findsNothing);
      expect(find.text('Existing record reference (optional)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('purchase-item-search-1')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-add-another-item')),
      );
      await tester.tap(find.byKey(const ValueKey('purchase-add-another-item')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('purchase-item-search-1')),
        findsNothing,
      );
      expect(
        find.textContaining('Complete this item before adding another'),
        findsWidgets,
      );

      tester
          .widget<DropdownMenu<int>>(
            find.byKey(const ValueKey('purchase-item-search-0')),
          )
          .onSelected!(1);
      await tester.pumpAndSettle();
      final selectedSearch = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('purchase-item-search-0')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        selectedSearch.controller!.text,
        contains('Exercise Book · 80 pages'),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('purchase-cost-0')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('purchase-selling-0')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('purchase-quantity-0'))).width,
        greaterThanOrEqualTo(180),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('purchase-cost-0'))).width,
        greaterThanOrEqualTo(220),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('purchase-selling-0'))).width,
        greaterThanOrEqualTo(220),
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-cost-0')),
        '6',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-selling-0')),
        '8',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-add-another-item')),
      );
      await tester.tap(find.byKey(const ValueKey('purchase-add-another-item')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('purchase-item-search-1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('purchase-line-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('purchase-line-1')), findsOneWidget);
    },
  );

  testWidgets(
    'item type accepts a new typed category and leaves pricing to inventory',
    (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        appWith({
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': false,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': <dynamic>[],
          'roleOptions': ['BUYER'],
          'units': ['piece', 'pack'],
          'categories': ['Books', 'Stationery'],
        }, onItemSaved: (input) => submitted = input),
      );
      await tester.pumpAndSettle();

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shop-add-item-type')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('item-type-name')),
        'Rice portion',
      );
      final category = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('item-type-category')),
      );
      expect(find.text('Other / Add new category'), findsNothing);
      category.onChanged!('__OTHER__');
      await tester.pumpAndSettle();
      expect(find.text('New category name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('item-type-other-category')),
        'Food',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save item type'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!['category'], 'Food');
      expect(submitted!.containsKey('parentItemId'), isFalse);
      expect(submitted!.containsKey('costPrice'), isFalse);
      expect(submitted!.containsKey('sellingPrice'), isFalse);
    },
  );

  testWidgets('item type requires a category and an Other category name', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      appWith({
        'currentUserId': 1,
        'currentUserName': 'Ama Admin',
        'isAdmin': true,
        'canBuy': true,
        'canConsign': false,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': <dynamic>[],
        'roleOptions': ['BUYER'],
        'units': ['piece'],
        'categories': ['Books', 'Other'],
      }, onItemSaved: (input) => submitted = input),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-add-item-type')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-type-name')),
      'Lunch bowl',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save item type'));
    await tester.pumpAndSettle();
    expect(find.text('Select a category'), findsOneWidget);
    expect(submitted, isNull);

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('item-type-category')),
        )
        .onChanged!('__OTHER__');
    final categoryDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('item-type-category')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(
      categoryDropdown.items!
          .where(
            (item) =>
                item.child is Text &&
                ((item.child as Text).data ?? '').startsWith('Other'),
          )
          .length,
      1,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save item type'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(submitted, isNull);
  });

  testWidgets('duplicate item code is shown against the code field', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith({
        'currentUserId': 1,
        'currentUserName': 'Ama Admin',
        'isAdmin': true,
        'canBuy': true,
        'canConsign': false,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': <dynamic>[],
        'roleOptions': ['BUYER'],
        'units': ['piece'],
        'categories': ['Books'],
      }, itemSaveError: 'This SKU is already used'),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-add-item-type')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-type-name')),
      'Exercise Book',
    );
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('item-type-category')),
        )
        .onChanged!('Books');
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('item-type-code-method')),
        )
        .onChanged!('MANUAL');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-type-code')),
      'EXB-80',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save item type'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This item code is already in use. Enter another code or choose Auto-generate.',
      ),
      findsOneWidget,
    );
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('item-type-code-method')),
        )
        .onChanged!('AUTO');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This item code is already in use. Enter another code or choose Auto-generate.',
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('item-type-code')), findsNothing);
    expect(
      find.text('A unique item code will be created when you save.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'stock entry searches a large catalogue and saves without a source',
    (tester) async {
      Map<String, dynamic>? submitted;
      final manyItems = List.generate(
        30,
        (index) => {
          'id': index + 1,
          'name': 'Book ${index + 1}',
          'displayName': 'Book ${index + 1}',
          'sku': 'BOOK-${(index + 1).toString().padLeft(2, '0')}',
          'category': 'Books',
          'unitOfMeasure': 'book',
          'costPrice': 5,
          'sellingPrice': 8,
          'centralQuantity': 2,
          'availableQuantity': 2,
          'totalOnHand': 2,
          'unassignedQuantity': 2,
          'heldQuantity': 0,
          'totalReservedQuantity': 0,
          'holders': <dynamic>[],
          'lowStockThreshold': 1,
          'lowStock': false,
          'active': true,
          'version': 0,
        },
      );
      await tester.pumpWidget(
        appWith(
          {
            'currentUserId': 1,
            'currentUserName': 'Ama Admin',
            'isAdmin': true,
            'canBuy': true,
            'canConsign': false,
            'canSell': false,
            'canTakePayment': false,
            'canRelease': false,
            'canHoldStock': false,
            'canManageRoles': true,
            'staff': <dynamic>[],
            'roleOptions': ['BUYER'],
            'units': ['piece', 'book'],
            'categories': ['Books'],
          },
          items: manyItems,
          onStockAdded: (input) => submitted = input,
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shop-add-stock')));
      await tester.pumpAndSettle();

      final menu = tester.widget<DropdownMenu<int>>(
        find.byKey(const ValueKey('purchase-item-search-0')),
      );
      expect(menu.filterCallback!(menu.dropdownMenuEntries, ''), hasLength(1));
      expect(
        menu.filterCallback!(menu.dropdownMenuEntries, 'book'),
        hasLength(16),
      );
      menu.onSelected!(1);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-cost-0')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-selling-0')),
        '8',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Add to inventory'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add to inventory'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.containsKey('sourceType'), isFalse);
      expect(submitted!.containsKey('sourceName'), isFalse);
      expect(submitted!['sourceReference'], '');
      expect((submitted!['lines'] as List), hasLength(1));
    },
  );

  testWidgets(
    'add new item from stock opens the item form and selects the saved item',
    (tester) async {
      Map<String, dynamic>? savedItem;
      Map<String, dynamic>? submittedStock;
      await tester.pumpWidget(
        appWith(
          {
            'currentUserId': 1,
            'currentUserName': 'Ama Admin',
            'isAdmin': true,
            'canBuy': true,
            'canConsign': false,
            'canSell': false,
            'canTakePayment': false,
            'canRelease': false,
            'canHoldStock': false,
            'canManageRoles': true,
            'staff': <dynamic>[],
            'roleOptions': ['BUYER'],
            'units': ['piece', 'pack'],
            'categories': ['Books', 'Stationery'],
          },
          onItemSaved: (input) => savedItem = input,
          onStockAdded: (input) => submittedStock = input,
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shop-add-stock')));
      await tester.pumpAndSettle();

      tester
          .widget<DropdownMenu<int>>(
            find.byKey(const ValueKey('purchase-item-search-0')),
          )
          .onSelected!(-1);
      await tester.pumpAndSettle();

      expect(find.text('Add item type'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-type-name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('item-type-name')),
        'Board eraser',
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('item-type-category')),
          )
          .onChanged!('Stationery');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save item type'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(find.byKey(const ValueKey('item-type-name')), findsNothing);
      final itemSearch = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('purchase-item-search-0')),
          matching: find.byType(TextField),
        ),
      );
      expect(itemSearch.controller!.text, contains('Board eraser'));

      await tester.enterText(
        find.byKey(const ValueKey('purchase-cost-0')),
        '4',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-selling-0')),
        '6',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Add to inventory'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add to inventory'));
      await tester.pumpAndSettle();

      expect(submittedStock, isNotNull);
      final line = Map<String, dynamic>.from(
        (submittedStock!['lines'] as List).single as Map,
      );
      expect(line['itemId'], 99);
      expect(line.containsKey('name'), isFalse);
      expect(line.containsKey('category'), isFalse);
    },
  );

  testWidgets('each shop table opens from its first column', (tester) async {
    await tester.pumpWidget(
      appWith({
        'currentUserId': 1,
        'currentUserName': 'Ama Admin',
        'isAdmin': true,
        'canBuy': true,
        'canConsign': true,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': [],
        'roleOptions': ['BUYER', 'SELLER', 'CASHIER', 'GOODS_STAFF'],
        'units': ['piece', 'book'],
        'categories': ['Books', 'Stationery'],
      }),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final itemTypesScroll = tester.widget<SingleChildScrollView>(
      find.byKey(
        const PageStorageKey('shop-item-types-table-horizontal-scroll'),
      ),
    );
    itemTypesScroll.controller!.jumpTo(
      itemTypesScroll.controller!.position.maxScrollExtent,
    );
    expect(itemTypesScroll.controller!.offset, greaterThan(0));

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final inventoryScroll = tester.widget<SingleChildScrollView>(
      find.byKey(
        const PageStorageKey('shop-inventory-table-horizontal-scroll'),
      ),
    );
    expect(inventoryScroll.controller!.offset, 0);

    inventoryScroll.controller!.jumpTo(
      inventoryScroll.controller!.position.maxScrollExtent,
    );
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final reopenedItemTypes = tester.widget<SingleChildScrollView>(
      find.byKey(
        const PageStorageKey('shop-item-types-table-horizontal-scroll'),
      ),
    );
    expect(reopenedItemTypes.controller!.offset, 0);
  });

  testWidgets(
    'goods officer sees paid pickup and no cashier or stock controls',
    (tester) async {
      await tester.pumpWidget(
        appWith(
          {
            'currentUserId': 4,
            'currentUserName': 'Goods Officer',
            'isAdmin': false,
            'canBuy': false,
            'canConsign': false,
            'canSell': false,
            'canTakePayment': false,
            'canRelease': true,
            'canHoldStock': false,
            'canManageRoles': false,
            'roles': ['GOODS_STAFF'],
          },
          receipts: [
            {
              'id': 3,
              'reference': 'SHOP-20260901-000003',
              'pickupToken': '482913',
              'status': 'PENDING_COLLECTION',
              'cashierName': 'Cashier',
              'version': 0,
              'sale': {
                'studentName': 'Kofi Mensah',
                'totalAmount': 8,
                'lines': [
                  {'itemName': 'Exercise Book', 'quantity': 1},
                ],
              },
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release goods'), findsOneWidget);
      expect(find.text('Take payment'), findsNothing);
      expect(find.text('Purchases'), findsNothing);
      await tester.tap(find.text('Release goods'));
      await tester.pumpAndSettle();
      expect(find.text('482913'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('shop-release-search')),
        '482913',
      );
      await tester.pump();
      expect(find.textContaining('SHOP-20260901-000003'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shop-find-order')));
      await tester.pumpAndSettle();
      expect(find.textContaining('SHOP-20260901-000003'), findsOneWidget);
      expect(find.textContaining('Token 482913'), findsNothing);
      expect(
        find.byKey(const ValueKey('shop-reopened-pickup-token')),
        findsNothing,
      );
      expect(find.text('Release'), findsOneWidget);
    },
  );

  testWidgets(
    'item types can be archived and restored without losing history',
    (tester) async {
      await tester.pumpWidget(
        appWith(
          {
            'currentUserId': 1,
            'currentUserName': 'Ama Admin',
            'isAdmin': true,
            'canBuy': true,
            'canConsign': true,
            'canSell': false,
            'canTakePayment': false,
            'canRelease': false,
            'canHoldStock': false,
            'canManageRoles': true,
            'staff': [],
            'roleOptions': ['BUYER', 'SELLER', 'CASHIER', 'GOODS_STAFF'],
            'units': ['piece'],
            'categories': ['Stationery'],
          },
          items: [
            {
              'id': 9,
              'name': 'Pencil',
              'displayName': 'Pencil',
              'sku': 'PEN-1',
              'category': 'Stationery',
              'unitOfMeasure': 'piece',
              'costPrice': 1,
              'sellingPrice': 2,
              'margin': 1,
              'centralQuantity': 0,
              'availableQuantity': 0,
              'totalOnHand': 0,
              'unassignedQuantity': 0,
              'heldQuantity': 0,
              'totalReservedQuantity': 0,
              'holders': [],
              'lowStockThreshold': 2,
              'lowStock': true,
              'active': true,
              'version': 0,
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('shop-item-type-actions-9')),
          )
          .onSelected!('toggle-active');
      await tester.pumpAndSettle();
      expect(find.text('Archive item type?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(find.textContaining('No active item types'), findsOneWidget);
      expect(find.text('Pencil'), findsNothing);

      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Item types'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('shop-item-type-actions-9')),
          )
          .onSelected!('toggle-active');
      await tester.pumpAndSettle();
      expect(find.text('Restore item type?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-item-type-actions-9')),
        findsOneWidget,
      );
    },
  );

  testWidgets('inventory adjustment waits for approval before changing stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith({
        'currentUserId': 1,
        'currentUserName': 'Ama Admin',
        'isAdmin': true,
        'canBuy': true,
        'canAdjustInventory': true,
        'canConsign': true,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': [],
        'inventoryApprovers': [
          {'id': 2, 'name': 'Kofi Reviewer'},
        ],
        'roleOptions': ['BUYER', 'SELLER', 'CASHIER', 'GOODS_STAFF'],
        'units': ['piece', 'book'],
        'categories': ['Books'],
      }),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.text('Adjustments'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shop-inventory-adjustments-table')),
      findsNothing,
    );

    final inventory = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-inventory-table')),
    );
    inventory.rows.first.cells.first.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Item information'), findsOneWidget);
    expect(find.text('Held for inspection'), findsOneWidget);
    expect(
      find.textContaining(
        'Held for inspection means returned, damaged or questionable stock',
      ),
      findsOneWidget,
    );
    tester
        .widget<TextButton>(
          find.byKey(const ValueKey('shop-request-adjustment-1')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Request inventory adjustment'), findsOneWidget);
    expect(
      find.textContaining('Current unassigned quantity: 12 book'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('inventory-adjustment-quantity')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('inventory-adjustment-reason')),
      'Three books were damaged by water',
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposed change: 12 → 9 book'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inventory-adjustment-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adjustments'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-inventory-adjustments-table')),
      findsOneWidget,
    );
    expect(find.text('12 → 9 book'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
    await tester.tap(find.text('Current stock'));
    await tester.pumpAndSettle();
    expect(find.text('12 book'), findsWidgets);
    tester
        .widget<DataTable>(find.byKey(const ValueKey('shop-inventory-table')))
        .rows
        .first
        .cells
        .first
        .onTap!();
    await tester.pumpAndSettle();
    final pendingButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('shop-request-adjustment-1')),
    );
    expect(pendingButton.onPressed, isNull);
  });

  testWidgets('stock received is a sortable modern table', (tester) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [],
          'roleOptions': ['BUYER', 'SELLER', 'CASHIER', 'GOODS_STAFF'],
          'units': ['piece'],
          'categories': ['Books'],
        },
        purchases: [
          {
            'id': 1,
            'supplier': 'Zeta Market',
            'purchaseDate': [2026, 8, 30],
            'buyerName': 'Zoe Buyer',
            'totalCost': 12,
            'notes': '',
            'lines': [
              {
                'itemName': 'Marker',
                'quantity': 2,
                'unitCost': 6,
                'lineTotal': 12,
              },
              {
                'itemName': 'Pencil',
                'quantity': 3,
                'unitCost': 2,
                'lineTotal': 6,
              },
            ],
          },
          {
            'id': 2,
            'supplier': 'Alpha Supplies',
            'purchaseDate': [2026, 9, 1],
            'buyerName': 'Ama Buyer',
            'totalCost': 5,
            'notes': 'Checked',
            'lines': [
              {'itemName': 'Pen', 'quantity': 5, 'unitCost': 1, 'lineTotal': 5},
            ],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
        .onSelected!(true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock history'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-stock-history-table')),
      findsOneWidget,
    );
    expect(find.text('01 Sep 2026'), findsOneWidget);
    expect(find.text('[2026, 9, 1]'), findsNothing);
    expect(find.text('Stock received'), findsNWidgets(2));

    var table = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-stock-history-table')),
    );
    expect(table.rows, hasLength(2));
    for (var column = 0; column < 5; column++) {
      table.columns[column].onSort!(column, true);
      await tester.pumpAndSettle();
      table = tester.widget<DataTable>(
        find.byKey(const ValueKey('shop-stock-history-table')),
      );
    }

    table.columns[0].onSort!(0, true);
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-stock-history-table')),
    );
    table.rows.first.cells.first.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Stock receipt details'), findsOneWidget);
    expect(
      find.textContaining('Purchased elsewhere · Zeta Market · 30/08/2026'),
      findsOneWidget,
    );
    expect(find.text('UNIT COST'), findsWidgets);
    expect(find.text('LINE TOTAL'), findsWidgets);
  });

  testWidgets('shop registers are sortable and paginated consistently', (
    tester,
  ) async {
    final items = List.generate(
      11,
      (index) => {
        'id': index + 1,
        'name': 'Item ${index + 1}',
        'displayName': 'Item ${index + 1}',
        'sku': 'ITEM-${(index + 1).toString().padLeft(2, '0')}',
        'category': index.isEven ? 'Books' : 'Uniforms',
        'unitOfMeasure': 'piece',
        'costPrice': index + 1,
        'sellingPrice': index + 3,
        'margin': 2,
        'centralQuantity': 20 - index,
        'availableQuantity': 20 - index,
        'totalOnHand': 20 - index + (index == 0 ? 7 : 0),
        'unassignedQuantity': 20 - index,
        'heldQuantity': index == 0 ? 7 : 0,
        'totalReservedQuantity': index == 0 ? 1 : 0,
        'holders': index == 0
            ? [
                {
                  'consignmentId': 1,
                  'holderName': 'Store Officer',
                  'locationName': 'Main store',
                  'status': 'ACTIVE',
                  'quantity': 7,
                  'reservedQuantity': 1,
                  'availableQuantity': 6,
                },
              ]
            : [],
        'lowStockThreshold': 3,
        'lowStock': false,
        'active': true,
        'createdAt': DateTime.now()
            .subtract(Duration(hours: index == 0 ? 1 : 48 + index))
            .toIso8601String(),
        'version': 0,
      },
    );
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [],
          'roleOptions': ['BUYER'],
          'units': ['piece'],
          'categories': ['Books', 'Uniforms'],
        },
        items: items,
        consignments: [
          {
            'id': 1,
            'sellerName': 'Store Officer',
            'itemName': 'Item 1',
            'status': 'ACTIVE',
            'assignedQuantity': 10,
            'soldQuantity': 2,
            'reservedQuantity': 1,
            'availableQuantity': 7,
            'holderId': 4,
          },
        ],
        sales: [
          {
            'id': 1,
            'createdAt': [2026, 9, 1, 14, 5, 0],
            'studentName': 'Kojo Mensah',
            'modelType': 'IMMEDIATE_RELEASE',
            'processedByName': 'Ama Admin',
            'paymentMethod': 'CASH',
            'status': 'COMPLETED',
            'totalAmount': 8,
            'profit': 2,
            'lines': [
              {
                'itemId': 1,
                'itemName': 'Item 1',
                'quantity': 1,
                'lineTotal': 8,
              },
            ],
          },
        ],
        auditEvents: [
          {
            'id': 1,
            'action': 'RETURNED',
            'entityType': 'CONSIGNMENT',
            'actorName': 'Ama Admin',
            'details': '2 pieces returned from Kofi Nketia · Unsold',
            'occurredAt': [2026, 9, 1, 16, 45, 0],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final inventoryFinder = find.byKey(const ValueKey('shop-inventory-table'));
    expect(inventoryFinder, findsOneWidget);
    var inventory = tester.widget<DataTable>(inventoryFinder);
    expect(
      inventory.columns.take(5).every((column) => column.onSort != null),
      isTrue,
    );
    expect(inventory.columns, hasLength(6));
    expect(find.text('DATE ADDED'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-new-item-1')), findsOneWidget);
    expect(find.text('27 piece'), findsOneWidget);
    inventory.rows.first.cells.first.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Item information'), findsOneWidget);
    expect(find.text('Available to sell'), findsOneWidget);
    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('shop-item-holders-1')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Who holds Item 1?'), findsOneWidget);
    expect(find.text('Store Officer'), findsOneWidget);
    expect(find.text('Main store'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.text('1-10 of 11'), findsOneWidget);

    final rowsMenu = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>).first,
    );
    rowsMenu.onChanged!(5);
    await tester.pumpAndSettle();
    expect(find.text('1-5 of 11'), findsOneWidget);
    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right).last,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('6-10 of 11'), findsOneWidget);

    inventory = tester.widget<DataTable>(inventoryFinder);
    inventory.columns[1].onSort!(1, false);
    await tester.pumpAndSettle();
    expect(tester.widget<DataTable>(inventoryFinder).sortColumnIndex, 1);

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Stock handovers'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final custody = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-stock-custody-table')),
    );
    expect(
      custody.columns.take(7).every((column) => column.onSort != null),
      isTrue,
    );

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-sales-table')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shop-item-performance-table')),
      findsOneWidget,
    );
    expect(find.text('01 Sep 2026'), findsOneWidget);
    expect(find.text('2:05 PM'), findsOneWidget);
    expect(find.textContaining('[2026, 9, 1'), findsNothing);

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Audit trail'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.text('01 Sep 2026'), findsOneWidget);
    expect(find.text('4:45 PM'), findsOneWidget);
    expect(
      find.textContaining('2 pieces returned from Kofi Nketia · Unsold'),
      findsOneWidget,
    );
  });

  testWidgets('owner shop report is period based, sortable and configurable', (
    tester,
  ) async {
    Uri? downloadedReport;
    await tester.pumpWidget(
      appWith({
        'currentUserId': 1,
        'currentUserName': 'Ama Admin',
        'isAdmin': true,
        'canBuy': true,
        'canConsign': true,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': [],
        'roleOptions': ['BUYER'],
        'units': ['book'],
        'categories': ['Books'],
      }, onReportDownload: (uri) => downloadedReport = uri),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Reports'))
        .onSelected!(true);
    await tester.pumpAndSettle();

    expect(find.text('Shop accounting report'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'This term'), findsOneWidget);
    expect(find.textContaining('Custom dates: From'), findsOneWidget);
    expect(find.text('GHS 32.00'), findsWidgets);
    expect(
      find.byKey(const ValueKey('shop-accounting-sales-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-accounting-reconciliations-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-accounting-adjustments-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-accounting-remittances-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-accounting-cash-held-table')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('shop-export-accounting-csv')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('shop-report-sales-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-report-performance-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-report-inventory-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-report-staff-stock-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shop-report-returns-table')),
      findsOneWidget,
    );
    final salesTable = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-report-sales-table')),
    );
    expect(salesTable.columns.every((column) => column.onSort != null), isTrue);
    for (final key in const [
      'shop-accounting-sales-table',
      'shop-accounting-adjustments-table',
      'shop-accounting-reconciliations-table',
      'shop-accounting-remittances-table',
      'shop-accounting-cash-held-table',
    ]) {
      final table = tester.widget<DataTable>(find.byKey(ValueKey(key)));
      expect(table.columns.every((column) => column.onSort != null), isTrue);
    }

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Last 7 days'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Last 7 days'))
          .selected,
      isTrue,
    );

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'This term'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'This term'))
          .selected,
      isTrue,
    );
    expect(
      find.textContaining('Custom dates: From 25 Aug 2026 to'),
      findsOneWidget,
    );

    tester
        .widget<FilterChip>(
          find.byKey(const ValueKey('shop-report-section-INVENTORY')),
        )
        .onSelected!(false);
    await tester.pump();
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('shop-download-report')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(downloadedReport, isNotNull);
    expect(
      downloadedReport!.queryParameters['sections'],
      isNot(contains('INVENTORY')),
    );
    expect(downloadedReport!.queryParameters['sections'], contains('SALES'));
  });

  testWidgets('bursar can open reports and manage sellers', (tester) async {
    await tester.pumpWidget(
      appWith({
        'currentUserId': 5,
        'currentUserName': 'School Bursar',
        'isAdmin': false,
        'canViewReports': true,
        'canBuy': false,
        'canConsign': false,
        'canSell': false,
        'canTakePayment': false,
        'canRelease': false,
        'canHoldStock': false,
        'canManageRoles': true,
        'staff': [],
        'roleOptions': [],
        'units': ['book'],
        'categories': ['Books'],
      }),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Reports'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Item types'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Sellers'), findsOneWidget);
  });

  testWidgets('seller can give only stock they personally hold', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 7,
          'currentUserName': 'Ama Seller',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': true,
          'canTakePayment': false,
          'canRelease': true,
          'canHoldStock': true,
          'canManageRoles': false,
          'roles': ['SELLER'],
        },
        consignments: [
          {
            'id': 11,
            'holderId': 7,
            'holderName': 'Ama Seller',
            'itemId': 1,
            'itemName': 'My Exercise Book',
            'status': 'ACTIVE',
            'availableQuantity': 5,
            'sellingPrice': 8,
          },
          {
            'id': 12,
            'holderId': 9,
            'holderName': 'Other Staff',
            'itemId': 2,
            'itemName': 'Other Staff Marker',
            'status': 'ACTIVE',
            'availableQuantity': 4,
            'sellingPrice': 6,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sell items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell and hand over now'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shop-sale-item-search-0')),
      'My Exercise',
    );
    await tester.pump();

    expect(
      find.text('My Exercise Book · 5 available · GHS 8.00 each'),
      findsOneWidget,
    );
    expect(find.textContaining('Other Staff Marker'), findsNothing);
  });

  testWidgets('stock issue shows a persistent maximum quantity warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [
            {'id': 9, 'name': 'Kofi Storekeeper'},
          ],
          'roleOptions': ['SELLER'],
          'units': ['book'],
          'categories': ['Books'],
        },
        shopRoles: const [
          {
            'id': 1,
            'userId': 9,
            'userName': 'Kofi Storekeeper',
            'roleCode': 'SELLER',
            'active': true,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Stock handovers'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare handover').last);
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('issue-stock-recipient')),
        )
        .onChanged!(9);
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('issue-stock-item')),
        )
        .onChanged!(1);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('issue-stock-quantity')),
      '13',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('issue-stock-restriction')),
      findsOneWidget,
    );
    expect(find.textContaining('Only 12 book are available'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('issue-stock-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('inventory action issues only a valid in-stock item', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canAdjustInventory': false,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [
            {'id': 9, 'name': 'Kofi Storekeeper'},
          ],
          'roleOptions': ['BUYER'],
          'units': ['book'],
          'categories': ['Books'],
        },
        shopRoles: const [
          {
            'id': 1,
            'userId': 9,
            'userName': 'Kofi Storekeeper',
            'roleCode': 'SELLER',
            'active': true,
          },
        ],
        items: [
          {
            'id': 1,
            'name': 'Exercise Book',
            'displayName': 'Exercise Book · 80 pages',
            'sku': 'EXB-80',
            'category': 'Books',
            'unitOfMeasure': 'book',
            'costPrice': 6,
            'sellingPrice': 8,
            'centralQuantity': 12,
            'availableQuantity': 12,
            'totalOnHand': 12,
            'unassignedQuantity': 12,
            'heldQuantity': 0,
            'totalReservedQuantity': 0,
            'lowStockThreshold': 3,
            'active': true,
            'version': 0,
          },
          {
            'id': 2,
            'name': 'Pencil',
            'displayName': 'Pencil',
            'sku': 'PEN-1',
            'category': 'Stationery',
            'unitOfMeasure': 'piece',
            'costPrice': 1,
            'sellingPrice': 2,
            'centralQuantity': 0,
            'availableQuantity': 0,
            'totalOnHand': 4,
            'unassignedQuantity': 0,
            'heldQuantity': 4,
            'totalReservedQuantity': 0,
            'lowStockThreshold': 2,
            'active': true,
            'version': 0,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inventory'))
        .onSelected!(true);
    await tester.pumpAndSettle();

    tester
        .state<PopupMenuButtonState<String>>(
          find.byKey(const ValueKey('shop-inventory-actions-1')),
        )
        .showButtonMenu();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare handover').last);
    await tester.pumpAndSettle();

    expect(find.text('Prepare stock handover'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey('issue-stock-item')),
          )
          .initialValue,
      1,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    tester
        .state<PopupMenuButtonState<String>>(
          find.byKey(const ValueKey('shop-inventory-actions-2')),
        )
        .showButtonMenu();
    await tester.pumpAndSettle();
    expect(
      find.text('Prepare handover — none available in central store'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text(
                'Prepare handover — none available in central store',
              ),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('stock issue requires a final confirmation with its effect', (
    tester,
  ) async {
    Map<String, dynamic>? issued;
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Admin',
          'isAdmin': true,
          'canBuy': true,
          'canAdjustInventory': false,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [
            {'id': 9, 'name': 'Kofi Storekeeper'},
          ],
          'roleOptions': ['SELLER'],
          'units': ['book'],
          'categories': ['Books'],
        },
        shopRoles: const [
          {
            'id': 1,
            'userId': 9,
            'userName': 'Kofi Storekeeper',
            'roleCode': 'SELLER',
            'active': true,
          },
        ],
        onStockIssued: (input) => issued = input,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Stock handovers'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare handover').last);
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('issue-stock-recipient')),
        )
        .onChanged!(9);
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('issue-stock-item')),
        )
        .onChanged!(1);
    await tester.enterText(
      find.byKey(const ValueKey('issue-stock-quantity')),
      '3',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('issue-stock-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Prepare this handover?'), findsOneWidget);
    expect(
      find.text(
        'Reserve 3 book of Exercise Book · 80 pages for Kofi Storekeeper?',
      ),
      findsOneWidget,
    );
    expect(find.text('AVAILABLE STOCK AFTER RESERVATION'), findsOneWidget);
    expect(find.text('12 → 9 book'), findsOneWidget);
    expect(issued, isNull);

    await tester.tap(find.byKey(const ValueKey('confirm-stock-issue')));
    await tester.pumpAndSettle();
    expect(issued, isNotNull);
    expect(issued!['sellerId'], 9);
    expect(issued!['itemId'], 1);
    expect(issued!['quantity'], 3);
  });

  testWidgets('stock recipient confirms physical receipt in a popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 9,
          'currentUserName': 'Kofi Storekeeper',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': true,
          'canManageRoles': false,
          'staff': <dynamic>[],
          'roleOptions': <dynamic>[],
          'units': ['book'],
          'categories': ['Books'],
        },
        consignments: [
          {
            'id': 5,
            'holderId': 9,
            'sellerName': 'Kofi Storekeeper',
            'itemName': 'Exercise Book · 80 pages',
            'unitOfMeasure': 'book',
            'status': 'PENDING_ACCEPTANCE',
            'assignedQuantity': 4,
            'soldQuantity': 0,
            'reservedQuantity': 0,
            'availableQuantity': 0,
            'remainingQuantity': 4,
            'version': 0,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'My stock'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm receipt'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Confirm stock received?'), findsOneWidget);
    expect(find.text('4 book · Exercise Book · 80 pages'), findsOneWidget);
    expect(
      find.textContaining('physically received and counted this stock'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Back').last);
    await tester.pumpAndSettle();
    expect(find.text('Confirm stock received?'), findsNothing);
  });

  testWidgets('sale accepts a staff member as the buyer', (tester) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 7,
          'currentUserName': 'Ama Seller',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': true,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': true,
          'canManageRoles': false,
          'roles': ['SELLER'],
          'staff': [
            {'id': 8, 'name': 'Yaw Teacher'},
          ],
        },
        consignments: [
          {
            'id': 11,
            'holderId': 7,
            'holderName': 'Ama Seller',
            'itemId': 1,
            'itemName': 'Exercise Book',
            'status': 'ACTIVE',
            'availableQuantity': 5,
            'sellingPrice': 8,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sell items'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell and hand over now'));
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('shop-buyer-type')),
        )
        .onChanged!('STAFF');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-staff-buyer')), findsNothing);
    expect(
      find.byKey(const ValueKey('shop-staff-buyer-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('shop-staff-buyer-search')),
      'Yaw',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('shop-staff-suggestions')),
      findsOneWidget,
    );
    await tester.tap(find.text('Yaw Teacher'));
    await tester.pump();
    expect(find.text('Staff member selected'), findsOneWidget);
  });

  testWidgets('student search suggests matches as the cashier types', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 7,
          'currentUserName': 'Ama Seller',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': true,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': true,
          'canManageRoles': false,
          'roles': ['SELLER'],
          'staff': [],
        },
        consignments: [
          {
            'id': 11,
            'holderId': 7,
            'holderName': 'Ama Seller',
            'itemId': 1,
            'itemName': 'Exercise Book',
            'status': 'ACTIVE',
            'availableQuantity': 5,
            'sellingPrice': 8,
          },
        ],
        studentDirectory: [
          {
            'name': 'Ama Boateng',
            'customStudentId': 'STU-100',
            'className': 'Basic 3',
            'section': 'Section 1',
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sell items'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell and hand over now'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('shop-student-buyer-search')),
      'Ama',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-student-suggestions')),
      findsOneWidget,
    );
    expect(find.text('Ama Boateng'), findsOneWidget);
    expect(find.textContaining('STU-100'), findsOneWidget);
    await tester.tap(find.text('Ama Boateng'));
    await tester.pump();
    expect(find.text('Selected · STU-100'), findsOneWidget);
  });

  testWidgets('an unmatched typed staff name remains usable as the buyer', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 7,
          'currentUserName': 'Ama Seller',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': true,
          'canTakePayment': false,
          'canRelease': false,
          'canHoldStock': true,
          'canManageRoles': false,
          'roles': ['SELLER'],
          'staff': [
            {'id': 8, 'name': 'Yaw Teacher'},
          ],
        },
        consignments: [
          {
            'id': 11,
            'holderId': 7,
            'holderName': 'Ama Seller',
            'itemId': 1,
            'itemName': 'Exercise Book',
            'status': 'ACTIVE',
            'availableQuantity': 5,
            'sellingPrice': 8,
          },
        ],
        onSaleSaved: (input) => submitted = input,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sell items'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell and hand over now'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('shop-buyer-type')),
        )
        .onChanged!('STAFF');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shop-staff-buyer-search')),
      'Visiting Coach',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('shop-sale-item-search-0')),
      'Exercise',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('shop-sale-item-suggestions-0')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text('Exercise Book · 5 available · GHS 8.00 each'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise Book · 5 available · GHS 8.00 each'));
    await tester.pump();
    await tester.ensureVisible(find.text('Record payment and release'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment and release'));
    await tester.pumpAndSettle();

    expect(submitted?['buyerType'], 'STAFF');
    expect(submitted?['buyerUserId'], isNull);
    expect(submitted?['buyerName'], 'Visiting Coach');
  });

  testWidgets(
    'cashier receives payment from Sales and searches available items',
    (tester) async {
      await tester.pumpWidget(
        appWith(
          {
            'currentUserId': 6,
            'currentUserName': 'Ama Cashier',
            'schoolName': 'Sunrise Academy',
            'isAdmin': false,
            'canBuy': false,
            'canConsign': false,
            'canSell': false,
            'canTakePayment': true,
            'canRelease': false,
            'canHoldStock': false,
            'canManageRoles': false,
            'roles': ['CASHIER'],
            'staff': [],
          },
          consignments: [
            {
              'id': 11,
              'holderId': 9,
              'holderName': 'Kofi Storekeeper',
              'locationName': 'Main store',
              'itemId': 1,
              'itemName': 'Exercise Book · 80 pages',
              'status': 'ACTIVE',
              'availableQuantity': 25,
              'sellingPrice': 8,
            },
          ],
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
          .onSelected!(true);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Take payment'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shop-receive-payment')));
      await tester.pumpAndSettle();
      expect(find.text('Sell for later collection'), findsWidgets);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('shop-student-buyer-search')),
        'Ama Customer',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('shop-sale-item-search-0')),
        '80 pages',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('shop-sale-item-suggestions-0')),
        findsOneWidget,
      );
      expect(
        find.text('Exercise Book · 80 pages · 25 available · GHS 8.00 each'),
        findsOneWidget,
      );
      expect(
        find.text('Held by Kofi Storekeeper · Main store'),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Exercise Book · 80 pages · 25 available · GHS 8.00 each'),
      );
      await tester.pump();
      expect(
        find.text('Exercise Book · 80 pages · 25 available · GHS 8.00 each'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Receive payment and create token'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receive payment and create token'));
      await tester.pumpAndSettle();

      expect(find.text('Payment received'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-receipt-preview')),
        findsOneWidget,
      );
      expect(find.text('Sunrise Academy'), findsOneWidget);
      expect(find.text('SHOP-TEST-1'), findsOneWidget);
      expect(find.text('Ama Customer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shop-receipt-preview')),
          matching: find.text('Exercise Book · 80 pages'),
        ),
        findsOneWidget,
      );
      expect(find.text('GHS 8.00 each'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-receipt-total')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-receipt-token')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-share-receipt')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-download-receipt')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('shop-print-receipt')), findsOneWidget);
    },
  );

  test('shop receipt PDF contains a complete printable document', () async {
    final bytes = await buildShopReceiptPdf(
      schoolName: 'Sunrise Academy',
      receipt: {
        'reference': 'SHOP-20260904-000101',
        'status': 'PENDING_COLLECTION',
        'pickupToken': '482913',
        'issuedAt': '2026-09-04T14:41:00',
        'cashierName': 'Ama Cashier',
        'custodianName': 'Kofi Storekeeper',
        'sale': {
          'buyerName': 'Ama Customer',
          'paymentMethod': 'CASH',
          'totalAmount': 24,
          'lines': [
            {
              'itemName': 'Exercise Book · 80 pages',
              'quantity': 3,
              'unitPrice': 8,
              'lineTotal': 24,
            },
          ],
        },
      },
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('issuing cashier can reopen a receipt and its token', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 6,
          'currentUserName': 'Ama Cashier',
          'isAdmin': false,
          'canBuy': false,
          'canConsign': false,
          'canSell': false,
          'canTakePayment': true,
          'canRelease': false,
          'canHoldStock': false,
          'canManageRoles': false,
          'roles': ['CASHIER'],
          'staff': [],
        },
        receipts: [
          {
            'id': 20,
            'reference': 'SHOP-20260901-000020',
            'pickupToken': '642519',
            'status': 'PENDING_COLLECTION',
            'cashierName': 'Ama Cashier',
            'issuedAt': '2026-09-04T14:41:00',
            'version': 0,
            'sale': {
              'id': 30,
              'buyerType': 'STAFF',
              'buyerName': 'Yaw Teacher',
              'paymentMethod': 'CASH',
              'totalAmount': 16,
              'lines': [
                {
                  'itemId': 1,
                  'itemName': 'Exercise Book',
                  'quantity': 2,
                  'unitPrice': 8,
                  'lineTotal': 16,
                },
              ],
            },
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Take payment'), findsNothing);
    expect(find.text('Sales history'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-receive-payment')), findsOneWidget);
    final paymentTable = tester.widget<DataTable>(
      find.byKey(const ValueKey('shop-sales-table')),
    );
    expect(paymentTable.sortColumnIndex, 0);
    expect(paymentTable.sortAscending, isFalse);
    expect(find.text('04 Sep 2026'), findsOneWidget);
    expect(find.text('2:41 PM'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('SHOP-20260901-000020'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('shop-sales-table-sort-date')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-sales-table-sort-date')));
    await tester.pump();
    expect(
      tester
          .widget<DataTable>(find.byKey(const ValueKey('shop-sales-table')))
          .sortAscending,
      isTrue,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('shop-view-sale-receipt-30')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-view-sale-receipt-30')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-receipt-preview')), findsOneWidget);
    expect(find.text('Yaw Teacher'), findsWidgets);
    expect(find.text('Paid · Awaiting collection'), findsOneWidget);
    expect(find.text('642519'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-receipt-token')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-print-receipt')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-download-receipt')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-share-receipt')), findsOneWidget);
  });

  testWidgets('customer return is requested from the original sale', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Cashier',
          'isAdmin': true,
          'canBuy': true,
          'canTakePayment': true,
          'canIssueRefunds': true,
          'returnApprovers': [
            {'id': 2, 'name': 'Kofi Reviewer'},
          ],
          'staff': [],
        },
        sales: [
          {
            'id': 30,
            'receiptReference': 'SHOP-20260903-000030',
            'buyerName': 'Ama Customer',
            'studentName': 'Ama Customer',
            'modelType': 'IMMEDIATE_RELEASE',
            'processedByName': 'Ama Cashier',
            'paymentMethod': 'CASH',
            'status': 'COLLECTED',
            'totalAmount': 8,
            'profit': 2,
            'createdAt': [2026, 9, 3, 9, 0, 0],
            'lines': [
              {
                'id': 31,
                'itemId': 1,
                'itemName': 'Exercise Book',
                'quantity': 1,
                'returnableQuantity': 1,
                'lineTotal': 8,
              },
            ],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<TextButton>(find.byKey(const ValueKey('shop-open-sale-30')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-start-return-30')));
    await tester.pumpAndSettle();
    expect(find.text('Request customer return'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('customer-return-reason')),
      'Wrong exercise book',
    );
    await tester.tap(find.byKey(const ValueKey('customer-return-submit')));
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Returns'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.text('Ama Customer'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.text('GHS 8.00'), findsOneWidget);
  });

  testWidgets('paid uncollected order can request cancellation approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 6,
          'currentUserName': 'Ama Cashier',
          'isAdmin': true,
          'canBuy': true,
          'canTakePayment': true,
          'canRequestReturns': true,
          'returnApprovers': [
            {'id': 2, 'name': 'Kofi Reviewer'},
          ],
          'staff': [],
        },
        receipts: [
          {
            'id': 20,
            'reference': 'SHOP-20260903-000020',
            'pickupToken': '642519',
            'status': 'PENDING_COLLECTION',
            'cashierName': 'Ama Cashier',
            'version': 0,
            'sale': {
              'id': 30,
              'buyerName': 'Yaw Teacher',
              'totalAmount': 16,
              'lines': [
                {
                  'itemId': 1,
                  'itemName': 'Exercise Book',
                  'quantity': 2,
                  'lineTotal': 16,
                },
              ],
            },
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('shop-view-sale-receipt-30')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-view-sale-receipt-30')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('shop-request-cancellation-20')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request order cancellation'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Buyer cancelled');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit for approval'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Returns'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.text('Cancel uncollected order'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
  });

  testWidgets('approver approves and cashier records the refund', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 2,
          'currentUserName': 'Kofi Reviewer',
          'isAdmin': true,
          'canBuy': true,
          'canTakePayment': true,
          'canIssueRefunds': true,
          'staff': [],
        },
        customerReturns: [
          {
            'id': 70,
            'saleId': 30,
            'receiptReference': 'SHOP-20260903-000030',
            'buyerName': 'Ama Customer',
            'requestType': 'CUSTOMER_RETURN',
            'status': 'PENDING_APPROVAL',
            'reason': 'Wrong exercise book',
            'requestedBy': 1,
            'requestedByName': 'Ama Cashier',
            'approverId': 2,
            'approverName': 'Kofi Reviewer',
            'requestedAt': [2026, 9, 3, 10, 0, 0],
            'refundAmount': 8,
            'version': 0,
            'lines': [
              {
                'itemName': 'Exercise Book',
                'quantity': 1,
                'condition': 'GOOD',
                'lineTotal': 8,
              },
            ],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Returns'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('shop-approve-return-70')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-issue-refund-70')), findsOneWidget);
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('shop-issue-refund-70')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Issue customer refund'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('refund-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('store person counts a staff hand-back before stock returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 4,
          'currentUserName': 'Store Officer',
          'isAdmin': false,
          'canBuy': false,
          'canReceiveStaffReturns': true,
          'staff': [],
        },
        staffReturns: [
          {
            'id': 60,
            'holderId': 3,
            'holderName': 'Yaw Seller',
            'itemName': 'Exercise Book',
            'requestedQuantity': 2,
            'status': 'PENDING_RECEIPT',
            'requestedAt': [2026, 9, 3, 11, 0, 0],
            'version': 0,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Returns'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('shop-receive-staff-return-60')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Quantity physically received'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('staff-return-receive-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('manager searches for staff and manages seller access', (
    tester,
  ) async {
    final changes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Manager',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': true,
          'canRelease': true,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [
            {
              'id': 7,
              'name': 'Yaw Owusu',
              'username': 'yaw.owusu',
              'schoolRole': 'CLASS_TEACHER',
            },
            {
              'id': 8,
              'name': 'Esi Boateng',
              'username': 'esi.boateng',
              'schoolRole': 'SECRETARY',
            },
          ],
          'roleOptions': ['SELLER'],
          'units': ['book'],
          'categories': ['Books'],
        },
        shopRoles: const [
          {
            'id': 1,
            'userId': 8,
            'userName': 'Esi Boateng',
            'roleCode': 'SELLER',
            'active': true,
          },
        ],
        onSellerChanged: (value) => changes.add(value),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sellers'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-sellers-table')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shop-add-seller')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shop-seller-search')),
      'Yaw',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shop-seller-result-7')));
    await tester.pumpAndSettle();

    expect(changes.last, {'userId': 7, 'roleCode': 'SELLER', 'active': true});
    expect(find.text('Yaw Owusu'), findsOneWidget);

    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('shop-disable-seller-7')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-disable-seller')));
    await tester.pumpAndSettle();
    expect(changes.last['active'], isFalse);
    expect(find.byKey(const ValueKey('shop-restore-seller-7')), findsOneWidget);

    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('shop-restore-seller-7')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(changes.last['active'], isTrue);
  });

  testWidgets('manager can inspect and focus the shop on one seller', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        {
          'currentUserId': 1,
          'currentUserName': 'Ama Manager',
          'isAdmin': true,
          'canBuy': true,
          'canConsign': true,
          'canSell': false,
          'canTakePayment': false,
          'canRelease': true,
          'canHoldStock': false,
          'canManageRoles': true,
          'staff': [
            {
              'id': 7,
              'name': 'Kofi Nketia',
              'username': 'kofi',
              'schoolRole': 'CLASS_TEACHER',
            },
            {
              'id': 8,
              'name': 'Adjoa Mensah',
              'username': 'adjoa',
              'schoolRole': 'SECRETARY',
            },
          ],
          'roleOptions': ['SELLER'],
          'units': ['book'],
          'categories': ['Books'],
        },
        shopRoles: const [
          {
            'id': 1,
            'userId': 7,
            'userName': 'Kofi Nketia',
            'roleCode': 'SELLER',
            'active': true,
          },
          {
            'id': 2,
            'userId': 8,
            'userName': 'Adjoa Mensah',
            'roleCode': 'SELLER',
            'active': true,
          },
        ],
        sales: const [
          {
            'id': 31,
            'createdAt': '2026-09-01T09:30:00',
            'receiptReference': 'SHOP-KOFI',
            'buyerName': 'Kofi Buyer',
            'modelType': 'CONSIGNMENT',
            'processedBy': 7,
            'processedByName': 'Kofi Nketia',
            'paymentMethod': 'CASH',
            'status': 'COLLECTED',
            'totalAmount': 8,
            'lines': [],
          },
          {
            'id': 32,
            'createdAt': '2026-09-01T10:30:00',
            'receiptReference': 'SHOP-ADJOA',
            'buyerName': 'Adjoa Buyer',
            'modelType': 'CONSIGNMENT',
            'processedBy': 8,
            'processedByName': 'Adjoa Mensah',
            'paymentMethod': 'MOMO',
            'status': 'COLLECTED',
            'totalAmount': 12,
            'lines': [],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sellers'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<TextButton>(find.byKey(const ValueKey('shop-view-seller-7')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Current stock responsibility'), findsOneWidget);
    expect(find.text('Sales and collections'), findsOneWidget);
    expect(find.text('Cash remittances and reconciliation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-filter-to-seller')));
    await tester.pumpAndSettle();

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sales'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing only Kofi Nketia'), findsOneWidget);
    expect(find.text('Kofi Buyer'), findsOneWidget);
    expect(find.text('Adjoa Buyer'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('shop-choose-seller-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-scope-all-sellers')));
    await tester.pumpAndSettle();
    expect(find.text('Adjoa Buyer'), findsOneWidget);
  });
}
