import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/incident_api_client.dart';
import '../domain/incident_models.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({
    super.key,
    required this.customSchoolId,
    required this.accessToken,
    this.onRefreshAccessToken,
    required this.reportedBy,
  });
  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String reportedBy;

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  late final IncidentApiClient _api;
  IncidentDashboardStats? _stats;
  IncidentPage? _page;
  bool _loading = true;
  String? _error;
  String _search = '';
  String _severity = '';
  String _status = '';
  int _pageIndex = 0;
  bool _showIncidentList = false;
  bool _showActivityList = false;
  IncidentRecord? _selected;

  @override
  void initState() {
    super.initState();
    _api = IncidentApiClient(
      customSchoolId: widget.customSchoolId,
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _api.getStats(),
        _api.getIncidents(
          page: _pageIndex,
          status: _status,
          severity: _severity,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = values[0] as IncidentDashboardStats;
        _page = values[1] as IncidentPage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return IncidentDetailView(
        api: _api,
        initial: _selected!,
        onBack: () {
          setState(() => _selected = null);
          _load();
        },
      );
    }
    if (_showActivityList) {
      return Column(
        children: [
          _ActivityListPageHeader(
            count: _stats?.recentActivity.length ?? 0,
            onBack: () => setState(() => _showActivityList = false),
            onRefresh: _load,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        _ActivityCard(
                          items: _stats!.recentActivity,
                          showAll: true,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }
    if (_showIncidentList) {
      return Column(
        children: [
          _IncidentListPageHeader(
            onBack: () => setState(() => _showIncidentList = false),
            onRefresh: _load,
            onCreate: _openCreate,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        _IncidentListCard(
                          page: _page!,
                          search: _search,
                          severity: _severity,
                          status: _status,
                          onSearch: (value) => setState(() => _search = value),
                          onSeverity: (value) {
                            _severity = value;
                            _pageIndex = 0;
                            _load();
                          },
                          onStatus: (value) {
                            _status = value;
                            _pageIndex = 0;
                            _load();
                          },
                          onOpen: _openIncident,
                          showAll: true,
                          onToggleView: () =>
                              setState(() => _showIncidentList = false),
                          onPage: (value) {
                            _pageIndex = value;
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _PageHeader(onRefresh: _load, onCreate: _openCreate),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 700 ? 16 : 24,
                      ),
                      children: [
                        _StatsGrid(stats: _stats!),
                        const SizedBox(height: 18),
                        _AnalyticsGrid(stats: _stats!),
                        const SizedBox(height: 18),
                        _IncidentListCard(
                          page: _page!,
                          search: _search,
                          severity: _severity,
                          status: _status,
                          onSearch: (value) => setState(() => _search = value),
                          onSeverity: (value) {
                            _severity = value;
                            _pageIndex = 0;
                            _load();
                          },
                          onStatus: (value) {
                            _status = value;
                            _pageIndex = 0;
                            _load();
                          },
                          onOpen: _openIncident,
                          showAll: false,
                          onToggleView: () =>
                              setState(() => _showIncidentList = true),
                          onPage: (value) {
                            _pageIndex = value;
                            _load();
                          },
                        ),
                        const SizedBox(height: 18),
                        _ActivityCard(
                          items: _stats!.recentActivity,
                          onViewAll: () =>
                              setState(() => _showActivityList = true),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openIncident(IncidentRecord item) async {
    setState(() => _loading = true);
    try {
      final detail = await _api.getIncident(item.incidentId);
      if (mounted) {
        setState(() {
          _selected = detail;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await showDialog<IncidentRecord>(
      context: context,
      builder: (_) => _CreateIncidentDialog(
        api: _api,
        schoolId: widget.customSchoolId,
        reportedBy: widget.reportedBy,
      ),
    );
    if (created != null) {
      _selected = created;
      await _load();
      if (mounted) setState(() => _selected = created);
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh, required this.onCreate});
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incident Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Track, investigate and resolve student incidents',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Log incident'),
        ),
      ],
    ),
  );
}

class _IncidentListPageHeader extends StatelessWidget {
  const _IncidentListPageHeader({
    required this.onBack,
    required this.onRefresh,
    required this.onCreate,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back to incident dashboard',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Incidents',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                'Search, filter and review reported incidents',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh incidents',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Log incident'),
        ),
      ],
    ),
  );
}

class _ActivityListPageHeader extends StatelessWidget {
  const _ActivityListPageHeader({
    required this.count,
    required this.onBack,
    required this.onRefresh,
  });

  final int count;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back to incident dashboard',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incident Activity',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                '$count ${count == 1 ? 'activity' : 'activities'} recorded',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh activity',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final IncidentDashboardStats stats;
  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Total this term',
        stats.total,
        Icons.warning_amber_rounded,
        AppColors.blue,
        stats.totalChange,
      ),
      (
        'Critical / High',
        stats.criticalOrHigh,
        Icons.error_outline_rounded,
        AppColors.red,
        '',
      ),
      (
        'Open / Pending',
        stats.openOrPending,
        Icons.schedule_rounded,
        AppColors.amber,
        '',
      ),
      (
        'Resolved',
        stats.resolved,
        Icons.check_circle_outline_rounded,
        const Color(0xFF22A06B),
        '',
      ),
      (
        'Students involved',
        stats.studentsInvolved,
        Icons.groups_2_outlined,
        AppColors.green,
        '',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        final itemWidth = (constraints.maxWidth - ((count - 1) * 12)) / count;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: itemWidth / 132,
          children: cards
              .map(
                (item) => _StatCard(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                  color: item.$4,
                  delta: item.$5,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.delta,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String delta;
  @override
  Widget build(BuildContext context) => Card(
    color: Color.alphaBlend(color.withValues(alpha: .035), Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color.withValues(alpha: .18)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (delta.isNotEmpty)
                Text(
                  delta,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({required this.stats});
  final IncidentDashboardStats stats;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 820) {
        return Column(
          children: [
            _BreakdownCard(
              title: 'By incident type',
              items: stats.typeBreakdown,
            ),
            const SizedBox(height: 12),
            _TrendCard(items: stats.weeklyTrend),
            const SizedBox(height: 12),
            _BreakdownCard(
              title: 'By severity',
              items: stats.severityBreakdown,
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              height: 372,
              child: _BreakdownCard(
                title: 'By incident type',
                items: stats.typeBreakdown,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                _TrendCard(items: stats.weeklyTrend),
                const SizedBox(height: 14),
                _BreakdownCard(
                  title: 'By severity',
                  items: stats.severityBreakdown,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.items});
  final String title;
  final List<IncidentBreakdown> items;
  Color get _accent => title.toLowerCase().contains('severity')
      ? AppColors.amber
      : AppColors.blue;

  @override
  Widget build(BuildContext context) => Card(
    color: Color.alphaBlend(_accent.withValues(alpha: .018), Colors.white),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const _EmptyCardState(
              icon: Icons.donut_small_rounded,
              title: 'No breakdown available',
              message:
                  'Incident categories will appear here after the first report.',
            )
          else
            ...items
                .take(7)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            _label(item.key),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: item.percentage / 100,
                              minHeight: 8,
                              color: _breakdownColor(item.key, _accent),
                              backgroundColor: _breakdownColor(
                                item.key,
                                _accent,
                              ).withValues(alpha: .1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${item.count}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    ),
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.items});
  final List<IncidentTrend> items;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<int>(
      1,
      (value, item) => item.count > value ? item.count : value,
    );
    return Card(
      color: Color.alphaBlend(
        AppColors.green.withValues(alpha: .018),
        Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 18,
                  color: AppColors.green,
                ),
                SizedBox(width: 7),
                Text(
                  'Weekly trend',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const _EmptyCardState(
                icon: Icons.monitor_heart_outlined,
                title: 'No trend data yet',
                message:
                    'Weekly activity will build as incidents are reported.',
              )
            else
              SizedBox(
                height: 125,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: items
                      .map(
                        (item) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.count}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 75 * item.count / max + 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.green,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IncidentListCard extends StatelessWidget {
  const _IncidentListCard({
    required this.page,
    required this.search,
    required this.severity,
    required this.status,
    required this.onSearch,
    required this.onSeverity,
    required this.onStatus,
    required this.onOpen,
    required this.showAll,
    required this.onToggleView,
    required this.onPage,
  });
  final IncidentPage page;
  final String search;
  final String severity;
  final String status;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSeverity;
  final ValueChanged<String> onStatus;
  final ValueChanged<IncidentRecord> onOpen;
  final bool showAll;
  final VoidCallback onToggleView;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final query = search.toLowerCase();
    final filteredItems = page.items
        .where(
          (item) =>
              query.isEmpty ||
              item.incidentId.toLowerCase().contains(query) ||
              item.title.toLowerCase().contains(query) ||
              (item.primaryStudent?.name.toLowerCase().contains(query) ??
                  false),
        )
        .toList();
    final items = showAll
        ? filteredItems
        : filteredItems.take(5).toList(growable: false);
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      showAll ? 'All incidents' : 'Recent incidents',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${page.totalElements} records',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onToggleView,
                      icon: Icon(
                        showAll
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(showAll ? 'Show recent' : 'View all'),
                    ),
                  ],
                ),
                if (showAll) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: onSearch,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search student or incident…',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Filter(
                        value: severity,
                        hint: 'All severity',
                        values: const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
                        onChanged: onSeverity,
                      ),
                      const SizedBox(width: 10),
                      _Filter(
                        value: status,
                        hint: 'All status',
                        values: const [
                          'REPORTED',
                          'OPEN',
                          'IN_PROGRESS',
                          'ESCALATED',
                          'RESOLVED',
                          'CLOSED',
                          'REOPENED',
                        ],
                        onChanged: onStatus,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 34),
              child: _EmptyCardState(
                icon: Icons.health_and_safety_outlined,
                title: 'No incidents to display',
                message:
                    'New incident reports will appear here. Adjust the filters if you are looking for an older record.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 780) {
                  return Column(
                    children: items
                        .map(
                          (item) => _IncidentTile(
                            item: item,
                            onTap: () => onOpen(item),
                          ),
                        )
                        .toList(),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Severity')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Reported by')),
                      ],
                      rows: items
                          .map(
                            (item) => DataRow(
                              onSelectChanged: (_) => onOpen(item),
                              cells: [
                                DataCell(
                                  Text(
                                    item.incidentId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(item.primaryStudent?.name ?? '—'),
                                ),
                                DataCell(
                                  _Pill(
                                    text: item.incidentTypeName,
                                    color: AppColors.green,
                                  ),
                                ),
                                DataCell(
                                  _Pill(
                                    text: _label(item.severity),
                                    color: _severityColor(item.severity),
                                  ),
                                ),
                                DataCell(Text(_formatDate(item.incidentDate))),
                                DataCell(
                                  _Pill(
                                    text: _label(item.status),
                                    color: _statusColor(item.status),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.reportedByName.isEmpty
                                        ? '—'
                                        : item.reportedByName,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          if (showAll) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Page ${page.page + 1} of ${page.totalPages == 0 ? 1 : page.totalPages}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: page.page > 0
                        ? () => onPage(page.page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: page.page + 1 < page.totalPages
                        ? () => onPage(page.page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.item, required this.onTap});
  final IncidentRecord item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: AppColors.greenSoft,
      child: Text(
        _initials(item.primaryStudent?.name ?? item.title),
        style: const TextStyle(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    title: Text(
      item.primaryStudent?.name ?? item.title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${item.incidentId} · ${item.incidentTypeName} · ${_formatDate(item.incidentDate)}',
    ),
    trailing: _Pill(
      text: _label(item.status),
      color: _statusColor(item.status),
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.value,
    required this.hint,
    required this.values,
    required this.onChanged,
  });
  final String value;
  final String hint;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButton<String>(
    value: value,
    hint: Text(hint),
    underline: const SizedBox.shrink(),
    items: ['', ...values]
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item.isEmpty ? hint : _label(item)),
          ),
        )
        .toList(),
    onChanged: (value) => onChanged(value ?? ''),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.items,
    this.onViewAll,
    this.showAll = false,
  });
  final List<IncidentActivity> items;
  final VoidCallback? onViewAll;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final recentItems = [...items]
      ..sort(
        (a, b) => (b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final visibleItems = showAll ? recentItems : recentItems.take(5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    showAll ? 'All activity' : 'Recent activity',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (!showAll && onViewAll != null)
                  TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: Text('View all (${items.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const _EmptyCardState(
                icon: Icons.history_toggle_off_rounded,
                title: 'No recent activity',
                message:
                    'Status changes and new reports will be recorded here.',
              )
            else
              ...visibleItems.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.greenSoft,
                    child: Icon(
                      Icons.history_rounded,
                      color: AppColors.green,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${item.incidentId} · ${item.description}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${item.performedBy} · ${item.occurredAt == null ? '' : _dateTime(item.occurredAt!)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class IncidentDetailView extends StatefulWidget {
  const IncidentDetailView({
    super.key,
    required this.api,
    required this.initial,
    required this.onBack,
  });
  final IncidentApiClient api;
  final IncidentRecord initial;
  final VoidCallback onBack;
  @override
  State<IncidentDetailView> createState() => _IncidentDetailViewState();
}

class _IncidentDetailViewState extends State<IncidentDetailView> {
  late IncidentRecord _incident;
  List<IncidentRecord> _related = const [];
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _incident = widget.initial;
    _loadRelated();
  }

  Future<void> _mutate(Future<IncidentRecord> future) async {
    setState(() => _saving = true);
    try {
      final value = await future;
      if (mounted) {
        setState(() => _incident = value);
        _loadRelated();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
              label: const Text('Incidents'),
            ),
            const Text(
              '/',
              style: TextStyle(color: AppColors.border, fontSize: 20),
            ),
            Text(
              _incident.incidentId,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (_saving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            OutlinedButton.icon(
              onPressed: _exportSummary,
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Export PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _editIncident,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                backgroundColor: const Color(0xFFFFF5F5),
              ),
              onPressed: _escalate,
              icon: const Icon(Icons.warning_amber_rounded, size: 17),
              label: const Text('Escalate'),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final main = _detailMain();
            final side = _detailSide();
            return ListView(
              padding: EdgeInsets.all(constraints.maxWidth < 700 ? 14 : 20),
              children: constraints.maxWidth >= 980
                  ? [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 16),
                          SizedBox(width: 310, child: side),
                        ],
                      ),
                    ]
                  : [main, const SizedBox(height: 14), side],
            );
          },
        ),
      ),
    ],
  );

  Widget _detailMain() => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_incident.incidentId} · ${_dateTime(_incident.incidentDate)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                _incident.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    text: _label(_incident.severity),
                    color: _severityColor(_incident.severity),
                  ),
                  _Pill(
                    text: _label(_incident.status),
                    color: _statusColor(_incident.status),
                  ),
                  _Pill(
                    text: _incident.incidentTypeName,
                    color: AppColors.green,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _incident.location,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                  border: const Border(
                    left: BorderSide(color: AppColors.green, width: 3),
                  ),
                ),
                child: Text(
                  _incident.description,
                  style: const TextStyle(height: 1.55),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _PeopleCard(
        incident: _incident,
        onAdd: _addPerson,
        onRemove: (person) {
          if (person.involvementId != null) {
            _mutate(
              widget.api.removePerson(
                _incident.incidentId,
                person.involvementId!,
              ),
            );
          }
        },
      ),
      const SizedBox(height: 14),
      _ActionsCard(
        incident: _incident,
        onAdd: _addAction,
        onEdit: _editAction,
        onRemove: (action) {
          if (action.actionId != null) {
            _mutate(
              widget.api.removeAction(_incident.incidentId, action.actionId!),
            );
          }
        },
      ),
      const SizedBox(height: 14),
      _TimelineCard(
        incident: _incident,
        onSearchMentions: widget.api.searchMentions,
        onPost: (note, type, parentUpdateId, mentions) => _mutate(
          widget.api.addComment(
            _incident.incidentId,
            note,
            type,
            parentUpdateId: parentUpdateId,
            mentions: mentions,
          ),
        ),
      ),
    ],
  );

  Widget _detailSide() => Column(
    children: [
      _MetaCard(incident: _incident),
      const SizedBox(height: 14),
      _StatusProgressCard(incident: _incident, onChange: _changeStatus),
      const SizedBox(height: 14),
      _NotificationCard(incident: _incident, onEdit: _editIncident),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Follow-up',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _incident.followUpRequired
                        ? Icons.schedule_rounded
                        : Icons.check_rounded,
                    color: _incident.followUpRequired
                        ? AppColors.amber
                        : AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _incident.followUpRequired
                          ? 'Follow-up required'
                          : 'No follow-up required',
                    ),
                  ),
                ],
              ),
              if (_incident.followUpNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _incident.followUpNotes,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _RelatedIncidentsCard(
        student: _incident.primaryStudent,
        incidents: _related,
        onOpen: (incident) async {
          await _mutate(widget.api.getIncident(incident.incidentId));
        },
      ),
    ],
  );

  void _exportSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The backend does not currently expose a PDF export endpoint.',
        ),
      ),
    );
  }

  Future<void> _loadRelated() async {
    final personId = _incident.primaryStudent?.personId ?? '';
    if (personId.isEmpty) {
      if (mounted) setState(() => _related = const []);
      return;
    }
    try {
      final value = await widget.api.getRelatedIncidents(
        _incident.incidentId,
        personId,
      );
      if (mounted && (_incident.primaryStudent?.personId ?? '') == personId) {
        setState(() => _related = value);
      }
    } catch (_) {
      if (mounted) setState(() => _related = const []);
    }
  }

  Future<void> _editIncident() async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditIncidentDialog(incident: _incident),
    );
    if (body != null) {
      await _mutate(widget.api.update(_incident.incidentId, body));
    }
  }

  Future<void> _escalate() async {
    final result = await showDialog<_EscalationResult>(
      context: context,
      builder: (_) => _EscalationDialog(
        incident: _incident,
        onSearchStaff: (query) async {
          final matches = await widget.api.searchMentions(query);
          return matches
              .where((mention) => !mention.isStudent)
              .toList(growable: false);
        },
      ),
    );
    if (result == null) return;
    await _mutate(
      widget.api.escalate(
        _incident.incidentId,
        severity: result.severity,
        escalatedBy: _incident.reportedByStaffId.isEmpty
            ? _incident.reportedByName
            : _incident.reportedByStaffId,
        escalatedTo: result.escalatedTo,
        reason: result.reason,
      ),
    );
  }

  Future<void> _changeStatus(String status) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mark as ${_label(status)}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Status note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (note != null) {
      _mutate(widget.api.updateStatus(_incident.incidentId, status, note));
    }
  }

  Future<void> _addPerson() async {
    final roles = await widget.api.getReference('involvement-roles');
    if (!mounted) return;
    final person = await showDialog<IncidentPerson>(
      context: context,
      builder: (_) => _PersonDialog(
        roles: roles,
        onSearchPeople: widget.api.searchMentions,
      ),
    );
    if (person != null) {
      _mutate(widget.api.addPerson(_incident.incidentId, person));
    }
  }

  Future<void> _addAction() async {
    final types = await widget.api.getReference('action-types');
    if (!mounted) return;
    final result = await showDialog<(IncidentLookup, String)>(
      context: context,
      builder: (_) => _ActionDialog(types: types),
    );
    if (result != null) {
      _mutate(
        widget.api.addAction(
          _incident.incidentId,
          type: result.$1,
          description: result.$2,
        ),
      );
    }
  }

  Future<void> _editAction(IncidentAction action) async {
    if (action.actionId == null) return;
    final types = await widget.api.getReference('action-types');
    if (!mounted) return;
    final result = await showDialog<(IncidentLookup, String)>(
      context: context,
      builder: (_) => _ActionDialog(types: types, source: action),
    );
    if (result != null) {
      _mutate(
        widget.api.updateAction(
          _incident.incidentId,
          actionId: action.actionId!,
          type: result.$1,
          description: result.$2,
        ),
      );
    }
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.incident,
    required this.onAdd,
    required this.onRemove,
  });
  final IncidentRecord incident;
  final VoidCallback onAdd;
  final ValueChanged<IncidentPerson> onRemove;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'People involved',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add person'),
              ),
            ],
          ),
          if (incident.people.isEmpty)
            const Text(
              'No people have been added.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...incident.people.map(
              (person) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.green,
                      child: Text(
                        _initials(person.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            person.subtitle,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Pill(text: person.roleName, color: AppColors.green),
                    IconButton(
                      onPressed: () => onRemove(person),
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.incident,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });
  final IncidentRecord incident;
  final VoidCallback onAdd;
  final ValueChanged<IncidentAction> onEdit;
  final ValueChanged<IncidentAction> onRemove;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actions taken',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Add action'),
              ),
            ],
          ),
          if (incident.actions.isEmpty)
            const Text(
              'No actions recorded.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...incident.actions.map(
              (action) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.greenSoft,
                  child: Icon(Icons.check_rounded, color: AppColors.green),
                ),
                title: Text(
                  action.actionTypeName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (action.description.isNotEmpty) Text(action.description),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Recorded${action.takenBy.isEmpty ? '' : ' by ${action.takenBy}'}',
                        action.takenAt == null
                            ? 'Time unavailable'
                            : _dateTime(action.takenAt!),
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (action.updatedAt != null &&
                        (action.takenAt == null ||
                            action.updatedAt != action.takenAt))
                      Text(
                        'Updated${action.updatedBy.isEmpty ? '' : ' by ${action.updatedBy}'} · ${_dateTime(action.updatedAt!)}',
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                trailing: action.actionId == null
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Action options',
                        onSelected: (value) {
                          if (value == 'edit') onEdit(action);
                          if (value == 'remove') onRemove(action);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_outlined, size: 18),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.red,
                              ),
                              title: Text('Remove'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _TimelineCard extends StatefulWidget {
  const _TimelineCard({
    required this.incident,
    required this.onPost,
    required this.onSearchMentions,
  });
  final IncidentRecord incident;
  final void Function(String, String, String?, List<IncidentMention>) onPost;
  final Future<List<IncidentMention>> Function(String) onSearchMentions;
  @override
  State<_TimelineCard> createState() => _TimelineCardState();
}

class _TimelineCardState extends State<_TimelineCard> {
  final _controller = TextEditingController();
  final _composerKey = GlobalKey();
  final _composerFocus = FocusNode();
  String _type = 'INTERNAL_NOTE';
  IncidentUpdate? _replyingTo;
  Timer? _mentionDebounce;
  List<IncidentMention> _mentionResults = const [];
  bool _searchingMentions = false;
  String? _mentionQuery;
  final List<IncidentMention> _selectedMentions = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleMentionInput);
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _controller
      ..removeListener(_handleMentionInput)
      ..dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _startReply(IncidentUpdate update) {
    setState(() {
      _replyingTo = update;
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = _composerKey.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: .75,
        );
      }
      if (mounted) _composerFocus.requestFocus();
    });
  }

  void _handleMentionInput() {
    final selection = _controller.selection;
    if (!selection.isValid) return;
    final beforeCursor = _controller.text.substring(0, selection.baseOffset);
    final match = RegExp(r'(?:^|\s)@([^@\n]*)$').firstMatch(beforeCursor);
    final query = match?.group(1)?.trim();
    _mentionDebounce?.cancel();
    if (query == null) {
      if (_mentionResults.isNotEmpty || _mentionQuery != null) {
        setState(() {
          _mentionResults = const [];
          _mentionQuery = null;
          _searchingMentions = false;
        });
      }
      return;
    }
    setState(() {
      _mentionQuery = query;
      _searchingMentions = query.length >= 2;
      if (query.length < 2) _mentionResults = const [];
    });
    if (query.length < 2) return;
    _mentionDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.onSearchMentions(query);
      if (!mounted || _mentionQuery != query) return;
      setState(() {
        _mentionResults = results;
        _searchingMentions = false;
      });
    });
  }

  void _insertMention(IncidentMention mention) {
    final cursor = _controller.selection.baseOffset;
    final before = _controller.text.substring(0, cursor);
    final after = _controller.text.substring(cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final replacement = '@${mention.name} ';
    _controller.value = TextEditingValue(
      text: '${before.substring(0, at)}$replacement$after',
      selection: TextSelection.collapsed(offset: at + replacement.length),
    );
    setState(() {
      if (!_selectedMentions.any(
        (item) =>
            item.id == mention.id && item.personType == mention.personType,
      )) {
        _selectedMentions.add(mention);
      }
      _mentionQuery = null;
      _mentionResults = const [];
    });
  }

  List<Widget> _buildThreads() {
    final updates = widget.incident.updates;
    final knownIds = updates.map((update) => update.updateId).toSet();
    final children = <String, List<IncidentUpdate>>{};
    final roots = <IncidentUpdate>[];
    for (final update in updates) {
      if (update.parentUpdateId.isEmpty ||
          !knownIds.contains(update.parentUpdateId)) {
        roots.add(update);
      } else {
        children.putIfAbsent(update.parentUpdateId, () => []).add(update);
      }
    }
    roots.sort((a, b) => _updateTime(b).compareTo(_updateTime(a)));
    for (final replies in children.values) {
      replies.sort((a, b) => _updateTime(a).compareTo(_updateTime(b)));
    }
    return roots.map((update) => _threadNode(update, children, 0)).toList();
  }

  DateTime _updateTime(IncidentUpdate update) =>
      update.updateDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);

  Widget _threadNode(
    IncidentUpdate update,
    Map<String, List<IncidentUpdate>> children,
    int depth,
  ) {
    final replies = children[update.updateId] ?? const <IncidentUpdate>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _updateTile(update, isReply: depth > 0),
          if (replies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 25, top: 7),
              padding: const EdgeInsets.only(left: 14),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFB8E3DC), width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (depth == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 14,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...replies.map(
                    (reply) => _threadNode(reply, children, depth + 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _updateTile(IncidentUpdate update, {required bool isReply}) {
    final systemEvent =
        update.type == 'STATUS_CHANGE' || update.type == 'ESCALATION';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 13 : 15,
          backgroundColor: _updateColor(update.type).withValues(alpha: .12),
          child: Icon(
            isReply ? Icons.reply_rounded : _updateIcon(update.type),
            color: _updateColor(update.type),
            size: isReply ? 13 : 15,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: systemEvent
                  ? _updateColor(update.type).withValues(alpha: .07)
                  : isReply
                  ? const Color(0xFFF8FBFB)
                  : Colors.white,
              border: Border.all(
                color: systemEvent
                    ? _updateColor(update.type).withValues(alpha: .35)
                    : isReply
                    ? const Color(0xFFCFE5E1)
                    : AppColors.border,
                width: systemEvent ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            update.updatedBy.isEmpty
                                ? 'System'
                                : update.updatedBy,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (isReply)
                            const Text(
                              'replied',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          _Pill(
                            text: _label(update.type),
                            color: _updateColor(update.type),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      update.updateDateTime == null
                          ? 'Time unavailable'
                          : _dateTime(update.updateDateTime!),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(update.note),
                if (!systemEvent && update.updateId.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _startReply(update),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                    ),
                    icon: const Icon(Icons.reply_rounded, size: 15),
                    label: const Text('Reply'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline & comments',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ..._buildThreads(),
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.updatedBy.isEmpty ? 'comment' : _replyingTo!.updatedBy}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          TextField(
            key: _composerKey,
            controller: _controller,
            focusNode: _composerFocus,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Add an update or comment… Use @ to mention someone',
            ),
          ),
          if (_mentionQuery != null)
            Container(
              constraints: const BoxConstraints(maxHeight: 230),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _mentionQuery!.length < 2
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Type at least 2 letters after @',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : _searchingMentions
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _mentionResults.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No matching students or staff',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: _mentionResults.map((mention) {
                        final color = mention.isStudent
                            ? AppColors.blue
                            : AppColors.purple;
                        return ListTile(
                          dense: true,
                          onTap: () => _insertMention(mention),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: color.withValues(alpha: .12),
                            child: Icon(
                              mention.isStudent
                                  ? Icons.school_outlined
                                  : Icons.badge_outlined,
                              color: color,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            mention.name,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(mention.subtitle),
                          trailing: _Pill(
                            text: mention.isStudent ? 'Student' : 'Staff',
                            color: color,
                          ),
                        );
                      }).toList(),
                    ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              DropdownButton<String>(
                value: _type,
                items:
                    const [
                          'INTERNAL_NOTE',
                          'PARENT_COMMUNICATION',
                          'STAFF_NOTE',
                        ]
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_label(item)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  final activeMentions = _selectedMentions
                      .where((mention) => text.contains('@${mention.name}'))
                      .toList(growable: false);
                  widget.onPost(
                    text,
                    _type,
                    _replyingTo?.updateId,
                    activeMentions,
                  );
                  _controller.clear();
                  setState(() {
                    _replyingTo = null;
                    _selectedMentions.clear();
                  });
                },
                child: const Text('Post comment'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.incident});
  final IncidentRecord incident;
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('ID', incident.incidentId),
      ('Date', _dateTime(incident.incidentDate)),
      ('Location', incident.location),
      ('Reported by', incident.reportedByName),
      ('Status', _label(incident.status)),
      ('Severity', _label(incident.severity)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incident details',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.$1.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusProgressCard extends StatelessWidget {
  const _StatusProgressCard({required this.incident, required this.onChange});

  final IncidentRecord incident;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'REPORTED',
      'OPEN',
      'IN_PROGRESS',
      'ESCALATED',
      'RESOLVED',
      'CLOSED',
      'REOPENED',
    ];
    final index = statuses.indexOf(incident.status);
    final progress = switch (incident.status) {
      'REPORTED' => .15,
      'OPEN' => .3,
      'IN_PROGRESS' => .55,
      'ESCALATED' => .75,
      'RESOLVED' => .9,
      'CLOSED' => 1.0,
      _ => .35,
    };
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailCardHeader(title: 'Update status'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: index < 0 ? 'REPORTED' : incident.status,
                        isDense: true,
                        items: statuses
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(_label(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null && value != incident.status) {
                            onChange(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedIncidentsCard extends StatelessWidget {
  const _RelatedIncidentsCard({
    required this.student,
    required this.incidents,
    required this.onOpen,
  });
  final IncidentPerson? student;
  final List<IncidentRecord> incidents;
  final ValueChanged<IncidentRecord> onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailCardHeader(
          title: 'Related incidents',
          trailing: student == null ? null : 'Same student',
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: incidents.isEmpty
              ? _EmptyCardState(
                  icon: Icons.link_off_rounded,
                  title: 'No related incidents',
                  message: student == null
                      ? 'Add a student to compare this case with their incident history.'
                      : 'No other incidents are linked to ${student!.name}.',
                )
              : Column(
                  children: incidents
                      .map(
                        (incident) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: () => onOpen(incident),
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.greenSoft,
                            child: Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: AppColors.green,
                            ),
                          ),
                          title: Text(
                            incident.incidentId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${incident.incidentTypeName} · ${_label(incident.severity)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}

class _DetailCardHeader extends StatelessWidget {
  const _DetailCardHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.incident, required this.onEdit});
  final IncidentRecord incident;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Parent / guardian', incident.parentNotified),
      ('Class teacher', incident.classTeacherNotified),
      ('Counselor', incident.counselorNotified),
      ('Headmaster', incident.headmasterNotified),
    ];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailCardHeader(title: 'Notifications', trailing: 'Edit'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...rows.map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: onEdit,
                    title: Text(row.$1),
                    trailing: Icon(
                      row.$2
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: row.$2 ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditIncidentDialog extends StatefulWidget {
  const _EditIncidentDialog({required this.incident});
  final IncidentRecord incident;

  @override
  State<_EditIncidentDialog> createState() => _EditIncidentDialogState();
}

class _EditIncidentDialogState extends State<_EditIncidentDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _followUpNotes;
  late String _severity;
  late bool _parent;
  late bool _teacher;
  late bool _counselor;
  late bool _headmaster;
  late bool _followUp;
  late DateTime _followUpDate;

  @override
  void initState() {
    super.initState();
    final incident = widget.incident;
    _title = TextEditingController(text: incident.title);
    _description = TextEditingController(text: incident.description);
    _location = TextEditingController(text: incident.location);
    _followUpNotes = TextEditingController(text: incident.followUpNotes);
    _severity = incident.severity;
    _parent = incident.parentNotified;
    _teacher = incident.classTeacherNotified;
    _counselor = incident.counselorNotified;
    _headmaster = incident.headmasterNotified;
    _followUp = incident.followUpRequired;
    _followUpDate =
        incident.followUpDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _followUpNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Edit ${widget.incident.incidentId}'),
    content: SizedBox(
      width: 580,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _severity = value ?? _severity),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              _dialogSwitch(
                'Parent / guardian',
                _parent,
                (value) => _parent = value,
              ),
              _dialogSwitch(
                'Class teacher',
                _teacher,
                (value) => _teacher = value,
              ),
              _dialogSwitch(
                'Counselor',
                _counselor,
                (value) => _counselor = value,
              ),
              _dialogSwitch(
                'Headmaster',
                _headmaster,
                (value) => _headmaster = value,
              ),
              const Divider(),
              _dialogSwitch(
                'Follow-up required',
                _followUp,
                (value) => _followUp = value,
              ),
              if (_followUp) ...[
                OutlinedButton.icon(
                  onPressed: _pickFollowUpDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                  label: Text('Follow-up: ${_formatDate(_followUpDate)}'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _followUpNotes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up notes',
                  ),
                  validator: _required,
                ),
              ],
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
      FilledButton(onPressed: _save, child: const Text('Save changes')),
    ],
  );

  Widget _dialogSwitch(String label, bool value, ValueChanged<bool> assign) =>
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (next) => setState(() => assign(next)),
      );

  String? _required(String? value) =>
      value?.trim().isEmpty != false ? 'Required' : null;

  Future<void> _pickFollowUpDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _followUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) setState(() => _followUpDate = selected);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.incident.editableJson(
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
        severity: _severity,
        parentNotified: _parent,
        classTeacherNotified: _teacher,
        counselorNotified: _counselor,
        headmasterNotified: _headmaster,
        followUpRequired: _followUp,
        followUpDate: _followUpDate,
        followUpNotes: _followUpNotes.text.trim(),
      ),
    );
  }
}

class _EscalationResult {
  const _EscalationResult({
    required this.severity,
    required this.escalatedTo,
    required this.reason,
  });
  final String severity;
  final String escalatedTo;
  final String reason;
}

class _EscalationDialog extends StatefulWidget {
  const _EscalationDialog({
    required this.incident,
    required this.onSearchStaff,
  });
  final IncidentRecord incident;
  final Future<List<IncidentMention>> Function(String) onSearchStaff;

  @override
  State<_EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<_EscalationDialog> {
  final _form = GlobalKey<FormState>();
  final _to = TextEditingController();
  final _reason = TextEditingController();
  late String _severity;
  Timer? _searchDebounce;
  List<IncidentMention> _staffResults = const [];
  IncidentMention? _selectedStaff;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _severity = switch (widget.incident.severity) {
      'LOW' => 'MEDIUM',
      'MEDIUM' => 'HIGH',
      _ => 'CRITICAL',
    };
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _to.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Escalate ${widget.incident.incidentId}'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: const InputDecoration(labelText: 'New severity'),
              items: const ['MEDIUM', 'HIGH', 'CRITICAL']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_label(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _severity = value ?? _severity),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _to,
              decoration: const InputDecoration(
                labelText: 'Escalate to',
                hintText: 'Search staff by name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _searchStaff,
              validator: (_) =>
                  _selectedStaff == null ? 'Select a staff member' : null,
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_staffResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 210),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _staffResults
                      .map(
                        (staff) => ListTile(
                          dense: true,
                          onTap: () => _selectStaff(staff),
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFF2EAFE),
                            child: Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: AppColors.purple,
                            ),
                          ),
                          title: Text(
                            staff.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            staff.subtitle.isEmpty
                                ? 'Staff'
                                : _label(staff.subtitle),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (_selectedStaff != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2FF),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFD8C5FA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.purple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedStaff!.name} · ${_selectedStaff!.subtitle.isEmpty ? 'Staff' : _label(_selectedStaff!.subtitle)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Escalation note (optional)',
              ),
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
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.warning_amber_rounded, size: 17),
        label: const Text('Escalate'),
      ),
    ],
  );

  void _searchStaff(String value) {
    if (_selectedStaff != null && value != _selectedStaff!.name) {
      _selectedStaff = null;
    }
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _staffResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.onSearchStaff(query);
      if (!mounted || _to.text.trim() != query) return;
      setState(() {
        _staffResults = results;
        _searching = false;
      });
    });
  }

  void _selectStaff(IncidentMention staff) {
    setState(() {
      _selectedStaff = staff;
      _staffResults = const [];
      _to.text = staff.name;
      _to.selection = TextSelection.collapsed(offset: staff.name.length);
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _EscalationResult(
        severity: _severity,
        escalatedTo: _selectedStaff!.id,
        reason: _reason.text.trim(),
      ),
    );
  }
}

class _CreateIncidentDialog extends StatefulWidget {
  const _CreateIncidentDialog({
    required this.api,
    required this.schoolId,
    required this.reportedBy,
  });
  final IncidentApiClient api;
  final String schoolId;
  final String reportedBy;
  @override
  State<_CreateIncidentDialog> createState() => _CreateIncidentDialogState();
}

class _CreateIncidentDialogState extends State<_CreateIncidentDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(
    text: 'Bullying reported near the JHS classroom block',
  );
  final _description = TextEditingController(
    text:
        'During the morning break, Kojo Mensah repeatedly pushed and verbally '
        'threatened another JHS 2 student near the classroom corridor. Two '
        'students witnessed the incident, and the class teacher separated the '
        'students before referring the matter to the school administrator.',
  );
  final _location = TextEditingController(text: 'JHS classroom corridor');
  List<IncidentLookup> _types = const [];
  IncidentLookup? _type;
  String _severity = 'HIGH';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _parent = true;
  bool _followUp = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.api
        .getReference('incident-types')
        .then((value) {
          if (mounted) {
            setState(() {
              _types = value;
              if (value.isNotEmpty) _type = value.first;
            });
          }
        })
        .catchError((error) {
          if (mounted) setState(() => _error = '$error');
        });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log new incident'),
    content: SizedBox(
      width: 600,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(_formatDate(_date)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<IncidentLookup>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Incident type'),
                items: _types
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value),
                validator: (value) =>
                    value == null ? 'Select an incident type' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_label(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _severity = value ?? _severity),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Incident title'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Parent notified'),
                value: _parent,
                onChanged: (value) => setState(() => _parent = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Follow-up required'),
                value: _followUp,
                onChanged: (value) => setState(() => _followUp = value),
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
        child: Text(_saving ? 'Saving…' : 'Save incident'),
      ),
    ],
  );

  String? _required(String? value) =>
      value?.trim().isEmpty != false ? 'Required' : null;
  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.api.create({
        'customSchoolId': widget.schoolId,
        'incidentType': '${_type!.id}',
        'severity': _severity,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'incidentDate':
            '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        'incidentTime':
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'location': _location.text.trim(),
        'parentNotified': _parent,
        'classTeacherNotified': false,
        'counselorNotified': false,
        'headmasterNotified': false,
        'followUpRequired': _followUp,
        if (_followUp)
          'followUpDate': _date
              .add(const Duration(days: 7))
              .toIso8601String()
              .substring(0, 10),
        if (_followUp) 'followUpNotes': 'Follow up on this incident.',
        'peopleInvolved': <Map<String, dynamic>>[],
        'actionRecords': <Map<String, dynamic>>[],
        'actionsTaken': <String>[],
      });
      if (mounted) Navigator.pop(context, created);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({required this.roles, required this.onSearchPeople});
  final List<IncidentLookup> roles;
  final Future<List<IncidentMention>> Function(String) onSearchPeople;
  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final id = TextEditingController(),
      name = TextEditingController(),
      subtitle = TextEditingController();
  String type = 'STUDENT';
  IncidentLookup? role;
  Timer? _searchDebounce;
  bool _searching = false;
  List<IncidentMention> _staffResults = const [];
  IncidentMention? _selectedStaff;

  @override
  void initState() {
    super.initState();
    if (widget.roles.isNotEmpty) role = widget.roles.first;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    id.dispose();
    name.dispose();
    subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add person involved'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Person type'),
              items: const ['STUDENT', 'STAFF', 'EXTERNAL']
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_label(item)),
                    ),
                  )
                  .toList(),
              onChanged: _changeType,
            ),
            const SizedBox(height: 10),
            if (type == 'STAFF') ...[
              TextField(
                controller: name,
                onChanged: _searchStaff,
                decoration: const InputDecoration(
                  labelText: 'Search staff',
                  hintText: 'Type staff name or ID',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_staffResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _staffResults
                        .map(
                          (staff) => ListTile(
                            dense: true,
                            onTap: () => _selectStaff(staff),
                            leading: const Icon(
                              Icons.badge_outlined,
                              color: AppColors.purple,
                            ),
                            title: Text(
                              staff.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${staff.id} · ${staff.subtitle.isEmpty ? 'Staff' : _label(staff.subtitle)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (_selectedStaff != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2FF),
                    border: Border.all(color: const Color(0xFFD8C5FA)),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_selectedStaff!.name}\n${_selectedStaff!.id} · ${_selectedStaff!.subtitle.isEmpty ? 'Staff' : _label(_selectedStaff!.subtitle)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ] else if (type == 'EXTERNAL') ...[
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  hintText: 'Enter the person’s full name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subtitle,
                decoration: const InputDecoration(
                  labelText: 'Description or relationship',
                  hintText: 'e.g. Parent, visitor, community member',
                ),
              ),
            ] else ...[
              TextField(
                controller: id,
                decoration: const InputDecoration(labelText: 'Student ID'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subtitle,
                decoration: const InputDecoration(labelText: 'Class'),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<IncidentLookup>(
              value: role,
              decoration: const InputDecoration(labelText: 'Involvement role'),
              items: widget.roles
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => role = value),
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
        onPressed: () {
          if (role == null) return;
          if (type == 'STAFF' && _selectedStaff == null) return;
          if (type == 'EXTERNAL' && name.text.trim().isEmpty) return;
          if (type == 'STUDENT' &&
              (id.text.trim().isEmpty || name.text.trim().isEmpty)) {
            return;
          }
          final personId = switch (type) {
            'STAFF' => _selectedStaff!.id,
            'EXTERNAL' =>
              'EXT-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}',
            _ => id.text.trim(),
          };
          final personName = type == 'STAFF'
              ? _selectedStaff!.name
              : name.text.trim();
          final personSubtitle = type == 'STAFF'
              ? _selectedStaff!.subtitle
              : subtitle.text.trim();
          Navigator.pop(
            context,
            IncidentPerson(
              personId: personId,
              personType: type,
              name: personName,
              subtitle: personSubtitle,
              roleId: role!.id,
              roleName: role!.name,
              avatarColor: '#009688',
            ),
          );
        },
        child: const Text('Add person'),
      ),
    ],
  );

  void _changeType(String? value) {
    if (value == null) return;
    _searchDebounce?.cancel();
    setState(() {
      type = value;
      id.clear();
      name.clear();
      subtitle.clear();
      _selectedStaff = null;
      _staffResults = const [];
      _searching = false;
    });
  }

  void _searchStaff(String value) {
    if (_selectedStaff != null && value != _selectedStaff!.name) {
      _selectedStaff = null;
    }
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _staffResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final matches = await widget.onSearchPeople(query);
      if (!mounted || name.text.trim() != query) return;
      setState(() {
        _staffResults = matches
            .where((person) => !person.isStudent)
            .toList(growable: false);
        _searching = false;
      });
    });
  }

  void _selectStaff(IncidentMention staff) {
    setState(() {
      _selectedStaff = staff;
      _staffResults = const [];
      name.text = staff.name;
      name.selection = TextSelection.collapsed(offset: staff.name.length);
    });
  }
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({required this.types, this.source});
  final List<IncidentLookup> types;
  final IncidentAction? source;
  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  IncidentLookup? type;
  late final TextEditingController description;
  @override
  void initState() {
    super.initState();
    description = TextEditingController(text: widget.source?.description ?? '');
    if (widget.source != null) {
      for (final option in widget.types) {
        if (option.id == widget.source!.actionTypeId ||
            option.name == widget.source!.actionTypeName) {
          type = option;
          break;
        }
      }
    }
    if (type == null && widget.types.isNotEmpty) type = widget.types.first;
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.source == null ? 'Add action taken' : 'Edit action'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<IncidentLookup>(
            value: type,
            decoration: const InputDecoration(labelText: 'Action type'),
            items: widget.types
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => type = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: type == null
            ? null
            : () => Navigator.pop(context, (type!, description.text.trim())),
        child: Text(widget.source == null ? 'Add action' : 'Save changes'),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text.isEmpty ? '—' : text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCardState extends StatelessWidget {
  const _EmptyCardState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.green, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.year}';
String _dateTime(DateTime value) =>
    '${_formatDate(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .where((item) => item.isNotEmpty)
    .take(2)
    .map((item) => item[0].toUpperCase())
    .join();

Color _updateColor(String type) => switch (type) {
  'PARENT_COMMUNICATION' => AppColors.blue,
  'STAFF_NOTE' => AppColors.amber,
  'STATUS_CHANGE' => const Color(0xFF8B5CF6),
  'ESCALATION' => AppColors.red,
  _ => AppColors.green,
};

Color _breakdownColor(String key, Color fallback) =>
    switch (key.toUpperCase()) {
      'CRITICAL' => AppColors.red,
      'HIGH' => const Color(0xFFF97316),
      'MEDIUM' => AppColors.amber,
      'LOW' => const Color(0xFF22A06B),
      _ => fallback,
    };

IconData _updateIcon(String type) => switch (type) {
  'PARENT_COMMUNICATION' => Icons.call_outlined,
  'STAFF_NOTE' => Icons.lock_outline_rounded,
  'STATUS_CHANGE' => Icons.sync_rounded,
  'ESCALATION' => Icons.warning_amber_rounded,
  _ => Icons.chat_bubble_outline_rounded,
};
Color _severityColor(String value) => switch (value) {
  'CRITICAL' => AppColors.red,
  'HIGH' => const Color(0xFFF97316),
  'MEDIUM' => AppColors.amber,
  _ => const Color(0xFF22A06B),
};
Color _statusColor(String value) => switch (value) {
  'ESCALATED' => AppColors.red,
  'IN_PROGRESS' => AppColors.purple,
  'RESOLVED' || 'CLOSED' => const Color(0xFF22A06B),
  _ => AppColors.blue,
};
