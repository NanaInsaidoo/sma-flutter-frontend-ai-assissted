import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/audit_api_client.dart';
import '../domain/audit_models.dart';
import 'audit_csv_export.dart';

enum _AuditPeriod { today, sevenDays, thirtyDays, custom, all }

typedef AuditCustomRangePicker =
    Future<(DateTime, DateTime)?> Function(
      BuildContext context,
      DateTime? currentStart,
      DateTime? currentEnd,
    );

typedef AuditCsvDownloader =
    Future<bool> Function(String fileName, String contents);

class AuditActivityScreen extends StatefulWidget {
  const AuditActivityScreen({
    super.key,
    required this.repository,
    this.pageSize = 20,
    this.customRangePicker,
    this.csvDownloader,
  });

  final AuditApiClient repository;
  final int pageSize;
  final AuditCustomRangePicker? customRangePicker;
  final AuditCsvDownloader? csvDownloader;

  @override
  State<AuditActivityScreen> createState() => _AuditActivityScreenState();
}

class _AuditActivityScreenState extends State<AuditActivityScreen> {
  static const _actions = <String>[
    'CREATE',
    'EDIT',
    'SUSPEND',
    'REACTIVATE',
    'DEACTIVATE',
    'DELETE',
    'PASSWORD_RESET',
    'PASSWORD_CHANGE_REQUIRED',
    'CREDENTIALS_RESENT',
    'OVERRIDE_GRANTED',
    'OVERRIDE_REVOKED',
    'OVERRIDE_EXPIRED',
    'LOGIN',
    'LOGIN_FAILED',
    'LOGOUT',
  ];

