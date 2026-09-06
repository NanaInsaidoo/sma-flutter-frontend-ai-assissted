import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data/shop_api_client.dart';
import '../../theme/app_theme.dart';
import '../../assessments/presentation/report_pdf_download.dart';
import 'shop_receipt_pdf.dart';
import 'shop_reconciliation_screen.dart';

enum _ShopPage {
  overview,
  itemTypes,
  catalog,
  consignments,
  sell,
  release,
  accounts,
  remittances,
  sales,
  reports,
  returns,
  roles,
  audit,
}

enum _InventorySection { current, adjustments, history }

class SchoolShopScreen extends StatefulWidget {
  const SchoolShopScreen({super.key, required this.api});
  final ShopApiClient api;
  @override
  State<SchoolShopScreen> createState() => _SchoolShopScreenState();
}

class _SchoolShopScreenState extends State<SchoolShopScreen> {
  ShopJson? _context, _dashboard;
  List<ShopJson> _items = [],
      _purchases = [],
      _consignments = [],
      _inventoryAdjustments = [];
  List<ShopJson> _availableCustody = [];
  List<ShopJson> _receipts = [],
      _sales = [],
      _roles = [],
      _auditEvents = [],
      _stockMovements = [],
      _customerReturns = [],
      _staffReturns = [];
  bool _loading = true;
  String? _error;
  String _receiptSearch = '';
  List<ShopJson> _releaseMatches = [];
  bool _searchingReceipts = false;
  bool _receiptSearchComplete = false;
  int? _salesDays = 30;
  ShopJson? _report;
  bool _reportLoading = false;
  bool _downloadingReport = false;
  int? _reportDays = 30;
  late DateTime _reportFrom = DateTime.now().subtract(const Duration(days: 29));
  late DateTime _reportTo = DateTime.now();
  final Set<String> _reportSections = {
    'SUMMARY',
    'SALES',
    'INVENTORY',
    'STAFF_STOCK',
    'RETURNS',
  };
  _ShopPage _page = _ShopPage.overview;
  _InventorySection _inventorySection = _InventorySection.current;

  bool get _admin => _context?['isAdmin'] == true;
  bool get _buyer => _context?['canBuy'] == true;
  bool get _seller => _context?['canSell'] == true;
  bool get _cashier => _context?['canTakePayment'] == true;
  bool get _goods => _context?['canRelease'] == true;
  bool get _holder => _context?['canHoldStock'] == true;
  List<ShopJson> get _activeItems =>
      _items.where((item) => item['active'] != false).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = await widget.api.context();
      final dashboard = await widget.api.dashboard();
      final items = await widget.api.items(
        includeInactive: context['canBuy'] == true,
      );
      final purchases = context['canBuy'] == true
          ? await widget.api.purchases()
          : <ShopJson>[];
      final inventoryAdjustments = context['canAdjustInventory'] == true
          ? await widget.api.inventoryAdjustments()
          : <ShopJson>[];
      final stockMovements = context['canBuy'] == true
          ? await widget.api.stockMovements()
          : <ShopJson>[];
      final consignments =
          context['canConsign'] == true ||
              context['canSell'] == true ||
              context['canHoldStock'] == true
          ? await widget.api.consignments(mine: context['canConsign'] != true)
          : <ShopJson>[];
      final availableCustody =
          context['isAdmin'] == true ||
              context['canSell'] == true ||
              context['canTakePayment'] == true
          ? await widget.api.availableCustody()
          : <ShopJson>[];
      final receipts =
          context['isAdmin'] == true ||
              context['canSell'] == true ||
              context['canTakePayment'] == true ||
              context['canRelease'] == true ||
              context['canHoldStock'] == true
          ? await widget.api.receipts()
          : <ShopJson>[];
      final sales = await widget.api.sales(
        from: _salesFromDate,
        to: _ymd(DateTime.now()),
      );
      final customerReturns = await widget.api.customerReturns();
      final staffReturns = await widget.api.staffReturns();
      final roles = context['canManageRoles'] == true
          ? await widget.api.roles()
          : <ShopJson>[];
      final audit = context['isAdmin'] == true
          ? await widget.api.audit()
          : <ShopJson>[];
      if (!mounted) return;
      setState(() {
        _context = context;
        _dashboard = dashboard;
        _items = items;
        _purchases = purchases;
        _inventoryAdjustments = inventoryAdjustments;
        _stockMovements = stockMovements;
        _consignments = consignments;
        _availableCustody = availableCustody;
        _receipts = receipts;
        _sales = sales;
        _customerReturns = customerReturns;
        _staffReturns = staffReturns;
        _roles = roles;
        _auditEvents = audit;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ShopPage> get _pages => [
    _ShopPage.overview,
    if (_buyer) _ShopPage.itemTypes,
    if (_buyer) _ShopPage.catalog,
    if (_buyer || _seller || _holder) _ShopPage.consignments,
    if (_seller) _ShopPage.sell,
    if (_goods) _ShopPage.release,
    _ShopPage.accounts,
    if (_admin || _seller || _cashier) _ShopPage.remittances,
    _ShopPage.sales,
    if (_admin || _buyer) _ShopPage.reports,
    _ShopPage.returns,
    if (_admin) _ShopPage.roles,
    if (_admin) _ShopPage.audit,
  ];

  String _label(_ShopPage page) => switch (page) {
    _ShopPage.overview => 'Overview',
    _ShopPage.itemTypes => 'Item types',
    _ShopPage.catalog => 'Inventory',
    _ShopPage.consignments => !_buyer ? 'My stock' : 'Stock handovers',
    _ShopPage.sell => 'Sell items',
    _ShopPage.release => 'Release goods',
    _ShopPage.accounts => 'Reconciliation',
    _ShopPage.remittances => 'Cash remittances',
    _ShopPage.sales => 'Sales',
    _ShopPage.reports => 'Reports',
    _ShopPage.returns => 'Returns',
    _ShopPage.roles => 'Shop roles',
    _ShopPage.audit => 'Audit trail',
  };

  IconData _icon(_ShopPage page) => switch (page) {
    _ShopPage.overview => Icons.dashboard_outlined,
    _ShopPage.itemTypes => Icons.category_outlined,
    _ShopPage.catalog => Icons.inventory_2_outlined,
    _ShopPage.consignments => Icons.move_to_inbox_outlined,
    _ShopPage.sell => Icons.point_of_sale_outlined,
    _ShopPage.release => Icons.qr_code_scanner_outlined,
    _ShopPage.accounts => Icons.balance_outlined,
    _ShopPage.remittances => Icons.payments_outlined,
    _ShopPage.sales => Icons.analytics_outlined,
    _ShopPage.reports => Icons.summarize_outlined,
    _ShopPage.returns => Icons.assignment_return_outlined,
    _ShopPage.roles => Icons.manage_accounts_outlined,
    _ShopPage.audit => Icons.history_outlined,
  };

  Future<void> _dialog(Widget child) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => child,
    );
    if (changed == true) await _load();
  }

