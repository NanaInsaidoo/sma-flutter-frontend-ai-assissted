import 'package:flutter/material.dart';
import '../data/shop_api_client.dart';
import '../../theme/app_theme.dart';

enum _ShopPage {
  overview,
  itemTypes,
  catalog,
  consignments,
  sell,
  cashier,
  release,
  accounts,
  sales,
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
      _reconciliations = [],
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
  int? _salesDays = 30;
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
      final sales = await widget.api.sales();
      final customerReturns = await widget.api.customerReturns();
      final staffReturns = await widget.api.staffReturns();
      final recs = context['isAdmin'] == true || context['canSell'] == true
          ? await widget.api.reconciliations()
          : <ShopJson>[];
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
        _reconciliations = recs;
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
    if (_cashier) _ShopPage.cashier,
    if (_goods) _ShopPage.release,
    if (_admin || _seller) _ShopPage.accounts,
    _ShopPage.sales,
    _ShopPage.returns,
    if (_admin) _ShopPage.roles,
    if (_admin) _ShopPage.audit,
  ];

  String _label(_ShopPage page) => switch (page) {
    _ShopPage.overview => 'Overview',
    _ShopPage.itemTypes => 'Item types',
    _ShopPage.catalog => 'Inventory',
    _ShopPage.consignments => !_buyer ? 'My stock' : 'Issue stock',
    _ShopPage.sell => 'Sell items',
    _ShopPage.cashier => 'Take payment',
    _ShopPage.release => 'Release goods',
    _ShopPage.accounts => 'Accounts',
    _ShopPage.sales => 'Sales',
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
    _ShopPage.cashier => Icons.receipt_long_outlined,
    _ShopPage.release => Icons.qr_code_scanner_outlined,
    _ShopPage.accounts => Icons.balance_outlined,
    _ShopPage.sales => Icons.analytics_outlined,
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
                        onSelected: (_) => setState(() => _page = page),
                      ),
                    ),
                  )
                  .toList(),
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
            _ShopPage.cashier => _cashierPage(),
            _ShopPage.release => _release(),
            _ShopPage.accounts => _accounts(),
            _ShopPage.sales => _salesPage(),
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
      onPressed: () => _dialog(
        _ItemDialog(api: widget.api, contextData: _context!, items: _items),
      ),
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
                label: 'Parent type',
                sortValue: (item) => _parentItemTypeName(item),
                cell: (item) => Text(_parentItemTypeName(item)),
              ),
              _ShopTableColumn(
                label: 'Unit cost',
                numeric: true,
                sortValue: (item) => item['costPrice'],
                cell: (item) => Text(_money(item['costPrice'])),
              ),
              _ShopTableColumn(
                label: 'Unit selling',
                numeric: true,
                sortValue: (item) => item['sellingPrice'],
                cell: (item) => Text(_money(item['sellingPrice'])),
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
                          items: _items,
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

  String _parentItemTypeName(ShopJson item) {
    final parentId = item['parentItemId'];
    if (parentId == null) return '—';
    for (final candidate in _items) {
      if (candidate['id'] == parentId) return '${candidate['displayName']}';
    }
    return 'Archived item type';
  }

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
                        ],
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Central store',
                      numeric: true,
                      sortValue: (item) =>
                          item['unassignedQuantity'] ?? item['centralQuantity'],
                      cell: (item) => Text(
                        '${item['unassignedQuantity'] ?? item['centralQuantity'] ?? item['availableQuantity']} ${item['unitOfMeasure']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'With staff',
                      numeric: true,
                      sortValue: (item) => item['heldQuantity'] ?? 0,
                      cell: (item) => Text(
                        '${item['heldQuantity'] ?? 0} ${item['unitOfMeasure']}',
                      ),
                    ),
                    _ShopTableColumn(
                      label: 'Reserved',
                      numeric: true,
                      sortValue: (item) =>
                          item['totalReservedQuantity'] ??
                          item['reservedQuantity'],
                      cell: (item) => Text(
                        '${item['totalReservedQuantity'] ?? item['reservedQuantity'] ?? 0} ${item['unitOfMeasure']}',
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

  Widget _inventoryActions(ShopJson item) => PopupMenuButton<String>(
    key: ValueKey('shop-inventory-actions-${item['id']}'),
    tooltip: 'Inventory actions',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (action) {
      if (action == 'details') {
        _showInventoryDetails(item);
      } else if (action == 'holders') {
        _showInventoryHolders(item);
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
      final reserved =
          ((item['totalReservedQuantity'] ?? item['reservedQuantity'] ?? 0)
                  as num)
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
                      label: 'Reserved',
                      value: '$reserved $unit',
                    ),
                    _InventoryQuantityCard(
                      label: 'Quarantined',
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
                      label: 'Reserved',
                      numeric: true,
                      sortValue: (row) => row['reservedQuantity'],
                      cell: (row) => Text('${row['reservedQuantity']}'),
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
            label: const Text('Issue stock'),
          ),
        ),
      const SizedBox(height: 12),
      _Panel(
        title: !_buyer ? 'Stock assigned to me' : 'Stock custody',
        subtitle:
            'The recipient must confirm receipt. Paid items awaiting collection remain reserved.',
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
    if (!accept) {
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
          title: 'Give items now',
          message:
              'Use stock you personally hold. Payment and physical release are recorded together.',
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
            label: const Text('Sell and give items'),
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
          title: 'Collect from store',
          message:
              'Receive payment and create a receipt with a one-time token. The stock holder releases the items later.',
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
            label: const Text('Sell for store collection'),
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
          child:
              _receipts
                  .where(
                    (r) => r['cashierName'] == _context?['currentUserName'],
                  )
                  .take(8)
                  .isEmpty
              ? const _Empty('You have not issued a receipt yet.')
              : Column(
                  children: _receipts
                      .where(
                        (r) => r['cashierName'] == _context?['currentUserName'],
                      )
                      .take(8)
                      .map(_receiptTile)
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _cashierPage() {
    final available = _availableCustody;
    return _ActionLanding(
      icon: Icons.receipt_long_outlined,
      title: 'Take payment and issue receipt',
      message:
          'Payment reserves the goods. A goods officer releases them later using the unique receipt number.',
      button: FilledButton.icon(
        onPressed: available.isEmpty
            ? null
            : () => _dialog(
                _SaleDialog(
                  api: widget.api,
                  choices: available,
                  contextData: _context!,
                  collectFromStore: true,
                ),
              ),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Take payment'),
      ),
      below:
          _receipts
              .where((r) => r['cashierName'] == _context?['currentUserName'])
              .take(8)
              .isEmpty
          ? const _Empty('No receipts issued by you yet.')
          : Column(
              children: _receipts
                  .where(
                    (r) => r['cashierName'] == _context?['currentUserName'],
                  )
                  .take(8)
                  .map(_receiptTile)
                  .toList(),
            ),
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
    return _Panel(
      title: 'Release goods',
      subtitle:
          'Enter the one-time token, receipt number or buyer name. Confirm the items before handing them over.',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('shop-release-search'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Token, receipt number or buyer name',
                    hintText: 'e.g. 482913 or Ama Mensah',
                  ),
                  onChanged: (value) => setState(() {
                    _receiptSearch = value;
                    _releaseMatches = [];
                  }),
                  onSubmitted: (_) => _findReceipt(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
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
                  label: Text(_searchingReceipts ? 'Finding…' : 'Find order'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_searchingReceipts)
            const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            )
          else if (pending.isEmpty)
            _Empty(
              query.isEmpty
                  ? 'Enter the buyer’s token, receipt number or name to find a paid order.'
                  : 'No pending pickup matches this search.',
            )
          else
            Column(
              children: pending
                  .map(
                    (r) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_2_outlined),
                        title: Text('${r['reference']}'),
                        subtitle: Text(
                          '${_receiptBuyer(r)} · Receipt total ${_money(r['sale']?['totalAmount'])}\n${_receiptItems(r)}\nToken confirmed · Sold by ${r['cashierName']}',
                        ),
                        isThreeLine: true,
                        trailing: FilledButton(
                          onPressed: () => _confirmRedeem(r),
                          child: const Text('Release'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _findReceipt() async {
    final query = _receiptSearch.trim();
    if (query.length < 2 || _searchingReceipts) return;
    setState(() {
      _searchingReceipts = true;
      _releaseMatches = [];
    });
    try {
      final rows = await widget.api.receipts(query: query);
      if (mounted && _receiptSearch.trim() == query) {
        setState(() => _releaseMatches = rows);
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

  Widget _accounts() => _Panel(
    title: 'Seller accounts',
    subtitle: _admin
        ? 'Review matched accounts and investigate flagged stock or cash differences.'
        : 'Report the stock physically remaining and the cash plus MoMo collected.',
    child: Column(
      children: [
        if (_admin)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  'Seller cash expected',
                  _money(_dashboard?['sellerCashExpected']),
                  Icons.request_quote_outlined,
                  AppColors.blue,
                ),
                _Metric(
                  'Cash reported by sellers',
                  _money(_dashboard?['sellerCashReported']),
                  Icons.fact_check_outlined,
                  AppColors.green,
                ),
              ],
            ),
          ),
        if (_seller)
          for (final c in _consignments.where(
            (c) => c['sellerId'] == _context?['currentUserId'],
          ))
            ListTile(
              title: Text('${c['itemName']}'),
              subtitle: Text(
                '${c['soldQuantity']} sold · ${c['returnedQuantity']} returned · ${c['remainingQuantity']} expected remaining',
              ),
              trailing: OutlinedButton(
                onPressed: () =>
                    _dialog(_ReconcileDialog(api: widget.api, consignment: c)),
                child: const Text('Prepare account'),
              ),
            ),
        const Divider(),
        if (_reconciliations.isEmpty)
          const _Empty('No seller accounts submitted yet.')
        else
          for (final r in _reconciliations)
            Card(
              color: r['status'] == 'FLAGGED'
                  ? AppColors.red.withValues(alpha: .05)
                  : null,
              child: ListTile(
                leading: Icon(
                  r['status'] == 'FLAGGED'
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  color: r['status'] == 'FLAGGED'
                      ? AppColors.red
                      : AppColors.green,
                ),
                title: Text('${r['sellerName']} · ${r['itemName']}'),
                subtitle: Text(
                  '${_status(r['status'])} · Stock difference ${r['stockVariance']} · Cash difference ${_money(r['cashVariance'])}',
                ),
                trailing:
                    _admin &&
                        r['sellerId'] != _context?['currentUserId'] &&
                        !{'APPROVED', 'REJECTED'}.contains(r['status'])
                    ? Wrap(
                        children: [
                          TextButton(
                            onPressed: () => _reviewAccount(r, false),
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: () => _reviewAccount(r, true),
                            child: const Text('Approve'),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
      ],
    ),
  );

  Future<void> _reviewAccount(ShopJson row, bool approve) async {
    try {
      await widget.api.reviewReconciliation(row['id'] as int, approve, '');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _changeSalesRange(int? days) async {
    setState(() {
      _salesDays = days;
      _loading = true;
    });
    try {
      final now = DateTime.now();
      final from = days == null
          ? '2020-01-01'
          : _ymd(now.subtract(Duration(days: days == 0 ? 0 : days - 1)));
      final rows = await widget.api.sales(from: from, to: _ymd(now));
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
        title: 'Recent sales',
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
                    label: 'Buyer',
                    sortValue: (row) =>
                        row['buyerName'] ?? row['studentName'] ?? 'Buyer',
                    cell: (row) => Text(
                      '${row['buyerName'] ?? row['studentName'] ?? 'Buyer'}',
                    ),
                  ),
                  _ShopTableColumn(
                    label: 'Model',
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
                      child: const Text('View'),
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

  Widget _receiptTile(ShopJson r) => ListTile(
    key: ValueKey('shop-issued-receipt-${r['id']}'),
    leading: const Icon(Icons.receipt_outlined),
    title: Text('${r['reference']}'),
    subtitle: Text('${_status(r['status'])} · ${_receiptBuyer(r)}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Receipt total ${_money(r['sale']?['totalAmount'])}'),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right),
      ],
    ),
    onTap: () => _showIssuedReceipt(r),
  );

  String _receiptBuyer(ShopJson r) =>
      '${r['sale']?['buyerName'] ?? r['sale']?['studentName'] ?? 'Buyer'}';

  Future<void> _showIssuedReceipt(ShopJson receipt) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issued receipt'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Receipt number',
                style: TextStyle(color: AppColors.muted),
              ),
              SelectableText(
                '${receipt['reference']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text('${_receiptBuyer(receipt)} · ${_status(receipt['status'])}'),
              const SizedBox(height: 8),
              Text(_receiptItems(receipt)),
              const SizedBox(height: 8),
              Text(
                'Receipt total ${_money(receipt['sale']?['totalAmount'])}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (receipt['pickupToken'] != null) ...[
                const Divider(height: 28),
                const Text(
                  'Collection token',
                  style: TextStyle(color: AppColors.muted),
                ),
                SelectableText(
                  '${receipt['pickupToken']}',
                  key: const ValueKey('shop-reopened-pickup-token'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Give this one-time token to the buyer.'),
              ],
            ],
          ),
        ),
        actions: [
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
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
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

String _status(dynamic value) => '${value ?? ''}'
    .toLowerCase()
    .replaceAll('_', ' ')
    .split(' ')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
String _stockSourceLabel(dynamic value) => switch ('$value') {
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
    required this.items,
    this.item,
  });
  final ShopApiClient api;
  final ShopJson contextData;
  final List<ShopJson> items;
  final ShopJson? item;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _category,
      _sku,
      _variant,
      _cost,
      _selling,
      _threshold;
  String _unit = 'piece';
  int? _parent;
  bool _active = true, _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item ?? {};
    _name = TextEditingController(text: '${i['name'] ?? ''}');
    _category = TextEditingController(text: '${i['category'] ?? ''}');
    _sku = TextEditingController(text: '${i['sku'] ?? ''}');
    _variant = TextEditingController(text: '${i['variantLabel'] ?? ''}');
    _cost = TextEditingController(
      text: i['costPrice'] == null ? '' : '${i['costPrice']}',
    );
    _selling = TextEditingController(
      text: i['sellingPrice'] == null ? '' : '${i['sellingPrice']}',
    );
    _threshold = TextEditingController(text: '${i['lowStockThreshold'] ?? 5}');
    _unit = '${i['unitOfMeasure'] ?? 'piece'}';
    _parent = i['parentItemId'] as int?;
    _active = i['active'] != false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _category,
      _sku,
      _variant,
      _cost,
      _selling,
      _threshold,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.saveItem({
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'sku': _sku.text.trim(),
        'unitOfMeasure': _unit,
        'parentItemId': _parent,
        'variantLabel': _variant.text.trim().isEmpty
            ? null
            : _variant.text.trim(),
        'costPrice': double.parse(_cost.text),
        'sellingPrice': double.parse(_selling.text),
        'lowStockThreshold': int.parse(_threshold.text),
        'active': _active,
        'version': widget.item?['version'],
      }, id: widget.item?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
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
                      'This creates the item type with zero quantity. Use Add stock when items are received into the shop.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Select or type a category',
                      ),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(
                        labelText: 'Item code (optional)',
                        hintText: 'Generated automatically if empty',
                      ),
                    ),
                  ),
                ],
              ),
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
              DropdownButtonFormField<int?>(
                value: _parent,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Parent item (optional)',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No parent item'),
                  ),
                  ...widget.items
                      .where((x) => x['id'] != widget.item?['id'])
                      .map(
                        (x) => DropdownMenuItem<int?>(
                          value: x['id'] as int,
                          child: Text('${x['displayName']}'),
                        ),
                      ),
                ],
                onChanged: (v) => setState(() => _parent = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit cost price (GHS)',
                      ),
                      validator: _moneyValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _selling,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit selling price (GHS)',
                      ),
                      validator: _positiveMoneyValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _threshold,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low-stock alert',
                      ),
                      validator: _wholeNumberValidator,
                    ),
                  ),
                ],
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
  bool newItem = false;
  String selectedItemLabel = '';
  String? category;
  String unit = 'piece';
  final itemSearch = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final cost = TextEditingController();
  final selling = TextEditingController();
  final name = TextEditingController();
  final sku = TextEditingController();
  final otherCategory = TextEditingController();
  final variant = TextEditingController();
  final threshold = TextEditingController(text: '5');
  void dispose() {
    itemSearch.dispose();
    quantity.dispose();
    cost.dispose();
    selling.dispose();
    name.dispose();
    sku.dispose();
    otherCategory.dispose();
    variant.dispose();
    threshold.dispose();
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
  final _sourceName = TextEditingController(),
      _sourceReference = TextEditingController(),
      _notes = TextEditingController();
  final List<_PurchaseLineDraft> _lines = [_PurchaseLineDraft()];
  String _sourceType = 'PURCHASED_ELSEWHERE';
  DateTime _date = DateTime.now();
  bool _saving = false;
  @override
  void dispose() {
    _sourceName.dispose();
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
    final ids = _lines.where((l) => !l.newItem).map((l) => l.itemId).toList();
    if (ids.toSet().length != ids.length) {
      _errorSnack(context, 'Each item can appear only once.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.recordStock({
        'sourceType': _sourceType,
        'sourceName': _sourceName.text.trim(),
        'sourceReference': _sourceReference.text.trim(),
        'receivedDate': _ymd(_date),
        'notes': _notes.text.trim(),
        'lines': _lines
            .map(
              (l) => {
                'itemId': l.newItem ? null : l.itemId,
                'name': l.newItem ? l.name.text.trim() : null,
                'category': l.newItem
                    ? (l.category == '__OTHER__'
                          ? l.otherCategory.text.trim()
                          : l.category)
                    : null,
                'sku': l.newItem && l.sku.text.trim().isNotEmpty
                    ? l.sku.text.trim()
                    : null,
                'unitOfMeasure': l.newItem ? l.unit : null,
                'variantLabel': l.newItem && l.variant.text.trim().isNotEmpty
                    ? l.variant.text.trim()
                    : null,
                'quantity': int.parse(l.quantity.text),
                'unitCost': double.parse(l.cost.text),
                'sellingPrice': double.parse(l.selling.text),
                'lowStockThreshold': l.newItem
                    ? int.parse(l.threshold.text)
                    : null,
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
    final hasSelection = line.newItem || line.itemId != null;
    final selectedSuggestion =
        line.itemSearch.text.trim() == line.selectedItemLabel;
    if (!hasSelection || !selectedSuggestion) return 'choose an item';
    if (line.newItem) {
      if (line.name.text.trim().isEmpty) return 'enter the item name';
      if (line.category == null) return 'choose or add a category';
      if (line.category == '__OTHER__' &&
          line.otherCategory.text.trim().isEmpty) {
        return 'enter the new category name';
      }
      if (_wholeNumberValidator(line.threshold.text) != null) {
        return 'enter a valid low-stock alert';
      }
    }
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
    if (!current.newItem &&
        _lines
            .take(_lines.length - 1)
            .where((line) => !line.newItem)
            .any((line) => line.itemId == current.itemId)) {
      _errorSnack(
        context,
        'This item is already included in this stock entry.',
      );
      return;
    }
    setState(() => _lines.add(_PurchaseLineDraft()));
  }

  Widget _purchaseItemPicker(int index) => FormField<int>(
    validator: (_) {
      final line = _lines[index];
      final hasSelection = line.newItem || line.itemId != null;
      final selectedSuggestion =
          line.itemSearch.text.trim() == line.selectedItemLabel;
      return hasSelection && selectedSuggestion
          ? null
          : 'Choose a suggestion or add a new item';
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
        return entries
            .where(
              (entry) =>
                  entry.value == -1 ||
                  entry.label.toLowerCase().contains(query),
            )
            .toList();
      },
      label: const Text('Item'),
      hintText: 'Search name or code',
      errorText: field.errorText,
      initialSelection: _lines[index].newItem ? -1 : _lines[index].itemId,
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
                label: '${i['displayName']} · ${i['sku']} · ${i['category']}',
                leadingIcon: const Icon(Icons.inventory_2_outlined),
              ),
            ),
      ],
      onSelected: (value) {
        field.didChange(value);
        setState(() {
          final line = _lines[index];
          line.newItem = value == -1;
          line.itemId = value == -1 ? null : value;
          if (value == -1) {
            line.selectedItemLabel = '＋ Add a new item';
            line.itemSearch.text = line.selectedItemLabel;
            return;
          }
          if (value != null) {
            final item = widget.items.firstWhere((x) => x['id'] == value);
            line.selectedItemLabel =
                '${item['displayName']} · ${item['sku']} · ${item['category']}';
            line.itemSearch.text = line.selectedItemLabel;
            line.cost.text = '${item['costPrice']}';
            line.selling.text = '${item['sellingPrice']}';
          }
        });
      },
    ),
  );

  Widget _purchaseQuantityField(int index) => TextFormField(
    controller: _lines[index].quantity,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(labelText: 'Quantity received'),
    validator: _positiveWholeNumberValidator,
  );

  Widget _purchaseCostField(int index) => TextFormField(
    controller: _lines[index].cost,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(labelText: 'Unit cost price (GHS)'),
    validator: _moneyValidator,
  );

  Widget _purchaseSellingField(int index) => TextFormField(
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

  Widget _compactPurchaseLine(int index) => SingleChildScrollView(
    key: ValueKey('purchase-line-$index'),
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: 980,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 360, child: _purchaseItemPicker(index)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: _purchaseQuantityField(index)),
          const SizedBox(width: 8),
          SizedBox(width: 150, child: _purchaseCostField(index)),
          const SizedBox(width: 8),
          SizedBox(width: 150, child: _purchaseSellingField(index)),
          const SizedBox(width: 12),
          SizedBox(height: 56, width: 120, child: _purchaseLineTotal(index)),
          const SizedBox(width: 8),
          SizedBox(width: 48, child: _removePurchaseLineButton(index)),
        ],
      ),
    ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('stock-source-type'),
                      value: _sourceType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'How was the stock obtained?',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PURCHASED_ELSEWHERE',
                          child: Text('Purchased — recorded elsewhere'),
                        ),
                        DropdownMenuItem(
                          value: 'SCHOOL_TRANSFER',
                          child: Text('Transferred from school office'),
                        ),
                        DropdownMenuItem(
                          value: 'DONATION',
                          child: Text('Donation'),
                        ),
                        DropdownMenuItem(
                          value: 'OPENING_STOCK',
                          child: Text('Opening stock'),
                        ),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(
                        () => _sourceType = value ?? 'PURCHASED_ELSEWHERE',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('stock-source-name'),
                      controller: _sourceName,
                      decoration: const InputDecoration(
                        labelText: 'Source name (optional)',
                        hintText: 'Supplier, office or donor',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('stock-source-reference'),
                      controller: _sourceReference,
                      decoration: const InputDecoration(
                        labelText: 'Existing record reference (optional)',
                        hintText: 'Expense, invoice or receipt number',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('stock-received-date'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Date received · ${_ymd(_date)}'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < _lines.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_lines[index].newItem)
                          _compactPurchaseLine(index)
                        else
                          Row(
                            children: [
                              Expanded(child: _purchaseItemPicker(index)),
                              _removePurchaseLineButton(index),
                            ],
                          ),
                        if (_lines[index].newItem) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lines[index].name,
                            decoration: const InputDecoration(
                              labelText: 'Item name',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _lines[index].category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: [
                                    ...(widget.contextData['categories']
                                                as List? ??
                                            [])
                                        .map(
                                          (c) => DropdownMenuItem<String>(
                                            value: '$c',
                                            child: Text('$c'),
                                          ),
                                        ),
                                    const DropdownMenuItem(
                                      value: '__OTHER__',
                                      child: Text('Other / Add new category'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _lines[index].category = v,
                                  ),
                                  validator: (v) => v == null
                                      ? 'Select or add a category'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _lines[index].sku,
                                  decoration: const InputDecoration(
                                    labelText: 'Item code (optional)',
                                    hintText: 'Generated automatically',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_lines[index].category == '__OTHER__') ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _lines[index].otherCategory,
                              decoration: const InputDecoration(
                                labelText: 'New category name',
                              ),
                              validator: _required,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _lines[index].unit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                  ),
                                  items:
                                      (widget.contextData['units'] as List? ??
                                              const ['piece'])
                                          .map(
                                            (u) => DropdownMenuItem<String>(
                                              value: '$u',
                                              child: Text('$u'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setState(
                                    () => _lines[index].unit = v ?? 'piece',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _lines[index].variant,
                                  decoration: const InputDecoration(
                                    labelText: 'Variant (optional)',
                                    hintText: 'Size 10, Blue',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_lines[index].newItem) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _purchaseQuantityField(index)),
                              const SizedBox(width: 8),
                              Expanded(child: _purchaseCostField(index)),
                              const SizedBox(width: 8),
                              Expanded(child: _purchaseSellingField(index)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _lines[index].threshold,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Low-stock alert',
                                  ),
                                  validator: _wholeNumberValidator,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              height: 52,
                              width: 140,
                              child: _purchaseLineTotal(index),
                            ),
                          ),
                        ],
                      ],
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
  });
  final ShopApiClient api;
  final ShopJson contextData;
  final List<ShopJson> items, roles;
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
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      await widget.api.createConsignment({
        'sellerId': _seller,
        'itemId': _item,
        'quantity': int.parse(_quantity.text),
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
      title: const Text('Issue stock to a staff member'),
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
                        child: Text('Damaged — quarantine'),
                      ),
                      DropdownMenuItem(
                        value: 'UNSELLABLE',
                        child: Text('Unsellable — quarantine'),
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
                  child: Text('Damaged — quarantine'),
                ),
                DropdownMenuItem(
                  value: 'UNSELLABLE',
                  child: Text('Unsellable — quarantine'),
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

class _ReconcileDialog extends StatefulWidget {
  const _ReconcileDialog({required this.api, required this.consignment});
  final ShopApiClient api;
  final ShopJson consignment;
  @override
  State<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends State<_ReconcileDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _stock, _cash;
  final _note = TextEditingController();
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _stock = TextEditingController(
      text: '${widget.consignment['remainingQuantity']}',
    );
    _cash = TextEditingController(
      text: '${widget.consignment['expectedCash']}',
    );
  }

  @override
  void dispose() {
    _stock.dispose();
    _cash.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.reconcile(widget.consignment['id'] as int, {
        'reportedRemaining': int.parse(_stock.text),
        'reportedCash': double.parse(_cash.text),
        'note': _note.text.trim(),
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
    title: const Text('Prepare seller account'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.consignment['itemName']} · ${widget.consignment['sellerName']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'System expects ${widget.consignment['remainingQuantity']} remaining and ${_money(widget.consignment['expectedCash'])} collected.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock physically remaining',
                    ),
                    validator: _wholeNumberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cash,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cash + MoMo collected',
                    ),
                    validator: _moneyValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
        child: Text(_saving ? 'Submitting…' : 'Submit account'),
      ),
    ],
  );
}

class _SaleLineDraft {
  _SaleLineDraft();
  int? choiceId;
  final quantity = TextEditingController(text: '1');
  void dispose() => quantity.dispose();
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
  String _buyerType = 'STUDENT';
  String _payment = 'CASH';
  bool _saving = false, _searching = false;

  @override
  void dispose() {
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

  double get _total => _lines.fold(0, (sum, l) {
    final c = _choice(l.choiceId);
    final q = int.tryParse(l.quantity.text) ?? 0;
    return sum + (c == null ? 0 : _price(c) * q);
  });

  Future<void> _searchStudent() async {
    final q = _studentSearch.text.trim();
    if (q.length < 2) {
      _errorSnack(context, 'Enter at least 2 letters or a student ID.');
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await widget.api.students(q);
      if (mounted) setState(() => _students = rows);
    } catch (e) {
      if (mounted) _errorSnack(context, e);
    } finally {
      if (mounted) setState(() => _searching = false);
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
        'buyerName': {'GUARDIAN', 'WALK_IN', 'OTHER'}.contains(_buyerType)
            ? _buyerName.text.trim()
            : null,
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

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      final reference = _result!['reference'];
      return AlertDialog(
        title: Text(
          widget.collectFromStore
              ? 'Payment received'
              : 'Sale and release recorded',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.collectFromStore
                    ? Icons.receipt_long_outlined
                    : Icons.check_circle_outline,
                size: 54,
                color: AppColors.green,
              ),
              const SizedBox(height: 12),
              if (reference != null) ...[
                const Text(
                  'Receipt number',
                  style: TextStyle(color: AppColors.muted),
                ),
                SelectableText(
                  '$reference',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_result!['pickupToken'] != null) ...[
                  const Text(
                    'Collection token',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  SelectableText(
                    '${_result!['pickupToken']}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const Text(
                    'The buyer gives this one-time token at the store.',
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const Text('The items were handed to the buyer.'),
              ] else
                const Text('The stock and payment records were updated.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(
        widget.collectFromStore
            ? 'Sell for collection from store'
            : 'Sell and give items now',
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
                      _buyerName.clear();
                      _buyerReference.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_buyerType == 'STUDENT')
                  FormField<ShopJson>(
                    validator: (_) =>
                        _student == null ? 'Select the student buying' : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_student != null)
                          InputChip(
                            avatar: const Icon(Icons.school_outlined, size: 18),
                            label: Text(
                              '${_student!['name']} · ${_student!['customStudentId']}',
                            ),
                            onDeleted: () => setState(() => _student = null),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'shop-student-buyer-search',
                                  ),
                                  controller: _studentSearch,
                                  onSubmitted: (_) => _searchStudent(),
                                  decoration: const InputDecoration(
                                    labelText: 'Student',
                                    hintText: 'Search name or student ID',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _searching ? null : _searchStudent,
                                icon: const Icon(Icons.search),
                                label: Text(
                                  _searching ? 'Searching…' : 'Search',
                                ),
                              ),
                            ],
                          ),
                        if (_student == null && _students.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: _students
                                  .map(
                                    (s) => ListTile(
                                      dense: true,
                                      title: Text('${s['name']}'),
                                      subtitle: Text(
                                        '${s['customStudentId']} · ${s['className'] ?? ''} ${s['section'] ?? ''}',
                                      ),
                                      onTap: () => setState(() {
                                        _student = s;
                                        _students = [];
                                        field.didChange(s);
                                      }),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else if (_buyerType == 'STAFF')
                  DropdownButtonFormField<int>(
                    key: const ValueKey('shop-staff-buyer'),
                    value: _staffBuyer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                    ),
                    items: _staff
                        .map(
                          (person) => DropdownMenuItem<int>(
                            value: person['id'] as int,
                            child: Text(
                              '${person['name'] ?? person['fullName'] ?? person['username']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _staffBuyer = value),
                    validator: (value) =>
                        value == null ? 'Select the staff member buying' : null,
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
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<int>(
                            value: _lines[index].choiceId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Item',
                            ),
                            items: widget.choices
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: _id(c),
                                    child: Text(
                                      '${_name(c)} · ${c['holderName']}${c['locationName'] == null ? '' : ' (${c['locationName']})'} · ${_available(c)} available · Unit price ${_money(c['sellingPrice'])}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _lines[index].choiceId = v),
                            validator: (v) =>
                                v == null ? 'Select an item' : null,
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
