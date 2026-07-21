import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/api_dashboard_repository.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';
import '../../admissions/presentation/admissions_screen.dart';
import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/presentation/attendance_dashboard_screen.dart';
import '../../classes/presentation/grade_streams_screen.dart';
import '../../fees/presentation/fee_management_screen.dart';
import '../../settings/presentation/school_settings_screen.dart';
import '../../staff/presentation/staff_screen.dart';
import '../../students/data/api_students_repository.dart';
import '../../students/presentation/students_screen.dart';

enum _SchoolAdminPage {
  dashboard,
  admissions,
  students,
  attendance,
  households,
  staff,
  classes,
  fees,
  calendar,
  settings,
}

class AdministratorDashboard extends StatefulWidget {
  const AdministratorDashboard({
    super.key,
    required this.repository,
    this.schoolId,
    this.schoolName,
    this.userDisplayName,
    this.role,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onLogout,
  });

  final DashboardRepository repository;
  final String? schoolId;
  final String? schoolName;
  final String? userDisplayName;
  final String? role;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onLogout;

  @override
  State<AdministratorDashboard> createState() => _AdministratorDashboardState();
}

class _AdministratorDashboardState extends State<AdministratorDashboard> {
  late Future<DashboardSnapshot> _dashboard;
  bool _sidebarCollapsed = false;
  _SchoolAdminPage _selectedPage = _SchoolAdminPage.dashboard;
  bool _openStartAdmissionOnNextAdmissions = false;
  bool _openRecordPaymentOnNextFees = false;
  bool _openAddEventOnNextCalendar = false;
  bool _openAddStaffOnNextStaff = false;

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

  void _selectPage(_SchoolAdminPage page) {
    setState(() {
      _selectedPage = page;
      if (page == _SchoolAdminPage.dashboard) {
        _dashboard = widget.repository.getAdministratorDashboard(_schoolId);
      }
    });
  }

  void _openStartAdmission() {
    setState(() {
      _openStartAdmissionOnNextAdmissions = true;
      _selectedPage = _SchoolAdminPage.admissions;
    });
  }

  void _openRecordPayment() {
    setState(() {
      _openRecordPaymentOnNextFees = true;
      _selectedPage = _SchoolAdminPage.fees;
    });
  }

  void _openAddCalendarEvent() {
    setState(() {
      _openAddEventOnNextCalendar = true;
      _selectedPage = _SchoolAdminPage.calendar;
    });
  }

  void _openAddStaff() {
    setState(() {
      _openAddStaffOnNextStaff = true;
      _selectedPage = _SchoolAdminPage.staff;
    });
  }