  Future<void> _selectPage(_ShopPage page) async {
    setState(() => _page = page);
    if (page == _ShopPage.reports && _report == null) await _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _context == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _context == null) {
      return Center(
        child: _MessageCard(
          icon: Icons.storefront_outlined,
          title: 'School shop unavailable',
          message: _error!,
          action: TextButton(onPressed: _load, child: const Text('Try again')),
        ),
      );
    }
    if (!_pages.contains(_page)) _page = _pages.first;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 34,
                color: AppColors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Shop',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Stock, student sales and collections in one place.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh shop',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _pages
                  .map(
                    (page) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(_icon(page), size: 18),
                        label: Text(_label(page)),
                        selected: _page == page,
                        onSelected: (_) => _selectPage(page),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_context?['reconciliationInProgress'] == true)
            Container(
              key: const ValueKey('shop-reconciliation-freeze'),
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reconciliation in progress. ${_context?['reconciliationCounterName'] ?? 'An administrator'} is checking your stock and money. Selling, collection releases, stock handovers, returns and cash remittances are temporarily paused for you; other sellers can continue.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          const SizedBox(height: 18),
          switch (_page) {
            _ShopPage.overview => _overview(),
            _ShopPage.itemTypes => _itemTypesPage(),
            _ShopPage.catalog => _catalog(),
            _ShopPage.consignments => _consignmentList(),
            _ShopPage.sell => _sell(),
            _ShopPage.release => _release(),
            _ShopPage.accounts => _accounts(),
            _ShopPage.remittances => _cashRemittances(),
            _ShopPage.sales => _salesPage(),
            _ShopPage.reports => _reportsPage(),
            _ShopPage.returns => _returnsPage(),
            _ShopPage.roles => _rolesPage(),
            _ShopPage.audit => _auditPage(),
          },
        ],
      ),
    );
  }

  Widget _overview() {
    final d = _dashboard ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (_admin || _buyer)
              _Metric(
                'Available stock',
                '${d['centralAvailable'] ?? 0}',
                Icons.inventory_outlined,
                AppColors.green,
              ),
            if (_admin || _buyer || _cashier || _goods)
              _Metric(
                'Reserved for pickup',
                '${d['reserved'] ?? 0}',
                Icons.hourglass_top_outlined,
                AppColors.blue,
              ),
            if (_admin || _seller || _cashier)
              _Metric(
                _admin ? 'Sales total' : 'My sales total',
                _money(d['revenue']),
                Icons.payments_outlined,
                AppColors.green,
              ),
            if (_admin || _buyer)
              _Metric(
                'Profit total',
                _money(d['profit']),
                Icons.trending_up_outlined,
                AppColors.blue,
              ),
            if (_admin)
              _Metric(
                'Stock received value',
                _money(d['receivedStockValue'] ?? d['purchasedCost']),
                Icons.shopping_cart_outlined,
                AppColors.blue,
              ),
            if (_admin || _cashier || _goods)
              _Metric(
                'Pending pickups',
                '${d['pendingPickups'] ?? 0}',
                Icons.local_shipping_outlined,
                AppColors.amber,
              ),
            if (_admin || _buyer || _seller)
              _Metric(
                'Needs attention',
                '${(_admin || _buyer) ? '${(d['lowStock'] as num?)?.toInt() ?? 0} low · ' : ''}${(d['flaggedReconciliations'] as num?)?.toInt() ?? 0} variance',
                Icons.warning_amber_outlined,
                AppColors.red,
              ),
          ],
        ),
        const SizedBox(height: 18),
        if ((_admin || _buyer) &&
            (d['lowStockItems'] as List? ?? []).isNotEmpty)
          _Panel(
            title: 'Low stock',
            subtitle: 'Available quantity is at or below the item threshold.',
            child: Column(
              children: _maps(d['lowStockItems'])
                  .map(
                    (i) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.warning_amber,
                        color: AppColors.amber,
                      ),
                      title: Text('${i['displayName']}'),
                      subtitle: Text(
                        '${i['availableQuantity']} ${i['unitOfMeasure']} available',
                      ),
                      trailing: Text('Reorder at ${i['lowStockThreshold']}'),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            if (_admin || _seller || _cashier)
              SizedBox(
                width: 430,
                child: _Panel(
                  title: 'Popular items',
                  subtitle: 'Highest quantities sold.',
                  child: _maps(d['topItems']).isEmpty
                      ? const _Empty('No sales recorded yet.')
                      : _popularItems(_maps(d['topItems'])),
                ),
              ),
            if (_admin || _seller)
              SizedBox(
                width: 560,
                child: _Panel(
                  title: 'Seller responsibility',
                  subtitle:
                      'Stock still held and cash expected from recorded sales.',
                  child: _maps(d['sellerLiability']).isEmpty
                      ? const _Empty(
                          'No stock is currently assigned to sellers.',
                        )
                      : _sellerResponsibility(
                          _maps(d['sellerLiability']).take(8).toList(),
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _popularItems(List<ShopJson> rows) {
    final largest = rows
        .map((row) => (row['quantity'] as num?)?.toDouble() ?? 0)
        .fold<double>(1, (current, value) => value > current ? value : current);
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? AppColors.green.withValues(alpha: .12)
                        : AppColors.blue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: index == 0 ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rows[index]['item']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value:
                              ((rows[index]['quantity'] as num?)?.toDouble() ??
                                  0) /
                              largest,
                          backgroundColor: AppColors.border,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${rows[index]['quantity']} sold',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (index != rows.length - 1)
            const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  Widget _sellerResponsibility(List<ShopJson> rows) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Row(
          children: [
            Expanded(flex: 3, child: Text('SELLER')),
            Expanded(flex: 3, child: Text('ITEM')),
            Expanded(child: Text('LEFT', textAlign: TextAlign.right)),
            SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text('CASH DUE', textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
      for (var index = 0; index < rows.length; index++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${rows[index]['seller']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${rows[index]['item']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              Expanded(
                child: Text(
                  '${rows[index]['remaining']}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  _money(rows[index]['expectedCash']),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (index != rows.length - 1)
          const Divider(height: 1, color: AppColors.border),
      ],
    ],
  );

  Widget _itemTypesPage() => _Panel(
    title: 'Item types',
    subtitle:
        'Reusable item definitions. Quantities are recorded separately when stock is received.',
    action: FilledButton.icon(
      key: const ValueKey('shop-add-item-type'),
      onPressed: () =>
          _dialog(_ItemDialog(api: widget.api, contextData: _context!)),
      icon: const Icon(Icons.add),
      label: const Text('Add item type'),
    ),
    child: _items.isEmpty
        ? const _Empty(
            'No item types yet. Add the first reusable item definition.',
          )
        : _ModernShopTable<ShopJson>(
            tableKey: 'shop-item-types-table',
            rows: _items,
            rowKey: (item) => 'shop-item-type-${item['id']}',
            columns: [
              _ShopTableColumn(
                label: 'Item type',
                sortValue: (item) => item['displayName'],
                cell: (item) => Text(
                  '${item['displayName']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _ShopTableColumn(
                label: 'Item code',
                sortValue: (item) => item['sku'],
                cell: (item) => Text('${item['sku']}'),
              ),
              _ShopTableColumn(
                label: 'Category',
                sortValue: (item) => item['category'],
                cell: (item) => Text('${item['category']}'),
              ),
              _ShopTableColumn(
                label: 'Unit',
                sortValue: (item) => item['unitOfMeasure'],
                cell: (item) => Text('${item['unitOfMeasure']}'),
              ),
              _ShopTableColumn(
                label: 'Low-stock alert',
                numeric: true,
                sortValue: (item) => item['lowStockThreshold'],
                cell: (item) => Text('${item['lowStockThreshold'] ?? 0}'),
              ),
              _ShopTableColumn(
                label: 'Status',
                sortValue: (item) => item['active'] == false ? 1 : 0,
                cell: (item) => Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(item['active'] == false ? 'Archived' : 'Active'),
                  backgroundColor:
                      (item['active'] == false
                              ? AppColors.muted
                              : AppColors.green)
                          .withValues(alpha: .1),
                ),
              ),
              _ShopTableColumn(
                label: 'Actions',
                cell: (item) => PopupMenuButton<String>(
                  key: ValueKey('shop-item-type-actions-${item['id']}'),
                  tooltip: 'Item type actions',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _dialog(
                        _ItemDialog(
                          api: widget.api,
                          contextData: _context!,
                          item: item,
                        ),
                      );
                      return;
                    }
                    _setItemTypeActive(item, item['active'] == false);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      key: ValueKey('shop-edit-item-type-${item['id']}'),
                      value: 'edit',
                      child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit item type'),
                      ),
                    ),
                    PopupMenuItem(
                      key: ValueKey(
                        item['active'] == false
                            ? 'shop-restore-item-type-${item['id']}'
                            : 'shop-archive-item-type-${item['id']}',
                      ),
                      value: 'toggle-active',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          item['active'] == false
                              ? Icons.restore_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          item['active'] == false
                              ? 'Restore item type'
                              : 'Archive item type',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );

  ShopJson _itemTypePayload(ShopJson item, bool active) => {
    'name': item['name'],
    'category': item['category'],
    'sku': item['sku'],
    'unitOfMeasure': item['unitOfMeasure'],
    'parentItemId': item['parentItemId'],
    'variantLabel': item['variantLabel'],
    'costPrice': item['costPrice'],
    'sellingPrice': item['sellingPrice'],
    'lowStockThreshold': item['lowStockThreshold'],
    'active': active,
    'version': item['version'],
  };

  Future<void> _setItemTypeActive(ShopJson item, bool active) async {
    final total = ((item['totalOnHand'] ?? item['centralQuantity'] ?? 0) as num)
        .toInt();
    if (!active && total > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Item type still has stock'),
          content: Text(
            '${item['displayName']} has $total ${item['unitOfMeasure']} on hand. Return, sell, or adjust that stock before archiving the item type.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(active ? 'Restore item type?' : 'Archive item type?'),
        content: Text(
          active
              ? '${item['displayName']} will become available for new stock receipts and sales again.'
              : '${item['displayName']} will be hidden from new stock receipts and sales. Its history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(active ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.saveItem(
        _itemTypePayload(item, active),
        id: item['id'] as int,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active ? 'Item type restored.' : 'Item type archived.',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    }
  }

  Widget _catalog() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SegmentedButton<_InventorySection>(
        key: const ValueKey('shop-inventory-sections'),
        segments: [
          ButtonSegment(
            value: _InventorySection.current,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Current stock'),
          ),
          if (_context?['canAdjustInventory'] == true)
            ButtonSegment(
              value: _InventorySection.adjustments,
              icon: const Icon(Icons.tune_outlined),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Adjustments'),
                  if (_inventoryAdjustments.any(
                    (row) => row['status'] == 'PENDING_APPROVAL',
                  )) ...[
                    const SizedBox(width: 6),
                    Badge(
                      label: Text(
                        '${_inventoryAdjustments.where((row) => row['status'] == 'PENDING_APPROVAL').length}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const ButtonSegment(
            value: _InventorySection.history,
            icon: Icon(Icons.history_outlined),
            label: Text('Stock history'),
          ),
        ],
        selected: {_inventorySection},
        onSelectionChanged: (value) =>
            setState(() => _inventorySection = value.first),
      ),
      const SizedBox(height: 14),
      if (_inventorySection == _InventorySection.current) ...[
        _Panel(
          title: 'Current inventory',
          subtitle:
              'What the school owns now. Select an item to see prices, availability and stock details.',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('shop-add-stock'),
                onPressed: () => _dialog(
                  _PurchaseDialog(
                    api: widget.api,
                    items: _activeItems,
                    contextData: _context!,
                  ),
                ),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add stock'),
              ),
            ],
          ),
          child: _activeItems.isEmpty
              ? const _Empty(
                  'No active item types are available. Add or restore one in Item types.',
                )
              : _ModernShopTable<ShopJson>(
                  tableKey: 'shop-inventory-table',
                  rows: _activeItems,
                  initialSortColumn: 1,
                  initialSortAscending: false,
                  rowKey: (item) => 'shop-item-${item['id']}',
                  onRowTap: _showInventoryDetails,
                  columns: [
                    _ShopTableColumn(
                      label: 'Item',
                      sortValue: (item) => item['displayName'],
                      cell: (item) => Row(
                        children: [
                          if (item['lowStock'] == true)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.warning_amber,
                                size: 18,
                                color: AppColors.amber,
                              ),
                            ),
                          Flexible(child: Text('${item['displayName']}')),
                          if (_isNewInventoryItem(item)) ...[
                            const SizedBox(width: 8),
                            Container(
                              key: ValueKey('shop-new-item-${item['id']}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  color: AppColors.blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Date added',
                      sortValue: (item) => _dateValue(item['createdAt']),
                      cell: (item) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dateLabel(item['createdAt']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (_timeLabel(item['createdAt']).isNotEmpty)
                            Text(
                              _timeLabel(item['createdAt']),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Available to sell',
                      numeric: true,
                      sortValue: (item) =>
                          item['schoolAvailableQuantity'] ??
                          item['availableQuantity'],
                      cell: (item) => Text(
                        '${item['schoolAvailableQuantity'] ?? item['availableQuantity'] ?? 0} ${item['unitOfMeasure']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Total stock',
                      numeric: true,
                      sortValue: (item) =>
                          item['totalOnHand'] ?? item['centralQuantity'],
                      cell: (item) => Text(
                        '${item['totalOnHand'] ?? item['centralQuantity'] ?? item['availableQuantity']} ${item['unitOfMeasure']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Stock status',
                      sortValue: (item) => _inventoryStatusRank(item),
                      cell: _inventoryStatusChip,
                    ),
                    _ShopTableColumn(label: 'Actions', cell: _inventoryActions),
                  ],
                ),
        ),
      ] else if (_inventorySection == _InventorySection.adjustments)
        _inventoryAdjustmentsPanel()
      else
        _stockHistoryPanel(),
    ],
  );

  Widget _stockHistoryPanel() => _Panel(
    title: 'Stock history',
    subtitle:
        'Every change to stock, including receipts, staff issues, reservations, releases, returns and adjustments.',
    child: _stockMovements.isEmpty
        ? const _Empty('No stock movements have been recorded yet.')
        : _ModernShopTable<ShopJson>(
            tableKey: 'shop-stock-history-table',
            rows: _stockMovements,
            initialSortColumn: 0,
            initialSortAscending: false,
            rowKey: (row) => 'shop-stock-movement-${row['id']}',
            onRowTap: _showStockMovementDetails,
            columns: [
              _ShopTableColumn(
                label: 'Date',
                sortValue: (row) => _dateValue(row['occurredAt']),
                cell: (row) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dateLabel(row['occurredAt']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _timeLabel(row['occurredAt']),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _ShopTableColumn(
                label: 'Movement',
                sortValue: (row) => row['movement'],
                cell: _stockMovementChip,
              ),
              _ShopTableColumn(
                label: 'Details',
                sortValue: (row) => row['details'],
                cell: (row) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Text(
                    '${row['details'] ?? 'No additional details'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
              _ShopTableColumn(
                label: 'Recorded by',
                sortValue: (row) => row['recordedBy'],
                cell: (row) => Text('${row['recordedBy']}'),
              ),
              _ShopTableColumn(
                label: 'Reference',
                sortValue: (row) => row['reference'],
                cell: (row) => Text('${row['reference']}'),
              ),
            ],
          ),
  );

  Widget _stockMovementChip(ShopJson row) {
    final effect = '${row['effect']}';
    final color = switch (effect) {
      'INCREASE' || 'RESTORED' => AppColors.green,
      'DECREASE' => AppColors.red,
      'RESERVED' || 'ADJUSTMENT' => AppColors.amber,
      _ => AppColors.blue,
    };
    final icon = switch (effect) {
      'INCREASE' || 'RESTORED' => Icons.add_circle_outline,
      'DECREASE' => Icons.remove_circle_outline,
      'RESERVED' => Icons.hourglass_top_outlined,
      'CONFIRMED' => Icons.check_circle_outline,
      'ADJUSTMENT' => Icons.tune_outlined,
      _ => Icons.swap_horiz_outlined,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: color),
      label: Text('${row['movement']}'),
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide(color: color.withValues(alpha: .25)),
    );
  }

  Future<void> _showStockMovementDetails(ShopJson movement) async {
    if ({'STOCK_RECEIPT', 'PURCHASE'}.contains(movement['entityType'])) {
      final receipt = _purchases.cast<ShopJson?>().firstWhere(
        (row) => row?['id'] == movement['entityId'],
        orElse: () => null,
      );
      if (receipt != null) {
        await _showPurchaseDetails(receipt);
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${movement['movement']}'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${movement['details'] ?? 'No additional details'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _InventoryInfo(
                label: 'Recorded by',
                value: '${movement['recordedBy']}',
              ),
              const SizedBox(height: 12),
              _InventoryInfo(
                label: 'Date and time',
                value:
                    '${_dateLabel(movement['occurredAt'])} · ${_timeLabel(movement['occurredAt'])}',
              ),
              const SizedBox(height: 12),
              _InventoryInfo(
                label: 'Reference',
                value: '${movement['reference']}',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int _inventoryAvailable(ShopJson item) =>
      ((item['schoolAvailableQuantity'] ??
                  ((item['totalOnHand'] ?? item['centralQuantity'] ?? 0) as num)
                          .toInt() -
                      ((item['totalReservedQuantity'] ??
                                  item['reservedQuantity'] ??
                                  0)
                              as num)
                          .toInt())
              as num)
          .toInt();

  bool _isNewInventoryItem(ShopJson item) {
    final createdAt = _shopDate(item['createdAt']);
    if (createdAt == null) return false;
    final age = DateTime.now().difference(createdAt);
    return !age.isNegative && age < const Duration(hours: 24);
  }

  int _inventoryStatusRank(ShopJson item) {
    final available = _inventoryAvailable(item);
    if (available <= 0) return 0;
    final threshold = (item['lowStockThreshold'] as num?)?.toInt() ?? 0;
    return available <= threshold ? 1 : 2;
  }

  Widget _inventoryStatusChip(ShopJson item) {
    final rank = _inventoryStatusRank(item);
    final label = switch (rank) {
      0 => 'Out of stock',
      1 => 'Low stock',
      _ => 'Healthy',
    };
    final color = switch (rank) {
      0 => AppColors.red,
      1 => AppColors.amber,
      _ => AppColors.green,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        rank == 2 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        size: 16,
        color: color,
      ),
      label: Text(label),
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide(color: color.withValues(alpha: .25)),
    );
  }

  bool _hasPendingInventoryAdjustment(ShopJson item) =>
      _inventoryAdjustments.any(
        (request) =>
            request['itemId'] == item['id'] &&
            request['status'] == 'PENDING_APPROVAL',
      );

  bool _canIssueInventoryItem(ShopJson item) =>
      _buyer &&
      item['active'] == true &&
      item['id'] != null &&
      ((item['availableQuantity'] as num?)?.toInt() ?? 0) > 0;

  String _issueInventoryLabel(ShopJson item) {
    if (item['active'] != true) return 'Prepare handover — item is archived';
    if (((item['availableQuantity'] as num?)?.toInt() ?? 0) <= 0) {
      return 'Prepare handover — none available in central store';
    }
    return 'Prepare handover';
  }

  Widget _inventoryActions(ShopJson item) => PopupMenuButton<String>(
    key: ValueKey('shop-inventory-actions-${item['id']}'),
    tooltip: 'Inventory actions',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (action) {
      if (action == 'details') {
        _showInventoryDetails(item);
      } else if (action == 'holders') {
        _showInventoryHolders(item);
      } else if (action == 'issue') {
        _dialog(
          _ConsignmentDialog(
            api: widget.api,
            contextData: _context!,
            items: _activeItems,
            roles: _roles,
            initialItem: item,
          ),
        );
      } else if (action == 'adjust') {
        _dialog(
          _InventoryAdjustmentDialog(
            api: widget.api,
            item: item,
            contextData: _context!,
          ),
        );
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'details', child: Text('View details')),
      if (_buyer)
        PopupMenuItem(
          value: _canIssueInventoryItem(item) ? 'issue' : null,
          enabled: _canIssueInventoryItem(item),
          child: Text(_issueInventoryLabel(item)),
        ),
      if (((item['heldQuantity'] as num?)?.toInt() ?? 0) > 0)
        const PopupMenuItem(
          value: 'holders',
          child: Text('View stock holders'),
        ),
      if (_context?['canAdjustInventory'] == true)
        PopupMenuItem(
          value: _hasPendingInventoryAdjustment(item) ? null : 'adjust',
          child: Text(
            _hasPendingInventoryAdjustment(item)
                ? 'Adjustment awaiting approval'
                : 'Request adjustment',
          ),
        ),
    ],
  );

  Future<void> _showInventoryDetails(ShopJson item) => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final unit = '${item['unitOfMeasure'] ?? 'items'}';
      final held = (item['heldQuantity'] as num?)?.toInt() ?? 0;
      final total =
          ((item['totalOnHand'] ?? item['centralQuantity'] ?? 0) as num)
              .toInt();
      final central =
          ((item['unassignedQuantity'] ?? item['centralQuantity'] ?? 0) as num)
              .toInt();
      final customerReserved = ((item['customerReservedQuantity'] ?? 0) as num)
          .toInt();
      final awaitingHandover = ((item['pendingTransferQuantity'] ?? 0) as num)
          .toInt();
      final awaitingReturn = ((item['pendingReturnQuantity'] ?? 0) as num)
          .toInt();
      final quarantined = ((item['quarantinedQuantity'] ?? 0) as num).toInt();
      final pending = _inventoryAdjustments
          .where((request) => request['itemId'] == item['id'])
          .toList();
      return AlertDialog(
        title: Text('${item['displayName']}'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _inventoryStatusChip(item),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item['sku']} · ${item['category']}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InventoryQuantityCard(
                      label: 'Central store',
                      value: '$central $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'With staff',
                      value: '$held $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Reserved for customers',
                      value: '$customerReserved $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Awaiting handover',
                      value: '$awaitingHandover $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Awaiting return',
                      value: '$awaitingReturn $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Held for inspection',
                      value: '$quarantined $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Available to sell',
                      value: '${_inventoryAvailable(item)} $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Total school stock',
                      value: '$total $unit',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Held for inspection means returned, damaged or questionable stock that cannot be sold until checked. Expected physical stock is central store plus stock confirmed with staff; reservations remain in that physical total until custody changes.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Item information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _InventoryInfo(label: 'Unit', value: unit),
                    if (item['costPrice'] != null)
                      _InventoryInfo(
                        label: 'Unit cost',
                        value: _money(item['costPrice']),
                      ),
                    _InventoryInfo(
                      label: 'Unit selling price',
                      value: _money(item['sellingPrice']),
                    ),
                    if (item['margin'] != null)
                      _InventoryInfo(
                        label: 'Unit margin',
                        value: _money(item['margin']),
                      ),
                    _InventoryInfo(
                      label: 'Low-stock alert',
                      value: '${item['lowStockThreshold'] ?? 0} $unit',
                    ),
                    _InventoryInfo(
                      label: 'Pending adjustments',
                      value:
                          '${pending.where((row) => row['status'] == 'PENDING_APPROVAL').length}',
                    ),
                  ],
                ),
                if (held > 0) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    key: ValueKey('shop-item-holders-${item['id']}'),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showInventoryHolders(item);
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('View stock holders'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (_context?['canAdjustInventory'] == true)
            TextButton(
              key: ValueKey('shop-request-adjustment-${item['id']}'),
              onPressed: _hasPendingInventoryAdjustment(item)
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _dialog(
                        _InventoryAdjustmentDialog(
                          api: widget.api,
                          item: item,
                          contextData: _context!,
                        ),
                      );
                    },
              child: Text(
                _hasPendingInventoryAdjustment(item)
                    ? 'Adjustment awaiting approval'
                    : 'Request adjustment',
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );

  Widget _inventoryAdjustmentsPanel() => _Panel(
    title: 'Adjustment requests',
    subtitle:
        'Requested corrections and write-offs. Stock changes only after approval.',
    child: _inventoryAdjustments.isEmpty
        ? const _Empty('No inventory adjustment requests have been recorded.')
        : _ModernShopTable<ShopJson>(
            tableKey: 'shop-inventory-adjustments-table',
            rows: _inventoryAdjustments,
            initialSortColumn: 0,
            initialSortAscending: false,
            rowKey: (row) => 'shop-inventory-adjustment-${row['id']}',
            columns: [
              _ShopTableColumn(
                label: 'Requested',
                sortValue: (row) => _shopDate(row['submittedAt']),
                cell: (row) => Text(_dateLabel(row['submittedAt'])),
              ),
              _ShopTableColumn(
                label: 'Item',
                sortValue: (row) => row['itemName'],
                cell: (row) => Text('${row['itemName']}'),
              ),
              _ShopTableColumn(
                label: 'Change',
                sortValue: (row) => row['change'],
                cell: (row) => Text(
                  '${row['currentQuantity']} → ${row['proposedQuantity']} ${row['unitOfMeasure']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _ShopTableColumn(
                label: 'Reason',
                sortValue: (row) => row['reason'],
                cell: (row) => Text('${row['reason']}'),
              ),
              _ShopTableColumn(
                label: 'Requester',
                sortValue: (row) => row['requesterName'],
                cell: (row) => Text('${row['requesterName']}'),
              ),
              _ShopTableColumn(
                label: 'Approver',
                sortValue: (row) => row['approverName'],
                cell: (row) => Text('${row['approverName']}'),
              ),
              _ShopTableColumn(
                label: 'Status',
                sortValue: (row) => row['status'],
                cell: (row) => Text(_status(row['status'])),
              ),
            ],
          ),
  );

  Future<void> _showInventoryHolders(ShopJson item) => showDialog<void>(
    context: context,
    builder: (_) {
      final holders = _maps(item['holders']);
      return AlertDialog(
        title: Text('Who holds ${item['displayName']}?'),
        content: SizedBox(
          width: 650,
          child: holders.isEmpty
              ? const _Empty('No stock is currently held by staff.')
              : _ModernShopTable<ShopJson>(
                  tableKey: 'shop-item-holder-breakdown',
                  rows: holders,
                  rowKey: (row) => 'shop-item-holder-${row['consignmentId']}',
                  columns: [
                    _ShopTableColumn(
                      label: 'Stock holder',
                      sortValue: (row) => row['holderName'],
                      cell: (row) => Text('${row['holderName']}'),
                    ),
                    _ShopTableColumn(
                      label: 'Location',
                      sortValue: (row) => row['locationName'] ?? '',
                      cell: (row) =>
                          Text('${row['locationName'] ?? 'Not specified'}'),
                    ),
                    _ShopTableColumn(
                      label: 'Status',
                      sortValue: (row) => row['status'],
                      cell: (row) => Text(_status(row['status'])),
                    ),
                    _ShopTableColumn(
                      label: 'On hand',
                      numeric: true,
                      sortValue: (row) => row['quantity'],
                      cell: (row) => Text('${row['quantity']}'),
                    ),
                    _ShopTableColumn(
                      label: 'Customer reserved',
                      numeric: true,
                      sortValue: (row) => row['reservedQuantity'],
                      cell: (row) => Text('${row['reservedQuantity']}'),
                    ),
                    _ShopTableColumn(
                      label: 'Awaiting return',
                      numeric: true,
                      sortValue: (row) => row['returnReservedQuantity'] ?? 0,
                      cell: (row) =>
                          Text('${row['returnReservedQuantity'] ?? 0}'),
                    ),
                    _ShopTableColumn(
                      label: 'Available',
                      numeric: true,
                      sortValue: (row) => row['availableQuantity'],
                      cell: (row) => Text('${row['availableQuantity']}'),
                    ),
                  ],
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );

  Future<void> _showPurchaseDetails(ShopJson purchase) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Stock receipt details'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${purchase['sourceTypeLabel'] ?? _stockSourceLabel(purchase['sourceType'])}${_stockSourceName(purchase) == null ? '' : ' · ${_stockSourceName(purchase)}'} · ${_dateOnly(purchase['receivedDate'] ?? purchase['purchaseDate'])}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recorded by ${purchase['recordedByName'] ?? purchase['buyerName']}',
              ),
              if ('${purchase['sourceReference'] ?? ''}'.trim().isNotEmpty)
                Text('Reference: ${purchase['sourceReference']}'),
              const SizedBox(height: 14),
              _ModernShopTable<ShopJson>(
                tableKey: 'shop-purchase-lines-${purchase['id']}',
                rows: _maps(purchase['lines']),
                columns: [
                  _ShopTableColumn(
                    label: 'Item',
                    sortValue: (line) => line['itemName'],
                    cell: (line) => Text('${line['itemName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Quantity',
                    numeric: true,
                    sortValue: (line) => line['quantity'],
                    cell: (line) => Text('${line['quantity']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Unit cost',
                    numeric: true,
                    sortValue: (line) => line['unitCost'],
                    cell: (line) => Text(_money(line['unitCost'])),
                  ),
                  _ShopTableColumn(
                    label: 'Line total',
                    numeric: true,
                    sortValue: (line) => line['lineTotal'],
                    cell: (line) => Text(_money(line['lineTotal'])),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total stock value: ${_money(purchase['totalValue'] ?? purchase['totalCost'])}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if ('${purchase['notes'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Notes: ${purchase['notes']}'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _consignmentList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_buyer)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _dialog(
              _ConsignmentDialog(
                api: widget.api,
                contextData: _context!,
                items: _activeItems,
                roles: _roles,
              ),
            ),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Prepare handover'),
          ),
        ),
      const SizedBox(height: 12),
      _Panel(
        title: !_buyer ? 'Stock assigned to me' : 'Stock handovers and custody',
        subtitle:
            'Preparing a handover reserves central stock. Custody changes only after the recipient physically counts and confirms it.',
        child: _consignments.isEmpty
            ? const _Empty('No stock has been issued.')
            : _ModernShopTable<ShopJson>(
                tableKey: 'shop-stock-custody-table',
                rows: _consignments,
                rowKey: (row) => 'shop-consignment-${row['id']}',
                columns: [
                  _ShopTableColumn(
                    label: 'Stock holder',
                    sortValue: (row) => row['sellerName'],
                    cell: (row) => Text('${row['sellerName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Item',
                    sortValue: (row) => row['itemName'],
                    cell: (row) => Text('${row['itemName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Status',
                    sortValue: (row) => row['status'],
                    cell: (row) => Text(_status(row['status'])),
                  ),
                  _ShopTableColumn(
                    label: 'Assigned',
                    numeric: true,
                    sortValue: (row) => row['assignedQuantity'],
                    cell: (row) => Text('${row['assignedQuantity']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Sold',
                    numeric: true,
                    sortValue: (row) => row['soldQuantity'],
                    cell: (row) => Text('${row['soldQuantity']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Reserved',
                    numeric: true,
                    sortValue: (row) => row['reservedQuantity'] ?? 0,
                    cell: (row) => Text('${row['reservedQuantity'] ?? 0}'),
                  ),
                  _ShopTableColumn(
                    label: 'Available',
                    numeric: true,
                    sortValue: (row) =>
                        row['availableQuantity'] ?? row['remainingQuantity'],
                    cell: (row) => Text(
                      '${row['availableQuantity'] ?? row['remainingQuantity']}',
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Actions',
                    cell: (row) =>
                        row['status'] == 'PENDING_ACCEPTANCE' &&
                            row['holderId'] == _context?['currentUserId']
                        ? Wrap(
                            spacing: 6,
                            children: [
                              TextButton(
                                onPressed: () => _answerIssue(row, false),
                                child: const Text('Problem'),
                              ),
                              FilledButton(
                                onPressed: () => _answerIssue(row, true),
                                child: const Text('Confirm receipt'),
                              ),
                            ],
                          )
                        : row['status'] == 'ACTIVE' &&
                              ((row['availableQuantity'] ?? 0) as num).toInt() >
                                  0 &&
                              !_hasPendingStaffReturn(row)
                        ? TextButton(
                            onPressed: () => _dialog(
                              _ReturnDialog(api: widget.api, consignment: row),
                            ),
                            child: const Text('Return'),
                          )
                        : _hasPendingStaffReturn(row)
                        ? const Text('Awaiting store')
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
      ),
    ],
  );

  bool _hasPendingStaffReturn(ShopJson consignment) => _staffReturns.any(
    (row) =>
        row['consignmentId'] == consignment['id'] &&
        row['status'] == 'PENDING_RECEIPT',
  );

  Future<void> _answerIssue(ShopJson row, bool accept) async {
    String? reason;
    if (accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm stock received?'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['assignedQuantity']} ${row['unitOfMeasure'] ?? 'items'} · ${row['itemName']}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Confirm only after you have physically received and counted this stock. You will become responsible for it after confirmation.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              key: const ValueKey('confirm-stock-received'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, confirm receipt'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    } else {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Report a stock problem'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What is wrong?',
              hintText: 'Wrong item or quantity',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Report problem'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.trim().isEmpty) return;
    }
    try {
      await widget.api.answerStockIssue(
        row,
        accept ? 'ACCEPT' : 'REJECT',
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Receipt confirmed. The stock is now available.'
                  : 'Problem reported. The stock returned to the central store.',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    }
  }

  Widget _sell() {
    final stock = _consignments
        .where(
          (c) =>
              c['holderId'] == _context?['currentUserId'] &&
              c['status'] == 'ACTIVE' &&
              ((c['availableQuantity'] ?? 0) as num).toInt() > 0,
        )
        .toList();
    return Column(
      children: [
        _ActionLanding(
          icon: Icons.shopping_bag_outlined,
          title: 'I have the items',
          message:
              'Use stock you personally hold. Receive payment and hand the items to the buyer immediately.',
          button: FilledButton.icon(
            onPressed: stock.isEmpty
                ? null
                : () => _dialog(
                    _SaleDialog(
                      api: widget.api,
                      choices: stock,
                      contextData: _context!,
                      collectFromStore: false,
                    ),
                  ),
            icon: const Icon(Icons.done_all),
            label: const Text('Sell and hand over now'),
          ),
          below: stock.isEmpty
              ? const _Empty(
                  'You need confirmed stock before giving items directly.',
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        _ActionLanding(
          icon: Icons.store_outlined,
          title: 'Another staff member has the items',
          message:
              'Receive payment now and create a receipt with a one-time token. The stock holder releases the items later.',
          button: FilledButton.icon(
            onPressed: _availableCustody.isEmpty
                ? null
                : () => _dialog(
                    _SaleDialog(
                      api: widget.api,
                      choices: _availableCustody,
                      contextData: _context!,
                      collectFromStore: true,
                    ),
                  ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Sell for later collection'),
          ),
          below: _availableCustody.isEmpty
              ? const _Empty('No confirmed store stock is available.')
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'My issued receipts',
          subtitle:
              'Open a receipt again to view its collection token and sale details.',
          child: _issuedReceiptsTable(
            emptyMessage: 'You have not issued a receipt yet.',
            tableKey: 'shop-seller-payments-table',
          ),
        ),
      ],
    );
  }

  Widget _release() {
    final query = _receiptSearch.trim().toLowerCase();
    final pending = _releaseMatches
        .where(
          (r) =>
              r['status'] == 'PENDING_COLLECTION' ||
              r['status'] == 'PENDING_PICKUP',
        )
        .toList();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: _Panel(
          title: 'Release goods',
          subtitle:
              'Find the paid order, check the items, then confirm handover.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final searchField = TextField(
                    key: const ValueKey('shop-release-search'),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Token, receipt number or buyer name',
                      hintText: 'e.g. 482913 or Ama Mensah',
                    ),
                    onChanged: (value) => setState(() {
                      _receiptSearch = value;
                      _releaseMatches = [];
                      _receiptSearchComplete = false;
                    }),
                    onSubmitted: (_) => _findReceipt(),
                  );
                  final findButton = SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      key: const ValueKey('shop-find-order'),
                      onPressed:
                          _searchingReceipts || _receiptSearch.trim().length < 2
                          ? null
                          : _findReceipt,
                      icon: _searchingReceipts
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _searchingReceipts ? 'Finding…' : 'Find order',
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        findButton,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 10),
                      findButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              if (_searchingReceipts)
                const LinearProgressIndicator()
              else if (pending.isEmpty)
                _Empty(
                  query.isEmpty
                      ? 'Enter the buyer’s token, receipt number or name to find a paid order.'
                      : _receiptSearchComplete
                      ? 'No pending pickup matches this search.'
                      : 'Select Find order or press Enter to search.',
                )
              else
                Column(
                  children: pending
                      .map(
                        (r) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _receiptBuyer(r),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r['reference']}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const Divider(height: 24),
                              for (final line in _maps(r['sale']?['lines']))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${line['quantity']} × ${line['itemName']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Receipt total ${_money(r['sale']?['totalAmount'])}',
                              ),
                              Text(
                                'Sold by ${r['cashierName']}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => _confirmRedeem(r),
                                    icon: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Release'),
                                  ),
                                  const Text(
                                    'Paid · Awaiting collection',
                                    style: TextStyle(
                                      color: AppColors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _findReceipt() async {
    final query = _receiptSearch.trim();
    if (query.length < 2 || _searchingReceipts) return;
    setState(() {
      _searchingReceipts = true;
      _receiptSearchComplete = false;
      _releaseMatches = [];
    });
    try {
      final rows = await widget.api.receipts(query: query);
      if (mounted && _receiptSearch.trim() == query) {
        setState(() {
          _releaseMatches = rows;
          _receiptSearchComplete = true;
        });
      }
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _searchingReceipts = false);
    }
  }

  Future<void> _confirmRedeem(ShopJson receipt) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Release these goods?'),
        content: Text(
          '${receipt['reference']}\n${_receiptItems(receipt)}\n\nConfirm the goods are physically ready before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm release'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.api.redeem(receipt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items released and recorded.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _accounts() => ShopReconciliationScreen(
    api: widget.api,
    contextData: _context!,
    onChanged: _load,
  );

  Widget _cashRemittances() => ShopReconciliationScreen(
    api: widget.api,
    contextData: _context!,
    onChanged: _load,
    view: ShopReconciliationView.remittances,
  );

  String get _salesFromDate => _salesDays == null
      ? '2020-01-01'
      : _ymd(
          DateTime.now().subtract(
            Duration(days: _salesDays == 0 ? 0 : _salesDays! - 1),
          ),
        );

  Future<void> _changeSalesRange(int? days) async {
    setState(() {
      _salesDays = days;
      _loading = true;
    });
    try {
      final now = DateTime.now();
      final rows = await widget.api.sales(from: _salesFromDate, to: _ymd(now));
      if (mounted) setState(() => _sales = rows);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ShopJson> get _itemPerformance {
    final rows = <int, ShopJson>{};
    for (final item in _items.where((i) => i['active'] == true)) {
      rows[item['id'] as int] = {
        'name': item['displayName'],
        'category': item['category'],
        'quantity': 0,
        'revenue': 0.0,
        'margin': 0.0,
        'available': item['availableQuantity'],
      };
    }
    for (final sale in _sales.where((s) => s['status'] != 'CANCELLED')) {
      for (final line in _maps(sale['lines'])) {
        final item = _items.cast<ShopJson?>().firstWhere(
          (i) => i?['id'] == line['itemId'],
          orElse: () => null,
        );
        final row = rows.putIfAbsent(
          line['itemId'] as int,
          () => {
            'name': line['itemName'],
            'category': 'Other',
            'quantity': 0,
            'revenue': 0.0,
            'margin': 0.0,
            'available': 0,
          },
        );
        final quantity = (line['quantity'] as num).toInt();
        row['quantity'] = (row['quantity'] as int) + quantity;
        row['revenue'] =
            (row['revenue'] as double) + (line['lineTotal'] as num).toDouble();
        if (item != null && item['costPrice'] != null) {
          row['margin'] =
              (row['margin'] as double) +
              ((item['sellingPrice'] as num).toDouble() -
                      (item['costPrice'] as num).toDouble()) *
                  quantity;
        }
      }
    }
    final result = rows.values.toList();
    result.sort(
      (a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int),
    );
    return result;
  }

  Widget _salesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_cashier) ...[
        FilledButton.icon(
          key: const ValueKey('shop-receive-payment'),
          onPressed: _loading || _availableCustody.isEmpty
              ? null
              : () => _dialog(
                  _SaleDialog(
                    api: widget.api,
                    choices: _availableCustody,
                    contextData: _context!,
                    collectFromStore: true,
                  ),
                ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Receive payment'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 18),
          child: Text(
            _availableCustody.isEmpty
                ? 'No confirmed store stock is available to sell.'
                : 'Receive payment and issue a receipt for collection from the store.',
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ],
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Metric(
            'Cash sales total',
            _money(_dashboard?['cashSales']),
            Icons.payments_outlined,
            AppColors.green,
          ),
          _Metric(
            'MoMo sales total',
            _money(_dashboard?['momoSales']),
            Icons.phone_android_outlined,
            AppColors.blue,
          ),
          if (_admin || _buyer)
            _Metric(
              'Stock value',
              _money(_dashboard?['stockValue']),
              Icons.inventory_outlined,
              AppColors.amber,
            ),
        ],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: _salesDays == 0,
              onSelected: (_) => _changeSalesRange(0),
            ),
            ChoiceChip(
              label: const Text('Last 7 days'),
              selected: _salesDays == 7,
              onSelected: (_) => _changeSalesRange(7),
            ),
            ChoiceChip(
              label: const Text('Last 30 days'),
              selected: _salesDays == 30,
              onSelected: (_) => _changeSalesRange(30),
            ),
            ChoiceChip(
              label: const Text('All time'),
              selected: _salesDays == null,
              onSelected: (_) => _changeSalesRange(null),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        title: 'Sales history',
        subtitle:
            'Immediate handovers and store collections share one financial record.',
        child: _sales.isEmpty
            ? const _Empty('No sales recorded yet.')
            : _ModernShopTable<ShopJson>(
                tableKey: 'shop-sales-table',
                rows: _sales,
                initialSortColumn: 0,
                initialSortAscending: false,
                rowKey: (row) => 'shop-sale-${row['id']}',
                columns: [
                  _ShopTableColumn(
                    label: 'Date',
                    sortValue: (row) => _dateValue(row['createdAt']),
                    cell: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dateLabel(row['createdAt']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _timeLabel(row['createdAt']),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Receipt',
                    sortValue: (row) => _saleReceiptReference(row),
                    cell: (row) => TextButton(
                      key: ValueKey('shop-view-sale-receipt-${row['id']}'),
                      onPressed: _saleReceiptReference(row) == null
                          ? null
                          : () => _viewSaleReceipt(row),
                      child: Text(
                        _saleReceiptReference(row) ?? 'Not available',
                      ),
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Buyer',
                    sortValue: (row) =>
                        row['buyerName'] ?? row['studentName'] ?? 'Buyer',
                    cell: (row) => Text(
                      '${row['buyerName'] ?? row['studentName'] ?? 'Buyer'}',
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Collection',
                    sortValue: (row) => row['modelType'],
                    cell: (row) => Text(
                      row['modelType'] == 'IMMEDIATE_RELEASE' ||
                              row['modelType'] == 'CONSIGNMENT'
                          ? 'Given immediately'
                          : 'Store collection',
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Processed by',
                    sortValue: (row) => row['processedByName'],
                    cell: (row) => Text('${row['processedByName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Payment',
                    sortValue: (row) => row['paymentMethod'],
                    cell: (row) => Text(_status(row['paymentMethod'])),
                  ),
                  _ShopTableColumn(
                    label: 'Status',
                    sortValue: (row) => row['status'],
                    cell: (row) => Text(_status(row['status'])),
                  ),
                  _ShopTableColumn(
                    label: 'Sale total',
                    numeric: true,
                    sortValue: (row) => row['totalAmount'],
                    cell: (row) => Text(_money(row['totalAmount'])),
                  ),
                  if (_admin || _buyer)
                    _ShopTableColumn(
                      label: 'Sale profit',
                      numeric: true,
                      sortValue: (row) => row['profit'],
                      cell: (row) => Text(_money(row['profit'])),
                    ),
                  _ShopTableColumn(
                    label: 'Actions',
                    cell: (row) => TextButton(
                      key: ValueKey('shop-open-sale-${row['id']}'),
                      onPressed: () => _showSaleDetails(row),
                      child: const Text('Details'),
                    ),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 12),
      _Panel(
        title: 'Item performance',
        subtitle: 'Best sellers and slow-moving items for the selected period.',
        child: _items.isEmpty
            ? const _Empty('Add catalogue items to see item performance.')
            : _ModernShopTable<ShopJson>(
                tableKey: 'shop-item-performance-table',
                rows: _itemPerformance,
                initialSortColumn: 2,
                initialSortAscending: false,
                rowKey: (row) => 'shop-performance-${row['id'] ?? row['name']}',
                columns: [
                  _ShopTableColumn(
                    label: 'Item',
                    sortValue: (row) => row['name'],
                    cell: (row) => Text('${row['name']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Category',
                    sortValue: (row) => row['category'],
                    cell: (row) => Text('${row['category']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Sold',
                    numeric: true,
                    sortValue: (row) => row['quantity'],
                    cell: (row) => Text('${row['quantity']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Revenue total',
                    numeric: true,
                    sortValue: (row) => row['revenue'],
                    cell: (row) => Text(_money(row['revenue'])),
                  ),
                  if (_admin || _buyer)
                    _ShopTableColumn(
                      label: 'Gross margin total',
                      numeric: true,
                      sortValue: (row) => row['margin'],
                      cell: (row) => Text(_money(row['margin'])),
                    ),
                  _ShopTableColumn(
                    label: 'Available',
                    numeric: true,
                    sortValue: (row) => row['available'],
                    cell: (row) => Text('${row['available']}'),
                  ),
                ],
              ),
      ),
    ],
  );

  Future<void> _loadReport() async {
    setState(() => _reportLoading = true);
    try {
      final report = await widget.api.reportSummary(
        from: _ymd(_reportFrom),
        to: _ymd(_reportTo),
      );
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) _errorSnack(context, error);
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _changeReportRange(int? days) async {
    final now = DateTime.now();
    setState(() {
      _reportDays = days;
      _reportTo = DateTime(now.year, now.month, now.day);
      _reportFrom = days == null
          ? DateTime(now.year, 1, 1)
          : _reportTo.subtract(Duration(days: days == 0 ? 0 : days - 1));
    });
    await _loadReport();
  }

  Future<void> _pickReportRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _reportFrom, end: _reportTo),
      helpText: 'Choose report period',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reportDays = -1;
      _reportFrom = picked.start;
      _reportTo = picked.end;
    });
    await _loadReport();
  }

  Future<void> _downloadShopReport() async {
    if (_reportSections.isEmpty) return;
    setState(() => _downloadingReport = true);
    try {
      final bytes = await widget.api.downloadReport(
        from: _ymd(_reportFrom),
        to: _ymd(_reportTo),
        sections: _reportSections,
      );
      final downloaded = await downloadReportPdf(
        'shop-report-${_ymd(_reportFrom)}-to-${_ymd(_reportTo)}.pdf',
        bytes,
      );
      if (!downloaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF download is available on web.')),
        );
      }
    } catch (error) {
      if (mounted) _errorSnack(context, error);
    } finally {
      if (mounted) setState(() => _downloadingReport = false);
    }
  }

  Widget _reportsPage() {
    final report = _report ?? <String, dynamic>{};
    final summary = Map<String, dynamic>.from(
      (report['summary'] as Map?) ?? const {},
    );
    final daily = _maps(report['dailySales']);
    final performance = _maps(report['itemPerformance']);
    final inventory = _maps(report['inventory']);
    final staffStock = _maps(report['staffStock']);
    final returns = _maps(report['returns']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Shop reports',
          subtitle:
              'Choose a period, review the figures, then download only the sections you need.',
          action: FilledButton.icon(
            key: const ValueKey('shop-download-report'),
            onPressed: _report == null || _downloadingReport
                ? null
                : _downloadShopReport,
            icon: _downloadingReport
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(_downloadingReport ? 'Preparing PDF…' : 'Download PDF'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: _reportDays == 0,
                    onSelected: (_) => _changeReportRange(0),
                  ),
                  ChoiceChip(
                    label: const Text('Last 7 days'),
                    selected: _reportDays == 7,
                    onSelected: (_) => _changeReportRange(7),
                  ),
                  ChoiceChip(
                    label: const Text('Last 30 days'),
                    selected: _reportDays == 30,
                    onSelected: (_) => _changeReportRange(30),
                  ),
                  ChoiceChip(
                    label: const Text('This year'),
                    selected: _reportDays == null,
                    onSelected: (_) => _changeReportRange(null),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('shop-custom-report-range'),
                    onPressed: _pickReportRange,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(
                      '${_dateLabel(_reportFrom)} – ${_dateLabel(_reportTo)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Include in PDF',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children:
                    const {
                      'SUMMARY': 'Summary',
                      'SALES': 'Sales',
                      'INVENTORY': 'Inventory',
                      'STAFF_STOCK': 'Staff stock',
                      'RETURNS': 'Returns',
                    }.entries.map((entry) {
                      final selected = _reportSections.contains(entry.key);
                      return FilterChip(
                        key: ValueKey('shop-report-section-${entry.key}'),
                        selected: selected,
                        label: Text(entry.value),
                        onSelected: (value) {
                          if (!value && _reportSections.length == 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Keep at least one report section.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (value) {
                              _reportSections.add(entry.key);
                            } else {
                              _reportSections.remove(entry.key);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
        if (_reportLoading) const LinearProgressIndicator(),
        if (_report == null && !_reportLoading)
          _MessageCard(
            icon: Icons.summarize_outlined,
            title: 'Report could not be loaded',
            message: 'Try loading this report again.',
            action: TextButton(
              onPressed: _loadReport,
              child: const Text('Try again'),
            ),
          ),
        if (_report != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                'Net sales',
                _money(summary['netSales']),
                Icons.payments_outlined,
                AppColors.green,
              ),
              _Metric(
                'Gross profit',
                _money(summary['grossProfit']),
                Icons.trending_up_outlined,
                AppColors.blue,
              ),
              _Metric(
                'Refunds issued',
                _money(summary['refunds']),
                Icons.currency_exchange_outlined,
                AppColors.amber,
              ),
              _Metric(
                'Stock value',
                _money(summary['stockValue']),
                Icons.inventory_2_outlined,
                AppColors.green,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'Sales activity',
            subtitle:
                '${summary['transactions'] ?? 0} sales · ${summary['unitsSold'] ?? 0} units sold · ${summary['unitsReturned'] ?? 0} returned',
            child: daily.isEmpty
                ? const _Empty('No sales or refunds in this period.')
                : _ModernShopTable<ShopJson>(
                    tableKey: 'shop-report-sales-table',
                    rows: daily,
                    initialSortColumn: 0,
                    initialSortAscending: false,
                    rowKey: (row) => 'shop-report-day-${row['date']}',
                    columns: [
                      _ShopTableColumn(
                        label: 'Date',
                        sortValue: (row) => _dateValue(row['date']),
                        cell: (row) => Text(_dateLabel(row['date'])),
                      ),
                      _ShopTableColumn(
                        label: 'Sales',
                        numeric: true,
                        sortValue: (row) => row['transactions'],
                        cell: (row) => Text('${row['transactions']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Units',
                        numeric: true,
                        sortValue: (row) => row['units'],
                        cell: (row) => Text('${row['units']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Gross sales',
                        numeric: true,
                        sortValue: (row) => row['grossSales'],
                        cell: (row) => Text(_money(row['grossSales'])),
                      ),
                      _ShopTableColumn(
                        label: 'Refunds',
                        numeric: true,
                        sortValue: (row) => row['refunds'],
                        cell: (row) => Text(_money(row['refunds'])),
                      ),
                      _ShopTableColumn(
                        label: 'Net sales',
                        numeric: true,
                        sortValue: (row) => row['netSales'],
                        cell: (row) => Text(
                          _money(row['netSales']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'Item performance',
            subtitle: 'Net quantities and revenue for the selected period.',
            child: performance.isEmpty
                ? const _Empty('No item activity in this period.')
                : _ModernShopTable<ShopJson>(
                    tableKey: 'shop-report-performance-table',
                    rows: performance,
                    initialSortColumn: 4,
                    initialSortAscending: false,
                    rowKey: (row) => 'shop-report-item-${row['item']}',
                    columns: [
                      _ShopTableColumn(
                        label: 'Item',
                        sortValue: (row) => row['item'],
                        cell: (row) => Text('${row['item']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Category',
                        sortValue: (row) => row['category'],
                        cell: (row) => Text('${row['category']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Sold',
                        numeric: true,
                        sortValue: (row) => row['sold'],
                        cell: (row) => Text('${row['sold']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Returned',
                        numeric: true,
                        sortValue: (row) => row['returned'],
                        cell: (row) => Text('${row['returned']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Net units',
                        numeric: true,
                        sortValue: (row) => row['netUnits'],
                        cell: (row) => Text('${row['netUnits']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Net revenue',
                        numeric: true,
                        sortValue: (row) => row['netRevenue'],
                        cell: (row) => Text(_money(row['netRevenue'])),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'Inventory position',
            subtitle:
                '${summary['centralUnits'] ?? 0} central · ${summary['staffHeldUnits'] ?? 0} with staff · ${summary['reservedUnits'] ?? 0} reserved · ${summary['quarantinedUnits'] ?? 0} held for inspection',
            child: inventory.isEmpty
                ? const _Empty('No inventory items.')
                : _ModernShopTable<ShopJson>(
                    tableKey: 'shop-report-inventory-table',
                    rows: inventory,
                    rowKey: (row) => 'shop-report-inventory-${row['id']}',
                    columns: [
                      _ShopTableColumn(
                        label: 'Item',
                        sortValue: (row) => row['item'],
                        cell: (row) => Row(
                          children: [
                            if (row['lowStock'] == true)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.warning_amber,
                                  size: 17,
                                  color: AppColors.amber,
                                ),
                              ),
                            Text('${row['item']}'),
                          ],
                        ),
                      ),
                      for (final column in const [
                        ('Central', 'central'),
                        ('With staff', 'withStaff'),
                        ('Reserved', 'reserved'),
                        ('Held for inspection', 'quarantined'),
                        ('Available', 'available'),
                        ('Total', 'totalOnHand'),
                      ])
                        _ShopTableColumn(
                          label: column.$1,
                          numeric: true,
                          sortValue: (row) => row[column.$2],
                          cell: (row) => Text('${row[column.$2]}'),
                        ),
                      _ShopTableColumn(
                        label: 'Cost value',
                        numeric: true,
                        sortValue: (row) => row['costValue'],
                        cell: (row) => Text(_money(row['costValue'])),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'Stock held by staff',
            subtitle: 'Custody, availability and expected cash.',
            child: staffStock.isEmpty
                ? const _Empty('No stock is currently held by staff.')
                : _ModernShopTable<ShopJson>(
                    tableKey: 'shop-report-staff-stock-table',
                    rows: staffStock,
                    rowKey: (row) => 'shop-report-staff-${row['id']}',
                    columns: [
                      _ShopTableColumn(
                        label: 'Staff member',
                        sortValue: (row) => row['staff'],
                        cell: (row) => Text('${row['staff']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Item',
                        sortValue: (row) => row['item'],
                        cell: (row) => Text('${row['item']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Held',
                        numeric: true,
                        sortValue: (row) => row['held'],
                        cell: (row) => Text('${row['held']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Reserved',
                        numeric: true,
                        sortValue: (row) => row['reserved'],
                        cell: (row) => Text('${row['reserved']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Available',
                        numeric: true,
                        sortValue: (row) => row['available'],
                        cell: (row) => Text('${row['available']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Cash due',
                        numeric: true,
                        sortValue: (row) => row['cashExpected'],
                        cell: (row) => Text(_money(row['cashExpected'])),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'Returns and refunds',
            subtitle:
                '${summary['returnRequests'] ?? 0} requests · ${summary['pendingReturns'] ?? 0} still pending',
            child: returns.isEmpty
                ? const _Empty('No return or refund activity in this period.')
                : _ModernShopTable<ShopJson>(
                    tableKey: 'shop-report-returns-table',
                    rows: returns,
                    initialSortColumn: 0,
                    initialSortAscending: false,
                    rowKey: (row) => 'shop-report-return-${row['id']}',
                    columns: [
                      _ShopTableColumn(
                        label: 'Requested',
                        sortValue: (row) => _dateValue(row['requestedAt']),
                        cell: (row) => Text(_dateLabel(row['requestedAt'])),
                      ),
                      _ShopTableColumn(
                        label: 'Receipt',
                        sortValue: (row) => row['receipt'],
                        cell: (row) => Text('${row['receipt']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Buyer',
                        sortValue: (row) => row['buyer'],
                        cell: (row) => Text('${row['buyer']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Request',
                        sortValue: (row) => row['type'],
                        cell: (row) => Text(_returnType(row['type'])),
                      ),
                      _ShopTableColumn(
                        label: 'Status',
                        sortValue: (row) => row['status'],
                        cell: (row) => _returnStatusChip('${row['status']}'),
                      ),
                      _ShopTableColumn(
                        label: 'Refund',
                        numeric: true,
                        sortValue: (row) => row['refund'],
                        cell: (row) => Text(_money(row['refund'])),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _returnsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Panel(
        title: 'Customer returns and refunds',
        subtitle:
            'Returned goods stay unavailable until approval. Refunds are recorded separately from the original sale.',
        child: _customerReturns.isEmpty
            ? const _Empty('No customer return or cancellation requests.')
            : _ModernShopTable<ShopJson>(
                tableKey: 'shop-customer-returns-table',
                rows: _customerReturns,
                initialSortColumn: 0,
                initialSortAscending: false,
                rowKey: (row) => 'shop-customer-return-${row['id']}',
                onRowTap: _showCustomerReturnDetails,
                columns: [
                  _ShopTableColumn(
                    label: 'Requested',
                    sortValue: (row) => _dateValue(row['requestedAt']),
                    cell: (row) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dateLabel(row['requestedAt'])),
                        Text(
                          _timeLabel(row['requestedAt']),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Receipt',
                    sortValue: (row) => row['receiptReference'],
                    cell: (row) => Text('${row['receiptReference']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Buyer',
                    sortValue: (row) => row['buyerName'],
                    cell: (row) => Text('${row['buyerName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Request',
                    sortValue: (row) => row['requestType'],
                    cell: (row) => Text(_returnType(row['requestType'])),
                  ),
                  _ShopTableColumn(
                    label: 'Refund',
                    numeric: true,
                    sortValue: (row) => row['refundAmount'],
                    cell: (row) => Text(_money(row['refundAmount'])),
                  ),
                  _ShopTableColumn(
                    label: 'Status',
                    sortValue: (row) => row['status'],
                    cell: (row) => _returnStatusChip('${row['status']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Actions',
                    cell: _customerReturnActions,
                  ),
                ],
              ),
      ),
      const SizedBox(height: 14),
      _Panel(
        title: 'Staff stock hand-backs',
        subtitle:
            'Stock returns to inventory only after another store person counts and receives it.',
        child: _staffReturns.isEmpty
            ? const _Empty('No staff stock hand-backs have been requested.')
            : _ModernShopTable<ShopJson>(
                tableKey: 'shop-staff-returns-table',
                rows: _staffReturns,
                initialSortColumn: 0,
                initialSortAscending: false,
                rowKey: (row) => 'shop-staff-return-${row['id']}',
                columns: [
                  _ShopTableColumn(
                    label: 'Requested',
                    sortValue: (row) => _dateValue(row['requestedAt']),
                    cell: (row) => Text(_dateLabel(row['requestedAt'])),
                  ),
                  _ShopTableColumn(
                    label: 'Staff member',
                    sortValue: (row) => row['holderName'],
                    cell: (row) => Text('${row['holderName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Item',
                    sortValue: (row) => row['itemName'],
                    cell: (row) => Text('${row['itemName']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Handing back',
                    numeric: true,
                    sortValue: (row) => row['requestedQuantity'],
                    cell: (row) => Text('${row['requestedQuantity']}'),
                  ),
                  _ShopTableColumn(
                    label: 'Received',
                    numeric: true,
                    sortValue: (row) => row['receivedQuantity'] ?? -1,
                    cell: (row) => Text('${row['receivedQuantity'] ?? '—'}'),
                  ),
                  _ShopTableColumn(
                    label: 'Status',
                    sortValue: (row) => row['status'],
                    cell: (row) => _returnStatusChip('${row['status']}'),
                  ),
                  _ShopTableColumn(label: 'Actions', cell: _staffReturnActions),
                ],
              ),
      ),
    ],
  );

  String _returnType(dynamic type) => type == 'UNCOLLECTED_CANCELLATION'
      ? 'Cancel uncollected order'
      : 'Customer return';

  Widget _returnStatusChip(String status) {
    final color = switch (status) {
      'COMPLETED' => AppColors.green,
      'REJECTED' || 'DISCREPANCY' => AppColors.red,
      'REFUND_PENDING' ||
      'PENDING_APPROVAL' ||
      'PENDING_RECEIPT' => AppColors.amber,
      _ => AppColors.blue,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_status(status)),
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide(color: color.withValues(alpha: .25)),
    );
  }

  Widget _customerReturnActions(ShopJson row) {
    final current = _context?['currentUserId'];
    if (row['status'] == 'PENDING_APPROVAL' && row['approverId'] == current) {
      return Wrap(
        spacing: 6,
        children: [
          TextButton(
            onPressed: () => _decideCustomerReturn(row, false),
            child: const Text('Reject'),
          ),
          FilledButton(
            key: ValueKey('shop-approve-return-${row['id']}'),
            onPressed: () => _decideCustomerReturn(row, true),
            child: const Text('Approve'),
          ),
        ],
      );
    }
    if (row['status'] == 'REFUND_PENDING' &&
        _context?['canIssueRefunds'] == true) {
      return FilledButton(
        key: ValueKey('shop-issue-refund-${row['id']}'),
        onPressed: () =>
            _dialog(_RefundDialog(api: widget.api, customerReturn: row)),
        child: const Text('Issue refund'),
      );
    }
    return TextButton(
      onPressed: () => _showCustomerReturnDetails(row),
      child: const Text('View'),
    );
  }

  Widget _staffReturnActions(ShopJson row) {
    final canReceive =
        _context?['canReceiveStaffReturns'] == true &&
        row['holderId'] != _context?['currentUserId'];
    if (row['status'] != 'PENDING_RECEIPT' || !canReceive) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      children: [
        TextButton(
          onPressed: () => _rejectStaffReturn(row),
          child: const Text('Problem'),
        ),
        FilledButton(
          key: ValueKey('shop-receive-staff-return-${row['id']}'),
          onPressed: () => _dialog(
            _ReceiveStaffReturnDialog(api: widget.api, staffReturn: row),
          ),
          child: const Text('Receive stock'),
        ),
      ],
    );
  }

  Future<void> _decideCustomerReturn(ShopJson row, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reject return request?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject request'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.isEmpty) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve return?'),
          content: Text(
            '${row['receiptReference']} · ${_money(row['refundAmount'])}\n\nReturned stock will be recorded now. The refund must then be issued separately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.api.decideCustomerReturn(
        row,
        approve ? 'APPROVE' : 'REJECT',
        reason: reason,
      );
      await _load();
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    }
  }

  Future<void> _rejectStaffReturn(ShopJson row) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report hand-back problem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What is wrong?',
            hintText: 'Items were not presented or cannot be counted',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Record problem'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await widget.api.receiveStaffReturn(row, action: 'REJECT', note: reason);
      await _load();
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    }
  }

  ShopJson? _receiptForSale(ShopJson sale) {
    for (final receipt in _receipts) {
      if (sale['id'] != null && receipt['sale']?['id'] == sale['id']) {
        return receipt;
      }
    }
    return null;
  }

  String? _saleReceiptReference(ShopJson sale) =>
      (sale['receiptReference'] ?? _receiptForSale(sale)?['reference'])
          as String?;

  Future<void> _viewSaleReceipt(ShopJson sale) async {
    try {
      var receipt = _receiptForSale(sale);
      if (receipt == null) {
        final reference = _saleReceiptReference(sale);
        if (reference == null) return;
        final matches = await widget.api.receipts(query: reference);
        for (final match in matches) {
          if (match['sale']?['id'] == sale['id']) {
            receipt = match;
            break;
          }
        }
      }
      if (!mounted) return;
      if (receipt == null) {
        _errorSnack(
          context,
          'This receipt is unavailable. Refresh and try again.',
        );
        return;
      }
      await _showIssuedReceipt(receipt);
    } catch (error) {
      if (mounted) _errorSnack(context, error);
    }
  }

  Future<void> _showSaleDetails(ShopJson sale) async {
    final returnable = _maps(sale['lines'])
        .where((line) => ((line['returnableQuantity'] ?? 0) as num).toInt() > 0)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sale details'),
        content: SizedBox(
          width: 650,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sale['buyerName'] ?? sale['studentName'] ?? 'Buyer'} · ${_money(sale['totalAmount'])}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final line in _maps(sale['lines']))
                ListTile(
                  dense: true,
                  title: Text('${line['quantity']} × ${line['itemName']}'),
                  subtitle: Text(
                    '${line['returnableQuantity'] ?? 0} available to return',
                  ),
                  trailing: Text(_money(line['lineTotal'])),
                ),
            ],
          ),
        ),
        actions: [
          if (_saleReceiptReference(sale) != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _viewSaleReceipt(sale);
              },
              child: const Text('View receipt'),
            ),
          if ({'COLLECTED', 'PARTIALLY_REFUNDED'}.contains(sale['status']) &&
              returnable.isNotEmpty)
            TextButton(
              key: ValueKey('shop-start-return-${sale['id']}'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _dialog(
                  _CustomerReturnDialog(
                    api: widget.api,
                    sale: sale,
                    approvers: _maps(_context?['returnApprovers']),
                  ),
                );
              },
              child: const Text('Start return'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerReturnDetails(ShopJson row) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(_returnType(row['requestType'])),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['receiptReference']} · ${row['buyerName']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _returnStatusChip('${row['status']}'),
            const SizedBox(height: 12),
            for (final line in _maps(row['lines']))
              ListTile(
                dense: true,
                title: Text('${line['quantity']} × ${line['itemName']}'),
                subtitle: Text('Condition: ${_status(line['condition'])}'),
                trailing: Text(_money(line['lineTotal'])),
              ),
            const Divider(),
            Text('Reason: ${row['reason']}'),
            Text('Requested by ${row['requestedByName']}'),
            Text('Approver: ${row['approverName']}'),
            if (row['refundedByName'] != null)
              Text(
                'Refunded by ${row['refundedByName']} via ${_status(row['refundMethod'])}',
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _rolesPage() {
    final staff = _maps(_context?['staff']);
    final byUser = <int, Set<String>>{};
    for (final r in _roles) {
      byUser
          .putIfAbsent(r['userId'] as int, () => <String>{})
          .add('${r['roleCode']}');
    }
    return _Panel(
      title: 'Shop responsibilities',
      subtitle:
          'Give each person only the work they perform. One person may have multiple roles in a small school.',
      child: Column(
        children: staff
            .map(
              (u) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${u['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children:
                              ((_context?['roleOptions'] as List? ?? [])
                                      .cast<String>())
                                  .map(
                                    (role) => FilterChip(
                                      label: Text(_roleName(role)),
                                      selected:
                                          byUser[u['id']]?.contains(role) ==
                                          true,
                                      onSelected: (value) =>
                                          _setRole(u, role, value),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _auditPage() => _Panel(
    title: 'Shop audit trail',
    subtitle:
        'Who changed stock, received payment, released goods or reviewed an account.',
    child: _auditEvents.isEmpty
        ? const _Empty('No shop activity has been recorded yet.')
        : Column(
            children: _auditEvents
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_outlined),
                    title: Text(
                      '${_status(e['action'])} · ${_status(e['entityType'])}',
                    ),
                    subtitle: Text('${e['actorName']} · ${e['details'] ?? ''}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _dateLabel(e['occurredAt']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _timeLabel(e['occurredAt']),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );

  Future<void> _setRole(ShopJson user, String role, bool active) async {
    try {
      await widget.api.saveRoles([
        {'userId': user['id'], 'roleCode': role, 'active': active},
      ]);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _issuedReceiptsTable({
    required String emptyMessage,
    required String tableKey,
  }) {
    final receipts = _receipts
        .where((r) => r['cashierName'] == _context?['currentUserName'])
        .toList();
    if (receipts.isEmpty) return _Empty(emptyMessage);
    return _ModernShopTable<ShopJson>(
      tableKey: tableKey,
      rows: receipts,
      initialSortColumn: 0,
      initialSortAscending: false,
      rowKey: (row) => 'shop-issued-receipt-${row['id']}',
      onRowTap: _showIssuedReceipt,
      columns: [
        _ShopTableColumn(
          label: 'Date',
          sortValue: (row) => _dateValue(row['issuedAt']),
          cell: (row) => Column(
            key: ValueKey('shop-open-receipt-row-${row['id']}'),
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(row['issuedAt']),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_timeLabel(row['issuedAt']).isNotEmpty)
                Text(
                  _timeLabel(row['issuedAt']),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        _ShopTableColumn(
          label: 'Receipt',
          sortValue: (row) => row['reference'],
          cell: (row) => Text(
            '${row['reference']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _ShopTableColumn(
          label: 'Buyer',
          sortValue: _receiptBuyer,
          cell: (row) => Text(_receiptBuyer(row)),
        ),
        _ShopTableColumn(
          label: 'Items',
          sortValue: (row) => _maps(row['sale']?['lines']).length,
          cell: (row) => Text(_receiptItemSummary(row)),
        ),
        _ShopTableColumn(
          label: 'Payment',
          sortValue: (row) => row['sale']?['paymentMethod'],
          cell: (row) =>
              Text(_status(row['sale']?['paymentMethod'] ?? 'Not recorded')),
        ),
        _ShopTableColumn(
          label: 'Status',
          sortValue: (row) => row['status'],
          cell: (row) => Text(_status(row['status'])),
        ),
        _ShopTableColumn(
          label: 'Amount',
          numeric: true,
          sortValue: (row) => row['sale']?['totalAmount'],
          cell: (row) => Text(_money(row['sale']?['totalAmount'])),
        ),
        _ShopTableColumn(
          label: 'Actions',
          cell: (row) => TextButton(
            key: ValueKey('shop-open-receipt-${row['id']}'),
            onPressed: () => _showIssuedReceipt(row),
            child: const Text('View receipt'),
          ),
        ),
      ],
    );
  }

  String _receiptBuyer(ShopJson r) =>
      '${r['sale']?['buyerName'] ?? r['sale']?['studentName'] ?? 'Buyer'}';

  String _receiptItemSummary(ShopJson receipt) {
    final lines = _maps(receipt['sale']?['lines']);
    final quantity = lines.fold<int>(
      0,
      (total, line) => total + ((line['quantity'] ?? 0) as num).toInt(),
    );
    final typeLabel = lines.length == 1 ? 'item type' : 'item types';
    final unitLabel = quantity == 1 ? 'unit' : 'units';
    return '${lines.length} $typeLabel · $quantity $unitLabel';
  }

  Future<void> _showIssuedReceipt(ShopJson receipt) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ShopReceiptDialog(
        receipt: receipt,
        schoolName: '${_context?['schoolName'] ?? 'School shop'}',
        title: 'Receipt',
        onDone: () => Navigator.pop(dialogContext),
        additionalActions: [
          if ({
                'PENDING_COLLECTION',
                'PENDING_PICKUP',
              }.contains(receipt['status']) &&
              _maps(_context?['returnApprovers']).isNotEmpty)
            TextButton(
              key: ValueKey('shop-request-cancellation-${receipt['id']}'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _dialog(
                  _CancellationRequestDialog(
                    api: widget.api,
                    receipt: receipt,
                    approvers: _maps(_context?['returnApprovers']),
                  ),
                );
              },
              child: const Text('Request cancellation'),
            ),
        ],
      ),
    );
  }

  String _receiptItems(ShopJson r) => _maps(
    r['sale']?['lines'],
  ).map((l) => '${l['quantity']} × ${l['itemName']}').join(', ');
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 205,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _InventoryQuantityCard extends StatelessWidget {
  const _InventoryQuantityCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 124,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F6),
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _InventoryInfo extends StatelessWidget {
  const _InventoryInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _ActionLanding extends StatelessWidget {
  const _ActionLanding({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    required this.below,
  });
  final IconData icon;
  final String title, message;
  final Widget button, below;
  @override
  Widget build(BuildContext context) =>
      _Panel(title: title, subtitle: message, action: button, child: below);
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) action!,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    ),
  );
}

class _ShopTableColumn<T> {
  const _ShopTableColumn({
    required this.label,
    required this.cell,
    this.sortValue,
    this.numeric = false,
  });

  final String label;
  final Widget Function(T row) cell;
  final Object? Function(T row)? sortValue;
  final bool numeric;
}

class _ModernShopTable<T> extends StatefulWidget {
  const _ModernShopTable({
    required this.tableKey,
    required this.rows,
    required this.columns,
    this.initialSortColumn = 0,
    this.initialSortAscending = true,
    this.rowKey,
    this.onRowTap,
  });

  final String tableKey;
  final List<T> rows;
  final List<_ShopTableColumn<T>> columns;
  final int initialSortColumn;
  final bool initialSortAscending;
  final Object Function(T row)? rowKey;
  final ValueChanged<T>? onRowTap;

  @override
  State<_ModernShopTable<T>> createState() => _ModernShopTableState<T>();
}

class _ModernShopTableState<T> extends State<_ModernShopTable<T>> {
  late int _sortColumn;
  late bool _sortAscending;
  final ScrollController _horizontalController = ScrollController(
    keepScrollOffset: false,
  );
  int _page = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _sortColumn = widget.initialSortColumn;
    _sortAscending = widget.initialSortAscending;
  }

  @override
  void didUpdateWidget(covariant _ModernShopTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableKey == widget.tableKey) return;
    _sortColumn = widget.initialSortColumn;
    _sortAscending = widget.initialSortAscending;
    _page = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  int _compareValues(Object? left, Object? right) {
    if (left == null && right == null) return 0;
    if (left == null) return -1;
    if (right == null) return 1;
    if (left is num && right is num) {
      return left.toDouble().compareTo(right.toDouble());
    }
    if (left is DateTime && right is DateTime) return left.compareTo(right);
    return left.toString().toLowerCase().compareTo(
      right.toString().toLowerCase(),
    );
  }

  List<T> get _sortedRows {
    final rows = [...widget.rows];
    final value = widget.columns[_sortColumn].sortValue;
    if (value == null) return rows;
    rows.sort((left, right) {
      final result = _compareValues(value(left), value(right));
      return _sortAscending ? result : -result;
    });
    return rows;
  }

  void _sort(int column, bool ascending) {
    if (widget.columns[column].sortValue == null) return;
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sortedRows;
    final pageCount = (rows.length / _rowsPerPage).ceil().clamp(1, 999);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _rowsPerPage;
    final visible = rows.skip(start).take(_rowsPerPage).toList();
    final activeSortColumn = widget.columns[_sortColumn].sortValue == null
        ? null
        : _sortColumn;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: PageStorageKey('${widget.tableKey}-horizontal-scroll'),
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                key: ValueKey(widget.tableKey),
                showCheckboxColumn: false,
                sortColumnIndex: activeSortColumn,
                sortAscending: _sortAscending,
                headingRowHeight: 48,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 62,
                horizontalMargin: 18,
                columnSpacing: 28,
                dividerThickness: .6,
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFF3F7F6),
                ),
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: .35,
                ),
                columns: widget.columns.asMap().entries.map((entry) {
                  final index = entry.key;
                  final column = entry.value;
                  return DataColumn(
                    numeric: column.numeric,
                    tooltip: column.sortValue == null
                        ? null
                        : 'Sort by ${column.label.toLowerCase()}',
                    onSort: column.sortValue == null ? null : _sort,
                    label: Row(
                      key: ValueKey(
                        '${widget.tableKey}-sort-${column.label.toLowerCase()}',
                      ),
                      children: [
                        Text(column.label.toUpperCase()),
                        if (column.sortValue != null &&
                            activeSortColumn != index) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.unfold_more_rounded,
                            size: 14,
                            color: AppColors.muted,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                rows: visible.map((row) {
                  final onTap = widget.onRowTap == null
                      ? null
                      : () => widget.onRowTap!(row);
                  return DataRow(
                    key: widget.rowKey == null
                        ? null
                        : ValueKey(widget.rowKey!(row)),
                    cells: widget.columns
                        .map(
                          (column) => DataCell(column.cell(row), onTap: onTap),
                        )
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Rows:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _rowsPerPage,
                items: const [5, 10, 20]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text('$value')),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _rowsPerPage = value ?? 10;
                  _page = 0;
                }),
              ),
              const SizedBox(width: 18),
              Text(
                rows.isEmpty
                    ? '0 of 0'
                    : '${start + 1}-${start + visible.length} of ${rows.length}',
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: page + 1 < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<ShopJson> _maps(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
String _money(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return 'GHS ${n.toStringAsFixed(2)}';
}

DateTime? _shopDate(dynamic value) {
  if (value is List && value.length >= 3) {
    return DateTime(
      (value[0] as num).toInt(),
      (value[1] as num).toInt(),
      (value[2] as num).toInt(),
      value.length > 3 ? (value[3] as num).toInt() : 0,
      value.length > 4 ? (value[4] as num).toInt() : 0,
      value.length > 5 ? (value[5] as num).toInt() : 0,
      value.length > 6 ? ((value[6] as num).toInt() ~/ 1000000) : 0,
    );
  }
  return DateTime.tryParse('$value');
}

DateTime _dateValue(dynamic value) => _shopDate(value) ?? DateTime(1970);

String _dateOnly(dynamic value) {
  final date = _dateValue(value);
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

const _shortMonths = [
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

String _dateLabel(dynamic value) {
  final date = _shopDate(value);
  if (date == null) return 'Not recorded';
  return '${date.day.toString().padLeft(2, '0')} ${_shortMonths[date.month - 1]} ${date.year}';
}

String _timeLabel(dynamic value) {
  final date = _shopDate(value);
  if (date == null) return '';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
}

String _status(dynamic value) {
  final raw = '${value ?? ''}';
  if (raw == 'PENDING_ACCEPTANCE') return 'Awaiting recipient confirmation';
  if (raw == 'PENDING_RECEIPT') return 'Awaiting store receipt';
  return raw
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

String _stockSourceLabel(dynamic value) => switch ('$value') {
  'NOT_RECORDED' => 'Source not recorded',
  'SCHOOL_TRANSFER' => 'School transfer',
  'DONATION' => 'Donation',
  'OPENING_STOCK' => 'Opening stock',
  'OTHER' => 'Other source',
  _ => 'Purchased elsewhere',
};
String? _stockSourceName(ShopJson entry) {
  final value = '${entry['sourceName'] ?? entry['supplier'] ?? ''}'.trim();
  return value.isEmpty || value == 'Not recorded' || value == 'Not specified'
      ? null
      : value;
}

String _roleName(String role) => switch (role) {
  'BUYER' => 'Stock manager',
  'SELLER' => 'Seller',
  'CASHIER' => 'Cashier',
  'GOODS_STAFF' => 'Store / goods release',
  _ => _status(role),
};

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({
    required this.api,
    required this.contextData,
    this.item,
    this.onSaved,
  });
  final ShopApiClient api;
  final ShopJson contextData;
  final ShopJson? item;
  final ValueChanged<ShopJson>? onSaved;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _otherCategory,
      _sku,
      _variant,
      _threshold;
  String? _category;
  String? _skuError;
  String _codeMethod = 'AUTO';
  String _unit = 'piece';
  bool _active = true, _saving = false;

  List<String> get _categoryOptions =>
      (widget.contextData['categories'] as List? ?? [])
          .map((value) => '$value'.trim())
          .where(
            (value) =>
                value.isNotEmpty &&
                value.toLowerCase() != 'other' &&
                value.toLowerCase() != 'other / add new category' &&
                value != '__OTHER__',
          )
          .toSet()
          .toList();

  @override
  void initState() {
    super.initState();
    final i = widget.item ?? {};
    final categories = _categoryOptions.toSet();
    final existingCategory = '${i['category'] ?? ''}'.trim();
    _name = TextEditingController(text: '${i['name'] ?? ''}');
    _category = existingCategory.isEmpty
        ? null
        : categories.contains(existingCategory)
        ? existingCategory
        : '__OTHER__';
    _otherCategory = TextEditingController(
      text: _category == '__OTHER__' ? existingCategory : '',
    );
    _sku = TextEditingController(text: '${i['sku'] ?? ''}');
    _codeMethod = widget.item == null ? 'AUTO' : 'MANUAL';
    _sku.addListener(_clearSkuError);
    _variant = TextEditingController(text: '${i['variantLabel'] ?? ''}');
    _threshold = TextEditingController(text: '${i['lowStockThreshold'] ?? 5}');
    _unit = '${i['unitOfMeasure'] ?? 'piece'}';
    _active = i['active'] != false;
  }

  @override
  void dispose() {
    _sku.removeListener(_clearSkuError);
    for (final c in [_name, _otherCategory, _sku, _variant, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearSkuError() {
    if (_skuError != null && mounted) setState(() => _skuError = null);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final savedItem = await widget.api.saveItem({
        'name': _name.text.trim(),
        'category': _category == '__OTHER__'
            ? _otherCategory.text.trim()
            : _category,
        'sku': _codeMethod == 'AUTO' ? '' : _sku.text.trim(),
        'unitOfMeasure': _unit,
        'variantLabel': _variant.text.trim().isEmpty
            ? null
            : _variant.text.trim(),
        'lowStockThreshold': int.parse(_threshold.text),
        'active': _active,
        'version': widget.item?['version'],
      }, id: widget.item?['id'] as int?);
      widget.onSaved?.call(savedItem);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final duplicateCode =
            e is ShopApiException &&
            e.statusCode == 409 &&
            (e.message.toLowerCase().contains('sku') ||
                e.message.toLowerCase().contains('item code')) &&
            e.message.toLowerCase().contains('used');
        if (duplicateCode) {
          setState(
            () => _skuError =
                'This item code is already in use. Enter another code or choose Auto-generate.',
          );
        } else {
          _errorSnack(context, e);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Add item type' : 'Edit item type'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item == null) ...[
                const _MessageCard(
                  icon: Icons.category_outlined,
                  title: 'Reusable item definition',
                  message:
                      'Define the name, category and unit here. Enter quantity, unit cost and unit selling price when stock is added.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('item-type-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('item-type-category'),
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        ..._categoryOptions.map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: '__OTHER__',
                          child: Text('Other / Add new category'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _category = value),
                      validator: (value) =>
                          value == null ? 'Select a category' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('item-type-code-method'),
                      value: _codeMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Item code method',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'AUTO',
                          child: Text('Auto-generate'),
                        ),
                        DropdownMenuItem(
                          value: 'MANUAL',
                          child: Text('Enter item code'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _codeMethod = value ?? 'AUTO';
                        _skuError = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_codeMethod == 'AUTO') ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'A unique item code will be created when you save.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('item-type-code'),
                  controller: _sku,
                  decoration: InputDecoration(
                    labelText: 'Item code',
                    hintText: 'Enter a unique code, e.g. EXB-80',
                    errorText: _skuError,
                  ),
                  validator: (value) => _skuError ?? _required(value),
                ),
              ],
              if (_category == '__OTHER__') ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('item-type-other-category'),
                  controller: _otherCategory,
                  decoration: const InputDecoration(
                    labelText: 'New category name',
                    hintText: 'Type the category name',
                  ),
                  validator: _required,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          (widget.contextData['units'] as List? ?? []).contains(
                            _unit,
                          )
                          ? _unit
                          : 'piece',
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items:
                          (widget.contextData['units'] as List? ??
                                  const ['piece'])
                              .cast<String>()
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _variant,
                      decoration: const InputDecoration(
                        labelText: 'Variant (optional)',
                        hintText: 'e.g. Size 10, Blue',
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.item != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current available quantity: ${widget.item!['availableQuantity']} ${widget.item!['unitOfMeasure']}\nUse Add stock to increase quantity so every stock receipt remains audited.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _threshold,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Low-stock alert'),
                validator: _wholeNumberValidator,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save item type'),
      ),
    ],
  );
}

class _PurchaseLineDraft {
  _PurchaseLineDraft();
  int? itemId;
  String selectedItemLabel = '';
  final itemSearch = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final cost = TextEditingController();
  final selling = TextEditingController();
  void dispose() {
    itemSearch.dispose();
    quantity.dispose();
    cost.dispose();
    selling.dispose();
  }
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({
    required this.api,
    required this.items,
    required this.contextData,
  });
  final ShopApiClient api;
  final List<ShopJson> items;
  final ShopJson contextData;
  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _form = GlobalKey<FormState>();
  final _sourceReference = TextEditingController(),
      _notes = TextEditingController();
  final List<_PurchaseLineDraft> _lines = [_PurchaseLineDraft()];
  DateTime _date = DateTime.now();
  bool _saving = false;
  @override
  void dispose() {
    _sourceReference.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ids = _lines.map((l) => l.itemId).toList();
    if (ids.toSet().length != ids.length) {
      _errorSnack(context, 'Each item can appear only once.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.recordStock({
        'sourceReference': _sourceReference.text.trim(),
        'receivedDate': _ymd(_date),
        'notes': _notes.text.trim(),
        'lines': _lines
            .map(
              (l) => {
                'itemId': l.itemId,
                'quantity': int.parse(l.quantity.text),
                'unitCost': double.parse(l.cost.text),
                'sellingPrice': double.parse(l.selling.text),
              },
            )
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _lineIncompleteMessage(_PurchaseLineDraft line) {
    final hasSelection = line.itemId != null;
    final selectedSuggestion =
        line.itemSearch.text.trim() == line.selectedItemLabel;
    if (!hasSelection || !selectedSuggestion) return 'choose an item';
    if (_positiveWholeNumberValidator(line.quantity.text) != null) {
      return 'enter the quantity received';
    }
    if (_moneyValidator(line.cost.text) != null) {
      return 'enter the unit cost price';
    }
    if (_positiveMoneyValidator(line.selling.text) != null) {
      return 'enter the unit selling price';
    }
    return null;
  }

  void _addAnotherItem() {
    final current = _lines.last;
    final missing = _lineIncompleteMessage(current);
    if (missing != null) {
      _form.currentState?.validate();
      _errorSnack(
        context,
        'Complete this item before adding another: $missing.',
      );
      return;
    }
    if (_lines
        .take(_lines.length - 1)
        .any((line) => line.itemId == current.itemId)) {
      _errorSnack(
        context,
        'This item is already included in this stock entry.',
      );
      return;
    }
    setState(() => _lines.add(_PurchaseLineDraft()));
  }

  String _itemPickerLabel(ShopJson item) {
    final displayName = '${item['displayName'] ?? item['name'] ?? ''}'.trim();
    return '$displayName · ${item['sku']} · ${item['category']}';
  }

  Future<void> _createAndSelectItem(
    int index,
    FormFieldState<int> field,
  ) async {
    final line = _lines[index];
    field.didChange(null);
    setState(() {
      line.itemId = null;
      line.selectedItemLabel = '';
      line.itemSearch.clear();
    });

    ShopJson? createdItem;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ItemDialog(
        api: widget.api,
        contextData: widget.contextData,
        onSaved: (item) => createdItem = item,
      ),
    );
    if (!mounted || createdItem == null) return;

    final item = createdItem!;
    widget.items.removeWhere((existing) => existing['id'] == item['id']);
    widget.items.add(item);
    final label = _itemPickerLabel(item);
    setState(() {
      line.itemId = item['id'] as int;
      line.selectedItemLabel = label;
      line.itemSearch.text = label;
      line.cost.clear();
      line.selling.clear();
    });
    field.didChange(line.itemId);
  }

  Widget _purchaseItemPicker(int index) => FormField<int>(
    validator: (_) {
      final line = _lines[index];
      final hasSelection = line.itemId != null;
      final selectedSuggestion =
          line.itemSearch.text.trim() == line.selectedItemLabel;
      return hasSelection && selectedSuggestion
          ? null
          : 'Select an existing item or choose Add a new item';
    },
    builder: (field) => DropdownMenu<int>(
      key: ValueKey('purchase-item-search-$index'),
      controller: _lines[index].itemSearch,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      filterCallback: (entries, filter) {
        final query = filter.trim().toLowerCase();
        final addNew = entries.where((entry) => entry.value == -1).toList();
        if (query.length < 2) return addNew;
        return [
          ...addNew,
          ...entries
              .where(
                (entry) =>
                    entry.value != -1 &&
                    entry.label.toLowerCase().contains(query),
              )
              .take(15),
        ];
      },
      label: const Text('Select item'),
      hintText: 'Search by name or item code, then select a result',
      errorText: field.errorText,
      initialSelection: _lines[index].itemId,
      dropdownMenuEntries: [
        const DropdownMenuEntry(
          value: -1,
          label: '＋ Add a new item',
          leadingIcon: Icon(Icons.add),
        ),
        ...widget.items
            .where((i) => i['active'] == true)
            .map(
              (i) => DropdownMenuEntry(
                value: i['id'] as int,
                label: _itemPickerLabel(i),
                leadingIcon: const Icon(Icons.inventory_2_outlined),
              ),
            ),
      ],
      onSelected: (value) {
        if (value == -1) {
          _createAndSelectItem(index, field);
          return;
        }
        field.didChange(value);
        setState(() {
          final line = _lines[index];
          line.itemId = value;
          if (value != null) {
            final item = widget.items.firstWhere((x) => x['id'] == value);
            line.selectedItemLabel = _itemPickerLabel(item);
            line.itemSearch.text = line.selectedItemLabel;
            line.cost.clear();
            line.selling.clear();
          }
        });
      },
    ),
  );

  Widget _purchaseQuantityField(int index) => TextFormField(
    key: ValueKey('purchase-quantity-$index'),
    controller: _lines[index].quantity,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(labelText: 'Quantity received'),
    validator: _positiveWholeNumberValidator,
  );

  Widget _purchaseCostField(int index) => TextFormField(
    key: ValueKey('purchase-cost-$index'),
    controller: _lines[index].cost,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(labelText: 'Unit cost price (GHS)'),
    validator: _moneyValidator,
  );

  Widget _purchaseSellingField(int index) => TextFormField(
    key: ValueKey('purchase-selling-$index'),
    controller: _lines[index].selling,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(labelText: 'Unit selling price (GHS)'),
    validator: _positiveMoneyValidator,
  );

  Widget _purchaseLineTotal(int index) => AnimatedBuilder(
    animation: Listenable.merge([_lines[index].quantity, _lines[index].cost]),
    builder: (context, _) {
      final quantity = int.tryParse(_lines[index].quantity.text.trim()) ?? 0;
      final unitCost = double.tryParse(_lines[index].cost.text.trim()) ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'LINE TOTAL',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(quantity * unitCost),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      );
    },
  );

  Widget _removePurchaseLineButton(int index) => IconButton(
    tooltip: 'Remove item',
    onPressed: _lines.length == 1
        ? null
        : () {
            setState(() {
              final line = _lines.removeAt(index);
              line.dispose();
            });
          },
    icon: const Icon(Icons.remove_circle_outline),
  );

  Widget _compactPurchaseLine(int index) => LayoutBuilder(
    key: ValueKey('purchase-line-$index'),
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 520;
      final fullWidth = constraints.maxWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _purchaseItemPicker(index)),
              const SizedBox(width: 8),
              SizedBox(width: 48, child: _removePurchaseLineButton(index)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: narrow ? fullWidth : 180,
                child: _purchaseQuantityField(index),
              ),
              SizedBox(
                width: narrow ? fullWidth : 220,
                child: _purchaseCostField(index),
              ),
              SizedBox(
                width: narrow ? fullWidth : 220,
                child: _purchaseSellingField(index),
              ),
              SizedBox(
                height: 56,
                width: narrow ? fullWidth : 150,
                child: _purchaseLineTotal(index),
              ),
            ],
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add stock'),
    content: SizedBox(
      width: 1040,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MessageCard(
                icon: Icons.move_to_inbox_outlined,
                title: 'Record stock entering the shop',
                message:
                    'This updates inventory only. It does not create an expense or record another payment.',
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('stock-received-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Date received · ${_ymd(_date)}'),
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < _lines.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_compactPurchaseLine(index)],
                    ),
                  ),
                ),
              TextButton.icon(
                key: const ValueKey('purchase-add-another-item'),
                onPressed: _addAnotherItem,
                icon: const Icon(Icons.add),
                label: const Text('Add another item'),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 4),
                child: Text(
                  'Complete the current item before adding another.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const ValueKey('stock-additional-details'),
                  title: const Text('Additional details'),
                  subtitle: const Text('Reference and notes are optional'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextFormField(
                      key: const ValueKey('stock-source-reference'),
                      controller: _sourceReference,
                      decoration: const InputDecoration(
                        labelText: 'Existing record reference (optional)',
                        hintText: 'Expense, invoice or receipt number',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Add to inventory'),
      ),
    ],
  );
}

class _ConsignmentDialog extends StatefulWidget {
  const _ConsignmentDialog({
    required this.api,
    required this.contextData,
    required this.items,
    required this.roles,
    this.initialItem,
  });
  final ShopApiClient api;
  final ShopJson contextData;
  final List<ShopJson> items, roles;
  final ShopJson? initialItem;
  @override
  State<_ConsignmentDialog> createState() => _ConsignmentDialogState();
}

class _ConsignmentDialogState extends State<_ConsignmentDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1'),
      _location = TextEditingController(),
      _note = TextEditingController();
  int? _seller, _item;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    final initialId = initial?['id'];
    final isValid =
        initial != null &&
        initial['active'] == true &&
        initialId is int &&
        ((initial['availableQuantity'] as num?)?.toInt() ?? 0) > 0 &&
        widget.items.any(
          (item) => item['id'] == initialId && item['active'] == true,
        );
    if (isValid) _item = initialId;
  }

  ShopJson? get _selectedItem {
    for (final item in widget.items) {
      if (item['id'] == _item) return item;
    }
    return null;
  }

  int? get _availableQuantity =>
      (_selectedItem?['availableQuantity'] as num?)?.toInt();

  String? get _quantityRestriction {
    final available = _availableQuantity;
    final requested = int.tryParse(_quantity.text.trim());
    if (available == null || requested == null || requested <= available) {
      return null;
    }
    return 'Only $available ${_selectedItem?['unitOfMeasure'] ?? 'items'} are available. Reduce the quantity to continue.';
  }

  @override
  void dispose() {
    _quantity.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _quantityRestriction != null) {
      setState(() {});
      return;
    }
    final recipient = _maps(
      widget.contextData['staff'],
    ).firstWhere((person) => person['id'] == _seller);
    final item = _selectedItem!;
    final quantity = int.parse(_quantity.text);
    final available = _availableQuantity ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Prepare this handover?'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reserve $quantity ${item['unitOfMeasure']} of ${item['displayName']} for ${recipient['name']}?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _InventoryInfo(
                label: 'Available stock after reservation',
                value:
                    '$available → ${available - quantity} ${item['unitOfMeasure']}',
              ),
              const SizedBox(height: 12),
              Text(
                'The stock remains in the central store until ${recipient['name']} physically counts and confirms receipt. Only then will custody move.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            key: const ValueKey('confirm-stock-issue'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prepare handover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      await widget.api.createConsignment({
        'sellerId': _seller,
        'itemId': _item,
        'quantity': quantity,
        'locationName': _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _serverError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = _maps(widget.contextData['staff']);
    return AlertDialog(
      title: const Text('Prepare stock handover'),
      content: SizedBox(
        width: 520,
        child: staff.isEmpty
            ? const _MessageCard(
                icon: Icons.person_add_alt,
                title: 'No staff available',
                message: 'Add active staff before issuing stock.',
              )
            : Form(
                key: _form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        key: const ValueKey('issue-stock-recipient'),
                        value: _seller,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Person receiving and keeping the stock',
                        ),
                        items: staff
                            .map(
                              (u) => DropdownMenuItem(
                                value: u['id'] as int,
                                child: Text('${u['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _seller = v),
                        validator: (v) =>
                            v == null ? 'Select a recipient' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: const ValueKey('issue-stock-item'),
                        value: _item,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: widget.items
                            .where(
                              (i) =>
                                  i['active'] == true &&
                                  (i['availableQuantity'] as num).toInt() > 0,
                            )
                            .map(
                              (i) => DropdownMenuItem(
                                value: i['id'] as int,
                                child: Text(
                                  '${i['displayName']} · ${i['availableQuantity']} available',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _item = v;
                          _serverError = null;
                          _form.currentState?.validate();
                        }),
                        validator: (v) => v == null ? 'Select an item' : null,
                      ),
                      if (_selectedItem != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_availableQuantity ?? 0} ${_selectedItem?['unitOfMeasure'] ?? 'items'} available to issue',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('issue-stock-quantity'),
                        controller: _quantity,
                        onChanged: (_) => setState(() {
                          _serverError = null;
                          _form.currentState?.validate();
                        }),
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          helperText: _availableQuantity == null
                              ? 'Select an item to see available stock'
                              : 'Maximum available: $_availableQuantity',
                        ),
                        validator: (value) {
                          final basic = _positiveWholeNumberValidator(value);
                          if (basic != null) return basic;
                          return _quantityRestriction;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Store or location (optional)',
                          hintText: 'Main store, Primary block',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'The recipient must confirm receipt before this stock can be sold.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      if (_quantityRestriction != null || _serverError != null)
                        Container(
                          key: const ValueKey('issue-stock-restriction'),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: .35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.red,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _quantityRestriction ?? _serverError!,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (staff.isNotEmpty)
          FilledButton(
            key: const ValueKey('issue-stock-submit'),
            onPressed: _saving || _quantityRestriction != null ? null : _save,
            child: Text(_saving ? 'Issuing…' : 'Send for confirmation'),
          ),
      ],
    );
  }
}

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({
    required this.api,
    required this.item,
    required this.contextData,
  });
  final ShopApiClient api;
  final ShopJson item;
  final ShopJson contextData;
  @override
  State<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends State<_InventoryAdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController();
  String _type = 'STOCK_REDUCTION';
  int? _approverId;
  bool _saving = false;

  List<ShopJson> get _approvers =>
      _maps(widget.contextData['inventoryApprovers']);
  int get _current =>
      ((widget.item['unassignedQuantity'] ??
                  widget.item['centralQuantity'] ??
                  0)
              as num)
          .toInt();
  int get _reserved => ((widget.item['reservedQuantity'] ?? 0) as num).toInt();
  int? get _entered => int.tryParse(_quantity.text.trim());
  int? get _proposed {
    final value = _entered;
    if (value == null) return null;
    return switch (_type) {
      'STOCK_INCREASE' => _current + value,
      'STOCK_REDUCTION' => _current - value,
      _ => value,
    };
  }

  @override
  void initState() {
    super.initState();
    if (_approvers.length == 1) _approverId = _approvers.first['id'] as int;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.requestInventoryAdjustment({
        'itemId': widget.item['id'],
        'adjustmentType': _type,
        'proposedQuantity': _proposed,
        'reason': _reason.text.trim(),
        'approverId': _approverId,
        'itemVersion': widget.item['version'],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposed = _proposed;
    final unit = '${widget.item['unitOfMeasure']}';
    return AlertDialog(
      title: const Text('Request inventory adjustment'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.item['displayName']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current unassigned quantity: $_current $unit${_reserved > 0 ? ' · $_reserved reserved' : ''}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('inventory-adjustment-type'),
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'What needs to change?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'STOCK_REDUCTION',
                      child: Text('Remove damaged, lost or expired stock'),
                    ),
                    DropdownMenuItem(
                      value: 'STOCK_INCREASE',
                      child: Text('Add stock found during a count'),
                    ),
                    DropdownMenuItem(
                      value: 'COUNT_CORRECTION',
                      child: Text('Correct to the physical count'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _type = value!;
                    _form.currentState?.validate();
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('inventory-adjustment-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _type == 'COUNT_CORRECTION'
                        ? 'Actual physical quantity'
                        : _type == 'STOCK_INCREASE'
                        ? 'Quantity to add'
                        : 'Quantity to remove',
                    helperText: _type == 'STOCK_REDUCTION'
                        ? 'Maximum removable now: ${_current - _reserved} $unit'
                        : null,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a whole quantity of zero or more';
                    }
                    if (_type != 'COUNT_CORRECTION' && parsed == 0) {
                      return 'Enter a quantity greater than zero';
                    }
                    final next = _proposed;
                    if (next == null || next < 0) {
                      return 'The resulting quantity cannot be negative';
                    }
                    if (next < _reserved) {
                      return 'Cannot go below $_reserved reserved items';
                    }
                    if (next == _current) {
                      return 'The proposed quantity must be different';
                    }
                    return null;
                  },
                ),
                if (proposed != null && proposed >= 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Proposed change: $_current → $proposed $unit',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('inventory-adjustment-reason'),
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Explain what happened and how it was verified',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                if (_approvers.isEmpty)
                  const _MessageCard(
                    icon: Icons.info_outline,
                    title: 'Another approver is required',
                    message:
                        'Add another administrator or head teacher before submitting this adjustment.',
                  )
                else
                  DropdownButtonFormField<int>(
                    key: const ValueKey('inventory-adjustment-approver'),
                    value: _approverId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Approver'),
                    items: _approvers
                        .map(
                          (person) => DropdownMenuItem<int>(
                            value: person['id'] as int,
                            child: Text('${person['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _approverId = value),
                    validator: (value) =>
                        value == null ? 'Select an approver' : null,
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Inventory will not change until the assigned approver approves this request.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('inventory-adjustment-submit'),
          onPressed: _saving || _approvers.isEmpty ? null : _save,
          child: Text(_saving ? 'Submitting…' : 'Submit for approval'),
        ),
      ],
    );
  }
}

class _CustomerReturnDialog extends StatefulWidget {
  const _CustomerReturnDialog({
    required this.api,
    required this.sale,
    required this.approvers,
  });
  final ShopApiClient api;
  final ShopJson sale;
  final List<ShopJson> approvers;
  @override
  State<_CustomerReturnDialog> createState() => _CustomerReturnDialogState();
}

class _CustomerReturnDialogState extends State<_CustomerReturnDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController();
  late int? _lineId;
  late int? _approverId;
  String _condition = 'GOOD';
  bool _saving = false;

  List<ShopJson> get _lines => _maps(widget.sale['lines'])
      .where((line) => ((line['returnableQuantity'] ?? 0) as num).toInt() > 0)
      .toList();
  ShopJson? get _line => _lines.cast<ShopJson?>().firstWhere(
    (line) => line?['id'] == _lineId,
    orElse: () => null,
  );

  @override
  void initState() {
    super.initState();
    _lineId = _lines.isEmpty ? null : _lines.first['id'] as int;
    _approverId = widget.approvers.isEmpty
        ? null
        : widget.approvers.first['id'] as int;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _lineId == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.requestCustomerReturn({
        'saleId': widget.sale['id'],
        'reason': _reason.text.trim(),
        'approverId': _approverId,
        'lines': [
          {
            'saleLineId': _lineId,
            'quantity': int.parse(_quantity.text),
            'condition': _condition,
          },
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request customer return'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('customer-return-item'),
              value: _lineId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Item returned'),
              items: _lines
                  .map(
                    (line) => DropdownMenuItem<int>(
                      value: line['id'] as int,
                      child: Text(
                        '${line['itemName']} · ${line['returnableQuantity']} returnable',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _lineId = value;
                _quantity.text = '1';
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('customer-return-quantity'),
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (value) {
                      final basic = _positiveWholeNumberValidator(value);
                      if (basic != null) return basic;
                      final maximum =
                          ((_line?['returnableQuantity'] ?? 0) as num).toInt();
                      return int.parse(value!) > maximum
                          ? 'Maximum returnable is $maximum'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('customer-return-condition'),
                    value: _condition,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Condition'),
                    items: const [
                      DropdownMenuItem(
                        value: 'GOOD',
                        child: Text('Good — can be sold'),
                      ),
                      DropdownMenuItem(
                        value: 'DAMAGED',
                        child: Text('Damaged — hold for inspection'),
                      ),
                      DropdownMenuItem(
                        value: 'UNSELLABLE',
                        child: Text('Unsellable — hold for inspection'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _condition = value ?? 'GOOD'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('customer-return-reason'),
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('customer-return-approver'),
              value: _approverId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Approver'),
              items: widget.approvers
                  .map(
                    (person) => DropdownMenuItem<int>(
                      value: person['id'] as int,
                      child: Text('${person['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _approverId = value),
              validator: (value) => value == null
                  ? 'Another administrator must approve this return'
                  : null,
            ),
            const SizedBox(height: 10),
            const Text(
              'The item remains on return hold until approval. Money is issued only after approval.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('customer-return-submit'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Submitting…' : 'Submit for approval'),
      ),
    ],
  );
}

class _CancellationRequestDialog extends StatefulWidget {
  const _CancellationRequestDialog({
    required this.api,
    required this.receipt,
    required this.approvers,
  });
  final ShopApiClient api;
  final ShopJson receipt;
  final List<ShopJson> approvers;
  @override
  State<_CancellationRequestDialog> createState() =>
      _CancellationRequestDialogState();
}

class _CancellationRequestDialogState
    extends State<_CancellationRequestDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late int? _approverId;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _approverId = widget.approvers.isEmpty
        ? null
        : widget.approvers.first['id'] as int;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.requestCollectionCancellation(
        widget.receipt,
        approverId: _approverId!,
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request order cancellation'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.receipt['reference']} · ${_money(widget.receipt['sale']?['totalAmount'])}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _approverId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Approver'),
              items: widget.approvers
                  .map(
                    (person) => DropdownMenuItem<int>(
                      value: person['id'] as int,
                      child: Text('${person['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _approverId = value),
              validator: (value) => value == null ? 'Select an approver' : null,
            ),
            const SizedBox(height: 10),
            const Text(
              'The goods stay reserved until another person approves. The refund is then issued separately.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Submitting…' : 'Submit for approval'),
      ),
    ],
  );
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.api, required this.customerReturn});
  final ShopApiClient api;
  final ShopJson customerReturn;
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  String _method = 'CASH';
  bool _saving = false;
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.issueRefund(
        widget.customerReturn,
        method: _method,
        reference: _reference.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Issue customer refund'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.customerReturn['buyerName']} · ${_money(widget.customerReturn['refundAmount'])}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('refund-method'),
              value: _method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Refund method'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'MOMO', child: Text('MoMo')),
              ],
              onChanged: (value) => setState(() => _method = value ?? 'CASH'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('refund-reference'),
              controller: _reference,
              decoration: InputDecoration(
                labelText: _method == 'MOMO'
                    ? 'MoMo refund reference'
                    : 'Payment reference (optional)',
              ),
              validator: (value) =>
                  _method == 'MOMO' && (value == null || value.trim().isEmpty)
                  ? 'Enter the MoMo refund reference'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        key: const ValueKey('refund-submit'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Recording…' : 'Confirm money issued'),
      ),
    ],
  );
}

class _ReceiveStaffReturnDialog extends StatefulWidget {
  const _ReceiveStaffReturnDialog({
    required this.api,
    required this.staffReturn,
  });
  final ShopApiClient api;
  final ShopJson staffReturn;
  @override
  State<_ReceiveStaffReturnDialog> createState() =>
      _ReceiveStaffReturnDialogState();
}

class _ReceiveStaffReturnDialogState extends State<_ReceiveStaffReturnDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  final _note = TextEditingController();
  String _condition = 'GOOD';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: '${widget.staffReturn['requestedQuantity']}',
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.receiveStaffReturn(
        widget.staffReturn,
        action: 'RECEIVE',
        receivedQuantity: int.parse(_quantity.text),
        condition: _condition,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Receive returned stock'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.staffReturn['holderName']} · ${widget.staffReturn['itemName']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('staff-return-received-quantity'),
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity physically received',
              ),
              validator: (value) {
                final basic = _positiveWholeNumberValidator(value);
                if (basic != null) return basic;
                return int.parse(value!) >
                        (widget.staffReturn['requestedQuantity'] as num).toInt()
                    ? 'Cannot exceed the hand-back request'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('staff-return-condition'),
              value: _condition,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: const [
                DropdownMenuItem(value: 'GOOD', child: Text('Good')),
                DropdownMenuItem(
                  value: 'DAMAGED',
                  child: Text('Damaged — hold for inspection'),
                ),
                DropdownMenuItem(
                  value: 'UNSELLABLE',
                  child: Text('Unsellable — hold for inspection'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _condition = value ?? 'GOOD'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Receiving note (optional)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        key: const ValueKey('staff-return-receive-submit'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Receiving…' : 'Confirm receipt'),
      ),
    ],
  );
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.api, required this.consignment});
  final ShopApiClient api;
  final ShopJson consignment;
  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1'),
      _reason = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.returnStock(
        widget.consignment,
        int.parse(_quantity.text),
        _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hand back unsold stock'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.consignment['itemName']} · ${widget.consignment['availableQuantity'] ?? widget.consignment['remainingQuantity']} available to return',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity handing back',
              ),
              validator: (v) {
                final basic = _positiveWholeNumberValidator(v);
                if (basic != null) return basic;
                return int.parse(v!) >
                        ((widget.consignment['availableQuantity'] ??
                                    widget.consignment['remainingQuantity'])
                                as num)
                            .toInt()
                    ? 'Cannot exceed remaining stock'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: _required,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Submitting…' : 'Submit hand-back'),
      ),
    ],
  );
}

class _SaleLineDraft {
  _SaleLineDraft();
  int? choiceId;
  final itemSearch = TextEditingController();
  final quantity = TextEditingController(text: '1');
  void dispose() {
    itemSearch.dispose();
    quantity.dispose();
  }
}

class _SaleDialog extends StatefulWidget {
  const _SaleDialog({
    required this.api,
    required this.choices,
    required this.contextData,
    required this.collectFromStore,
  });
  final ShopApiClient api;
  final List<ShopJson> choices;
  final ShopJson contextData;
  final bool collectFromStore;
  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _form = GlobalKey<FormState>();
  final _studentSearch = TextEditingController(),
      _buyerName = TextEditingController(),
      _buyerReference = TextEditingController(),
      _momo = TextEditingController();
  final List<_SaleLineDraft> _lines = [_SaleLineDraft()];
  List<ShopJson> _students = [];
  ShopJson? _student, _result;
  int? _staffBuyer;
  Timer? _studentSearchDebounce;
  int _studentSearchGeneration = 0;
  String _buyerType = 'STUDENT';
  String _payment = 'CASH';
  bool _saving = false, _searching = false;

  @override
  void dispose() {
    _studentSearchDebounce?.cancel();
    _studentSearch.dispose();
    _buyerName.dispose();
    _buyerReference.dispose();
    _momo.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int _id(ShopJson c) => c['id'] as int;
  String _name(ShopJson c) => '${c['itemName']}';
  int _available(ShopJson c) =>
      ((c['availableQuantity'] ?? c['remainingQuantity']) as num).toInt();
  double _price(ShopJson c) => (c['sellingPrice'] as num).toDouble();
  List<ShopJson> get _staff => _maps(widget.contextData['staff']);

  String _staffName(ShopJson person) =>
      '${person['name'] ?? person['fullName'] ?? person['username'] ?? ''}';

  ShopJson? _staffById(int? id) {
    if (id == null) return null;
    for (final person in _staff) {
      if (person['id'] == id) return person;
    }
    return null;
  }

  List<ShopJson> get _staffMatches {
    final query = _buyerName.text.trim().toLowerCase();
    if (query.isEmpty || _staffBuyer != null) return const [];
    return _staff
        .where((person) {
          final searchable = [
            _staffName(person),
            person['username'],
            person['email'],
            person['staffId'],
          ].whereType<Object>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .take(8)
        .toList();
  }

  String get _buyerTypeLabel => switch (_buyerType) {
    'GUARDIAN' => 'Guardian or parent',
    'WALK_IN' => 'Walk-in buyer',
    'OTHER' => 'Other buyer',
    _ => 'Buyer',
  };
  ShopJson? _choice(int? id) {
    if (id == null) return null;
    for (final c in widget.choices) {
      if (_id(c) == id) return c;
    }
    return null;
  }

  List<ShopJson> _itemMatches(_SaleLineDraft line) {
    final query = line.itemSearch.text.trim().toLowerCase();
    if (query.isEmpty || line.choiceId != null) return const [];
    return widget.choices
        .where((choice) {
          final searchable = [
            _itemOptionText(choice),
            _name(choice),
            choice['sku'],
            choice['itemCode'],
            choice['holderName'],
            choice['locationName'],
          ].whereType<Object>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .take(8)
        .toList();
  }

  String _itemOptionText(ShopJson choice) =>
      '${_name(choice)} · ${_available(choice)} available · ${_money(choice['sellingPrice'])} each';

  String _itemSuggestionDetail(ShopJson choice) {
    final location = choice['locationName'];
    return 'Held by ${choice['holderName']}${location == null ? '' : ' · $location'}';
  }

  double get _total => _lines.fold(0, (sum, l) {
    final c = _choice(l.choiceId);
    final q = int.tryParse(l.quantity.text) ?? 0;
    return sum + (c == null ? 0 : _price(c) * q);
  });

  void _studentSearchChanged(String value) {
    if (_student != null && value.trim() != '${_student!['name']}'.trim()) {
      _student = null;
    }
    _studentSearchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _students = [];
        _searching = false;
      });
      return;
    }
    setState(() {});
    _studentSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      _searchStudent,
    );
  }

  Future<void> _searchStudent() async {
    final q = _studentSearch.text.trim();
    if (q.length < 2) return;
    final generation = ++_studentSearchGeneration;
    setState(() => _searching = true);
    try {
      final rows = await widget.api.students(q);
      if (mounted && generation == _studentSearchGeneration) {
        setState(() => _students = rows.take(8).toList());
      }
    } catch (e) {
      if (mounted && generation == _studentSearchGeneration) {
        setState(() => _students = []);
      }
    } finally {
      if (mounted && generation == _studentSearchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ids = _lines.map((l) => l.choiceId).toList();
    if (ids.toSet().length != ids.length) {
      _errorSnack(context, 'Each item can appear only once.');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'buyerType': _buyerType,
        'studentCustomId': _buyerType == 'STUDENT'
            ? (_student == null ? null : _student!['customStudentId'])
            : null,
        'buyerUserId': _buyerType == 'STAFF' ? _staffBuyer : null,
        'buyerName': switch (_buyerType) {
          'STUDENT' when _student == null => _studentSearch.text.trim(),
          'STAFF' when _staffBuyer == null => _buyerName.text.trim(),
          'GUARDIAN' || 'WALK_IN' || 'OTHER' => _buyerName.text.trim(),
          _ => null,
        },
        'buyerReference': _buyerReference.text.trim().isEmpty
            ? null
            : _buyerReference.text.trim(),
        'paymentMethod': _payment,
        'momoReference': _payment == 'MOMO' ? _momo.text.trim() : null,
        'fulfillmentMode': widget.collectFromStore
            ? 'STORE_COLLECTION'
            : 'IMMEDIATE_RELEASE',
        'lines': _lines.map((l) {
          final c = _choice(l.choiceId)!;
          return {
            'itemId': c['itemId'],
            'consignmentId': c['id'],
            'quantity': int.parse(l.quantity.text),
          };
        }).toList(),
      };
      final result = widget.collectFromStore
          ? await widget.api.issueReceipt(body)
          : await widget.api.sellerSale(body);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ShopJson _receiptData() {
    final serverSale = _result?['sale'];
    final sale = serverSale is Map
        ? Map<String, dynamic>.from(serverSale)
        : <String, dynamic>{};
    final buyerName = _buyerType == 'STUDENT'
        ? (_student?['name'] ?? _studentSearch.text.trim())
        : _buyerName.text.trim();
    final saleLines = sale['lines'] is List
        ? sale['lines']
        : _lines.map((line) {
            final choice = _choice(line.choiceId)!;
            final quantity = int.tryParse(line.quantity.text) ?? 0;
            final unitPrice = _price(choice);
            return {
              'itemName': _name(choice),
              'quantity': quantity,
              'unitPrice': unitPrice,
              'lineTotal': unitPrice * quantity,
            };
          }).toList();
    return {
      ...?_result,
      'issuedAt': _result?['issuedAt'] ?? DateTime.now().toIso8601String(),
      'cashierName':
          _result?['cashierName'] ?? widget.contextData['currentUserName'],
      'custodianName':
          _result?['custodianName'] ??
          (_lines.isEmpty
              ? null
              : _choice(_lines.first.choiceId)?['holderName']),
      'sale': {
        ...sale,
        'buyerType': sale['buyerType'] ?? _buyerType,
        'buyerName': sale['buyerName'] ?? buyerName,
        'paymentMethod': sale['paymentMethod'] ?? _payment,
        'momoReference':
            sale['momoReference'] ??
            (_payment == 'MOMO' ? _momo.text.trim() : null),
        'totalAmount': sale['totalAmount'] ?? _total,
        'lines': saleLines,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ShopReceiptDialog(
        receipt: _receiptData(),
        schoolName: '${widget.contextData['schoolName'] ?? 'School shop'}',
        onDone: () => Navigator.pop(context, true),
      );
    }
    return AlertDialog(
      title: Text(
        widget.collectFromStore
            ? 'Sell for later collection'
            : 'Sell and hand over now',
      ),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('shop-buyer-type'),
                  value: _buyerType,
                  decoration: const InputDecoration(labelText: 'Buyer type'),
                  items: const [
                    DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem(
                      value: 'STAFF',
                      child: Text('Staff member'),
                    ),
                    DropdownMenuItem(
                      value: 'GUARDIAN',
                      child: Text('Guardian or parent'),
                    ),
                    DropdownMenuItem(
                      value: 'WALK_IN',
                      child: Text('Walk-in buyer'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _buyerType = value;
                      _student = null;
                      _students = [];
                      _staffBuyer = null;
                      _studentSearch.clear();
                      _buyerName.clear();
                      _buyerReference.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_buyerType == 'STUDENT')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const ValueKey('shop-student-buyer-search'),
                        controller: _studentSearch,
                        onChanged: _studentSearchChanged,
                        onFieldSubmitted: (_) => _searchStudent(),
                        decoration: InputDecoration(
                          labelText: 'Student name or ID',
                          hintText: 'Start typing to find a student',
                          helperText: _student == null
                              ? 'Select a suggestion, or keep the typed name if the buyer is not listed.'
                              : 'Selected · ${_student!['customStudentId']}',
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _student != null
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.green,
                                )
                              : const Icon(Icons.search),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the student name'
                            : null,
                      ),
                      if (_student == null && _students.isNotEmpty)
                        _BuyerSuggestions(
                          key: const ValueKey('shop-student-suggestions'),
                          rows: _students,
                          nameOf: (person) => '${person['name']}',
                          detailOf: (person) =>
                              '${person['customStudentId']} · ${person['className'] ?? ''} ${person['section'] ?? ''}'
                                  .trim(),
                          onSelected: (person) => setState(() {
                            _studentSearchDebounce?.cancel();
                            _student = person;
                            _studentSearch.text = '${person['name']}';
                            _students = [];
                          }),
                        ),
                    ],
                  )
                else if (_buyerType == 'STAFF')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const ValueKey('shop-staff-buyer-search'),
                        controller: _buyerName,
                        onChanged: (value) => setState(() {
                          if (_staffBuyer == null) return;
                          final selected = _staffById(_staffBuyer);
                          if (selected == null ||
                              value.trim() != _staffName(selected).trim()) {
                            _staffBuyer = null;
                          }
                        }),
                        decoration: InputDecoration(
                          labelText: 'Staff name',
                          hintText: 'Start typing to find a staff member',
                          helperText: _staffBuyer == null
                              ? 'Select a suggestion, or keep the typed name if the buyer is not listed.'
                              : 'Staff member selected',
                          suffixIcon: _staffBuyer == null
                              ? const Icon(Icons.search)
                              : const Icon(
                                  Icons.check_circle,
                                  color: AppColors.green,
                                ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the staff member name'
                            : null,
                      ),
                      if (_staffMatches.isNotEmpty)
                        _BuyerSuggestions(
                          key: const ValueKey('shop-staff-suggestions'),
                          rows: _staffMatches,
                          nameOf: _staffName,
                          detailOf: (person) =>
                              '${person['staffId'] ?? person['email'] ?? person['username'] ?? 'School staff'}',
                          onSelected: (person) => setState(() {
                            _staffBuyer = person['id'] as int;
                            _buyerName.text = _staffName(person);
                          }),
                        ),
                    ],
                  )
                else
                  TextFormField(
                    key: const ValueKey('shop-other-buyer-name'),
                    controller: _buyerName,
                    decoration: InputDecoration(
                      labelText: '$_buyerTypeLabel name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the ${_buyerTypeLabel.toLowerCase()} name'
                        : null,
                  ),
                if (_buyerType != 'STUDENT') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('shop-buyer-reference'),
                    controller: _buyerReference,
                    decoration: const InputDecoration(
                      labelText: 'Phone, ID or reference (optional)',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < _lines.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                key: ValueKey('shop-sale-item-search-$index'),
                                controller: _lines[index].itemSearch,
                                onChanged: (value) => setState(() {
                                  final selected = _choice(
                                    _lines[index].choiceId,
                                  );
                                  if (selected != null &&
                                      value.trim() !=
                                          _itemOptionText(selected).trim()) {
                                    _lines[index].choiceId = null;
                                  }
                                }),
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Item',
                                  hintText: 'Start typing item name or code',
                                  helperText: _lines[index].choiceId == null
                                      ? 'Select an available stock item from the suggestions.'
                                      : 'Selected stock · ${_itemSuggestionDetail(_choice(_lines[index].choiceId)!)}',
                                  helperMaxLines: 2,
                                  suffixIcon: _lines[index].choiceId == null
                                      ? const Icon(Icons.search)
                                      : const Icon(
                                          Icons.check_circle,
                                          color: AppColors.green,
                                        ),
                                ),
                                validator: (_) => _lines[index].choiceId == null
                                    ? 'Select a valid item from the suggestions'
                                    : null,
                              ),
                              if (_itemMatches(_lines[index]).isNotEmpty)
                                _ItemSuggestions(
                                  key: ValueKey(
                                    'shop-sale-item-suggestions-$index',
                                  ),
                                  rows: _itemMatches(_lines[index]),
                                  nameOf: _itemOptionText,
                                  detailOf: _itemSuggestionDetail,
                                  onSelected: (choice) => setState(() {
                                    _lines[index].choiceId = _id(choice);
                                    _lines[index].itemSearch.text =
                                        _itemOptionText(choice);
                                  }),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lines[index].quantity,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            validator: (v) {
                              final basic = _positiveWholeNumberValidator(v);
                              if (basic != null) return basic;
                              final c = _choice(_lines[index].choiceId);
                              return c != null && int.parse(v!) > _available(c)
                                  ? 'Max ${_available(c)}'
                                  : null;
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: _lines.length == 1
                              ? null
                              : () {
                                  setState(() {
                                    final line = _lines.removeAt(index);
                                    line.dispose();
                                  });
                                },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_SaleLineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another item'),
                ),
                const Divider(height: 28),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'CASH',
                      icon: Icon(Icons.payments_outlined),
                      label: Text('Cash'),
                    ),
                    ButtonSegment(
                      value: 'MOMO',
                      icon: Icon(Icons.phone_android_outlined),
                      label: Text('MoMo'),
                    ),
                  ],
                  selected: {_payment},
                  onSelectionChanged: (v) => setState(() => _payment = v.first),
                ),
                if (_payment == 'MOMO') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _momo,
                    decoration: const InputDecoration(
                      labelText: 'MoMo transaction reference',
                    ),
                    validator: _required,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Sale total',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      _money(_total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
                if (widget.collectFromStore)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Payment reserves the selected goods until pickup.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Saving…'
                : widget.collectFromStore
                ? 'Receive payment and create token'
                : 'Record payment and release',
          ),
        ),
      ],
    );
  }
}

class _ShopReceiptDialog extends StatefulWidget {
  const _ShopReceiptDialog({
    required this.receipt,
    required this.schoolName,
    required this.onDone,
    this.title = 'Payment received',
    this.additionalActions = const [],
  });

  final ShopJson receipt;
  final String schoolName;
  final VoidCallback onDone;
  final String title;
  final List<Widget> additionalActions;

  @override
  State<_ShopReceiptDialog> createState() => _ShopReceiptDialogState();
}

class _ShopReceiptDialogState extends State<_ShopReceiptDialog> {
  String? _working;

  ShopJson get _sale => widget.receipt['sale'] is Map
      ? Map<String, dynamic>.from(widget.receipt['sale'] as Map)
      : <String, dynamic>{};
  List<ShopJson> get _lines => _maps(_sale['lines']);
  String get _reference => '${widget.receipt['reference'] ?? 'SHOP-RECEIPT'}';
  String get _fileName =>
      '${_reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-')}.pdf';

  Future<void> _runReceiptAction(String action) async {
    setState(() => _working = action);
    try {
      final bytes = await buildShopReceiptPdf(
        receipt: widget.receipt,
        schoolName: widget.schoolName,
      );
      final success = switch (action) {
        'download' => await downloadReportPdf(_fileName, bytes),
        'print' => await Printing.layoutPdf(
          name: _fileName,
          onLayout: (_) async => bytes,
        ),
        'share' => await Printing.sharePdf(
          bytes: bytes,
          filename: _fileName,
          subject: '${widget.schoolName} shop receipt',
          body: 'Receipt $_reference',
        ),
        _ => false,
      };
      if (!success && mounted) {
        _errorSnack(
          context,
          action == 'share'
              ? 'Sharing is not available on this device. Download the receipt instead.'
              : 'The receipt could not be ${action == 'print' ? 'opened for printing' : 'downloaded'}.',
        );
      }
    } catch (error) {
      if (mounted) _errorSnack(context, error);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = '${widget.receipt['pickupToken'] ?? ''}'.trim();
    final issuedAt = widget.receipt['issuedAt'];
    final paymentMethod = '${_sale['paymentMethod'] ?? 'CASH'}'.toUpperCase();
    final paymentReference = '${_sale['momoReference'] ?? ''}'.trim();
    final paymentLabel = paymentMethod == 'MOMO'
        ? 'Mobile Money${paymentReference.isEmpty ? '' : ' · $paymentReference'}'
        : _status(paymentMethod);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title)),
          IconButton(onPressed: widget.onDone, icon: const Icon(Icons.close)),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Container(
            key: const ValueKey('shop-receipt-preview'),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.schoolName,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'SCHOOL SHOP RECEIPT',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ReceiptStatusPill(shopReceiptStatusLabel(widget.receipt)),
                  ],
                ),
                const Divider(height: 30),
                _ReceiptDetail(label: 'Receipt number', value: _reference),
                _ReceiptDetail(
                  label: 'Date',
                  value:
                      '${_dateLabel(issuedAt)}${_timeLabel(issuedAt).isEmpty ? '' : ' · ${_timeLabel(issuedAt)}'}',
                ),
                _ReceiptDetail(
                  label: 'Buyer',
                  value:
                      '${_sale['buyerName'] ?? _sale['studentName'] ?? 'Not specified'}',
                ),
                _ReceiptDetail(label: 'Payment', value: paymentLabel),
                _ReceiptDetail(
                  label: 'Received by',
                  value:
                      '${widget.receipt['cashierName'] ?? _sale['processedByName'] ?? 'School shop'}',
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  color: AppColors.green.withValues(alpha: .07),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ITEM',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 45,
                        child: Text(
                          'QTY',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'TOTAL',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final line in _lines)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${line['itemName'] ?? 'Item'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_money(line['unitPrice'])} each',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${line['quantity'] ?? 0}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            _money(line['lineTotal']),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL PAID',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        _money(_sale['totalAmount']),
                        key: const ValueKey('shop-receipt-total'),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (token.isNotEmpty &&
                    shopReceiptAwaitingCollection(widget.receipt)) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: .35),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'COLLECTION TOKEN',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        SelectableText(
                          token,
                          key: const ValueKey('shop-receipt-token'),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        Text(
                          'Present this receipt and token to ${widget.receipt['custodianName'] ?? 'the store'} to collect the items.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        ...widget.additionalActions,
        OutlinedButton.icon(
          key: const ValueKey('shop-share-receipt'),
          onPressed: _working == null ? () => _runReceiptAction('share') : null,
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Share'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('shop-download-receipt'),
          onPressed: _working == null
              ? () => _runReceiptAction('download')
              : null,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download PDF'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('shop-print-receipt'),
          onPressed: _working == null ? () => _runReceiptAction('print') : null,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print'),
        ),
        FilledButton(
          onPressed: _working == null ? widget.onDone : null,
          child: Text(_working == null ? 'Done' : 'Preparing…'),
        ),
      ],
    );
  }
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ReceiptStatusPill extends StatelessWidget {
  const _ReceiptStatusPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.green,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _BuyerSuggestions extends StatelessWidget {
  const _BuyerSuggestions({
    super.key,
    required this.rows,
    required this.nameOf,
    required this.detailOf,
    required this.onSelected,
  });

  final List<ShopJson> rows;
  final String Function(ShopJson) nameOf;
  final String Function(ShopJson) detailOf;
  final ValueChanged<ShopJson> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final person = rows[index];
        return ListTile(
          dense: true,
          leading: const CircleAvatar(
            radius: 16,
            child: Icon(Icons.person_outline, size: 18),
          ),
          title: Text(nameOf(person)),
          subtitle: Text(detailOf(person)),
          onTap: () => onSelected(person),
        );
      },
    ),
  );
}

class _ItemSuggestions extends StatelessWidget {
  const _ItemSuggestions({
    super.key,
    required this.rows,
    required this.nameOf,
    required this.detailOf,
    required this.onSelected,
  });

  final List<ShopJson> rows;
  final String Function(ShopJson) nameOf;
  final String Function(ShopJson) detailOf;
  final ValueChanged<ShopJson> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    constraints: const BoxConstraints(maxHeight: 240),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = rows[index];
        return ListTile(
          dense: true,
          leading: const CircleAvatar(
            radius: 16,
            child: Icon(Icons.inventory_2_outlined, size: 17),
          ),
          title: Text(nameOf(item)),
          subtitle: Text(detailOf(item)),
          onTap: () => onSelected(item),
        );
      },
    ),
  );
}

String? _required(dynamic value) =>
    value == null || '$value'.trim().isEmpty ? 'Required' : null;
String? _moneyValidator(String? value) =>
    value == null || double.tryParse(value) == null || double.parse(value) < 0
    ? 'Enter a valid amount'
    : null;
String? _positiveMoneyValidator(String? value) =>
    value == null || double.tryParse(value) == null || double.parse(value) <= 0
    ? 'Enter an amount above zero'
    : null;
String? _wholeNumberValidator(String? value) =>
    value == null || int.tryParse(value) == null || int.parse(value) < 0
    ? 'Enter a whole number'
    : null;
String? _positiveWholeNumberValidator(String? value) =>
    value == null || int.tryParse(value) == null || int.parse(value) <= 0
    ? 'Enter a number above zero'
    : null;
String _ymd(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
void _errorSnack(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text('$error')));
