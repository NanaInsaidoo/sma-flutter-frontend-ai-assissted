import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

class AdministratorDashboard extends StatefulWidget {
  const AdministratorDashboard({
    super.key,
    required this.repository,
    this.schoolId,
    this.schoolName,
    this.userDisplayName,
    this.role,
    this.onLogout,
  });

  final DashboardRepository repository;
  final String? schoolId;
  final String? schoolName;
  final String? userDisplayName;
  final String? role;
  final VoidCallback? onLogout;

  @override
  State<AdministratorDashboard> createState() => _AdministratorDashboardState();
}

class _AdministratorDashboardState extends State<AdministratorDashboard> {
  late Future<DashboardSnapshot> _dashboard;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repository.getAdministratorDashboard(_schoolId);
  }

  void _refresh() {
    setState(() {
      _dashboard = widget.repository.getAdministratorDashboard(_schoolId);
    });
  }

  String get _schoolId {
    final fromSession = widget.schoolId?.trim() ?? '';
    return fromSession.isEmpty ? 'demo-school' : fromSession;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(onRetry: _refresh);
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.requireData;
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1100;
            if (desktop) {
              return Scaffold(
                body: Row(
                  children: [
                    _Sidebar(
                      data: data,
                      collapsed: _sidebarCollapsed,
                      schoolName: widget.schoolName,
                      role: widget.role,
                      onLogout: widget.onLogout,
                      onCollapse: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                    ),
                    Expanded(
                      child: _DashboardBody(
                        data: data,
                        onRefresh: _refresh,
                        userDisplayName: widget.userDisplayName,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              drawer: Drawer(
                child: _Sidebar(
                  data: data,
                  isDrawer: true,
                  schoolName: widget.schoolName,
                  role: widget.role,
                  onLogout: widget.onLogout,
                ),
              ),
              body: _DashboardBody(
                data: data,
                onRefresh: _refresh,
                userDisplayName: widget.userDisplayName,
                showMenu: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.onRefresh,
    this.userDisplayName,
    this.showMenu = false,
  });

  final DashboardSnapshot data;
  final VoidCallback onRefresh;
  final String? userDisplayName;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          data: data,
          showMenu: showMenu,
          userDisplayName: userDisplayName,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.maxWidth < 650 ? 16.0 : 28.0;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OfflineBanner(lastUpdated: data.lastUpdated),
                      const SizedBox(height: 18),
                      _MetricGrid(metrics: data.metrics),
                      const SizedBox(height: 20),
                      _DashboardGrid(data: data),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.data,
    required this.showMenu,
    this.userDisplayName,
  });
  final DashboardSnapshot data;
  final bool showMenu;
  final String? userDisplayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              'Good morning, ${_displayName(data, userDisplayName)}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 600)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '${data.term} · ${data.academicYear}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 10),
          const _TopIcon(icon: Icons.search_rounded, label: 'Search'),
          const SizedBox(width: 8),
          const _TopIcon(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            hasBadge: true,
          ),
        ],
      ),
    );
  }

  String _displayName(DashboardSnapshot data, String? userDisplayName) {
    final name = userDisplayName?.trim() ?? '';
    return name.isEmpty ? data.administratorName : name;
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.label,
    this.hasBadge = false,
  });
  final IconData icon;
  final String label;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.text),
            if (hasBadge)
              Positioned(
                right: 8,
                top: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.lastUpdated});
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(lastUpdated).format(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF8D99A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_outlined,
            size: 19,
            color: Color(0xFFA96D00),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Views are available offline · Last refreshed today at $time · Changes require internet',
              style: const TextStyle(
                color: Color(0xFF855900),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: .7,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              metric.value,
              style: const TextStyle(
                fontSize: 26,
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              metric.caption,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              metric.change,
              style: TextStyle(
                color: metric.color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.data});
  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 950;
        if (!wide) {
          return Column(
            children: [
              _AdmissionsCard(groups: data.admissions),
              const SizedBox(height: 16),
              _AttentionCard(alerts: data.alerts),
              const SizedBox(height: 16),
              _FinanceCard(fees: data.fees),
              const SizedBox(height: 16),
              _AttendanceCard(attendance: data.attendance),
              const SizedBox(height: 16),
              _QuickActionsCard(),
              const SizedBox(height: 16),
              _EventsCard(events: data.events),
              const SizedBox(height: 16),
              _ActivityCard(activities: data.activities),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _AdmissionsCard(groups: data.admissions),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _FinanceCard(fees: data.fees)),
                      const SizedBox(width: 16),
                      Expanded(child: _EventsCard(events: data.events)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _QuickActionsCard(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _AttentionCard(alerts: data.alerts),
                  const SizedBox(height: 16),
                  _AttendanceCard(attendance: data.attendance),
                  const SizedBox(height: 16),
                  _ActivityCard(activities: data.activities),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (action != null)
                  Text(
                    action!,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _AdmissionsCard extends StatelessWidget {
  const _AdmissionsCard({required this.groups});
  final List<AdmissionGroup> groups;

  @override
  Widget build(BuildContext context) {
    final maxValue = groups
        .map((item) => item.value)
        .reduce((a, b) => a > b ? a : b);
    return _SectionCard(
      title: 'New admissions this term',
      action: 'View admissions →',
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: groups.map((item) {
            final barHeight = 35 + (item.value / maxValue * 85);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${item.value}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: barHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.alerts});
  final List<SchoolAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Attention required',
      action: 'View all →',
      child: Column(
        children: alerts.map((alert) {
          final color = switch (alert.level) {
            AlertLevel.critical => AppColors.red,
            AlertLevel.warning => AppColors.amber,
            AlertLevel.info => AppColors.blue,
          };
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .07),
              border: Border.all(color: color.withValues(alpha: .25)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.message,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.context,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.fees});
  final FeeSummary fees;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Fee collection',
      action: 'Details →',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${(fees.collectionRate * 100).round()}%',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'of billed fees collected',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: fees.collectionRate,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.green,
            backgroundColor: AppColors.greenSoft,
          ),
          const SizedBox(height: 18),
          _MoneyRow(
            label: 'Collected',
            amount: fees.collected,
            color: AppColors.green,
          ),
          _MoneyRow(
            label: 'Outstanding',
            amount: fees.outstanding,
            color: AppColors.red,
          ),
          _MoneyRow(
            label: 'Waivers approved',
            amount: fees.waivers,
            color: AppColors.amber,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Text(
            'GH\u20b5${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.attendance});
  final AttendanceSummary attendance;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: "Today's attendance",
      action: 'Full report →',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(attendance.percentage * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  '${attendance.present} of ${attendance.total} present',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: attendance.percentage,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.green,
            backgroundColor: AppColors.greenSoft,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AttendanceValue(
                  value: attendance.present,
                  label: 'Present',
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceValue(
                  value: attendance.absent,
                  label: 'Absent',
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceValue(
                  value: attendance.late,
                  label: 'Late',
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceValue extends StatelessWidget {
  const _AttendanceValue({
    required this.value,
    required this.label,
    required this.color,
  });
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});
  final List<SchoolEvent> events;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upcoming events',
      action: 'Calendar →',
      child: Column(
        children: events
            .map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          Text(
                            event.day,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            event.month,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            event.category,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.person_add_alt_1_rounded, 'Admit student'),
      (Icons.payments_rounded, 'Receive payment'),
      (Icons.group_add_rounded, 'Add staff'),
      (Icons.campaign_rounded, 'Send announcement'),
      (Icons.event_rounded, 'Create event'),
    ];
    return _SectionCard(
      title: 'Quick actions',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: actions
            .map(
              (action) => OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Internet connection is required to make changes.',
                    ),
                  ),
                ),
                icon: Icon(action.$1, size: 18),
                label: Text(action.$2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities});
  final List<RecentActivity> activities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent activity',
      child: Column(
        children: activities
            .map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.greenSoft,
                      child: Text(
                        activity.initials,
                        style: const TextStyle(
                          color: AppColors.green,
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
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${activity.name} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: activity.detail),
                              ],
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activity.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.data,
    this.collapsed = false,
    this.isDrawer = false,
    this.schoolName,
    this.role,
    this.onLogout,
    this.onCollapse,
  });
  final DashboardSnapshot data;
  final bool collapsed;
  final bool isDrawer;
  final String? schoolName;
  final String? role;
  final VoidCallback? onLogout;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final width = isDrawer
        ? 280.0
        : collapsed
        ? 84.0
        : 250.0;
    final displaySchoolName = _displaySchoolName(data, schoolName);
    final displayRole = _displayRole(role);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: AppColors.navyDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 16 : 20,
                vertical: 18,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displaySchoolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            displayRole,
                            style: const TextStyle(
                              color: Color(0xFF9DA8B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isDrawer)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _SidebarButton(
                  icon: collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  label: 'Collapse',
                  collapsed: collapsed,
                  onTap: onCollapse,
                ),
              ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _SidebarButton(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    collapsed: collapsed,
                    active: true,
                  ),
                  _SidebarButton(
                    icon: Icons.assignment_ind_rounded,
                    label: 'Admissions',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.groups_rounded,
                    label: 'People',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.menu_book_rounded,
                    label: 'Academics',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Finance',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.campaign_rounded,
                    label: 'Communication',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    collapsed: collapsed,
                  ),
                  _SidebarButton(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Administration',
                    collapsed: collapsed,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _SidebarButton(
                icon: Icons.logout_rounded,
                label: 'Log out',
                collapsed: collapsed,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displaySchoolName(DashboardSnapshot data, String? schoolName) {
    final name = schoolName?.trim() ?? '';
    return name.isEmpty ? data.schoolName : name;
  }

  String _displayRole(String? role) {
    final value = role?.trim() ?? '';
    if (value.isEmpty) return 'School Staff';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.collapsed,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: collapsed ? label : '',
        child: Material(
          color: active ? AppColors.green : const Color(0xFF202B3D),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 16 : 14,
                vertical: 13,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (label != 'Dashboard' &&
                        label != 'Log out' &&
                        label != 'Collapse')
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9DA8B8),
                        size: 18,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            const Text('Dashboard data is not available yet.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