  String get _schoolId {
    return widget.schoolId?.trim() ?? '';
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
                      selectedPage: _selectedPage,
                      onSelectPage: _selectPage,
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
                        selectedPage: _selectedPage,
                        onSelectPage: _selectPage,
                        schoolId: _schoolId,
                        schoolName: widget.schoolName,
                        accessToken: widget.accessToken,
                        onRefreshAccessToken: widget.onRefreshAccessToken,
                        openStartAdmissionOnNextAdmissions:
                            _openStartAdmissionOnNextAdmissions,
                        onStartAdmissionRequestConsumed: () => setState(
                          () => _openStartAdmissionOnNextAdmissions = false,
                        ),
                        openRecordPaymentOnNextFees:
                            _openRecordPaymentOnNextFees,
                        onRecordPaymentRequestConsumed: () => setState(
                          () => _openRecordPaymentOnNextFees = false,
                        ),
                        openAddEventOnNextCalendar: _openAddEventOnNextCalendar,
                        onAddEventRequestConsumed: () =>
                            setState(() => _openAddEventOnNextCalendar = false),
                        openAddStaffOnNextStaff: _openAddStaffOnNextStaff,
                        onAddStaffRequestConsumed: () =>
                            setState(() => _openAddStaffOnNextStaff = false),
                        onStartAdmission: _openStartAdmission,
                        onRecordPayment: _openRecordPayment,
                        onAddCalendarEvent: _openAddCalendarEvent,
                        onAddStaff: _openAddStaff,
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
                  selectedPage: _selectedPage,
                  onSelectPage: (page) {
                    _selectPage(page);
                    Navigator.pop(context);
                  },
                  onLogout: widget.onLogout,
                ),
              ),
              body: _DashboardBody(
                data: data,
                onRefresh: _refresh,
                userDisplayName: widget.userDisplayName,
                showMenu: true,
                selectedPage: _selectedPage,
                onSelectPage: _selectPage,
                schoolId: _schoolId,
                schoolName: widget.schoolName,
                accessToken: widget.accessToken,
                onRefreshAccessToken: widget.onRefreshAccessToken,
                openStartAdmissionOnNextAdmissions:
                    _openStartAdmissionOnNextAdmissions,
                onStartAdmissionRequestConsumed: () =>
                    setState(() => _openStartAdmissionOnNextAdmissions = false),
                openRecordPaymentOnNextFees: _openRecordPaymentOnNextFees,
                onRecordPaymentRequestConsumed: () =>
                    setState(() => _openRecordPaymentOnNextFees = false),
                openAddEventOnNextCalendar: _openAddEventOnNextCalendar,
                onAddEventRequestConsumed: () =>
                    setState(() => _openAddEventOnNextCalendar = false),
                openAddStaffOnNextStaff: _openAddStaffOnNextStaff,
                onAddStaffRequestConsumed: () =>
                    setState(() => _openAddStaffOnNextStaff = false),
                onStartAdmission: _openStartAdmission,
                onRecordPayment: _openRecordPayment,
                onAddCalendarEvent: _openAddCalendarEvent,
                onAddStaff: _openAddStaff,
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
    required this.selectedPage,
    required this.onSelectPage,
    required this.schoolId,
    this.schoolName,
    this.accessToken,
    this.onRefreshAccessToken,
    required this.openStartAdmissionOnNextAdmissions,
    required this.onStartAdmissionRequestConsumed,
    required this.openRecordPaymentOnNextFees,
    required this.onRecordPaymentRequestConsumed,
    required this.openAddEventOnNextCalendar,
    required this.onAddEventRequestConsumed,
    required this.openAddStaffOnNextStaff,
    required this.onAddStaffRequestConsumed,
    required this.onStartAdmission,
    required this.onRecordPayment,
    required this.onAddCalendarEvent,
    required this.onAddStaff,
  });

  final DashboardSnapshot data;
  final VoidCallback onRefresh;
  final String? userDisplayName;
  final bool showMenu;
  final _SchoolAdminPage selectedPage;
  final ValueChanged<_SchoolAdminPage> onSelectPage;
  final String schoolId;
  final String? schoolName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final bool openStartAdmissionOnNextAdmissions;
  final VoidCallback onStartAdmissionRequestConsumed;
  final bool openRecordPaymentOnNextFees;
  final VoidCallback onRecordPaymentRequestConsumed;
  final bool openAddEventOnNextCalendar;
  final VoidCallback onAddEventRequestConsumed;
  final bool openAddStaffOnNextStaff;
  final VoidCallback onAddStaffRequestConsumed;
  final VoidCallback onStartAdmission;
  final VoidCallback onRecordPayment;
  final VoidCallback onAddCalendarEvent;
  final VoidCallback onAddStaff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          data: data,
          showMenu: showMenu,
          userDisplayName: userDisplayName,
        ),
        Expanded(child: _content(context)),
      ],
    );
  }

  Widget _content(BuildContext context) {
    if (selectedPage == _SchoolAdminPage.admissions) {
      return AdmissionsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        openStartAdmissionOnLoad: openStartAdmissionOnNextAdmissions,
        onStartAdmissionRequestConsumed: onStartAdmissionRequestConsumed,
      );
    }

    if (selectedPage == _SchoolAdminPage.households) {
      return HouseholdsGuardiansScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    if (selectedPage == _SchoolAdminPage.students) {
      return StudentsScreen(
        term: data.term,
        academicYear: data.academicYear,
        repository: ApiStudentsRepository(
          customSchoolId: schoolId,
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onOpenHousehold: () => onSelectPage(_SchoolAdminPage.households),
      );
    }

    if (selectedPage == _SchoolAdminPage.attendance) {
      return AttendanceDashboardScreen(
        customSchoolId: schoolId,
        term: data.term,
        academicYear: data.academicYear,
        repository: AttendanceApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
      );
    }

    if (selectedPage == _SchoolAdminPage.staff) {
      return StaffScreen(
        openAddStaffOnLoad: openAddStaffOnNextStaff,
        onAddStaffRequestConsumed: onAddStaffRequestConsumed,
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    if (selectedPage == _SchoolAdminPage.fees) {
      return FeeManagementScreen(
        customSchoolId: schoolId,
        schoolName: schoolName?.trim().isNotEmpty == true
            ? schoolName!.trim()
            : data.schoolName,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        openRecordPaymentOnLoad: openRecordPaymentOnNextFees,
        onRecordPaymentRequestConsumed: onRecordPaymentRequestConsumed,
      );
    }

    if (selectedPage == _SchoolAdminPage.classes) {
      return GradeStreamsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    if (selectedPage == _SchoolAdminPage.calendar) {
      return _SchoolCalendarPage(
        data: data,
        repository: ApiDashboardRepository(
          accessToken: accessToken,
          administratorName: data.administratorName,
          schoolName: schoolName,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        schoolId: schoolId,
        onBack: () => onSelectPage(_SchoolAdminPage.dashboard),
        onRefresh: onRefresh,
        openAddEventOnLoad: openAddEventOnNextCalendar,
        onAddEventRequestConsumed: onAddEventRequestConsumed,
      );
    }

    if (selectedPage == _SchoolAdminPage.settings) {
      return SchoolSettingsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    return RefreshIndicator(
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
                _DashboardGrid(
                  data: data,
                  onOpenAdmissions: () =>
                      onSelectPage(_SchoolAdminPage.admissions),
                  onOpenAttendance: () =>
                      onSelectPage(_SchoolAdminPage.attendance),
                  onOpenFees: () => onSelectPage(_SchoolAdminPage.fees),
                  onOpenCalendar: () => onSelectPage(_SchoolAdminPage.calendar),
                  onStartAdmission: onStartAdmission,
                  onRecordPayment: onRecordPayment,
                  onCreateEvent: onAddCalendarEvent,
                  onAddStaffLater: onAddStaff,
                  onSendAnnouncementLater: () => _showLaterMessage(
                    context,
                    'Send announcement will be connected when Communications is ready.',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLaterMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                [
                  data.termLabel,
                  if (data.termDateRange.isNotEmpty) data.termDateRange,
                ].join(' · '),
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
  const _DashboardGrid({
    required this.data,
    required this.onOpenAdmissions,
    required this.onOpenAttendance,
    required this.onOpenFees,
    required this.onOpenCalendar,
    required this.onStartAdmission,
    required this.onRecordPayment,
    required this.onCreateEvent,
    required this.onAddStaffLater,
    required this.onSendAnnouncementLater,
  });
  final DashboardSnapshot data;
  final VoidCallback onOpenAdmissions;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenFees;
  final VoidCallback onOpenCalendar;
  final VoidCallback onStartAdmission;
  final VoidCallback onRecordPayment;
  final VoidCallback onCreateEvent;
  final VoidCallback onAddStaffLater;
  final VoidCallback onSendAnnouncementLater;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 950;
        if (!wide) {
          return Column(
            children: [
              _AdmissionsCard(
                groups: data.admissions,
                onOpenAdmissions: onOpenAdmissions,
              ),
              const SizedBox(height: 16),
              _AttentionCard(alerts: data.alerts),
              const SizedBox(height: 16),
              _FinanceCard(fees: data.fees, onOpenFees: onOpenFees),
              const SizedBox(height: 16),
              _AttendanceCard(
                attendance: data.attendance,
                onOpenAttendance: onOpenAttendance,
              ),
              const SizedBox(height: 16),
              _QuickActionsCard(
                onStartAdmission: onStartAdmission,
                onRecordPayment: onRecordPayment,
                onAddStaffLater: onAddStaffLater,
                onSendAnnouncementLater: onSendAnnouncementLater,
                onCreateEvent: onCreateEvent,
              ),
              const SizedBox(height: 16),
              _EventsCard(events: data.events, onOpenCalendar: onOpenCalendar),
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
                  _AdmissionsCard(
                    groups: data.admissions,
                    onOpenAdmissions: onOpenAdmissions,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FinanceCard(
                          fees: data.fees,
                          onOpenFees: onOpenFees,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _EventsCard(
                          events: data.events,
                          onOpenCalendar: onOpenCalendar,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _QuickActionsCard(
                    onStartAdmission: onStartAdmission,
                    onRecordPayment: onRecordPayment,
                    onAddStaffLater: onAddStaffLater,
                    onSendAnnouncementLater: onSendAnnouncementLater,
                    onCreateEvent: onCreateEvent,
                  ),
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
                  _AttendanceCard(
                    attendance: data.attendance,
                    onOpenAttendance: onOpenAttendance,
                  ),
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
  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });
  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

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
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Text(
                        action!,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
  const _AdmissionsCard({required this.groups, required this.onOpenAdmissions});
  final List<AdmissionGroup> groups;
  final VoidCallback onOpenAdmissions;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _SectionCard(
        title: 'New admissions this term',
        action: 'View admissions →',
        onAction: onOpenAdmissions,
        child: const _DashboardEmptyState(
          icon: Icons.person_add_alt_1_outlined,
          message: 'No admissions recorded for this term yet.',
        ),
      );
    }

    final maxValue = groups
        .map((item) => item.value)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 31);
    final totalAdmissions = groups.fold<int>(
      0,
      (total, group) => total + group.value,
    );
    return _SectionCard(
      title: 'New admissions this term',
      action: 'View admissions →',
      onAction: onOpenAdmissions,
      child: Column(
        children: [
          SizedBox(
            height: 155,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: groups.map((item) {
                final barHeight = item.value == 0
                    ? 5.0
                    : 24 + (item.value / maxValue * 76);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${item.value}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.value == 0
                                ? AppColors.muted
                                : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: item.value == 0
                                ? AppColors.greenSoft
                                : AppColors.green,
                            borderRadius: const BorderRadius.vertical(
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Total new admissions',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '$totalAdmissions ${totalAdmissions == 1 ? 'student' : 'students'}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
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
      child: alerts.isEmpty
          ? const _DashboardEmptyState(
              icon: Icons.task_alt_rounded,
              message: 'Nothing requires attention right now.',
            )
          : Column(
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
                            if (alert.title.isNotEmpty) ...[
                              Text(
                                alert.title,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              alert.message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
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
  const _FinanceCard({required this.fees, required this.onOpenFees});
  final FeeSummary fees;
  final VoidCallback onOpenFees;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Fee collection',
      action: 'Details →',
      onAction: onOpenFees,
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
  const _AttendanceCard({
    required this.attendance,
    required this.onOpenAttendance,
  });
  final AttendanceSummary attendance;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: "Today's attendance",
      action: 'Full report →',
      onAction: onOpenAttendance,
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
  const _EventsCard({required this.events, required this.onOpenCalendar});
  final List<SchoolEvent> events;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upcoming events',
      action: 'Calendar →',
      onAction: onOpenCalendar,
      child: events.isEmpty
          ? const _DashboardEmptyState(
              icon: Icons.event_available_outlined,
              message: 'No upcoming events have been added.',
            )
          : Column(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
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
                                  event.description.trim().isEmpty
                                      ? 'No description provided'
                                      : event.description.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _eventStyle(
                                        event.category,
                                      ).background,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      _eventTypeLabel(event.category),
                                      style: TextStyle(
                                        color: _eventStyle(
                                          event.category,
                                        ).foreground,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
  const _QuickActionsCard({
    required this.onStartAdmission,
    required this.onRecordPayment,
    required this.onAddStaffLater,
    required this.onSendAnnouncementLater,
    required this.onCreateEvent,
  });

  final VoidCallback onStartAdmission;
  final VoidCallback onRecordPayment;
  final VoidCallback onAddStaffLater;
  final VoidCallback onSendAnnouncementLater;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.person_add_alt_1_rounded, 'Admit student', onStartAdmission),
      (Icons.payments_rounded, 'Receive payment', onRecordPayment),
      (Icons.group_add_rounded, 'Add staff', onAddStaffLater),
      (Icons.campaign_rounded, 'Send announcement', onSendAnnouncementLater),
      (Icons.event_rounded, 'Create event', onCreateEvent),
    ];
    return _SectionCard(
      title: 'Quick actions',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: actions
            .map(
              (action) => OutlinedButton.icon(
                onPressed: action.$3,
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
      child: activities.isEmpty
          ? const _DashboardEmptyState(
              icon: Icons.history_rounded,
              message: 'No recent activity to display.',
            )
          : Column(
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

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.muted, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SchoolCalendarPage extends StatefulWidget {
  const _SchoolCalendarPage({
    required this.data,
    required this.repository,
    required this.schoolId,
    required this.onBack,
    required this.onRefresh,
    this.openAddEventOnLoad = false,
    this.onAddEventRequestConsumed,
  });

  final DashboardSnapshot data;
  final DashboardRepository repository;
  final String schoolId;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool openAddEventOnLoad;
  final VoidCallback? onAddEventRequestConsumed;

  @override
  State<_SchoolCalendarPage> createState() => _SchoolCalendarPageState();
}

class _SchoolCalendarPageState extends State<_SchoolCalendarPage> {
  final TextEditingController _eventSearch = TextEditingController();
  late DateTime _visibleMonth;
  String? _highlightedEventKey;
  bool _showSearchSuggestions = false;
  bool _showPastEvents = false;
  bool _eventActionBusy = false;
  bool _openingAddEventRequest = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    DateTime? initial;
    for (final event in widget.data.calendarEvents) {
      if (!event.endDate.isBefore(_dateOnly(today))) {
        initial = event.startDate;
        break;
      }
    }
    final month = initial ?? today;
    _visibleMonth = DateTime(month.year, month.month);
    _maybeOpenAddEventRequest();
  }

  @override
  void didUpdateWidget(covariant _SchoolCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.openAddEventOnLoad && widget.openAddEventOnLoad) {
      _maybeOpenAddEventRequest();
    }
  }

  void _maybeOpenAddEventRequest() {
    if (!widget.openAddEventOnLoad || _openingAddEventRequest) return;
    _openingAddEventRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onAddEventRequestConsumed?.call();
      if (mounted) await _addEvent();
      _openingAddEventRequest = false;
    });
  }

  @override
  void dispose() {
    _eventSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width < 700 ? 16.0 : 28.0;
    final allEvents = widget.data.calendarEvents;
    final query = _eventSearch.text.trim();
    final isSearching = query.isNotEmpty;
    final matchedEvents = _filteredEvents(allEvents);
    final listEvents = isSearching ? matchedEvents : allEvents;
    final today = _dateOnly(DateTime.now());
    final upcoming =
        listEvents.where((event) => !event.endDate.isBefore(today)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past =
        listEvents.where((event) => event.endDate.isBefore(today)).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarHeader(
            data: widget.data,
            visibleMonth: _visibleMonth,
            onBack: widget.onBack,
            onPrevious: () => setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
              );
            }),
            onNext: () => setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
              );
            }),
            onAddEvent: _eventActionBusy ? null : _addEvent,
          ),
          const SizedBox(height: 14),
          _CalendarSearchBar(
            controller: _eventSearch,
            suggestions: isSearching && _showSearchSuggestions
                ? matchedEvents.take(6).toList()
                : const [],
            showSuggestions: isSearching && _showSearchSuggestions,
            resultCount: matchedEvents.length,
            totalCount: allEvents.length,
            onChanged: () => setState(() {
              _highlightedEventKey = null;
              _showSearchSuggestions = _eventSearch.text.trim().isNotEmpty;
            }),
            onClear: () {
              _eventSearch.clear();
              setState(() {
                _highlightedEventKey = null;
                _showSearchSuggestions = false;
              });
            },
            onSelect: _selectSearchEvent,
          ),
          const SizedBox(height: 14),
          _CalendarGrid(
            visibleMonth: _visibleMonth,
            events: allEvents,
            highlightedEventKey: _highlightedEventKey,
          ),
          const SizedBox(height: 18),
          _CalendarEventList(
            upcoming: upcoming,
            past: past,
            isSearching: isSearching,
            showPastEvents: _showPastEvents,
            onTogglePast: () =>
                setState(() => _showPastEvents = !_showPastEvents),
            onEdit: _eventActionBusy ? null : _editEvent,
            onDelete: _eventActionBusy ? null : _deleteEvent,
          ),
        ],
      ),
    );
  }

  void _selectSearchEvent(SchoolEvent event) {
    FocusScope.of(context).unfocus();
    setState(() {
      _visibleMonth = DateTime(event.startDate.year, event.startDate.month);
      _highlightedEventKey = _calendarEventKey(event);
      _showSearchSuggestions = false;
      _showPastEvents = event.endDate.isBefore(_dateOnly(DateTime.now()));
    });
  }

  List<SchoolEvent> _filteredEvents(List<SchoolEvent> events) {
    final query = _eventSearch.text.trim().toLowerCase();
    if (query.isEmpty) return events;
    return events.where((event) {
      final haystack = [
        event.title,
        event.description,
        event.category,
        _eventTypeLabel(event.category),
        _formatCalendarDate(event.startDate),
        _formatCalendarDate(event.endDate),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  DateTime _defaultEventDate() {
    final today = _dateOnly(DateTime.now());
    if (today.year == _visibleMonth.year &&
        today.month == _visibleMonth.month) {
      return today;
    }
    return DateTime(_visibleMonth.year, _visibleMonth.month);
  }

  Future<void> _addEvent() async {
    try {
      final types = await widget.repository.getCalendarEventTypes();
      if (!mounted) return;
      if (types.isEmpty) {
        _showMessage('Event types could not be loaded.');
        return;
      }
      final payload = await showGeneralDialog<CalendarEventPayload>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Close event editor',
        barrierColor: Colors.black.withValues(alpha: .45),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => Align(
          alignment: Alignment.centerRight,
          child: _CalendarEventEditor(
            eventTypes: types,
            initialDate: _defaultEventDate(),
            academicTermId: widget.data.academicTermId,
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
      );
      if (payload == null || !mounted) return;
      setState(() => _eventActionBusy = true);
      await widget.repository.createCalendarEvent(
        schoolId: widget.schoolId,
        event: payload,
      );
      if (!mounted) return;
      widget.onRefresh();
      _showMessage('Calendar event added.');
    } catch (error) {
      if (mounted) _showMessage('Could not add event. $error');
    } finally {
      if (mounted) setState(() => _eventActionBusy = false);
    }
  }

  Future<void> _editEvent(SchoolEvent event) async {
    if ((event.id ?? '').trim().isEmpty) {
      _showMessage('This event cannot be edited because it has no event ID.');
      return;
    }
    try {
      final types = await widget.repository.getCalendarEventTypes();
      if (!mounted) return;
      if (types.isEmpty) {
        _showMessage('Event types could not be loaded.');
        return;
      }
      final payload = await showGeneralDialog<CalendarEventPayload>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Close event editor',
        barrierColor: Colors.black.withValues(alpha: .45),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => Align(
          alignment: Alignment.centerRight,
          child: _CalendarEventEditor(
            event: event,
            eventTypes: types,
            academicTermId: event.academicTermId ?? widget.data.academicTermId,
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
      );
      if (payload == null || !mounted) return;
      setState(() => _eventActionBusy = true);
      await widget.repository.updateCalendarEvent(
        schoolId: widget.schoolId,
        eventId: event.id!.trim(),
        event: payload,
      );
      if (!mounted) return;
      widget.onRefresh();
      _showMessage('Calendar event updated.');
    } catch (error) {
      if (mounted) _showMessage('Could not update event. $error');
    } finally {
      if (mounted) setState(() => _eventActionBusy = false);
    }
  }

  Future<void> _deleteEvent(SchoolEvent event) async {
    if ((event.id ?? '').trim().isEmpty) {
      _showMessage('This event cannot be deleted because it has no event ID.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete calendar event?'),
        content: Text(
          'This will remove "${event.title}" from the school calendar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _eventActionBusy = true);
    try {
      await widget.repository.deleteCalendarEvent(
        schoolId: widget.schoolId,
        eventId: event.id!.trim(),
      );
      if (!mounted) return;
      widget.onRefresh();
      _showMessage('Calendar event deleted.');
    } catch (error) {
      if (mounted) _showMessage('Could not delete event. $error');
    } finally {
      if (mounted) setState(() => _eventActionBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.data,
    required this.visibleMonth,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onAddEvent,
  });

  final DashboardSnapshot data;
  final DateTime visibleMonth;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 700 ? double.infinity : 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'School Calendar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.termLabel} Academic Year',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 1),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Back'),
        ),
        _CalendarIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
          label: 'Previous month',
        ),
        SizedBox(
          width: 132,
          child: Center(
            child: Text(
              '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _CalendarIconButton(
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
          label: 'Next month',
        ),
        FilledButton.icon(
          onPressed: onAddEvent,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Event'),
        ),
      ],
    );
  }
}

class _CalendarSearchBar extends StatelessWidget {
  const _CalendarSearchBar({
    required this.controller,
    required this.suggestions,
    required this.showSuggestions,
    required this.resultCount,
    required this.totalCount,
    required this.onChanged,
    required this.onClear,
    required this.onSelect,
  });

  final TextEditingController controller;
  final List<SchoolEvent> suggestions;
  final bool showSuggestions;
  final int resultCount;
  final int totalCount;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<SchoolEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSearching = controller.text.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText:
                          'Search events by name, description, type, or date',
                      suffixIcon: isSearching
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: onClear,
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSearching
                        ? AppColors.green.withValues(alpha: .08)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    isSearching
                        ? '$resultCount of $totalCount events'
                        : '$totalCount ${totalCount == 1 ? 'event' : 'events'}',
                    style: TextStyle(
                      color: isSearching ? AppColors.green : AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (showSuggestions) ...[
              const SizedBox(height: 10),
              if (suggestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'No events match your search.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: suggestions
                        .map(
                          (event) => _CalendarSearchSuggestion(
                            event: event,
                            onTap: () => onSelect(event),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarSearchSuggestion extends StatelessWidget {
  const _CalendarSearchSuggestion({required this.event, required this.onTap});

  final SchoolEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.category);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: [
                  Text(
                    event.day,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    event.month,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _eventTypeLabel(event.category),
                style: TextStyle(
                  color: style.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarIconButton extends StatelessWidget {
  const _CalendarIconButton({
    required this.icon,
    required this.onPressed,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          fixedSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.events,
    required this.highlightedEventKey,
  });

  final DateTime visibleMonth;
  final List<SchoolEvent> events;
  final String? highlightedEventKey;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final calendarStart = firstDay.subtract(
      Duration(days: firstDay.weekday % 7),
    );
    final cells = List.generate(
      42,
      (index) => calendarStart.add(Duration(days: index)),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: const [
                _WeekdayLabel('SUN'),
                _WeekdayLabel('MON'),
                _WeekdayLabel('TUE'),
                _WeekdayLabel('WED'),
                _WeekdayLabel('THU'),
                _WeekdayLabel('FRI'),
                _WeekdayLabel('SAT'),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 92,
            ),
            itemBuilder: (context, index) {
              final date = cells[index];
              final dateEvents = events
                  .where((event) => _eventTouchesDate(event, date))
                  .toList();
              return _CalendarDayCell(
                date: date,
                isCurrentMonth: date.month == visibleMonth.month,
                events: dateEvents,
                highlightedEventKey: highlightedEventKey,
              );
            },
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: _CalendarLegend(),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.events,
    required this.highlightedEventKey,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final List<SchoolEvent> events;
  final String? highlightedEventKey;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(2).toList();
    final extra = events.length - visibleEvents.length;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: isCurrentMonth ? AppColors.text : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final event in visibleEvents) ...[
            _CalendarEventPill(
              event: event,
              isHighlighted: highlightedEventKey == _calendarEventKey(event),
            ),
            const SizedBox(height: 4),
          ],
          if (extra > 0)
            Text(
              '+$extra more',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarEventPill extends StatelessWidget {
  const _CalendarEventPill({required this.event, required this.isHighlighted});

  final SchoolEvent event;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.amber.withValues(alpha: .22)
            : style.background,
        borderRadius: BorderRadius.circular(4),
        border: isHighlighted
            ? Border.all(color: AppColors.amber, width: 1.4)
            : null,
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: style.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    const labels = ['Exam', 'Meeting', 'Payment', 'School Event', 'Holiday'];
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: labels.map((label) {
        final style = _eventStyle(label);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: style.foreground.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CalendarEventList extends StatelessWidget {
  const _CalendarEventList({
    required this.upcoming,
    required this.past,
    required this.isSearching,
    required this.showPastEvents,
    required this.onTogglePast,
    required this.onEdit,
    required this.onDelete,
  });

  final List<SchoolEvent> upcoming;
  final List<SchoolEvent> past;
  final bool isSearching;
  final bool showPastEvents;
  final VoidCallback onTogglePast;
  final ValueChanged<SchoolEvent>? onEdit;
  final ValueChanged<SchoolEvent>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  isSearching ? 'Matching Events' : 'Upcoming Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${upcoming.length} ${upcoming.length == 1 ? 'event' : 'events'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const Spacer(),
                if (!isSearching)
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Term Only'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: _DashboardEmptyState(
                icon: Icons.event_busy_rounded,
                message: isSearching
                    ? 'No matching upcoming events.'
                    : 'No upcoming events this term.',
              ),
            )
          else
            ..._groupEvents(upcoming).entries.map(
              (entry) => _CalendarMonthGroup(
                monthLabel: entry.key,
                events: entry.value,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          if (past.isNotEmpty) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onTogglePast,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      showPastEvents
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${showPastEvents ? 'Hide' : 'Show'} past events (${past.length})',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showPastEvents)
              ..._groupEvents(past).entries.map(
                (entry) => _CalendarMonthGroup(
                  monthLabel: entry.key,
                  events: entry.value,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CalendarMonthGroup extends StatelessWidget {
  const _CalendarMonthGroup({
    required this.monthLabel,
    required this.events,
    required this.onEdit,
    required this.onDelete,
  });

  final String monthLabel;
  final List<SchoolEvent> events;
  final ValueChanged<SchoolEvent>? onEdit;
  final ValueChanged<SchoolEvent>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Text(
                monthLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        ...events.map(
          (event) => _CalendarFullEventRow(
            event: event,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

class _CalendarFullEventRow extends StatelessWidget {
  const _CalendarFullEventRow({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolEvent event;
  final ValueChanged<SchoolEvent>? onEdit;
  final ValueChanged<SchoolEvent>? onDelete;

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    event.day,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    event.month,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _eventTypeLabel(event.category),
                style: TextStyle(
                  color: style.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CalendarRowIcon(
              icon: Icons.edit_outlined,
              label: 'Edit event',
              onTap: onEdit == null ? null : () => onEdit!(event),
            ),
            const SizedBox(width: 6),
            _CalendarRowIcon(
              icon: Icons.delete_outline_rounded,
              label: 'Delete event',
              onTap: onDelete == null ? null : () => onDelete!(event),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarRowIcon extends StatelessWidget {
  const _CalendarRowIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? AppColors.muted.withValues(alpha: .45)
                : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _CalendarEventEditor extends StatefulWidget {
  const _CalendarEventEditor({
    this.event,
    required this.eventTypes,
    this.initialDate,
    this.academicTermId,
  });

  final SchoolEvent? event;
  final List<CalendarEventType> eventTypes;
  final DateTime? initialDate;
  final int? academicTermId;

  @override
  State<_CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<_CalendarEventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _eventTypeId;
  late bool _isSchoolDay;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final initialDate = _dateOnly(widget.initialDate ?? DateTime.now());
    _name = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _startDate = event?.startDate ?? initialDate;
    _endDate = event?.endDate ?? initialDate;
    _eventTypeId = _initialEventTypeId();
    _isSchoolDay = event?.isSchoolDay ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  int _initialEventTypeId() {
    final event = widget.event;
    final existingId = event?.eventTypeId;
    if (existingId != null &&
        widget.eventTypes.any((type) => type.id == existingId)) {
      return existingId;
    }
    final category = _eventTypeLabel(event?.category ?? '').toLowerCase();
    for (final type in widget.eventTypes) {
      if (_eventTypeLabel(type.name).toLowerCase() == category ||
          type.name.trim().toLowerCase() ==
              (event?.category ?? '').trim().toLowerCase()) {
        return type.id;
      }
    }
    return widget.eventTypes.first.id;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }
    Navigator.of(context).pop(
      CalendarEventPayload(
        name: _name.text.trim(),
        description: _description.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        eventTypeId: _eventTypeId,
        isSchoolDay: _isSchoolDay,
        academicTermId: widget.academicTermId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isEditing = widget.event != null;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: width < 620 ? width : 440,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit calendar event'
                                : 'Add calendar event',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isEditing
                                ? 'Update event details for the school calendar'
                                : 'Create a new event for the current school term',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Event name',
                            hintText: 'e.g. PTA Meeting',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the event name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _eventTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Event type',
                          ),
                          items: widget.eventTypes
                              .map(
                                (type) => DropdownMenuItem<int>(
                                  value: type.id,
                                  child: Text(_eventTypeLabel(type.name)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _eventTypeId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _CalendarDateField(
                                label: 'Start date',
                                value: _startDate,
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CalendarDateField(
                                label: 'End date',
                                value: _endDate,
                                onTap: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _description,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional short event description',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: _isSchoolDay,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('School day'),
                          subtitle: const Text(
                            'Turn off for holidays and non-teaching days.',
                          ),
                          onChanged: (value) =>
                              setState(() => _isSchoolDay = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(isEditing ? 'Save event' : 'Add event'),
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
  }
}

class _CalendarDateField extends StatelessWidget {
  const _CalendarDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(_formatCalendarDate(value)),
      ),
    );
  }
}

class _EventVisualStyle {
  const _EventVisualStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

_EventVisualStyle _eventStyle(String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.contains('exam') || normalized.contains('assessment')) {
    return _EventVisualStyle(
      AppColors.red,
      AppColors.red.withValues(alpha: .12),
    );
  }
  if (normalized.contains('meeting') || normalized.contains('inspection')) {
    return _EventVisualStyle(
      AppColors.blue,
      AppColors.blue.withValues(alpha: .12),
    );
  }
  if (normalized.contains('payment') || normalized.contains('fee')) {
    return _EventVisualStyle(
      AppColors.amber,
      AppColors.amber.withValues(alpha: .14),
    );
  }
  if (normalized.contains('holiday') || normalized.contains('break')) {
    return _EventVisualStyle(
      AppColors.purple,
      AppColors.purple.withValues(alpha: .12),
    );
  }
  return _EventVisualStyle(
    AppColors.green,
    AppColors.green.withValues(alpha: .12),
  );
}

String _eventTypeLabel(String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.contains('exam') || normalized.contains('assessment')) {
    return 'Exam';
  }
  if (normalized.contains('meeting') || normalized.contains('inspection')) {
    return 'Meeting';
  }
  if (normalized.contains('payment') || normalized.contains('fee')) {
    return 'Payment';
  }
  if (normalized.contains('holiday') || normalized.contains('break')) {
    return 'Holiday';
  }
  return category.trim().isEmpty ? 'School Event' : category.trim();
}

Map<String, List<SchoolEvent>> _groupEvents(List<SchoolEvent> events) {
  final groups = <String, List<SchoolEvent>>{};
  for (final event in events) {
    final key = '${_monthName(event.startDate.month)} ${event.startDate.year}';
    groups.putIfAbsent(key, () => <SchoolEvent>[]).add(event);
  }
  return groups;
}

bool _eventTouchesDate(SchoolEvent event, DateTime date) {
  final day = _dateOnly(date);
  return !day.isBefore(_dateOnly(event.startDate)) &&
      !day.isAfter(_dateOnly(event.endDate));
}

String _calendarEventKey(SchoolEvent event) {
  final id = event.id?.trim();
  if (id != null && id.isNotEmpty) return id;
  return [
    event.title.trim(),
    _formatCalendarDate(event.startDate),
    _formatCalendarDate(event.endDate),
    event.category.trim(),
  ].join('|');
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatCalendarDate(DateTime value) {
  return '${value.day} ${_monthName(value.month).substring(0, 3)} ${value.year}';
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.data,
    this.collapsed = false,
    this.isDrawer = false,
    this.schoolName,
    this.role,
    required this.selectedPage,
    required this.onSelectPage,
    this.onLogout,
    this.onCollapse,
  });
  final DashboardSnapshot data;
  final bool collapsed;
  final bool isDrawer;
  final String? schoolName;
  final String? role;
  final _SchoolAdminPage selectedPage;
  final ValueChanged<_SchoolAdminPage> onSelectPage;
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
                    active: selectedPage == _SchoolAdminPage.dashboard,
                    onTap: () => onSelectPage(_SchoolAdminPage.dashboard),
                  ),
                  _SidebarButton(
                    icon: Icons.assignment_ind_rounded,
                    label: 'Admissions',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.admissions,
                    onTap: () => onSelectPage(_SchoolAdminPage.admissions),
                  ),
                  _SidebarButton(
                    icon: Icons.school_rounded,
                    label: 'Students',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.students,
                    onTap: () => onSelectPage(_SchoolAdminPage.students),
                  ),
                  _SidebarButton(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.attendance,
                    onTap: () => onSelectPage(_SchoolAdminPage.attendance),
                  ),
                  _SidebarButton(
                    icon: Icons.groups_rounded,
                    label: 'Households & Guardians',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.households,
                    onTap: () => onSelectPage(_SchoolAdminPage.households),
                  ),
                  _SidebarButton(
                    icon: Icons.badge_rounded,
                    label: 'Staff Management',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.staff,
                    onTap: () => onSelectPage(_SchoolAdminPage.staff),
                  ),
                  _SidebarButton(
                    icon: Icons.account_tree_rounded,
                    label: 'Classes & Streams',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.classes,
                    onTap: () => onSelectPage(_SchoolAdminPage.classes),
                  ),
                  _SidebarButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Fees & Requirements',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.fees,
                    onTap: () => onSelectPage(_SchoolAdminPage.fees),
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
                    label: 'Settings',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.settings,
                    onTap: () => onSelectPage(_SchoolAdminPage.settings),
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