  final _searchController = TextEditingController();
  Timer? _searchTimer;
  AuditLogPage? _page;
  AuditStatistics? _statistics;
  List<AuditScopeOption> _scopes = const [];
  String? _scopeKey;
  String? _action;
  _AuditPeriod _period = _AuditPeriod.thirtyDays;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  final Map<String, AuditLogRecord> _selectedRecords = {};

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final scopes = await widget.repository.getScopes();
      if (!mounted) return;
      setState(() {
        _scopes = scopes;
        _scopeKey = scopes.isEmpty ? null : scopes.first.value;
      });
      await _load(includeStatistics: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool includeStatistics = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _dateRange(_period);
      final results = await Future.wait<Object>([
        widget.repository.getAuditLogs(
          page: _currentPage,
          size: widget.pageSize,
          search: _searchController.text,
          actionType: _action,
          startDate: range.$1,
          endDate: range.$2,
          scopeKey: _scopeKey,
        ),
        if (includeStatistics || _statistics == null)
          widget.repository.getStatistics(
            scopeKey: _scopeKey,
            startDate: range.$1,
            endDate: range.$2,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _page = results.first as AuditLogPage;
        if (results.length > 1) {
          _statistics = results[1] as AuditStatistics;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _reloadFromFirstPage({bool includeStatistics = false}) {
    _currentPage = 0;
    _load(includeStatistics: includeStatistics);
  }

  void _searchChanged(String _) {
    if (_selectedRecords.isNotEmpty) {
      setState(_selectedRecords.clear);
    }
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 450),
      _reloadFromFirstPage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('audit-activity-screen'),
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(compact),
                const SizedBox(height: 18),
                _notice(),
                const SizedBox(height: 18),
                _summary(compact),
                const SizedBox(height: 18),
                _filters(compact),
                const SizedBox(height: 14),
                _content(compact),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Audit & Activity',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Review account, access and security activity recorded for this workspace.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
    final refresh = OutlinedButton.icon(
      key: const ValueKey('audit-refresh'),
      onPressed: _loading ? null : () => _load(includeStatistics: true),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Refresh'),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 14), refresh],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        refresh,
      ],
    );
  }

  Widget _notice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.green, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Audit records are permanent and read-only. Deleted accounts remain identifiable through a retained snapshot.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(bool compact) {
    final stats = _statistics;
    final cards = [
      _Metric(
        'Total records',
        stats?.totalLogs ?? 0,
        Icons.history_rounded,
        AppColors.green,
      ),
      _Metric(
        'Accounts created',
        stats?.createCount ?? 0,
        Icons.person_add_alt_1_rounded,
        AppColors.blue,
      ),
      _Metric(
        'Profile changes',
        stats?.editCount ?? 0,
        Icons.edit_note_rounded,
        AppColors.purple,
      ),
      _Metric(
        'Access actions',
        stats?.accessChangeCount ?? 0,
        Icons.admin_panel_settings_outlined,
        AppColors.amber,
      ),
      _Metric(
        'Failed sign-ins',
        stats?.failedLoginCount ?? 0,
        Icons.gpp_bad_outlined,
        AppColors.red,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 2 : 5,
        mainAxisExtent: 108,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _metricCard(cards[index]),
    );
  }

  Widget _metricCard(_Metric metric) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(metric.icon, color: metric.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${metric.value}',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    metric.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(bool compact) {
    final search = TextField(
      key: const ValueKey('audit-search'),
      controller: _searchController,
      onChanged: _searchChanged,
      onSubmitted: (_) => _reloadFromFirstPage(),
      decoration: const InputDecoration(
        labelText: 'Search activity',
        hintText: 'Person, username or description',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
    final scope = _scopes.length <= 1
        ? null
        : DropdownButtonFormField<String>(
            key: const ValueKey('audit-scope-filter'),
            value: _scopeKey,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Activity scope'),
            items: _scopes
                .map(
                  (value) => DropdownMenuItem(
                    value: value.value,
                    child: Text(value.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || value == _scopeKey) return;
              setState(() {
                _scopeKey = value;
                _selectedRecords.clear();
              });
              _reloadFromFirstPage(includeStatistics: true);
            },
          );
    final action = DropdownButtonFormField<String?>(
      key: const ValueKey('audit-action-filter'),
      value: _action,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Action'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All actions')),
        ..._actions.map(
          (value) =>
              DropdownMenuItem(value: value, child: Text(_actionLabel(value))),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _action = value;
          _selectedRecords.clear();
        });
        _reloadFromFirstPage();
      },
    );
    final period = DropdownButtonFormField<_AuditPeriod>(
      key: const ValueKey('audit-period-filter'),
      value: _period,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Period'),
      items: const [
        DropdownMenuItem(value: _AuditPeriod.today, child: Text('Today')),
        DropdownMenuItem(
          value: _AuditPeriod.sevenDays,
          child: Text('Last 7 days'),
        ),
        DropdownMenuItem(
          value: _AuditPeriod.thirtyDays,
          child: Text('Last 30 days'),
        ),
        DropdownMenuItem(
          value: _AuditPeriod.custom,
          child: Text('Custom range'),
        ),
        DropdownMenuItem(value: _AuditPeriod.all, child: Text('All time')),
      ],
      onChanged: _selectPeriod,
    );
    final clear = TextButton.icon(
      onPressed:
          _action == null &&
              _period == _AuditPeriod.thirtyDays &&
              _searchController.text.isEmpty
          ? null
          : () {
              _searchController.clear();
              setState(() {
                _action = null;
                _period = _AuditPeriod.thirtyDays;
                _customStart = null;
                _customEnd = null;
                _selectedRecords.clear();
              });
              _reloadFromFirstPage(includeStatistics: true);
            },
      icon: const Icon(Icons.filter_alt_off_outlined),
      label: const Text('Clear'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: compact
            ? Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  if (scope != null) ...[scope, const SizedBox(height: 10)],
                  action,
                  const SizedBox(height: 10),
                  period,
                  if (_period == _AuditPeriod.custom) _customRangeSummary(),
                  Align(alignment: Alignment.centerRight, child: clear),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: 320, child: search),
                      if (scope != null) SizedBox(width: 230, child: scope),
                      SizedBox(width: 190, child: action),
                      SizedBox(width: 190, child: period),
                      clear,
                    ],
                  ),
                  if (_period == _AuditPeriod.custom) _customRangeSummary(),
                ],
              ),
      ),
    );
  }

  Widget _content(bool compact) {
    if (_loading && _page == null) {
      return const Card(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return Card(
        child: SizedBox(
          height: 240,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.red),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }
    final page = _page;
    if (page == null || page.logs.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.manage_search_rounded, color: AppColors.muted),
                SizedBox(height: 10),
                Text('No activity matches the selected filters.'),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          _recordsToolbar(page, compact),
          const Divider(height: 1),
          if (compact)
            ...page.logs.map(_mobileRow)
          else
            _desktopTable(page.logs),
          const Divider(height: 1),
          _pagination(page),
        ],
      ),
    );
  }

  Widget _desktopTable(List<AuditLogRecord> records) {
    final allSelected = _allPageRecordsSelected(records);
    final anySelected = records.any(
      (record) => _selectedRecords.containsKey(record.id),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAF9)),
        columns: [
          DataColumn(
            label: Checkbox(
              key: const ValueKey('audit-select-page'),
              value: allSelected
                  ? true
                  : anySelected
                  ? null
                  : false,
              tristate: true,
              onChanged: (_) => _togglePageSelection(records),
            ),
          ),
          const DataColumn(label: Text('DATE & TIME')),
          const DataColumn(label: Text('ACTIVITY')),
          if (_scopes.length > 1) const DataColumn(label: Text('SCOPE')),
          const DataColumn(label: Text('AFFECTED ACCOUNT')),
          const DataColumn(label: Text('DONE BY')),
          const DataColumn(label: Text('DETAILS')),
        ],
        rows: records.map((record) {
          final style = _actionStyle(record.actionType);
          return DataRow(
            cells: [
              DataCell(
                Checkbox(
                  key: ValueKey('audit-select-${record.id}'),
                  value: _selectedRecords.containsKey(record.id),
                  onChanged: (selected) =>
                      _setRecordSelected(record, selected ?? false),
                ),
              ),
              DataCell(
                SizedBox(width: 128, child: Text(_dateTime(record.timestamp))),
              ),
              DataCell(_actionChip(record.actionType, style)),
              if (_scopes.length > 1)
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      _scopeLabel(record.customSchoolId),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              DataCell(
                SizedBox(
                  width: 180,
                  child: _person(record.subjectName, record.subjectUsername),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 170,
                  child: _person(record.actorName, record.performedByUsername),
                ),
              ),
              DataCell(
                InkWell(
                  onTap: () => _showDetails(record),
                  child: SizedBox(
                    width: 350,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _recordsToolbar(AuditLogPage page, bool compact) {
    final selectedCount = _selectedRecords.length;
    final allPageSelected = _allPageRecordsSelected(page.logs);
    final recordLabel = page.totalElements == 1 ? 'record' : 'records';
    final selectionActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          key: const ValueKey('audit-toggle-page-selection'),
          onPressed: () => _togglePageSelection(page.logs),
          icon: Icon(
            allPageSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          label: Text(allPageSelected ? 'Clear page' : 'Select page'),
        ),
        FilledButton.icon(
          key: const ValueKey('audit-download-selected'),
          onPressed: selectedCount == 0 ? null : _downloadSelected,
          icon: const Icon(Icons.download_rounded),
          label: Text('Download selected ($selectedCount)'),
        ),
      ],
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity records',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          selectedCount == 0
              ? '${page.totalElements} $recordLabel match the current filters'
              : '$selectedCount selected · ${page.totalElements} $recordLabel match',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 10), selectionActions],
            )
          : Row(
              children: [
                Expanded(child: summary),
                selectionActions,
              ],
            ),
    );
  }

  bool _allPageRecordsSelected(List<AuditLogRecord> records) =>
      records.isNotEmpty &&
      records.every((record) => _selectedRecords.containsKey(record.id));

  void _togglePageSelection(List<AuditLogRecord> records) {
    final clearPage = _allPageRecordsSelected(records);
    setState(() {
      for (final record in records) {
        if (clearPage) {
          _selectedRecords.remove(record.id);
        } else {
          _selectedRecords[record.id] = record;
        }
      }
    });
  }

  void _setRecordSelected(AuditLogRecord record, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecords[record.id] = record;
      } else {
        _selectedRecords.remove(record.id);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedRecords.isEmpty) return;
    final count = _selectedRecords.length;
    final recordLabel = count == 1 ? 'record' : 'records';
    try {
      final download = widget.csvDownloader ?? exportAuditCsv;
      final downloaded = await download(_downloadFileName(), _selectedCsv());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? '$count selected audit $recordLabel downloaded.'
                : 'Downloads are not available on this device.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected audit records could not be downloaded.'),
        ),
      );
    }
  }

  String _selectedCsv() {
    const headings = <String>[
      'Date and time',
      'School/Scope',
      'Action',
      'Affected account',
      'Affected username',
      'Affected role',
      'Done by',
      'Done by username',
      'Description',
      'IP address',
      'Device',
      'Metadata',
    ];
    final records = _selectedRecords.values.toList()
      ..sort((left, right) {
        final leftTime =
            left.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightTime =
            right.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightTime.compareTo(leftTime);
      });
    final rows = <List<Object?>>[
      headings,
      ...records.map(
        (record) => <Object?>[
          record.timestamp?.toIso8601String() ?? '',
          _scopeLabel(record.customSchoolId),
          _actionLabel(record.actionType),
          record.subjectName,
          record.subjectUsername,
          _actionLabel(record.subjectRole),
          record.actorName,
          record.performedByUsername,
          record.description,
          record.ipAddress,
          record.userAgent,
          record.metadata ?? '',
        ],
      ),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _downloadFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'audit_activity_selected_'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';
  }

  Widget _mobileRow(AuditLogRecord record) {
    final style = _actionStyle(record.actionType);
    return InkWell(
      onTap: () => _showDetails(record),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  key: ValueKey('audit-select-${record.id}'),
                  value: _selectedRecords.containsKey(record.id),
                  onChanged: (selected) =>
                      _setRecordSelected(record, selected ?? false),
                ),
                const SizedBox(width: 4),
                _actionChip(record.actionType, style),
                const Spacer(),
                Text(
                  _dateTime(record.timestamp),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${record.actorName} → ${record.subjectName}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (_scopes.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                _scopeLabel(record.customSchoolId),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pagination(AuditLogPage page) {
    final shownPage = page.totalPages == 0 ? 0 : page.currentPage + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            'Page $shownPage of ${page.totalPages}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('audit-previous-page'),
            tooltip: 'Previous page',
            onPressed: _loading || page.currentPage <= 0
                ? null
                : () {
                    _currentPage -= 1;
                    _load();
                  },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const ValueKey('audit-next-page'),
            tooltip: 'Next page',
            onPressed: _loading || page.currentPage + 1 >= page.totalPages
                ? null
                : () {
                    _currentPage += 1;
                    _load();
                  },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _person(String name, String username) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (username.trim().isNotEmpty && username.trim() != name.trim())
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
      ],
    );
  }

  Widget _actionChip(String action, _ActionStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _actionLabel(action),
        style: TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _showDetails(AuditLogRecord record) {
    final metadata = _prettyMetadata(record.metadata);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _actionStyle(record.actionType).icon,
              color: _actionStyle(record.actionType).color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_actionLabel(record.actionType))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Date and time', _dateTime(record.timestamp)),
                _detail('Scope', _scopeLabel(record.customSchoolId)),
                _detail('Affected account', record.subjectName),
                if (record.subjectUsername.isNotEmpty)
                  _detail('Username', record.subjectUsername),
                if (record.subjectRole.isNotEmpty)
                  _detail('Role', _actionLabel(record.subjectRole)),
                _detail('Performed by', record.actorName),
                const SizedBox(height: 8),
                const Text(
                  'Activity details',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(record.description),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Recorded change details'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          metadata,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (record.ipAddress.isNotEmpty || record.userAgent.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Technical details'),
                    children: [
                      if (record.ipAddress.isNotEmpty)
                        _detail('IP address', record.ipAddress),
                      if (record.userAgent.isNotEmpty)
                        _detail('Device', record.userAgent),
                    ],
                  ),
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
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
  }

  Future<void> _selectPeriod(_AuditPeriod? value) async {
    if (value == null || value == _period) return;
    if (value != _AuditPeriod.custom) {
      setState(() {
        _period = value;
        _selectedRecords.clear();
      });
      _reloadFromFirstPage(includeStatistics: true);
      return;
    }

    final picker = widget.customRangePicker ?? _showCustomRangePicker;
    final selected = await picker(context, _customStart, _customEnd);
    if (!mounted || selected == null) return;
    setState(() {
      _customStart = selected.$1;
      _customEnd = selected.$2;
      _period = _AuditPeriod.custom;
      _selectedRecords.clear();
    });
    _reloadFromFirstPage(includeStatistics: true);
  }

  Widget _customRangeSummary() {
    final start = _customStart;
    final end = _customEnd;
    if (start == null || end == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_dateTimeSingleLine(start)}  to  ${_dateTimeSingleLine(end)}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('audit-change-custom-range'),
            onPressed: () async {
              final picker = widget.customRangePicker ?? _showCustomRangePicker;
              final selected = await picker(context, start, end);
              if (!mounted || selected == null) return;
              setState(() {
                _customStart = selected.$1;
                _customEnd = selected.$2;
                _selectedRecords.clear();
              });
              _reloadFromFirstPage(includeStatistics: true);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<(DateTime, DateTime)?> _showCustomRangePicker(
    BuildContext context,
    DateTime? currentStart,
    DateTime? currentEnd,
  ) async {
    final now = DateTime.now();
    var start =
        currentStart ??
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
    var end = currentEnd ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
    String? validationMessage;

    return showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final compactHeight = MediaQuery.sizeOf(context).height < 500;
          Future<void> choose({required bool isStart}) async {
            final original = isStart ? start : end;
            final date = await showDatePicker(
              context: context,
              initialDate: original,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 2, 12, 31),
              helpText: isStart ? 'Select start date' : 'Select end date',
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(original),
              helpText: isStart ? 'Select start time' : 'Select end time',
            );
            if (time == null || !context.mounted) return;
            final selected = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
              isStart ? 0 : 59,
            );
            setDialogState(() {
              if (isStart) {
                start = selected;
              } else {
                end = selected;
              }
              validationMessage = end.isBefore(start)
                  ? 'The end date and time must be after the start.'
                  : null;
            });
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compactHeight ? 14 : 18,
                    compactHeight ? 14 : 18,
                    compactHeight ? 14 : 18,
                    compactHeight ? 12 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.date_range_rounded,
                              color: AppColors.green,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose a date range',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!compactHeight) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Set the exact start and end time for the activity you want to review.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: compactHeight ? 10 : 16),
                      _rangePickerRow(
                        key: const ValueKey('audit-custom-start'),
                        label: 'FROM',
                        value: start,
                        dense: compactHeight,
                        onTap: () => choose(isStart: true),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 21),
                        child: Container(
                          width: 2,
                          height: 8,
                          color: AppColors.border,
                        ),
                      ),
                      _rangePickerRow(
                        key: const ValueKey('audit-custom-end'),
                        label: 'TO',
                        value: end,
                        dense: compactHeight,
                        onTap: () => choose(isStart: false),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  validationMessage!,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: compactHeight ? 10 : 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey('audit-apply-custom-range'),
                              onPressed: end.isBefore(start)
                                  ? null
                                  : () => Navigator.pop(dialogContext, (
                                      start,
                                      end,
                                    )),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Apply range'),
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
        },
      ),
    );
  }

  Widget _rangePickerRow({
    required Key key,
    required String label,
    required DateTime value,
    bool dense = false,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: const Color(0xFFF8FAF9),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 5 : 8,
          ),
          child: Row(
            children: [
              Container(
                width: dense ? 34 : 38,
                height: dense ? 34 : 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.green,
                  size: 21,
                ),
              ),
              SizedBox(width: dense ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateTimeSingleLine(value),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: dense ? 13 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.green,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(String customSchoolId) {
    if (customSchoolId.trim().isEmpty ||
        customSchoolId.trim().toLowerCase() == 'platform') {
      return 'Platform';
    }
    for (final scope in _scopes) {
      if (scope.value.toLowerCase() ==
          'school:${customSchoolId.trim()}'.toLowerCase()) {
        return scope.label;
      }
    }
    return customSchoolId;
  }

  (DateTime?, DateTime?) _dateRange(_AuditPeriod period) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return switch (period) {
      _AuditPeriod.today => (DateTime(now.year, now.month, now.day), end),
      _AuditPeriod.sevenDays => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
        end,
      ),
      _AuditPeriod.thirtyDays => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29)),
        end,
      ),
      _AuditPeriod.custom => (_customStart, _customEnd),
      _AuditPeriod.all => (null, null),
    };
  }

  String _dateTime(DateTime? value) {
    if (value == null) return 'Unknown time';
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${_month(value.month)} ${value.day}, ${value.year}\n'
        '$hour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  String _dateTimeSingleLine(DateTime value) =>
      _dateTime(value).replaceFirst('\n', ' at ');

  String _month(int month) => const [
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
  ][month - 1];

  String _prettyMetadata(String? value) {
    if (value?.trim().isEmpty ?? true) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(value!));
    } catch (_) {
      return value!.trim();
    }
  }

  static String _actionLabel(String value) {
    final words = value
        .trim()
        .toLowerCase()
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
    return words.join(' ');
  }

  _ActionStyle _actionStyle(String action) {
    return switch (action) {
      'CREATE' => const _ActionStyle(
        AppColors.green,
        Icons.person_add_alt_1_rounded,
      ),
      'EDIT' => const _ActionStyle(AppColors.blue, Icons.edit_note_rounded),
      'LOGIN' ||
      'LOGOUT' => const _ActionStyle(AppColors.green, Icons.login_rounded),
      'LOGIN_FAILED' => const _ActionStyle(
        AppColors.red,
        Icons.gpp_bad_outlined,
      ),
      'DELETE' ||
      'DEACTIVATE' ||
      'SUSPEND' => const _ActionStyle(AppColors.red, Icons.block_rounded),
      'PASSWORD_RESET' || 'PASSWORD_CHANGE_REQUIRED' || 'CREDENTIALS_RESENT' =>
        const _ActionStyle(AppColors.amber, Icons.key_rounded),
      _ => const _ActionStyle(
        AppColors.purple,
        Icons.admin_panel_settings_outlined,
      ),
    };
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _ActionStyle {
  const _ActionStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}
