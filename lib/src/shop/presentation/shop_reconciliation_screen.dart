import 'dart:async';
import 'dart:ui' show SemanticsRole;
import 'package:flutter/material.dart';
import '../data/shop_api_client.dart';
import '../../theme/app_theme.dart';
import 'shop_cash_remittance_csv_export.dart';

typedef ShopCashRemittanceCsvDownloader =
    Future<bool> Function(String fileName, String contents);

enum ShopReconciliationView { counts, remittances }

List<ShopJson> _rows(dynamic v) =>
    (v as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
String _money(dynamic n) => 'GHS ${(n as num? ?? 0).toStringAsFixed(2)}';
String _status(dynamic s) => switch (s) {
  'CLOSED_BALANCED' => 'Closed — balanced',
  'CLOSED_WITH_DIFFERENCES' => 'Closed — differences recorded',
  'AWAITING_SELLER_ACK' => 'Waiting for staff acknowledgement',
  'PENDING_RESOLUTION' => 'Difference awaiting resolution',
  'DISPUTED' => 'Count disputed',
  'PENDING_RECEIPT' => 'Awaiting receipt',
  _ => '$s'.toLowerCase().replaceAll('_', ' '),
};
DateTime? _date(dynamic v) => v is List && v.length >= 3
    ? DateTime(
        v[0],
        v[1],
        v[2],
        v.length > 3 ? v[3] : 0,
        v.length > 4 ? v[4] : 0,
      )
    : DateTime.tryParse('$v');
String _when(dynamic v) {
  final d = _date(v);
  if (d == null) return 'Opening records';
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
  return '${d.day} ${months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _difference(num n, {bool money = false}) => n == 0
    ? 'Matches'
    : '${money ? _money(n.abs()) : n.abs()} ${n < 0 ? 'short' : 'extra'}';

class ShopReconciliationScreen extends StatefulWidget {
  const ShopReconciliationScreen({
    super.key,
    required this.api,
    required this.contextData,
    required this.onChanged,
    this.view = ShopReconciliationView.counts,
    this.sellerFilterId,
    this.csvDownloader,
  });
  final ShopApiClient api;
  final ShopJson contextData;
  final VoidCallback onChanged;
  final ShopReconciliationView view;
  final int? sellerFilterId;
  final ShopCashRemittanceCsvDownloader? csvDownloader;
  @override
  State<ShopReconciliationScreen> createState() =>
      _ShopReconciliationScreenState();
}

class _ShopReconciliationScreenState extends State<ShopReconciliationScreen> {
  List<ShopJson> _periods = [], _handovers = [];
  bool _loading = true, _busy = false;
  String? _error;
  int _sort = 0, _page = 0;
  bool _ascending = false;
  final _remittanceSearch = TextEditingController();
  String _remittanceStatus = 'ALL';
  DateTimeRange? _remittanceRange;
  int _remittanceSort = 0, _remittancePage = 0;
  bool _remittanceAscending = false, _exporting = false;
  int get _user => widget.contextData['currentUserId'] as int;
  bool get _admin =>
      widget.contextData['isAdmin'] == true ||
      widget.contextData['canManageRoles'] == true;
  List<ShopJson> get _approvers => _rows(
    widget.contextData['inventoryApprovers'] ??
        widget.contextData['returnApprovers'],
  );
  List<ShopJson> get _staff => _rows(
    widget.contextData['reconciliationStaff'] ?? widget.contextData['staff'],
  ).where((person) => person['id'] != _user).toList();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remittanceSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = widget.view == ShopReconciliationView.counts
          ? await widget.api.periods()
          : await widget.api.cashHandovers();
      if (mounted) {
        setState(() {
          if (widget.view == ShopReconciliationView.counts) {
            _periods = values;
          } else {
            _handovers = values;
          }
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _chooseStaff() async {
    var filtered = [..._staff];
    int? selectedId;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select seller to reconcile'),
          content: SizedBox(
            width: 520,
            height: 470,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'One seller is counted at a time. Only people who have received stock are listed.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('recon-staff-search'),
                  decoration: const InputDecoration(
                    labelText: 'Search sellers by name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setDialogState(() {
                    final query = value.trim().toLowerCase();
                    filtered = _staff
                        .where(
                          (p) => '${p['name']}'.toLowerCase().contains(query),
                        )
                        .toList();
                  }),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matching staff member'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final person = filtered[index];
                            final isSelected = selectedId == person['id'];
                            final units = person['assignedUnits'] as num?;
                            final itemCount =
                                person['assignedItemCount'] as num?;
                            final details = units == null
                                ? 'Seller with assigned stock'
                                : units == 0
                                ? 'No stock remaining · shop money may still need checking'
                                : '${units.toInt()} units across ${itemCount?.toInt() ?? 0} item types';
                            return ListTile(
                              key: ValueKey('recon-staff-${person['id']}'),
                              selected: isSelected,
                              selectedTileColor: AppColors.green.withValues(
                                alpha: 0.08,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? AppColors.green
                                    : const Color(0xFFE8F2F0),
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : AppColors.green,
                                child: const Icon(Icons.storefront_outlined),
                              ),
                              title: Text('${person['name']}'),
                              subtitle: Text(
                                '${person['role'] ?? 'Seller'} · $details${person['reconciliationOpen'] == true ? ' · Count already open' : ''}',
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.green,
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () => setDialogState(
                                () => selectedId = person['id'] as int,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('recon-confirm-staff'),
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedId),
              child: Text(
                selectedId == null
                    ? 'Select a seller'
                    : _staff.firstWhere(
                            (person) => person['id'] == selectedId,
                          )['reconciliationOpen'] ==
                          true
                    ? 'Continue this count'
                    : 'Start this count',
              ),
            ),
          ],
        ),
      ),
    );
    return selected;
  }

  Future<void> _start({int? staffId, bool refresh = false}) async {
    final selected = staffId ?? await _chooseStaff();
    if (selected == null) return;
    await _perform(() async {
      final row = await widget.api.startPeriod(
        staffId: selected,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PeriodCountDialog(
          api: widget.api,
          row: row,
          approvers: _approvers,
        ),
      );
      if (!mounted) return;
      await _load();
      if (result == 'REFRESH') {
        setState(() => _busy = false);
        await _start(staffId: row['staffId'] as int, refresh: true);
      }
    });
  }

  Future<void> _open(ShopJson row) => _perform(() async {
    final fresh = await widget.api.period(row['id'] as int);
    if (!mounted) return;
    setState(() => _busy = false);
    if (fresh['status'] == 'DRAFT' && fresh['counterId'] == _user) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PeriodCountDialog(
          api: widget.api,
          row: fresh,
          approvers: _approvers,
        ),
      );
      await _load();
      if (result == 'REFRESH' && mounted) {
        setState(() => _busy = false);
        await _start(staffId: fresh['staffId'] as int, refresh: true);
      }
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PeriodReviewDialog(
        api: widget.api,
        row: fresh,
        userId: _user,
        admin: _admin,
      ),
    );
    if (changed == true) {
      await _load();
      widget.onChanged();
    }
  });
  Future<void> _handover() => _perform(() async {
    setState(() => _busy = false);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CashHandoverDialog(api: widget.api, people: _approvers),
    );
    if (changed == true) await _load();
  });
  Future<void> _answerHandover(ShopJson h, String action) => _perform(() async {
    setState(() => _busy = false);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          action == 'CONFIRM'
              ? 'Confirm cash received?'
              : action == 'CANCEL'
              ? 'Cancel cash remittance?'
              : 'Report cash not received?',
        ),
        content: Text(
          action == 'CONFIRM'
              ? 'Confirm you physically received ${_money(h['amount'])} from ${h['senderName']}. Both cash balances will update.'
              : action == 'CANCEL'
              ? 'Only cancel if the cash is still in your custody or has been returned to you.'
              : 'Confirm you have not received this cash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await widget.api.decideCashHandover(h, action);
      await _load();
    }
  });

  List<ShopJson> _filteredRemittances() {
    final query = _remittanceSearch.text.trim().toLowerCase();
    final result = _handovers.where((row) {
      if (widget.sellerFilterId != null &&
          row['senderId'] != widget.sellerFilterId &&
          row['recipientId'] != widget.sellerFilterId) {
        return false;
      }
      if (_remittanceStatus != 'ALL' && row['status'] != _remittanceStatus) {
        return false;
      }
      final created = _date(row['createdAt']);
      if (_remittanceRange != null && created != null) {
        final from = DateTime(
          _remittanceRange!.start.year,
          _remittanceRange!.start.month,
          _remittanceRange!.start.day,
        );
        final until = DateTime(
          _remittanceRange!.end.year,
          _remittanceRange!.end.month,
          _remittanceRange!.end.day + 1,
        );
        if (created.isBefore(from) || !created.isBefore(until)) return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        'REM-${(row['id'] as num? ?? 0).toInt().toString().padLeft(6, '0')}',
        row['senderName'],
        row['recipientName'],
        row['status'],
        row['note'],
        row['amount'],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    result.sort((a, b) {
      final dynamic av = switch (_remittanceSort) {
        0 => _date(a['createdAt'])?.millisecondsSinceEpoch ?? 0,
        1 => a['id'] ?? 0,
        2 => a['senderName'] ?? '',
        3 => a['recipientName'] ?? '',
        4 => a['amount'] ?? 0,
        5 => a['status'] ?? '',
        _ => _date(a['confirmedAt'])?.millisecondsSinceEpoch ?? 0,
      };
      final dynamic bv = switch (_remittanceSort) {
        0 => _date(b['createdAt'])?.millisecondsSinceEpoch ?? 0,
        1 => b['id'] ?? 0,
        2 => b['senderName'] ?? '',
        3 => b['recipientName'] ?? '',
        4 => b['amount'] ?? 0,
        5 => b['status'] ?? '',
        _ => _date(b['confirmedAt'])?.millisecondsSinceEpoch ?? 0,
      };
      final comparison = av is num && bv is num
          ? av.compareTo(bv)
          : '$av'.compareTo('$bv');
      return _remittanceAscending ? comparison : -comparison;
    });
    return result;
  }

  String _remittanceReference(ShopJson row) =>
      'REM-${(row['id'] as num? ?? 0).toInt().toString().padLeft(6, '0')}';

  String _csvCell(Object? value) {
    final valueText = value?.toString() ?? '';
    final escaped = valueText.replaceAll('"', '""');
    return escaped.contains(RegExp('[,"\\n\\r]')) ? '"$escaped"' : escaped;
  }

  String _remittanceCsv(List<ShopJson> rows) {
    final values = <List<Object?>>[
      [
        'Remittance number',
        'Date sent',
        'Sender',
        'Recipient / confirmer',
        'Amount (GHS)',
        'Status',
        'Date confirmed',
        'Notes',
        'Accounting treatment',
      ],
      for (final row in rows)
        [
          _remittanceReference(row),
          _date(row['createdAt'])?.toIso8601String() ?? '',
          row['senderName'],
          row['recipientName'],
          (row['amount'] as num? ?? 0).toStringAsFixed(2),
          _status(row['status']),
          _date(row['confirmedAt'])?.toIso8601String() ?? '',
          row['note'] ?? '',
          'Cash custody transfer — not additional income',
        ],
    ];
    return values.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  Future<void> _exportRemittances() async {
    final rows = _filteredRemittances();
    if (rows.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final fileName =
          'shop_cash_remittances_'
          '${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}.csv';
      final exporter = widget.csvDownloader ?? exportShopCashRemittances;
      final downloaded = await exporter(fileName, _remittanceCsv(rows));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? '${rows.length} remittance records exported.'
                : 'CSV downloads are not available on this device.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The remittance export failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _chooseRemittanceRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _remittanceRange,
    );
    if (picked != null && mounted) {
      setState(() {
        _remittanceRange = picked;
        _remittancePage = 0;
      });
    }
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 215,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _remittanceStatusChip(dynamic status) {
    final value = '$status';
    final color = switch (value) {
      'CONFIRMED' => AppColors.green,
      'PENDING_RECEIPT' => Colors.orange.shade800,
      'REJECTED' => Colors.red.shade700,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _status(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<void> _showRemittance(ShopJson row) async {
    String? action;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Cash remittance details')),
            _remittanceStatusChip(row['status']),
          ],
        ),
        content: SizedBox(
          width: 610,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Remittance number', _remittanceReference(row)),
                const Divider(height: 1),
                _detailRow('Date sent', _when(row['createdAt'])),
                const Divider(height: 1),
                _detailRow('From', '${row['senderName']}'),
                const Divider(height: 1),
                _detailRow('To / confirmed by', '${row['recipientName']}'),
                const Divider(height: 1),
                _detailRow('Amount', _money(row['amount'])),
                const Divider(height: 1),
                _detailRow(
                  'Date confirmed',
                  row['confirmedAt'] == null ? '—' : _when(row['confirmedAt']),
                ),
                if ('${row['note'] ?? ''}'.trim().isNotEmpty) ...[
                  const Divider(height: 1),
                  _detailRow('Notes', '${row['note']}'),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.green,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This is a transfer of cash custody. It is not additional income.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (row['status'] == 'PENDING_RECEIPT' && row['senderId'] == _user)
            TextButton(
              onPressed: () {
                action = 'CANCEL';
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel remittance'),
            ),
          if (row['status'] == 'PENDING_RECEIPT' &&
              row['recipientId'] == _user) ...[
            OutlinedButton(
              onPressed: () {
                action = 'REJECT';
                Navigator.pop(dialogContext);
              },
              child: const Text('Not received'),
            ),
            FilledButton(
              onPressed: () {
                action = 'CONFIRM';
                Navigator.pop(dialogContext);
              },
              child: const Text('Confirm receipt'),
            ),
          ],
        ],
      ),
    );
    if (action != null && mounted) await _answerHandover(row, action!);
  }

  Widget _remittancePanel() {
    final filtered = _filteredRemittances();
    final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 10;
    final page = _remittancePage.clamp(0, lastPage);
    final scopedHandovers = widget.sellerFilterId == null
        ? _handovers
        : _handovers
              .where(
                (row) =>
                    row['senderId'] == widget.sellerFilterId ||
                    row['recipientId'] == widget.sellerFilterId,
              )
              .toList();
    num amountFor(String status) => scopedHandovers
        .where((row) => row['status'] == status)
        .fold<num>(0, (sum, row) => sum + (row['amount'] as num? ?? 0));
    final pendingCount = scopedHandovers
        .where((row) => row['status'] == 'PENDING_RECEIPT')
        .length;
    final rejectedCount = scopedHandovers
        .where((row) => row['status'] == 'REJECTED')
        .length;
    final cancelledCount = scopedHandovers
        .where((row) => row['status'] == 'CANCELLED')
        .length;
    final rangeLabel = _remittanceRange == null
        ? 'All dates'
        : '${_when(_remittanceRange!.start).split(' ·').first} – '
              '${_when(_remittanceRange!.end).split(' ·').first}';
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Track collected cash passed between staff. The recipient confirms after physically counting it.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard(
                'Confirmed remittances',
                _money(amountFor('CONFIRMED')),
                Icons.verified_outlined,
                AppColors.green,
              ),
              _summaryCard(
                'Pending receipt',
                '$pendingCount · ${_money(amountFor('PENDING_RECEIPT'))}',
                Icons.schedule,
                Colors.orange.shade800,
              ),
              _summaryCard(
                'Reported not received',
                '$rejectedCount',
                Icons.report_outlined,
                Colors.red.shade700,
              ),
              _summaryCard(
                'Cancelled',
                '$cancelledCount',
                Icons.cancel_outlined,
                AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          key: const ValueKey('remittance-search'),
                          controller: _remittanceSearch,
                          decoration: const InputDecoration(
                            labelText: 'Search remittances',
                            hintText: 'Number, sender or recipient',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() => _remittancePage = 0),
                        ),
                      ),
                      SizedBox(
                        width: 205,
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey('remittance-status-filter'),
                          value: _remittanceStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All statuses'),
                            ),
                            DropdownMenuItem(
                              value: 'PENDING_RECEIPT',
                              child: Text('Pending receipt'),
                            ),
                            DropdownMenuItem(
                              value: 'CONFIRMED',
                              child: Text('Confirmed'),
                            ),
                            DropdownMenuItem(
                              value: 'REJECTED',
                              child: Text('Not received'),
                            ),
                            DropdownMenuItem(
                              value: 'CANCELLED',
                              child: Text('Cancelled'),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            _remittanceStatus = value ?? 'ALL';
                            _remittancePage = 0;
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('remittance-date-filter'),
                        onPressed: _chooseRemittanceRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(rangeLabel),
                      ),
                      if (_remittanceRange != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _remittanceRange = null;
                            _remittancePage = 0;
                          }),
                          child: const Text('Clear dates'),
                        ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('export-remittances'),
                        onPressed: filtered.isEmpty || _exporting
                            ? null
                            : _exportRemittances,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          _exporting ? 'Exporting…' : 'Export filtered CSV',
                        ),
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text('No cash remittances match these filters.'),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          key: const ValueKey('cash-remittance-table'),
                          showCheckboxColumn: false,
                          sortColumnIndex: _remittanceSort,
                          sortAscending: _remittanceAscending,
                          headingRowColor: const WidgetStatePropertyAll(
                            Color(0xFFF3F7F6),
                          ),
                          columns: [
                            for (final label in [
                              'Date sent',
                              'Remittance no.',
                              'Sender',
                              'Recipient',
                              'Amount',
                              'Status',
                              'Confirmed',
                            ])
                              DataColumn(
                                numeric: label == 'Amount',
                                label: Text(label),
                                onSort: (index, ascending) => setState(() {
                                  _remittanceSort = index;
                                  _remittanceAscending = ascending;
                                  _remittancePage = 0;
                                }),
                              ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.skip(page * 10).take(10).map((row) {
                            return DataRow(
                              onSelectChanged: (_) => _showRemittance(row),
                              cells: [
                                DataCell(Text(_when(row['createdAt']))),
                                DataCell(Text(_remittanceReference(row))),
                                DataCell(Text('${row['senderName']}')),
                                DataCell(Text('${row['recipientName']}')),
                                DataCell(Text(_money(row['amount']))),
                                DataCell(_remittanceStatusChip(row['status'])),
                                DataCell(
                                  Text(
                                    row['confirmedAt'] == null
                                        ? '—'
                                        : _when(row['confirmedAt']),
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    key: ValueKey(
                                      'view-remittance-${row['id']}',
                                    ),
                                    onPressed: () => _showRemittance(row),
                                    child: const Text('View'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                if (filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${page * 10 + 1}–${(page * 10 + 10).clamp(0, filtered.length)} of ${filtered.length}',
                        ),
                        IconButton(
                          tooltip: 'Previous remittance page',
                          onPressed: page > 0
                              ? () => setState(() => _remittancePage = page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next remittance page',
                          onPressed: (page + 1) * 10 < filtered.length
                              ? () => setState(() => _remittancePage = page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Accounting note: confirmed remittances move cash responsibility between staff. They do not create additional sales income.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remittances = widget.view == ShopReconciliationView.remittances;
    final scopedPeriods = widget.sellerFilterId == null
        ? _periods
        : _periods
              .where((row) => row['staffId'] == widget.sellerFilterId)
              .toList();
    final draft = scopedPeriods.any(
      (r) => r['counterId'] == _user && r['status'] == 'DRAFT',
    );
    final sorted = [...scopedPeriods]
      ..sort((a, b) {
        final dynamic av = switch (_sort) {
          0 => _date(a['cutoff'])?.millisecondsSinceEpoch ?? 0,
          1 => a['staffName'],
          2 => a['status'],
          _ => a['counterName'],
        };
        final dynamic bv = switch (_sort) {
          0 => _date(b['cutoff'])?.millisecondsSinceEpoch ?? 0,
          1 => b['staffName'],
          2 => b['status'],
          _ => b['counterName'],
        };
        final c = av is num && bv is num
            ? av.compareTo(bv)
            : '$av'.compareTo('$bv');
        return _ascending ? c : -c;
      });
    final page = _page.clamp(0, sorted.isEmpty ? 0 : (sorted.length - 1) ~/ 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              remittances ? 'Cash remittances' : 'Reconciliation',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (!remittances && _admin)
              FilledButton.icon(
                key: const ValueKey('shop-start-reconciliation'),
                onPressed: _busy || _loading || _staff.isEmpty
                    ? null
                    : () => _start(),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  draft ? 'Start or continue a count' : 'Start reconciliation',
                ),
              ),
            if (remittances)
              FilledButton.icon(
                key: const ValueKey('shop-remit-cash'),
                onPressed: _busy ? null : _handover,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Remit collected cash'),
              ),
            IconButton(
              onPressed: _busy ? null : _load,
              tooltip: remittances
                  ? 'Refresh cash remittances'
                  : 'Refresh reconciliations',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          remittances
              ? 'Record shop cash passed between staff. The recipient counts and confirms every transfer.'
              : 'An administrator counts one staff member at a time. The staff member acknowledges the result; a different administrator resolves any difference.',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (!remittances && _admin && !_loading && _staff.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'No sellers are ready for reconciliation. Issue stock to a seller and have them confirm receipt first.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if (_error != null) _ErrorBanner(_error!),
        if (_loading || _busy) const LinearProgressIndicator(),
        if (!remittances) ...[
          const SizedBox(height: 20),
          if (!_loading && sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No reconciliation periods yet. Start your first stock and money count.',
              ),
            ),
          if (sorted.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          key: const ValueKey('shop-period-table'),
                          showCheckboxColumn: false,
                          sortColumnIndex: _sort,
                          sortAscending: _ascending,
                          headingRowColor: const WidgetStatePropertyAll(
                            Color(0xFFF3F7F6),
                          ),
                          columns: [
                            for (final label in [
                              'Count cutoff',
                              'Staff',
                              'Status',
                              'Counted by',
                            ])
                              DataColumn(
                                label: Text(label),
                                onSort: (i, a) => setState(() {
                                  _sort = i;
                                  _ascending = a;
                                  _page = 0;
                                }),
                              ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: sorted
                              .skip(page * 10)
                              .take(10)
                              .map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(Text(_when(r['cutoff']))),
                                    DataCell(Text('${r['staffName']}')),
                                    DataCell(Text(_status(r['status']))),
                                    DataCell(
                                      Text('${r['counterName'] ?? '—'}'),
                                    ),
                                    DataCell(
                                      TextButton(
                                        key: ValueKey(
                                          'shop-open-period-${r['id']}',
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _open(r),
                                        child: const Text('View'),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${page * 10 + 1}–${(page * 10 + 10).clamp(0, sorted.length)} of ${sorted.length}',
                      ),
                      IconButton(
                        tooltip: 'Previous page',
                        onPressed: page > 0
                            ? () => setState(() => _page = page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'Next page',
                        onPressed: (page + 1) * 10 < sorted.length
                            ? () => setState(() => _page = page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        if (remittances) _remittancePanel(),
      ],
    );
  }
}

class _CountControllers {
  _CountControllers(this.row)
    : count = TextEditingController(text: row['counted']?.toString() ?? ''),
      note = TextEditingController(text: row['note']?.toString() ?? '');
  final ShopJson row;
  final TextEditingController count, note;
  num? get delta => int.tryParse(count.text) == null
      ? null
      : int.parse(count.text) - (row['expected'] as num);
  void dispose() {
    count.dispose();
    note.dispose();
  }
}

Widget _sectionTitle(String title, String subtitle) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  ),
);

Widget _itemLabel(String name, String location) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    Text(
      location,
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
  ],
);

class _DifferenceBadge extends StatelessWidget {
  const _DifferenceBadge(this.value, {this.money = false});
  final num? value;
  final bool money;
  @override
  Widget build(BuildContext context) {
    final color = value == null
        ? AppColors.muted
        : value == 0
        ? AppColors.green
        : value! < 0
        ? Colors.red.shade700
        : Colors.orange.shade800;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value == null ? 'Not counted' : _difference(value!, money: money),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Fixed column proportions keep quantities aligned; long labels wrap rather than truncate.
class _ReconGrid extends StatelessWidget {
  const _ReconGrid({required this.headings, required this.rows, this.gridKey});
  final Key? gridKey;
  final List<String> headings;
  final List<List<Widget>> rows;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: constraints.maxWidth < 1080 ? 1080 : constraints.maxWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Table(
            key: gridKey,
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.35),
              2: FlexColumnWidth(1.65),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(2.8),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFE3E9E8)),
              bottom: BorderSide(color: Color(0xFFE3E9E8)),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFEDF4F2)),
                children: [
                  for (final heading in headings)
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      role: SemanticsRole.columnHeader,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Text(
                          heading,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF48635E),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8FAFA),
                  ),
                  children: [
                    for (final cell in rows[i])
                      // Stable cell nodes keep web text inputs focused during
                      // caret updates and automatic-save rebuilds.
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        role: SemanticsRole.cell,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: cell,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PeriodCountDialog extends StatefulWidget {
  const _PeriodCountDialog({
    required this.api,
    required this.row,
    required this.approvers,
  });
  final ShopApiClient api;
  final ShopJson row;
  final List<ShopJson> approvers;
  @override
  State<_PeriodCountDialog> createState() => _PeriodCountDialogState();
}

class _PeriodCountDialogState extends State<_PeriodCountDialog> {
  final _form = GlobalKey<FormState>();
  late final List<_CountControllers> _stock;
  late final TextEditingController _cash, _momo, _cashNote, _momoNote, _note;
  late ShopJson _row;
  int? _approver;
  bool _compare = false, _busy = false;
  bool _saving = false;
  Timer? _debounce;
  Future<bool>? _saveInFlight;
  int _revision = 0, _savedRevision = 0;
  DateTime? _savedAt;
  String? _error;
  @override
  void initState() {
    super.initState();
    _row = widget.row;
    _stock = _rows(_row['stock']).map(_CountControllers.new).toList();
    _cash = TextEditingController(text: _row['countedCash']?.toString() ?? '');
    _momo = TextEditingController(text: _row['verifiedMomo']?.toString() ?? '');
    _cashNote = TextEditingController(text: _row['cashNote'] ?? '');
    _momoNote = TextEditingController(text: _row['momoNote'] ?? '');
    _note = TextEditingController(text: _row['note'] ?? '');
    _approver = _row['approverId'] as int?;
    for (final c in [
      ..._stock.expand((s) => [s.count, s.note]),
      _cash,
      _momo,
      _cashNote,
      _momoNote,
      _note,
    ]) {
      var previous = c.text;
      c.addListener(() {
        if (previous == c.text) return;
        previous = c.text;
        _edited();
      });
    }
  }

  void _edited() {
    if (!mounted) return;
    setState(() => _revision++);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () => _persistDraft());
  }

  ShopJson _payload(bool submit) => {
    'version': _row['version'],
    'approverId': _approver,
    'countedCash': num.tryParse(_cash.text),
    'verifiedMomo': num.tryParse(_momo.text),
    'cashNote': _cashNote.text,
    'momoNote': _momoNote.text,
    'note': _note.text,
    'submit': submit,
    'stock': _stock
        .map(
          (c) => {
            'key': c.row['key'],
            'counted': int.tryParse(c.count.text),
            'note': c.note.text,
          },
        )
        .toList(),
  };

  bool get _invalidDraft =>
      _stock.any(
        (c) =>
            c.count.text.trim().isNotEmpty && _quantity(c.count.text) != null,
      ) ||
      (_cash.text.isNotEmpty && _amount(_cash.text) != null) ||
      (_momo.text.isNotEmpty && _amount(_momo.text, signed: true) != null);

  bool get _hasDifference =>
      _stock.any((row) => row.delta != null && row.delta != 0) ||
      (_delta(_cash, _row['expectedCash']) ?? 0) != 0 ||
      (_delta(_momo, _row['expectedMomo']) ?? 0) != 0;

  Future<bool> _persistDraft({bool force = false}) {
    _debounce?.cancel();
    if (force) _revision++;
    return _saveInFlight ??= _writeDraft().whenComplete(
      () => _saveInFlight = null,
    );
  }

  Future<bool> _writeDraft() async {
    if (_savedRevision == _revision) return true;
    if (mounted) setState(() => _saving = true);
    try {
      while (mounted && _savedRevision != _revision) {
        if (_invalidDraft) {
          setState(
            () => _error =
                'Not saved yet. Correct the quantities or amounts; your entries are still here.',
          );
          return false;
        }
        final revision = _revision;
        final saved = await widget.api.submitPeriod(
          _row['id'] as int,
          _payload(false),
        );
        _row = saved;
        _savedRevision = revision;
        if (mounted) {
          setState(() {
            _savedAt = DateTime.now();
            _error = null;
          });
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Not saved — $e Your entries are still on this screen. Retry before closing.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await _persistDraft();
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, 'SAVED');
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _stock) {
      c.dispose();
    }
    for (final c in [_cash, _momo, _cashNote, _momoNote, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  num? _delta(TextEditingController c, dynamic expected) =>
      num.tryParse(c.text) == null
      ? null
      : num.parse(c.text) - (expected as num);
  Future<void> _save(bool submit) async {
    if (submit && !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    if (!await _persistDraft(force: !submit) || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      if (submit) {
        await widget.api.submitPeriod(_row['id'] as int, _payload(true));
      }
      if (mounted) Navigator.pop(context, submit ? 'SUBMITTED' : 'SAVED');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Refresh the count?'),
        content: const Text(
          'This loads current balances and clears these counts. Recount stock and money before submitting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Refresh count'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      setState(() => _busy = true);
      _debounce?.cancel();
      if (_saveInFlight != null) await _saveInFlight;
      if (mounted) Navigator.pop(context, 'REFRESH');
    }
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text(
          'No balances will change. The cancelled draft remains in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    _debounce?.cancel();
    if (_saveInFlight != null && !await _saveInFlight!) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await widget.api.decidePeriod(
        _row,
        'CANCEL',
        'Count draft cancelled by counter',
      );
      if (mounted) Navigator.pop(context, 'DISCARDED');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _quantity(String? s) {
    final n = int.tryParse(s ?? '');
    return n == null || n < 0 ? 'Enter a whole quantity, zero or more' : null;
  }

  String? _amount(String? s, {bool signed = false}) {
    final n = num.tryParse(s ?? '');
    return n == null ||
            !n.isFinite ||
            (!signed && n < 0) ||
            !RegExp(
              signed ? r'^-?\d+(\.\d{1,2})?$' : r'^\d+(\.\d{1,2})?$',
            ).hasMatch(s ?? '')
        ? 'Enter an amount with up to 2 decimal places'
        : null;
  }

  Widget _explanation(
    TextEditingController c,
    String key, {
    bool required = true,
  }) => Padding(
    padding: EdgeInsets.zero,
    child: TextFormField(
      key: ValueKey(key),
      controller: c,
      readOnly: _busy,
      maxLength: 1000,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: required ? 'Explain the difference' : 'Notes (optional)',
        isDense: true,
        counterText: '',
        errorMaxLines: 3,
      ),
      validator: (s) => required && (s == null || s.trim().isEmpty)
          ? 'An explanation is required'
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final cashDelta = _delta(_cash, _row['expectedCash']);
    final momoDelta = _delta(_momo, _row['expectedMomo']);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _compare
                  ? 'Review the count'
                  : 'Count ${_row['staffName']}’s stock and money',
            ),
            const SizedBox(height: 8),
            Text(
              '${_stock.where((c) => int.tryParse(c.count.text) != null).length} of ${_stock.length} items counted',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              _saving
                  ? 'Saving draft…'
                  : _error != null
                  ? 'Not saved — attention needed'
                  : _savedRevision != _revision
                  ? 'Unsaved changes…'
                  : _savedAt != null
                  ? 'All changes saved'
                  : 'Draft saved · changes save automatically',
              key: const ValueKey('recon-save-status'),
              style: TextStyle(
                fontSize: 13,
                color: _error == null ? AppColors.green : Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 1180,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_when(_row['periodStart'])} → ${_when(_row['cutoff'])}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_row['staffName']} is temporarily unable to sell or move assigned stock while this reconciliation is open. Other sellers can continue. Count all physical stock, including reserved items.',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy ? null : _refresh,
                      child: const Text('Refresh expected balances'),
                    ),
                  ),
                  if (_error != null) _ErrorBanner(_error!),
                  if (_error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy || _saving
                            ? null
                            : () => _persistDraft(force: true),
                        icon: const Icon(Icons.sync),
                        label: const Text('Retry saving'),
                      ),
                    ),
                  if (_stock.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No stock is assigned to this staff member. Complete the money check below.',
                      ),
                    ),
                  _sectionTitle(
                    'Stock count',
                    'Enter physical quantities. Reserved items are included in the expected count.',
                  ),
                  _ReconGrid(
                    gridKey: const ValueKey('recon-count-table'),
                    headings: const [
                      'Item / location',
                      'Expected',
                      'Counted',
                      'Difference',
                      'Explanation',
                    ],
                    rows: [
                      for (final c in _stock)
                        [
                          _itemLabel(
                            '${c.row['itemName']}',
                            '${c.row['location']}',
                          ),
                          Text(
                            '${c.row['expected']}\n${(c.row['customerReserved'] as num? ?? 0) + (c.row['returnReserved'] as num? ?? 0) + (c.row['transferReserved'] as num? ?? 0)} reserved',
                          ),
                          TextFormField(
                            key: ValueKey('recon-count-${c.row['key']}'),
                            controller: c.count,
                            readOnly: _compare || _busy,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Actual quantity',
                              isDense: true,
                              errorMaxLines: 3,
                            ),
                            validator: _quantity,
                          ),
                          _DifferenceBadge(c.delta),
                          _explanation(
                            c.note,
                            'recon-note-${c.row['key']}',
                            required: c.delta != null && c.delta != 0,
                          ),
                        ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    'Money check',
                    'Count cash physically held by ${_row['staffName']} and verify their Mobile Money records separately.',
                  ),
                  _ReconGrid(
                    gridKey: const ValueKey('recon-money-table'),
                    headings: const [
                      'Payment type',
                      'Expected (GHS)',
                      'Actual (GHS)',
                      'Difference',
                      'Explanation',
                    ],
                    rows: [
                      [
                        _itemLabel(
                          'Cash held',
                          'Includes sales, refunds and confirmed cash remittances assigned to this staff member.',
                        ),
                        Text(_money(_row['expectedCash'])),
                        TextFormField(
                          key: const ValueKey('recon-cash'),
                          controller: _cash,
                          readOnly: _compare || _busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Counted cash',
                            isDense: true,
                            errorMaxLines: 3,
                          ),
                          validator: _amount,
                        ),
                        _DifferenceBadge(cashDelta, money: true),
                        _explanation(
                          _cashNote,
                          'recon-cash-note',
                          required: cashDelta != null && cashDelta != 0,
                        ),
                      ],
                      [
                        _itemLabel(
                          'Mobile Money',
                          '${_row['staffName']}’s net receipts, not the whole school wallet.',
                        ),
                        Text(_money(_row['expectedMomo'])),
                        TextFormField(
                          key: const ValueKey('recon-momo'),
                          controller: _momo,
                          readOnly: _compare || _busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Verified amount',
                            isDense: true,
                            errorMaxLines: 3,
                          ),
                          validator: (s) => _amount(s, signed: true),
                        ),
                        _DifferenceBadge(momoDelta, money: true),
                        _explanation(
                          _momoNote,
                          'recon-momo-note',
                          required: momoDelta != null && momoDelta != 0,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('recon-approver'),
                    value: _approver,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText:
                          'Independent resolver (if there is a difference)',
                    ),
                    items: widget.approvers
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a['id'] as int,
                            child: Text('${a['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) {
                            _approver = v;
                            _edited();
                          },
                    validator: (v) => _hasDifference && v == null
                        ? 'Choose an independent resolver'
                        : null,
                  ),
                  if (widget.approvers.isEmpty)
                    Text(
                      'Another active administrator or head teacher is needed to resolve any difference. You can save a draft.',
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    readOnly: _busy,
                    maxLength: 1000,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Additional notes (optional)',
                    ),
                  ),
                  if (_compare)
                    Text(
                      'Submitting does not change balances. ${_row['staffName']} must acknowledge this count. Any difference then goes to the independent resolver.',
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _close,
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _save(false),
            child: const Text('Save draft'),
          ),
          TextButton(
            onPressed: _busy ? null : _discard,
            child: const Text('Discard draft'),
          ),
          if (_compare)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _compare = false),
              child: const Text('Edit counts'),
            ),
          FilledButton(
            key: const ValueKey('recon-submit'),
            onPressed: _busy
                ? null
                : () {
                    if (_compare) {
                      _save(true);
                    } else if (_form.currentState!.validate()) {
                      setState(() => _compare = true);
                    }
                  },
            child: Text(
              _busy
                  ? 'Saving…'
                  : _compare
                  ? 'Send to staff for acknowledgement'
                  : 'Compare',
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodReviewDialog extends StatefulWidget {
  const _PeriodReviewDialog({
    required this.api,
    required this.row,
    required this.userId,
    required this.admin,
  });
  final ShopApiClient api;
  final ShopJson row;
  final int userId;
  final bool admin;
  @override
  State<_PeriodReviewDialog> createState() => _PeriodReviewDialogState();
}

class _PeriodReviewDialogState extends State<_PeriodReviewDialog> {
  bool _busy = false;
  String? _error;

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Container(
    width: 230,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _personDetail(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9F9),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.green),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );

  Future<void> _decide(String action) async {
    final controller = TextEditingController();
    final needsNote = const {'DISPUTE', 'REJECT', 'RESOLVE'}.contains(action);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(switch (action) {
            'ACKNOWLEDGE' => 'Acknowledge this count?',
            'DISPUTE' => 'Dispute this count?',
            'REJECT' => 'Reject this reconciliation?',
            'RESOLVE' => 'Confirm differences and close reconciliation?',
            _ => 'Confirm action?',
          }),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action == 'ACKNOWLEDGE'
                    ? 'You confirm that the displayed physical count is accurate. A balanced count will close; any difference goes to the independent resolver.'
                    : action == 'DISPUTE'
                    ? 'Explain what is incorrect. No stock or money balance will change.'
                    : action == 'RESOLVE'
                    ? 'This will update the recorded balances using the confirmed differences and permanently close this reconciliation. Continue only after checking the count. This action cannot be undone. Add a note explaining any difference.'
                    : 'Explain why. No stock or money adjustment will be applied.',
              ),
              if (needsNote)
                TextField(
                  key: const ValueKey('recon-decision-note'),
                  controller: controller,
                  maxLength: 1000,
                  maxLines: 3,
                  onChanged: (_) => set(() {}),
                  decoration: InputDecoration(
                    labelText: action == 'RESOLVE'
                        ? 'Resolution note (required)'
                        : 'Explanation',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: needsNote && controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(c, true),
              child: Text(
                action == 'RESOLVE' ? 'Confirm and close' : 'Confirm',
              ),
            ),
          ],
        ),
      ),
    );
    final note = controller.text;
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.decidePeriod(widget.row, action, note);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final awaitingStaff = r['status'] == 'AWAITING_SELLER_ACK';
    final seller = awaitingStaff && r['staffId'] == widget.userId;
    final resolver =
        const {'PENDING_RESOLUTION', 'DISPUTED'}.contains(r['status']) &&
        r['approverId'] == widget.userId &&
        r['staffId'] != widget.userId &&
        r['counterId'] != widget.userId &&
        widget.admin;
    final stock = _rows(r['stock']);
    final stockDifferences = stock
        .where((row) => (row['variance'] as num? ?? 0) != 0)
        .length;
    final cashDifference = r['cashVariance'] as num? ?? 0;
    final momoDifference = r['momoVariance'] as num? ?? 0;
    final balanced =
        stockDifferences == 0 && cashDifference == 0 && momoDifference == 0;
    final actionTitle = seller
        ? 'Your confirmation is required'
        : resolver
        ? 'Your independent decision is required'
        : 'Reconciliation record';
    final actionMessage = seller
        ? 'Check the physical stock and money figures below. Acknowledge only if they match what was counted with you. Report a problem if anything is incorrect.'
        : resolver
        ? 'Review every difference and its explanation. Resolve only after checking the physical count or supporting evidence; otherwise send it for a recount.'
        : 'This view shows the submitted physical count, the expected records, and every recorded difference.';
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text('Reconciliation #${r['id']}')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (balanced ? AppColors.green : Colors.orange.shade800)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _status(r['status']),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: balanced ? AppColors.green : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 1180,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('recon-review-decision-summary'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: seller
                      ? const Color(0xFFEAF5F2)
                      : resolver
                      ? const Color(0xFFFFF6E8)
                      : const Color(0xFFF3F6F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: seller
                        ? AppColors.green.withValues(alpha: 0.25)
                        : resolver
                        ? Colors.orange.withValues(alpha: 0.35)
                        : const Color(0xFFDCE4E2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      seller
                          ? Icons.verified_user_outlined
                          : resolver
                          ? Icons.rule_folder_outlined
                          : Icons.receipt_long_outlined,
                      color: seller
                          ? AppColors.green
                          : resolver
                          ? Colors.orange.shade800
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actionTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(actionMessage),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _personDetail(
                    'SELLER BEING RECONCILED',
                    '${r['staffName']}',
                    Icons.storefront_outlined,
                  ),
                  _personDetail(
                    'COUNTED BY',
                    '${r['counterName'] ?? '—'}',
                    Icons.person_search_outlined,
                  ),
                  _personDetail(
                    'INDEPENDENT APPROVER',
                    '${r['approverName'] ?? 'Not needed unless there is a difference'}',
                    Icons.gavel_outlined,
                  ),
                  _personDetail(
                    'COUNT PERIOD',
                    '${_when(r['periodStart'])} → ${_when(r['cutoff'])}',
                    Icons.date_range_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                key: const ValueKey('recon-review-summary'),
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock checked',
                    value: '${stock.length} item lines',
                    color: AppColors.green,
                  ),
                  _metric(
                    icon: stockDifferences == 0
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    label: 'Stock differences',
                    value: stockDifferences == 0
                        ? 'None'
                        : '$stockDifferences need attention',
                    color: stockDifferences == 0
                        ? AppColors.green
                        : Colors.red.shade700,
                  ),
                  _metric(
                    icon: Icons.payments_outlined,
                    label: 'Cash difference',
                    value: _difference(cashDifference, money: true),
                    color: cashDifference == 0
                        ? AppColors.green
                        : cashDifference < 0
                        ? Colors.red.shade700
                        : Colors.orange.shade800,
                  ),
                  _metric(
                    icon: Icons.phone_android_outlined,
                    label: 'Mobile Money difference',
                    value: _difference(momoDifference, money: true),
                    color: momoDifference == 0
                        ? AppColors.green
                        : momoDifference < 0
                        ? Colors.red.shade700
                        : Colors.orange.shade800,
                  ),
                ],
              ),
              if (_error != null) _ErrorBanner(_error!),
              const SizedBox(height: 24),
              _sectionTitle(
                'Stock count',
                'Review each item. Differences are highlighted and must include an explanation.',
              ),
              _ReconGrid(
                gridKey: const ValueKey('recon-review-stock-table'),
                headings: const [
                  'Item / location',
                  'Expected',
                  'Counted',
                  'Difference',
                  'Explanation',
                ],
                rows: [
                  for (final s in stock)
                    [
                      _itemLabel('${s['itemName']}', '${s['location']}'),
                      Text('${s['expected']}'),
                      Text(
                        s['counted'] == null
                            ? 'Not counted'
                            : '${s['counted']}',
                      ),
                      _DifferenceBadge(
                        s['counted'] == null
                            ? null
                            : s['variance'] as num? ?? 0,
                      ),
                      Text('${s['note'] ?? ''}'.isEmpty ? '—' : '${s['note']}'),
                    ],
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle(
                'Money check',
                'Cash and Mobile Money are reconciled separately.',
              ),
              _ReconGrid(
                gridKey: const ValueKey('recon-review-money-table'),
                headings: const [
                  'Payment type',
                  'Expected (GHS)',
                  'Actual (GHS)',
                  'Difference',
                  'Explanation',
                ],
                rows: [
                  [
                    _itemLabel('Cash held', 'Physical cash'),
                    Text(_money(r['expectedCash'])),
                    Text(
                      r['countedCash'] == null
                          ? 'Not counted'
                          : _money(r['countedCash']),
                    ),
                    _DifferenceBadge(
                      r['countedCash'] == null
                          ? null
                          : r['cashVariance'] as num? ?? 0,
                      money: true,
                    ),
                    Text('${r['cashNote'] ?? '—'}'),
                  ],
                  [
                    _itemLabel('Mobile Money', 'Verified net receipts'),
                    Text(_money(r['expectedMomo'])),
                    Text(
                      r['verifiedMomo'] == null
                          ? 'Not counted'
                          : _money(r['verifiedMomo']),
                    ),
                    _DifferenceBadge(
                      r['verifiedMomo'] == null
                          ? null
                          : r['momoVariance'] as num? ?? 0,
                      money: true,
                    ),
                    Text('${r['momoNote'] ?? '—'}'),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if ('${r['note'] ?? ''}'.isNotEmpty ||
                  '${r['decisionNote'] ?? ''}'.isNotEmpty ||
                  '${r['disputeNote'] ?? ''}'.isNotEmpty ||
                  r['decidedAt'] != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E7E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes and decision history',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ('${r['note'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Counter note: ${r['note']}'),
                      ],
                      if ('${r['decisionNote'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Resolution note: ${r['decisionNote']}'),
                      ],
                      if ('${r['disputeNote'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Seller’s concern: ${r['disputeNote']}'),
                      ],
                      if (r['decidedAt'] != null) ...[
                        const SizedBox(height: 8),
                        Text('Decision recorded ${_when(r['decidedAt'])}'),
                      ],
                    ],
                  ),
                ),
              if (const {
                'PENDING_RESOLUTION',
                'DISPUTED',
              }.contains(r['status']))
                const _ErrorBanner(
                  'No balance has changed yet. Only the assigned independent administrator can resolve and record these differences.',
                ),
              if (r['investigation'] == 'RESOLVED')
                Text(
                  'Investigation resolved: ${r['resolutionNote']} · ${_when(r['resolvedAt'])}',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (seller) ...[
          OutlinedButton(
            key: const ValueKey('recon-dispute'),
            onPressed: _busy ? null : () => _decide('DISPUTE'),
            child: const Text('Report a problem'),
          ),
          FilledButton(
            key: const ValueKey('recon-acknowledge'),
            onPressed: _busy ? null : () => _decide('ACKNOWLEDGE'),
            child: const Text('Acknowledge as correct'),
          ),
        ],
        if (resolver) ...[
          OutlinedButton(
            onPressed: _busy ? null : () => _decide('REJECT'),
            child: const Text('Send for recount'),
          ),
          FilledButton(
            key: const ValueKey('recon-resolve'),
            onPressed: _busy ? null : () => _decide('RESOLVE'),
            child: const Text('Resolve differences'),
          ),
        ],
      ],
    );
  }
}

class _CashHandoverDialog extends StatefulWidget {
  const _CashHandoverDialog({required this.api, required this.people});
  final ShopApiClient api;
  final List<ShopJson> people;
  @override
  State<_CashHandoverDialog> createState() => _CashHandoverDialogState();
}

class _CashHandoverDialogState extends State<_CashHandoverDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _recipient;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.handOverCash({
        'recipientId': _recipient,
        'amount': num.tryParse(_amount.text),
        'note': _note.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Remit collected cash'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record cash collected through shop sales that you are physically giving to another responsible person. It stays on your record until the recipient counts and confirms it.',
            ),
            if (_error != null) _ErrorBanner(_error!),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Recipient'),
              items: widget.people
                  .map(
                    (p) => DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text('${p['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _recipient = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Cash amount (GHS)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _busy || _recipient == null ? null : _save,
        child: const Text('Submit remittance'),
      ),
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.amber.withValues(alpha: .1),
      border: Border.all(color: AppColors.amber),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message),
  );
}
