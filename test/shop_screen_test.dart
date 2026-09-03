import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/shop/data/shop_api_client.dart';
import 'package:school_management_app/src/shop/presentation/school_shop_screen.dart';

void main() {
  Widget appWith(
    Map<String, dynamic> context, {
    List<dynamic> consignments = const [],
    List<dynamic> receipts = const [],
    List<dynamic> purchases = const [],
    List<dynamic>? items,
    List<dynamic> sales = const [],
    List<dynamic> auditEvents = const [],
    List<dynamic> inventoryAdjustments = const [],
    List<dynamic>? stockMovements,
    List<dynamic> customerReturns = const [],
    List<dynamic> staffReturns = const [],
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
    final customerReturnRows = customerReturns
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final staffReturnRows = staffReturns
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
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
      } else if (path.endsWith('/items')) {
        body = itemRows;
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
        final sale = sales.firstWhere(
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
      } else if (path.endsWith('/sales')) {
        body = sales;
      } else if (path.endsWith('/reconciliations') || path.endsWith('/roles')) {
        body = [];
      } else if (path.endsWith('/audit')) {
        body = auditEvents;
      } else if (path.endsWith('/custody/available')) {
        body = consignments;
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
      expect(find.text('Shop roles'), findsOneWidget);

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
      expect(find.text('Unit cost price (GHS)'), findsOneWidget);
      expect(find.text('Unit selling price (GHS)'), findsOneWidget);
      expect(find.text('LINE TOTAL'), findsOneWidget);
      expect(find.text('GHS 0.00'), findsOneWidget);
      expect(find.text('How was the stock obtained?'), findsOneWidget);
      expect(find.text('Source name (optional)'), findsOneWidget);
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

      final itemSearch = find.descendant(
        of: find.byKey(const ValueKey('purchase-item-search-0')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(itemSearch);
      await tester.tap(itemSearch);
      await tester.enterText(itemSearch, 'EXB-80');
      await tester.pumpAndSettle();
      expect(
        find.text('Exercise Book · 80 pages · EXB-80 · Books'),
        findsOneWidget,
      );
      expect(find.text('＋ Add a new item'), findsOneWidget);
      await tester.tap(find.text('Exercise Book · 80 pages · EXB-80 · Books'));
      await tester.pumpAndSettle();
      final selectedSearch = tester.widget<TextField>(itemSearch);
      expect(
        selectedSearch.controller!.text,
        contains('Exercise Book · 80 pages'),
      );
      expect(find.text('GHS 6.00'), findsWidgets);
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
      inventory.columns.take(6).every((column) => column.onSort != null),
      isTrue,
    );
    expect(inventory.columns, hasLength(7));
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
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Issue stock'))
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
    await tester.tap(find.text('Sell and give items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();

    expect(find.textContaining('My Exercise Book'), findsOneWidget);
    expect(find.textContaining('Other Staff Marker'), findsNothing);
  });

  testWidgets('stock issue shows a persistent maximum quantity warning', (
    tester,
  ) async {
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
        'staff': [
          {'id': 9, 'name': 'Kofi Storekeeper'},
        ],
        'roleOptions': ['BUYER'],
        'units': ['book'],
        'categories': ['Books'],
      }),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Issue stock'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue stock').last);
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
    await tester.tap(find.text('Sell and give items'));
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('shop-buyer-type')),
        )
        .onChanged!('STAFF');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-staff-buyer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-staff-buyer')));
    await tester.pumpAndSettle();
    expect(find.text('Yaw Teacher'), findsWidgets);
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
            'version': 0,
            'sale': {
              'buyerType': 'STAFF',
              'buyerName': 'Yaw Teacher',
              'totalAmount': 16,
              'lines': [
                {'itemName': 'Exercise Book', 'quantity': 2},
              ],
            },
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Take payment'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-issued-receipt-20')));
    await tester.pumpAndSettle();

    expect(find.text('Issued receipt'), findsOneWidget);
    expect(find.text('Yaw Teacher · Pending Collection'), findsOneWidget);
    expect(find.text('642519'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shop-reopened-pickup-token')),
      findsOneWidget,
    );
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
                {'itemName': 'Exercise Book', 'quantity': 2, 'lineTotal': 16},
              ],
            },
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Take payment'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-issued-receipt-20')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('shop-request-cancellation-20')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request order cancellation'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Buyer cancelled');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit for approval'));
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
}
