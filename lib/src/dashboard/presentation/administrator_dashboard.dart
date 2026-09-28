import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/dashboard_repository.dart';
import '../data/teacher_dashboard_summary.dart';
import '../data/teacher_workspace_api_client.dart';
import '../domain/dashboard_models.dart';
import '../../admissions/presentation/admissions_screen.dart';
import '../../admissions/data/admissions_api_client.dart';
import '../../approvals/data/approval_api_client.dart';
import '../../approvals/domain/approval_models.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../audit/data/audit_api_client.dart';
import '../../audit/presentation/audit_activity_screen.dart';
import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/presentation/attendance_dashboard_screen.dart';
import '../../assessments/data/assessment_api_client.dart';
import '../../assessments/presentation/assessment_dashboard_screen.dart';
import '../../assessments/presentation/evaluation_management_screen.dart';
import '../../classes/presentation/grade_streams_screen.dart';
import '../../classes/presentation/teacher_classes_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../fees/presentation/fee_management_screen.dart';
import '../../fees/data/fee_api_client.dart';
import '../../fees/domain/fee_models.dart' hide FeeSummary;
import '../../incidents/data/incident_api_client.dart';
import '../../incidents/presentation/incidents_screen.dart';
import '../../settings/presentation/school_settings_screen.dart';
import '../../term_review/presentation/term_review_screen.dart';
import '../../term_review/data/staff_review_api_client.dart';
import '../../term_review/data/teacher_term_review_api_client.dart';
import '../../term_review/data/bursar_term_closure_api_client.dart';
import '../../term_review/data/headmaster_term_closure_api_client.dart';
import '../../term_review/presentation/teacher_term_closing_screen.dart';
import '../../term_review/presentation/bursar_term_closing_screen.dart';
import '../../staff/presentation/staff_screen.dart';
import '../../leave/data/leave_api_client.dart';
import '../../leave/presentation/leave_management_screen.dart';
import '../../staff_attendance/data/staff_attendance_api_client.dart';
import '../../staff_attendance/presentation/staff_attendance_screen.dart';
import '../../students/data/api_students_repository.dart';
import '../../students/domain/student_models.dart';
import '../../students/presentation/students_screen.dart';
import '../../shop/data/shop_api_client.dart';
import '../../shop/presentation/school_shop_screen.dart';
import '../../readiness/data/school_readiness_repository.dart';
import '../../readiness/domain/school_readiness.dart';
import '../../notifications/data/school_notification_api_client.dart';
import '../../notifications/domain/school_notification_models.dart';

enum _SchoolAdminPage {
  dashboard,
  approvals,
  admissions,
  students,
  attendance,
  staffAttendance,
  myLeave,
  leave,
  assessments,
  evaluations,
  finalReports,
  households,
  staff,
  classes,
  fees,
  shop,
  expenses,
  incidents,
  calendar,
  termReview,
  auditActivity,
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
    this.roles = const [],
    this.userId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onLogout,
    this.readinessRepository,
    this.teacherDashboardLoader,
    this.approvalInboxLoader,
  });

  final DashboardRepository repository;
  final String? schoolId;
  final String? schoolName;
  final String? userDisplayName;
  final String? role;
  final List<String> roles;
  final int? userId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onLogout;
  final SchoolReadinessRepository? readinessRepository;
  final Future<TeacherDashboardSummary> Function()? teacherDashboardLoader;
  final Future<ApprovalInbox?> Function()? approvalInboxLoader;

  @override
  State<AdministratorDashboard> createState() => _AdministratorDashboardState();
}

class _AdministratorDashboardState extends State<AdministratorDashboard> {
  Future<DashboardSnapshot>? _dashboard;
  late Future<SchoolReadiness> _readiness;
  late Future<FeeWorkflowSummary?> _feeWorkflowSummary;
  late Future<ApprovalInbox?> _approvalInbox;
  late Future<SchoolNotificationInbox?> _notifications;
  late Future<bool> _shopAccess;
  bool _sidebarCollapsed = false;
  _SchoolAdminPage _selectedPage = _SchoolAdminPage.dashboard;
  bool _openStartAdmissionOnNextAdmissions = false;
  bool _focusStudentSearchOnNextStudents = false;
  String? _studentProfileToOpenId;
  bool _openRecordPaymentOnNextFees = false;
  String? _recordPaymentStudentId;
  bool _openNewRequisitionOnNextExpenses = false;
  bool _openAddEventOnNextCalendar = false;
  bool _openAddStaffOnNextStaff = false;
  bool _openFeeStructureOnNextFees = false;
  int? _assessmentStreamId;
  int? _evaluationStreamId;
  String? _evaluationStreamName;
  int? _teacherClassStreamId;
  bool _selectingTeacherClass = false;
  late String _activeRole;

  @override
  void initState() {
    super.initState();
    _activeRole = _initialRole();
    _dashboard = _loadDashboard();
    _readiness = widget.readinessRepository == null
        ? Future.value(SchoolReadiness.readySchool)
        : widget.readinessRepository!.getReadiness(_schoolId);
    _feeWorkflowSummary = _loadFeeWorkflowSummary();
    _approvalInbox = _loadApprovalInbox();
    _notifications = _loadNotifications();
    _shopAccess = _loadShopAccess();
  }

  @override
  void didUpdateWidget(covariant AdministratorDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_availableRoles.contains(_activeRole)) {
      _activeRole = _initialRole();
      _selectedPage = _SchoolAdminPage.dashboard;
      _dashboard = _loadDashboard();
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
      _notifications = _loadNotifications();
      _shopAccess = _loadShopAccess();
    }
  }

  List<String> get _availableRoles {
    final values = <String>{};
    final primary = widget.role?.trim().toUpperCase() ?? '';
    if (primary.isNotEmpty) values.add(primary);
    values.addAll(
      widget.roles
          .map((role) => role.trim().toUpperCase())
          .where((role) => role.isNotEmpty),
    );
    return values.toList(growable: false);
  }

  String _initialRole() {
    final primary = widget.role?.trim().toUpperCase() ?? '';
    if (primary.isNotEmpty) return primary;
    return _availableRoles.isEmpty ? 'STAFF' : _availableRoles.first;
  }

  void _changeWorkspace(String role) {
    if (role == _activeRole) return;
    setState(() {
      _activeRole = role;
      _selectedPage = _SchoolAdminPage.dashboard;
      _dashboard = _loadDashboard();
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
      _notifications = _loadNotifications();
      _shopAccess = _loadShopAccess();
    });
  }

  Future<bool> _loadShopAccess() async {
    if (_schoolId.isEmpty || widget.accessToken?.isNotEmpty != true) {
      return false;
    }
    try {
      final context = await ShopApiClient(
        schoolId: _schoolId,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).context();
      return context['isAdmin'] == true ||
          context['canSell'] == true ||
          context['canTakePayment'] == true ||
          context['canRelease'] == true ||
          context['canHoldStock'] == true ||
          context['canBuy'] == true ||
          context['canConsign'] == true ||
          context['canReceiveStaffReturns'] == true ||
          context['canIssueRefunds'] == true;
    } catch (_) {
      return false;
    }
  }

  void _refresh() {
    setState(() {
      _dashboard = _loadDashboard();
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
      _notifications = _loadNotifications();
    });
  }

  void _refreshApprovalInbox() {
    if (!mounted) return;
    setState(() {
      _approvalInbox = _loadApprovalInbox();
    });
  }

  void _refreshFeeWorkflowSummary() {
    if (!mounted) return;
    setState(() {
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
      _notifications = _loadNotifications();
    });
  }

  Future<DashboardSnapshot> _loadDashboard() {
    return Future.sync(
      () => widget.repository.getAdministratorDashboard(_schoolId),
    ).then((value) => value);
  }

  Future<FeeWorkflowSummary?> _loadFeeWorkflowSummary() async {
    if (_schoolId.isEmpty || !_canSeeFinancialNotices(_activeRole)) return null;
    try {
      final api = FeeApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
      final term = await api.getCurrentTerm(_schoolId);
      if (term.id <= 0) return null;
      return api.getFeeWorkflowSummary(
        customSchoolId: _schoolId,
        academicTermId: term.id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ApprovalInbox?> _loadApprovalInbox() async {
    if (_schoolId.isEmpty) return null;
    if (widget.approvalInboxLoader != null) {
      return widget.approvalInboxLoader!.call();
    }
    try {
      return await ApprovalApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getInbox(_schoolId);
    } catch (_) {
      return null;
    }
  }

  Future<SchoolNotificationInbox?> _loadNotifications() async {
    if (_schoolId.isEmpty) return null;
    try {
      return await SchoolNotificationApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getInbox(_schoolId);
    } catch (_) {
      return null;
    }
  }

  void _refreshNotifications() {
    if (!mounted) return;
    setState(() => _notifications = _loadNotifications());
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SchoolNotificationsSheet(
        inbox: _notifications,
        schoolId: _schoolId,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
        onChanged: _refreshNotifications,
      ),
    );
  }

  void _selectPage(_SchoolAdminPage page) {
    if (_isTeachingRole(_activeRole) && page == _SchoolAdminPage.assessments) {
      unawaited(_openTeacherScopedPage(page));
      return;
    }
    setState(() {
      _openFeeStructureOnNextFees = false;
      _focusStudentSearchOnNextStudents = false;
      _studentProfileToOpenId = null;
      _openNewRequisitionOnNextExpenses = false;
      _assessmentStreamId = null;
      _evaluationStreamId = null;
      _evaluationStreamName = null;
      _selectedPage = page;
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
      _notifications = _loadNotifications();
      if (page == _SchoolAdminPage.dashboard) {
        _dashboard = _loadDashboard();
        _readiness = widget.readinessRepository == null
            ? Future.value(SchoolReadiness.readySchool)
            : widget.readinessRepository!.getReadiness(_schoolId);
      }
    });
  }

  void _openAssessmentsForStream(int streamId) {
    setState(() {
      _assessmentStreamId = streamId;
      _selectedPage = _SchoolAdminPage.assessments;
    });
  }

  void _openTeacherClass(TeacherClassAssignment assignment) {
    setState(() {
      _teacherClassStreamId = assignment.streamId;
      _selectedPage = _SchoolAdminPage.classes;
    });
  }

  Future<void> _openTeacherScopedPage(_SchoolAdminPage page) async {
    if (_selectingTeacherClass) return;
    _selectingTeacherClass = true;
    try {
      final workspace = await TeacherWorkspaceApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).get(_schoolId);
      if (!mounted) return;

      final classes = workspace.assignedClasses;
      if (classes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No classes are assigned to you yet. Ask an administrator to add a class or subject assignment.',
            ),
          ),
        );
        return;
      }

      final selected = classes.length == 1
          ? classes.first
          : await showTeacherClassChooser(
              context: context,
              classes: classes,
              selectedStreamId: page == _SchoolAdminPage.assessments
                  ? _assessmentStreamId
                  : _evaluationStreamId,
              title: page == _SchoolAdminPage.assessments
                  ? 'Choose a class for assessments'
                  : 'Choose a class for evaluations',
              message: page == _SchoolAdminPage.assessments
                  ? 'Assessments will open for the class you select.'
                  : 'Evaluations will open for the class you select.',
            );
      if (!mounted || selected == null) return;

      setState(() {
        if (page == _SchoolAdminPage.assessments) {
          _assessmentStreamId = selected.streamId;
          _evaluationStreamId = null;
          _evaluationStreamName = null;
        } else {
          _assessmentStreamId = null;
          _evaluationStreamId = selected.streamId;
          _evaluationStreamName = selected.label;
        }
        _selectedPage = page;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your assigned classes could not be loaded.'),
        ),
      );
    } finally {
      _selectingTeacherClass = false;
    }
  }

  void _openFeeWorkflow() {
    setState(() {
      _openFeeStructureOnNextFees = true;
      _selectedPage = _SchoolAdminPage.fees;
      _feeWorkflowSummary = _loadFeeWorkflowSummary();
      _approvalInbox = _loadApprovalInbox();
    });
  }

  void _openStartAdmission() {
    setState(() {
      _openStartAdmissionOnNextAdmissions = true;
      _selectedPage = _SchoolAdminPage.admissions;
    });
  }

  void _openFindStudent() {
    setState(() {
      _studentProfileToOpenId = null;
      _focusStudentSearchOnNextStudents = true;
      _selectedPage = _SchoolAdminPage.students;
    });
  }

  void _openStudentProfile(String studentId) {
    setState(() {
      _focusStudentSearchOnNextStudents = false;
      _studentProfileToOpenId = studentId;
      _selectedPage = _SchoolAdminPage.students;
    });
  }

  void _openRecordPayment() {
    setState(() {
      _recordPaymentStudentId = null;
      _openRecordPaymentOnNextFees = true;
      _selectedPage = _SchoolAdminPage.fees;
    });
  }

  void _openRecordPaymentForStudent(EnrolledStudent student) {
    setState(() {
      _recordPaymentStudentId = student.id;
      _openRecordPaymentOnNextFees = true;
      _selectedPage = _SchoolAdminPage.fees;
    });
  }

  void _openRecordExpense() {
    setState(() {
      _openNewRequisitionOnNextExpenses = true;
      _selectedPage = _SchoolAdminPage.expenses;
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
    return FutureBuilder<SchoolReadiness>(
      future: _readiness,
      builder: (context, _) => _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return FutureBuilder<DashboardSnapshot>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final teachingRole = _isTeachingRole(_activeRole);
        final dashboardUnavailable = snapshot.hasError && !teachingRole;
        final data = snapshot.data ?? _teachingWorkspaceSnapshot();
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
                      role: _activeRole,
                      roles: _availableRoles,
                      onRoleChanged: _changeWorkspace,
                      selectedPage: _selectedPage,
                      approvalInbox: _approvalInbox,
                      shopAccess: _shopAccess,
                      onSelectPage: _selectPage,
                      onLogout: widget.onLogout,
                      onCollapse: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                    ),
                    Expanded(
                      child: _DashboardBody(
                        data: data,
                        repository: widget.repository,
                        feeWorkflowSummary: _feeWorkflowSummary,
                        approvalInbox: _approvalInbox,
                        notifications: _notifications,
                        onOpenNotifications: _openNotifications,
                        dashboardUnavailable: dashboardUnavailable,
                        onRefresh: _refresh,
                        userDisplayName: widget.userDisplayName,
                        role: _activeRole,
                        userId: widget.userId,
                        selectedPage: _selectedPage,
                        onSelectPage: _selectPage,
                        assessmentStreamId: _assessmentStreamId,
                        evaluationStreamId: _evaluationStreamId,
                        evaluationStreamName: _evaluationStreamName,
                        teacherClassStreamId: _teacherClassStreamId,
                        onOpenTeacherClass: _openTeacherClass,
                        onOpenAssessmentsForStream: _openAssessmentsForStream,
                        onOpenFeeWorkflow: _openFeeWorkflow,
                        onFeeWorkflowChanged: _refreshFeeWorkflowSummary,
                        openFeeStructureOnNextFees: _openFeeStructureOnNextFees,
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
                        recordPaymentStudentId: _recordPaymentStudentId,
                        onRecordPaymentRequestConsumed: () => setState(() {
                          _openRecordPaymentOnNextFees = false;
                          _recordPaymentStudentId = null;
                        }),
                        openAddEventOnNextCalendar: _openAddEventOnNextCalendar,
                        onAddEventRequestConsumed: () =>
                            setState(() => _openAddEventOnNextCalendar = false),
                        openAddStaffOnNextStaff: _openAddStaffOnNextStaff,
                        onAddStaffRequestConsumed: () =>
                            setState(() => _openAddStaffOnNextStaff = false),
                        onStartAdmission: _openStartAdmission,
                        focusStudentSearchOnNextStudents:
                            _focusStudentSearchOnNextStudents,
                        studentProfileToOpenId: _studentProfileToOpenId,
                        onOpenStudentProfile: _openStudentProfile,
                        onFindStudent: _openFindStudent,
                        onRecordPayment: _openRecordPayment,
                        onCollectStudentPayment: _openRecordPaymentForStudent,
                        openNewRequisitionOnNextExpenses:
                            _openNewRequisitionOnNextExpenses,
                        onNewRequisitionRequestConsumed: () => setState(
                          () => _openNewRequisitionOnNextExpenses = false,
                        ),
                        onRecordExpense: _openRecordExpense,
                        onAddCalendarEvent: _openAddCalendarEvent,
                        onAddStaff: _openAddStaff,
                        teacherDashboardLoader: widget.teacherDashboardLoader,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              onDrawerChanged: (opened) {
                if (opened) _refreshApprovalInbox();
              },
              drawer: Drawer(
                child: _Sidebar(
                  data: data,
                  isDrawer: true,
                  schoolName: widget.schoolName,
                  role: _activeRole,
                  roles: _availableRoles,
                  onRoleChanged: _changeWorkspace,
                  selectedPage: _selectedPage,
                  approvalInbox: _approvalInbox,
                  shopAccess: _shopAccess,
                  onSelectPage: (page) {
                    _selectPage(page);
                    Navigator.pop(context);
                  },
                  onLogout: widget.onLogout,
                ),
              ),
              body: _DashboardBody(
                data: data,
                repository: widget.repository,
                feeWorkflowSummary: _feeWorkflowSummary,
                approvalInbox: _approvalInbox,
                notifications: _notifications,
                onOpenNotifications: _openNotifications,
                dashboardUnavailable: dashboardUnavailable,
                onRefresh: _refresh,
                userDisplayName: widget.userDisplayName,
                role: _activeRole,
                userId: widget.userId,
                showMenu: true,
                selectedPage: _selectedPage,
                onSelectPage: _selectPage,
                assessmentStreamId: _assessmentStreamId,
                evaluationStreamId: _evaluationStreamId,
                evaluationStreamName: _evaluationStreamName,
                teacherClassStreamId: _teacherClassStreamId,
                onOpenTeacherClass: _openTeacherClass,
                onOpenAssessmentsForStream: _openAssessmentsForStream,
                onOpenFeeWorkflow: _openFeeWorkflow,
                onFeeWorkflowChanged: _refreshFeeWorkflowSummary,
                openFeeStructureOnNextFees: _openFeeStructureOnNextFees,
                schoolId: _schoolId,
                schoolName: widget.schoolName,
                accessToken: widget.accessToken,
                onRefreshAccessToken: widget.onRefreshAccessToken,
                openStartAdmissionOnNextAdmissions:
                    _openStartAdmissionOnNextAdmissions,
                onStartAdmissionRequestConsumed: () =>
                    setState(() => _openStartAdmissionOnNextAdmissions = false),
                openRecordPaymentOnNextFees: _openRecordPaymentOnNextFees,
                recordPaymentStudentId: _recordPaymentStudentId,
                onRecordPaymentRequestConsumed: () => setState(() {
                  _openRecordPaymentOnNextFees = false;
                  _recordPaymentStudentId = null;
                }),
                openAddEventOnNextCalendar: _openAddEventOnNextCalendar,
                onAddEventRequestConsumed: () =>
                    setState(() => _openAddEventOnNextCalendar = false),
                openAddStaffOnNextStaff: _openAddStaffOnNextStaff,
                onAddStaffRequestConsumed: () =>
                    setState(() => _openAddStaffOnNextStaff = false),
                onStartAdmission: _openStartAdmission,
                focusStudentSearchOnNextStudents:
                    _focusStudentSearchOnNextStudents,
                studentProfileToOpenId: _studentProfileToOpenId,
                onOpenStudentProfile: _openStudentProfile,
                onFindStudent: _openFindStudent,
                onRecordPayment: _openRecordPayment,
                onCollectStudentPayment: _openRecordPaymentForStudent,
                openNewRequisitionOnNextExpenses:
                    _openNewRequisitionOnNextExpenses,
                onNewRequisitionRequestConsumed: () =>
                    setState(() => _openNewRequisitionOnNextExpenses = false),
                onRecordExpense: _openRecordExpense,
                onAddCalendarEvent: _openAddCalendarEvent,
                onAddStaff: _openAddStaff,
                teacherDashboardLoader: widget.teacherDashboardLoader,
              ),
            );
          },
        );
      },
    );
  }

  DashboardSnapshot _teachingWorkspaceSnapshot() {
    return DashboardSnapshot(
      schoolName: widget.schoolName?.trim() ?? '',
      administratorName: widget.userDisplayName?.trim() ?? '',
      term: '',
      academicYear: '',
      termStartDate: '',
      termEndDate: '',
      lastUpdated: DateTime.now(),
      metrics: const [],
      admissions: const [],
      alerts: const [],
      events: const [],
      calendarEvents: const [],
      activities: const [],
      attendance: const AttendanceSummary(
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
      ),
      fees: const FeeSummary(collected: 0, outstanding: 0, waivers: 0),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.repository,
    required this.feeWorkflowSummary,
    required this.approvalInbox,
    required this.notifications,
    required this.onOpenNotifications,
    required this.dashboardUnavailable,
    required this.onRefresh,
    this.userDisplayName,
    this.role,
    this.userId,
    this.showMenu = false,
    required this.selectedPage,
    required this.onSelectPage,
    this.assessmentStreamId,
    this.evaluationStreamId,
    this.evaluationStreamName,
    this.teacherClassStreamId,
    required this.onOpenTeacherClass,
    required this.onOpenAssessmentsForStream,
    required this.onOpenFeeWorkflow,
    required this.onFeeWorkflowChanged,
    required this.openFeeStructureOnNextFees,
    required this.schoolId,
    this.schoolName,
    this.accessToken,
    this.onRefreshAccessToken,
    required this.openStartAdmissionOnNextAdmissions,
    required this.onStartAdmissionRequestConsumed,
    required this.openRecordPaymentOnNextFees,
    this.recordPaymentStudentId,
    required this.onRecordPaymentRequestConsumed,
    required this.openAddEventOnNextCalendar,
    required this.onAddEventRequestConsumed,
    required this.openAddStaffOnNextStaff,
    required this.onAddStaffRequestConsumed,
    required this.onStartAdmission,
    required this.focusStudentSearchOnNextStudents,
    this.studentProfileToOpenId,
    required this.onOpenStudentProfile,
    required this.onFindStudent,
    required this.onRecordPayment,
    required this.onCollectStudentPayment,
    required this.openNewRequisitionOnNextExpenses,
    required this.onNewRequisitionRequestConsumed,
    required this.onRecordExpense,
    required this.onAddCalendarEvent,
    required this.onAddStaff,
    this.teacherDashboardLoader,
  });

  final DashboardSnapshot data;
  final DashboardRepository repository;
  final Future<FeeWorkflowSummary?> feeWorkflowSummary;
  final Future<ApprovalInbox?> approvalInbox;
  final Future<SchoolNotificationInbox?> notifications;
  final VoidCallback onOpenNotifications;
  final bool dashboardUnavailable;
  final VoidCallback onRefresh;
  final String? userDisplayName;
  final String? role;
  final int? userId;
  final bool showMenu;
  final _SchoolAdminPage selectedPage;
  final ValueChanged<_SchoolAdminPage> onSelectPage;
  final int? assessmentStreamId;
  final int? evaluationStreamId;
  final String? evaluationStreamName;
  final int? teacherClassStreamId;
  final ValueChanged<TeacherClassAssignment> onOpenTeacherClass;
  final ValueChanged<int> onOpenAssessmentsForStream;
  final VoidCallback onOpenFeeWorkflow;
  final VoidCallback onFeeWorkflowChanged;
  final bool openFeeStructureOnNextFees;
  final String schoolId;
  final String? schoolName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final bool openStartAdmissionOnNextAdmissions;
  final VoidCallback onStartAdmissionRequestConsumed;
  final bool openRecordPaymentOnNextFees;
  final String? recordPaymentStudentId;
  final VoidCallback onRecordPaymentRequestConsumed;
  final bool openAddEventOnNextCalendar;
  final VoidCallback onAddEventRequestConsumed;
  final bool openAddStaffOnNextStaff;
  final VoidCallback onAddStaffRequestConsumed;
  final VoidCallback onStartAdmission;
  final bool focusStudentSearchOnNextStudents;
  final String? studentProfileToOpenId;
  final ValueChanged<String> onOpenStudentProfile;
  final VoidCallback onFindStudent;
  final VoidCallback onRecordPayment;
  final ValueChanged<EnrolledStudent> onCollectStudentPayment;
  final bool openNewRequisitionOnNextExpenses;
  final VoidCallback onNewRequisitionRequestConsumed;
  final VoidCallback onRecordExpense;
  final VoidCallback onAddCalendarEvent;
  final VoidCallback onAddStaff;
  final Future<TeacherDashboardSummary> Function()? teacherDashboardLoader;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeeWorkflowSummary?>(
      future: feeWorkflowSummary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final showNotice =
            selectedPage == _SchoolAdminPage.dashboard &&
            _canSeeFinancialNotices(role) &&
            summary != null &&
            (summary.streamsWithoutActiveFees > 0 ||
                summary.pendingMyApproval > 0 ||
                summary.masterPendingMyApproval > 0 ||
                summary.requiredItemsPendingMyApproval > 0);
        return Column(
          children: [
            _TopBar(
              data: data,
              showMenu: showMenu,
              userDisplayName: userDisplayName,
              notifications: notifications,
              onNotifications: onOpenNotifications,
            ),
            if (showNotice)
              _GlobalFinanceWorkflowBanner(
                summary: summary,
                onOpen:
                    summary.pendingMyApproval > 0 ||
                        summary.masterPendingMyApproval > 0 ||
                        summary.requiredItemsPendingMyApproval > 0
                    ? () => onSelectPage(_SchoolAdminPage.approvals)
                    : onOpenFeeWorkflow,
              ),
            Expanded(child: _content(context)),
          ],
        );
      },
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

    if (selectedPage == _SchoolAdminPage.approvals) {
      return ApprovalsScreen(
        schoolId: schoolId,
        repository: ApprovalApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onInboxChanged: (_) => onFeeWorkflowChanged(),
        onOpenSource: (ApprovalItem item) {
          if (item.sourcePage == 'fees') {
            onSelectPage(_SchoolAdminPage.fees);
          } else if (item.sourcePage == 'students') {
            onSelectPage(_SchoolAdminPage.students);
          } else if (item.sourcePage == 'incidents') {
            onSelectPage(_SchoolAdminPage.incidents);
          } else if (item.sourcePage == 'shop') {
            onSelectPage(_SchoolAdminPage.shop);
          } else if (item.sourcePage == 'expenses') {
            onSelectPage(_SchoolAdminPage.expenses);
          } else if (item.sourcePage == 'assessments') {
            onSelectPage(_SchoolAdminPage.assessments);
          } else if (item.sourcePage == 'evaluations') {
            onSelectPage(_SchoolAdminPage.evaluations);
          } else if (item.sourcePage == 'finalReports') {
            onSelectPage(_SchoolAdminPage.finalReports);
          } else if (item.sourcePage == 'leave') {
            showLeaveRequestDetails(
              context: context,
              requestId: item.entityId,
              api: LeaveApiClient(
                schoolId: schoolId,
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
              onChanged: onFeeWorkflowChanged,
            );
          }
        },
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
        customSchoolId: schoolId,
        viewerRole: role,
        admissionsApi: AdmissionsApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        term: data.term,
        academicYear: data.academicYear,
        focusSearchOnLoad: focusStudentSearchOnNextStudents,
        initialStudentId: studentProfileToOpenId,
        repository: ApiStudentsRepository(
          customSchoolId: schoolId,
          viewerRole: role,
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onOpenHousehold: () => onSelectPage(_SchoolAdminPage.households),
        onCollectPayment: _canSeeFinancialNotices(role)
            ? onCollectStudentPayment
            : null,
        onApprovalChanged: onFeeWorkflowChanged,
      );
    }

    if (selectedPage == _SchoolAdminPage.attendance) {
      return AttendanceDashboardScreen(
        customSchoolId: schoolId,
        schoolName: schoolName,
        viewerRole: role,
        term: data.term,
        academicYear: data.academicYear,
        repository: AttendanceApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onOpenCalendar: () => onSelectPage(_SchoolAdminPage.calendar),
        canAcknowledge: _canAcknowledgeAttendance(role),
      );
    }

    if (selectedPage == _SchoolAdminPage.staffAttendance) {
      return StaffAttendanceScreen(
        schoolId: schoolId,
        schoolName: schoolName,
        repository: StaffAttendanceApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
      );
    }

    if (selectedPage == _SchoolAdminPage.myLeave ||
        selectedPage == _SchoolAdminPage.leave) {
      final personal = selectedPage == _SchoolAdminPage.myLeave;
      if (!personal && !_canManageLeave(role)) {
        return const Center(
          child: Text('Open My Leave to view your own leave requests.'),
        );
      }
      return LeaveManagementScreen(
        key: ValueKey(personal ? 'my-leave-page' : 'leave-management-page'),
        myLeave: personal,
        api: LeaveApiClient(
          schoolId: schoolId,
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onChanged: onFeeWorkflowChanged,
      );
    }

    if (selectedPage == _SchoolAdminPage.evaluations) {
      return EvaluationManagementScreen(
        key: ValueKey('evaluation-management-screen-$evaluationStreamId'),
        schoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        viewerRole: role?.trim().isNotEmpty == true
            ? role!.trim()
            : 'Administrator',
        viewerName: userDisplayName?.trim().isNotEmpty == true
            ? userDisplayName!.trim()
            : data.administratorName,
        initialStreamId: evaluationStreamId,
        initialStreamName: evaluationStreamName,
      );
    }

    if (selectedPage == _SchoolAdminPage.assessments ||
        selectedPage == _SchoolAdminPage.finalReports) {
      return AssessmentDashboardScreen(
        key: ValueKey('${selectedPage.name}-$assessmentStreamId'),
        schoolName: schoolName?.trim().isNotEmpty == true
            ? schoolName!.trim()
            : data.schoolName,
        term: data.term,
        academicYear: data.academicYear,
        customSchoolId: schoolId,
        accessToken: accessToken,
        viewerRole: role?.trim().isNotEmpty == true
            ? role!.trim()
            : 'Administrator',
        viewerName: userDisplayName?.trim().isNotEmpty == true
            ? userDisplayName!.trim()
            : data.administratorName,
        initialStreamId: assessmentStreamId,
        openFinalReportsOnLoad: selectedPage == _SchoolAdminPage.finalReports,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    if (selectedPage == _SchoolAdminPage.staff) {
      return StaffScreen(
        openAddStaffOnLoad: openAddStaffOnNextStaff,
        onAddStaffRequestConsumed: onAddStaffRequestConsumed,
        customSchoolId: schoolId,
        currentUserId: userId,
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
        role: role,
        userId: userId,
        openRecordPaymentOnLoad: openRecordPaymentOnNextFees,
        recordPaymentStudentId: recordPaymentStudentId,
        openFeeStructureOnLoad: openFeeStructureOnNextFees,
        onRecordPaymentRequestConsumed: onRecordPaymentRequestConsumed,
        onWorkflowChanged: onFeeWorkflowChanged,
        onOpenStudent: onOpenStudentProfile,
      );
    }

    if (selectedPage == _SchoolAdminPage.shop) {
      return SchoolShopScreen(
        role: role,
        api: ShopApiClient(
          schoolId: schoolId,
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
      );
    }

    if (selectedPage == _SchoolAdminPage.expenses) {
      return ExpensesScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        recordedBy: userDisplayName?.trim().isNotEmpty == true
            ? userDisplayName!.trim()
            : data.administratorName,
        currentUserId: userId,
        role: role,
        openNewRequisitionOnLoad: openNewRequisitionOnNextExpenses,
        onNewRequisitionRequestConsumed: onNewRequisitionRequestConsumed,
      );
    }

    if (selectedPage == _SchoolAdminPage.incidents) {
      return IncidentsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        reportedBy: userDisplayName?.trim().isNotEmpty == true
            ? userDisplayName!.trim()
            : data.administratorName,
      );
    }

    if (selectedPage == _SchoolAdminPage.classes) {
      if (_isTeachingRole(role)) {
        return TeacherClassesScreen(
          schoolId: schoolId,
          displayName: userDisplayName?.trim().isNotEmpty == true
              ? userDisplayName!.trim()
              : data.administratorName,
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
          onOpenAttendance: () => onSelectPage(_SchoolAdminPage.attendance),
          onOpenAssessments: onOpenAssessmentsForStream,
          onOpenEvaluations: () => onSelectPage(_SchoolAdminPage.evaluations),
          onOpenIncidents: () => onSelectPage(_SchoolAdminPage.incidents),
          onOpenCalendar: () => onSelectPage(_SchoolAdminPage.calendar),
          initialStreamId: teacherClassStreamId,
          onBack: () => onSelectPage(_SchoolAdminPage.dashboard),
        );
      }
      return GradeStreamsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
        onOpenAttendance: () => onSelectPage(_SchoolAdminPage.attendance),
        onOpenAssessments: () => onSelectPage(_SchoolAdminPage.assessments),
        onOpenIncidents: () => onSelectPage(_SchoolAdminPage.incidents),
        onOpenCalendar: () => onSelectPage(_SchoolAdminPage.calendar),
      );
    }

    if (selectedPage == _SchoolAdminPage.calendar) {
      return _SchoolCalendarPage(
        data: data,
        repository: repository,
        schoolId: schoolId,
        role: role,
        onBack: () => onSelectPage(_SchoolAdminPage.dashboard),
        onRefresh: onRefresh,
        openAddEventOnLoad: openAddEventOnNextCalendar,
        onAddEventRequestConsumed: onAddEventRequestConsumed,
      );
    }

    if (selectedPage == _SchoolAdminPage.termReview) {
      final normalizedRole = role?.trim().toUpperCase();
      final teacherRepository = TeacherTermReviewApiClient(
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
      final bursarRepository = BursarTermClosureApiClient(
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
      if ((normalizedRole == 'CLASS_TEACHER' ||
              normalizedRole == 'SUBJECT_TEACHER') &&
          userId != null) {
        return TeacherTermClosingScreen(
          schoolId: schoolId,
          teacherUserId: userId!,
          repository: teacherRepository,
          onOpenAssessments: () => onSelectPage(_SchoolAdminPage.assessments),
          onOpenIncidents: () => onSelectPage(_SchoolAdminPage.incidents),
        );
      }
      if (normalizedRole == 'BURSAR') {
        return BursarTermClosingScreen(
          schoolId: schoolId,
          actorUserId: userId,
          repository: bursarRepository,
          onOpenFees: () => onSelectPage(_SchoolAdminPage.fees),
          onOpenExpenses: () => onSelectPage(_SchoolAdminPage.expenses),
        );
      }
      return TermReviewScreen(
        schoolId: schoolId,
        reviewerUserId: userId,
        repository: StaffReviewApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        teacherReviewRepository: teacherRepository,
        bursarClosureRepository: bursarRepository,
        headmasterClosureRepository: HeadmasterTermClosureApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
        onTermTransitioned: onRefresh,
      );
    }

    if (selectedPage == _SchoolAdminPage.settings) {
      return SchoolSettingsScreen(
        customSchoolId: schoolId,
        accessToken: accessToken,
        onRefreshAccessToken: onRefreshAccessToken,
      );
    }

    if (selectedPage == _SchoolAdminPage.auditActivity) {
      return AuditActivityScreen(
        repository: AuditApiClient(
          accessToken: accessToken,
          onRefreshAccessToken: onRefreshAccessToken,
        ),
      );
    }

    if (_isTeachingRole(role)) {
      return _TeacherWorkspaceLanding(
        displayName: userDisplayName?.trim().isNotEmpty == true
            ? userDisplayName!.trim()
            : data.administratorName,
        role: role,
        schoolId: schoolId,
        loadSummary:
            teacherDashboardLoader ??
            TeacherDashboardSummaryLoader(
              schoolId: schoolId,
              displayName: userDisplayName?.trim().isNotEmpty == true
                  ? userDisplayName!.trim()
                  : data.administratorName,
              workspaceApi: TeacherWorkspaceApiClient(
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
              attendanceApi: AttendanceApiClient(
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
              assessmentApi: AssessmentApiClient(
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
              leaveApi: LeaveApiClient(
                schoolId: schoolId,
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
              incidentApi: IncidentApiClient(
                customSchoolId: schoolId,
                accessToken: accessToken,
                onRefreshAccessToken: onRefreshAccessToken,
              ),
            ).load,
        events: data.events,
        onOpenClasses: () => onSelectPage(_SchoolAdminPage.classes),
        onOpenClass: onOpenTeacherClass,
        onOpenAttendance: () => onSelectPage(_SchoolAdminPage.attendance),
        onOpenAssessments: () => onSelectPage(_SchoolAdminPage.assessments),
        onOpenIncidents: () => onSelectPage(_SchoolAdminPage.incidents),
        onOpenMyLeave: () => onSelectPage(_SchoolAdminPage.myLeave),
        onOpenCalendar: () => onSelectPage(_SchoolAdminPage.calendar),
        onOpenTermReview: () => onSelectPage(_SchoolAdminPage.termReview),
        approvalInbox: approvalInbox,
        onOpenApprovals: () => onSelectPage(_SchoolAdminPage.approvals),
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
                if (dashboardUnavailable) ...[
                  _DashboardDataUnavailableBanner(onRetry: onRefresh),
                ],
                const SizedBox(height: 18),
                FutureBuilder<ApprovalInbox?>(
                  future: approvalInbox,
                  builder: (context, snapshot) => Column(
                    children: [
                      _QuickActionsCard(
                        role: role,
                        inbox: snapshot.data,
                        onFindStudent: onFindStudent,
                        onRecordPayment: onRecordPayment,
                        onRecordExpense: onRecordExpense,
                        onOpenApprovals: () =>
                            onSelectPage(_SchoolAdminPage.approvals),
                        onOpenFees: () => onSelectPage(_SchoolAdminPage.fees),
                        onStartAdmission: onStartAdmission,
                        onAddStaff: onAddStaff,
                        onCreateEvent: onAddCalendarEvent,
                      ),
                      const SizedBox(height: 20),
                      _MetricGrid(metrics: data.metrics),
                      const SizedBox(height: 20),
                      _DashboardGrid(
                        data: data,
                        additionalAlerts: _approvalAttentionAlerts(
                          snapshot.data,
                          onOpen: () =>
                              onSelectPage(_SchoolAdminPage.approvals),
                        ),
                        onOpenAdmissions: () =>
                            onSelectPage(_SchoolAdminPage.admissions),
                        onOpenAttendance: () =>
                            onSelectPage(_SchoolAdminPage.attendance),
                        onOpenFees: () => onSelectPage(_SchoolAdminPage.fees),
                        onOpenCalendar: () =>
                            onSelectPage(_SchoolAdminPage.calendar),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardDataUnavailableBanner extends StatelessWidget {
  const _DashboardDataUnavailableBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('dashboard-data-unavailable-warning'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.muted),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'The dashboard summary is temporarily unavailable. You can still use all school features.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _GlobalFinanceWorkflowBanner extends StatelessWidget {
  const _GlobalFinanceWorkflowBanner({
    required this.summary,
    required this.onOpen,
  });

  final FeeWorkflowSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final approvals =
        summary.pendingMyApproval +
        summary.masterPendingMyApproval +
        summary.requiredItemsPendingMyApproval;
    final details = <String>[
      if (approvals > 0)
        '$approvals financial ${approvals == 1 ? 'approval requires' : 'approvals require'} your decision',
      if (summary.streamsWithoutActiveFees > 0)
        '${summary.streamsWithoutActiveFees} of ${summary.activeStreams} streams do not have active fees',
    ];
    return Material(
      color: const Color(0xFFFFF8E8),
      child: InkWell(
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.amber.withValues(alpha: .35)),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 19,
                color: AppColors.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  details.join(' · '),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: Text(approvals > 0 ? 'Review fees' : 'Set up fees'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.data,
    required this.showMenu,
    this.userDisplayName,
    required this.notifications,
    required this.onNotifications,
  });
  final DashboardSnapshot data;
  final bool showMenu;
  final String? userDisplayName;
  final Future<SchoolNotificationInbox?> notifications;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      height: width >= 1000 ? 88 : 70,
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
          if (width >= 1000)
            _TermContextPills(data: data)
          else if (width >= 600)
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
          FutureBuilder<SchoolNotificationInbox?>(
            future: notifications,
            builder: (context, snapshot) => _TopIcon(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              badgeCount: snapshot.data?.unreadCount ?? 0,
              onTap: onNotifications,
            ),
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

class _SchoolNotificationsSheet extends StatefulWidget {
  const _SchoolNotificationsSheet({
    required this.inbox,
    required this.schoolId,
    required this.accessToken,
    required this.onRefreshAccessToken,
    required this.onChanged,
  });

  final Future<SchoolNotificationInbox?> inbox;
  final String schoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback onChanged;

  @override
  State<_SchoolNotificationsSheet> createState() =>
      _SchoolNotificationsSheetState();
}

class _SchoolNotificationsSheetState extends State<_SchoolNotificationsSheet> {
  late Future<SchoolNotificationInbox?> _inbox = widget.inbox;
  int? _markingRead;

  Future<void> _markRead(SchoolNotificationItem item) async {
    if (item.read || _markingRead != null) return;
    setState(() => _markingRead = item.id);
    try {
      await SchoolNotificationApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).markRead(schoolId: widget.schoolId, notificationId: item.id);
      widget.onChanged();
      if (mounted) {
        setState(() {
          _markingRead = null;
          _inbox = SchoolNotificationApiClient(
            accessToken: widget.accessToken,
            onRefreshAccessToken: widget.onRefreshAccessToken,
          ).getInbox(widget.schoolId);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _markingRead = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .72;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 680,
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<SchoolNotificationInbox?>(
                future: _inbox,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  final items = snapshot.data?.items ?? const [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 42,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No notifications yet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: item.read
                            ? Colors.white
                            : AppColors.greenSoft.withValues(alpha: .65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          onTap: () => _markRead(item),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(
                                      alpha: .12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 20,
                                    color: AppColors.amber,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          if (!item.read)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.message,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          height: 1.35,
                                        ),
                                      ),
                                      if (item.createdAt != null) ...[
                                        const SizedBox(height: 7),
                                        Text(
                                          _notificationTime(item.createdAt!),
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_markingRead == item.id) ...[
                                  const SizedBox(width: 10),
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _notificationTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} · $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _TermContextPills extends StatelessWidget {
  const _TermContextPills({required this.data});

  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('top-term-context'),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.academicYear.trim().isNotEmpty)
            _TermContextPill(
              icon: Icons.calendar_month_rounded,
              label: data.academicYear.trim(),
            ),
          if (data.academicYear.trim().isNotEmpty &&
              data.term.trim().isNotEmpty)
            const SizedBox(width: 7),
          if (data.term.trim().isNotEmpty)
            _TermContextPill(icon: Icons.flag_rounded, label: data.term.trim()),
          if (data.termDateRange.isNotEmpty) ...[
            const SizedBox(width: 7),
            _TermContextPill(
              icon: Icons.calendar_today_rounded,
              label: data.termDateRange,
            ),
          ],
        ],
      ),
    );
  }
}

class _TermContextPill extends StatelessWidget {
  const _TermContextPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.green),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
              if (badgeCount > 0)
                Positioned(
                  right: 3,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

List<SchoolAlert> _approvalAttentionAlerts(
  ApprovalInbox? inbox, {
  VoidCallback? onOpen,
}) {
  if (inbox == null) return const [];
  final alerts = <SchoolAlert>[];
  final seen = <String>{};
  void add(ApprovalItem item, {required bool assignedToMe}) {
    if (!_isReportCorrectionItem(item) ||
        !item.pending ||
        !seen.add(item.key)) {
      return;
    }
    alerts.add(
      SchoolAlert(
        title: _scoreCorrectionAttentionTitle(item, assignedToMe: assignedToMe),
        message: '${item.title}. ${item.subtitle}',
        context: assignedToMe
            ? 'Requests & Approvals · My approvals'
            : 'Requests & Approvals · My requests',
        level: AlertLevel.warning,
        onTap: onOpen,
      ),
    );
  }

  for (final item in inbox.myApprovals) {
    add(item, assignedToMe: true);
  }
  for (final item in inbox.myRequests) {
    add(item, assignedToMe: false);
  }
  return alerts;
}

String _scoreCorrectionAttentionTitle(
  ApprovalItem item, {
  required bool assignedToMe,
}) => switch (item.status) {
  'APPROVED_REGENERATION_REQUIRED' =>
    assignedToMe
        ? 'Approved report correction needs regeneration'
        : 'Your report correction was approved; regeneration is pending',
  'REGENERATED_AWAITING_PUBLICATION' =>
    assignedToMe
        ? 'Corrected report is awaiting publication'
        : 'Your corrected report is awaiting publication',
  _ =>
    assignedToMe
        ? 'Report correction awaiting your approval'
        : 'Your report correction is awaiting approval',
};

bool _isReportCorrectionItem(ApprovalItem item) =>
    item.type == 'REPORT_CORRECTION' || item.type == 'REPORT_SCORE_CORRECTION';

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.data,
    this.additionalAlerts = const [],
    required this.onOpenAdmissions,
    required this.onOpenAttendance,
    required this.onOpenFees,
    required this.onOpenCalendar,
  });
  final DashboardSnapshot data;
  final List<SchoolAlert> additionalAlerts;
  final VoidCallback onOpenAdmissions;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenFees;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final alerts = [...additionalAlerts, ...data.alerts];
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
              _AttentionCard(alerts: alerts),
              const SizedBox(height: 16),
              _FinanceCard(fees: data.fees, onOpenFees: onOpenFees),
              const SizedBox(height: 16),
              _AttendanceCard(
                attendance: data.attendance,
                onOpenAttendance: onOpenAttendance,
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
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _AttentionCard(alerts: alerts),
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

  static const _visibleAlertCount = 3;

  void _showAllAlerts(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All attention items',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AttentionItem(
                      key: ValueKey('all-attention-item-$index'),
                      alert: alerts[index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleAlerts = alerts.take(_visibleAlertCount).toList();
    final remainingCount = alerts.length - visibleAlerts.length;
    return _SectionCard(
      title: 'Attention required',
      action: remainingCount > 0 ? '+ $remainingCount more' : null,
      onAction: remainingCount > 0 ? () => _showAllAlerts(context) : null,
      child: alerts.isEmpty
          ? const _DashboardEmptyState(
              icon: Icons.task_alt_rounded,
              message: 'Nothing requires attention right now.',
            )
          : Column(
              children: [
                for (var index = 0; index < visibleAlerts.length; index++) ...[
                  _AttentionItem(
                    key: ValueKey('dashboard-attention-item-$index'),
                    alert: visibleAlerts[index],
                  ),
                  if (index < visibleAlerts.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({super.key, required this.alert});

  final SchoolAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.level) {
      AlertLevel.critical => AppColors.red,
      AlertLevel.warning => AppColors.amber,
      AlertLevel.info => AppColors.blue,
    };
    final content = Container(
      width: double.infinity,
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.context,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (alert.onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ],
      ),
    );
    if (alert.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alert.onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
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
      title: 'Student attendance',
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
                  'Term-to-date attendance',
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  attendance.studentsNeedingAttention == 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: attendance.studentsNeedingAttention == 0
                      ? AppColors.green
                      : AppColors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attendance.studentsNeedingAttention == 0
                        ? 'No attendance concerns'
                        : '${attendance.studentsNeedingAttention} student${attendance.studentsNeedingAttention == 1 ? '' : 's'} need follow-up',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
    required this.role,
    required this.inbox,
    required this.onFindStudent,
    required this.onRecordExpense,
    required this.onOpenApprovals,
    required this.onOpenFees,
    required this.onStartAdmission,
    required this.onRecordPayment,
    required this.onAddStaff,
    required this.onCreateEvent,
  });

  final String? role;
  final ApprovalInbox? inbox;
  final VoidCallback onFindStudent;
  final VoidCallback onRecordExpense;
  final VoidCallback onOpenApprovals;
  final VoidCallback onOpenFees;
  final VoidCallback onStartAdmission;
  final VoidCallback onRecordPayment;
  final VoidCallback onAddStaff;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final normalizedRole = role?.trim().toUpperCase() ?? '';
    final financialRole = _canSeeFinancialNotices(normalizedRole);
    final managesSchool = const {
      'ADMINISTRATOR',
      'ADMIN',
      'HEAD_TEACHER',
      'HEADMASTER',
    }.contains(normalizedRole);
    final actions = <_DashboardQuickAction>[
      _DashboardQuickAction(
        icon: Icons.person_search_rounded,
        label: 'Find student',
        description: 'Search by name, ID or guardian',
        color: AppColors.green,
        onTap: onFindStudent,
      ),
      if (financialRole)
        _DashboardQuickAction(
          icon: Icons.payments_rounded,
          label: 'Record payment',
          description: 'Open fee collection',
          color: AppColors.blue,
          onTap: onRecordPayment,
        ),
      if (financialRole)
        _DashboardQuickAction(
          icon: Icons.receipt_long_rounded,
          label: 'Record expense',
          description: 'Start an expense requisition',
          color: AppColors.purple,
          onTap: onRecordExpense,
        ),
      if (financialRole)
        _DashboardQuickAction(
          icon: Icons.approval_rounded,
          label: 'Requests & approvals',
          description: inbox == null
              ? 'Open your request inbox'
              : '${inbox!.pendingMyRequests} requests · ${inbox!.pendingMyApproval} approvals',
          color: AppColors.amber,
          badgeCount: inbox?.pendingTotal ?? 0,
          onTap: onOpenApprovals,
        ),
    ];
    final moreActions = <({String label, IconData icon, VoidCallback onTap})>[
      if (financialRole)
        (
          label: 'Fee management',
          icon: Icons.account_balance_wallet_outlined,
          onTap: onOpenFees,
        ),
      if (managesSchool)
        (
          label: 'Start admission',
          icon: Icons.person_add_alt_1_rounded,
          onTap: onStartAdmission,
        ),
      if (managesSchool)
        (label: 'Add staff', icon: Icons.group_add_rounded, onTap: onAddStaff),
      if (managesSchool)
        (
          label: 'Add school event',
          icon: Icons.event_rounded,
          onTap: onCreateEvent,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick actions',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Start common tasks without searching the menu.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (moreActions.isNotEmpty)
                  PopupMenuButton<int>(
                    tooltip: 'More actions',
                    onSelected: (index) => moreActions[index].onTap(),
                    itemBuilder: (context) => [
                      for (var index = 0; index < moreActions.length; index++)
                        PopupMenuItem<int>(
                          value: index,
                          child: Row(
                            children: [
                              Icon(moreActions[index].icon, size: 19),
                              const SizedBox(width: 10),
                              Text(moreActions[index].label),
                            ],
                          ),
                        ),
                    ],
                    child: const _MoreActionsButton(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 920
                    ? actions.length.clamp(1, 4)
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final action in actions)
                      SizedBox(
                        width: width,
                        child: _DashboardQuickActionButton(action: action),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardQuickAction {
  const _DashboardQuickAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
}

class _DashboardQuickActionButton extends StatelessWidget {
  const _DashboardQuickActionButton({required this.action});

  final _DashboardQuickAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        key: ValueKey(
          'dashboard-quick-${action.label.toLowerCase().replaceAll(' ', '-')}',
        ),
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: action.color.withValues(alpha: .2)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: action.color, size: 22),
                  ),
                  if (action.badgeCount > 0)
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 21),
                        height: 21,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          action.badgeCount > 99
                              ? '99+'
                              : '${action.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: action.color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreActionsButton extends StatelessWidget {
  const _MoreActionsButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 18, color: AppColors.green),
          SizedBox(width: 6),
          Text(
            'More actions',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
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
    required this.role,
    required this.onBack,
    required this.onRefresh,
    this.openAddEventOnLoad = false,
    this.onAddEventRequestConsumed,
  });

  final DashboardSnapshot data;
  final DashboardRepository repository;
  final String schoolId;
  final String? role;
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

  bool get _canManage => _canManageCalendar(widget.role);

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
      if (mounted && _canManage) await _addEvent();
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
            canManage: _canManage,
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
            onAddEvent: !_canManage || _eventActionBusy
                ? null
                : () => _addEvent(),
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
            onOpenEvent: _openEvent,
            onOpenDay: _openDayEvents,
            onAddEvent: !_canManage || _eventActionBusy
                ? null
                : _addEventForDate,
            onDeleteDay: !_canManage || _eventActionBusy
                ? null
                : _deleteEventsForDate,
          ),
          const SizedBox(height: 18),
          _CalendarEventList(
            upcoming: upcoming,
            past: past,
            isSearching: isSearching,
            showPastEvents: _showPastEvents,
            onTogglePast: () =>
                setState(() => _showPastEvents = !_showPastEvents),
            onEdit: !_canManage || _eventActionBusy ? null : _editEvent,
            onDelete: !_canManage || _eventActionBusy ? null : _deleteEvent,
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

  Future<void> _openEvent(SchoolEvent event) async {
    final eventId = (event.id ?? '').trim();
    final history = eventId.isEmpty
        ? Future.value(const <CalendarEventChange>[])
        : widget.repository.getCalendarEventHistory(
            schoolId: widget.schoolId,
            eventId: eventId,
          );
    final action = await showDialog<_CalendarEventDetailsAction>(
      context: context,
      builder: (context) => _CalendarEventDetailsDialog(
        event: event,
        canManage: _canManage,
        history: history,
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _CalendarEventDetailsAction.edit:
        await _editEvent(event);
        return;
      case _CalendarEventDetailsAction.delete:
        await _deleteEvent(event);
        return;
      case null:
        return;
    }
  }

  Future<void> _openDayEvents(DateTime date, List<SchoolEvent> events) async {
    final selected = await showDialog<SchoolEvent>(
      context: context,
      builder: (context) =>
          _CalendarDayEventsDialog(date: date, events: events),
    );
    if (selected != null && mounted) await _openEvent(selected);
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

  Future<void> _addEvent({DateTime? initialDate}) async {
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
            initialDate: initialDate ?? _defaultEventDate(),
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

  void _addEventForDate(DateTime date) {
    _addEvent(initialDate: _dateOnly(date));
  }

  Future<void> _deleteEventsForDate(
    DateTime date,
    List<SchoolEvent> events,
  ) async {
    if (events.isEmpty) return;
    SchoolEvent? selected;
    if (events.length == 1) {
      selected = events.single;
    } else {
      selected = await showDialog<SchoolEvent>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(
            'Choose an event to delete · ${_formatCalendarDate(date)}',
          ),
          children: [
            for (final event in events)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(event),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: AppColors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(event.title)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (selected != null && mounted) await _deleteEvent(selected);
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
    required this.canManage,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onAddEvent,
  });

  final DashboardSnapshot data;
  final DateTime visibleMonth;
  final bool canManage;
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
        if (canManage)
          FilledButton.icon(
            onPressed: onAddEvent,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Event'),
          )
        else
          const Chip(
            avatar: Icon(Icons.visibility_outlined, size: 17),
            label: Text('View only'),
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

enum _CalendarEventDetailsAction { edit, delete }

class _CalendarEventDetailsDialog extends StatelessWidget {
  const _CalendarEventDetailsDialog({
    required this.event,
    required this.canManage,
    required this.history,
  });

  final SchoolEvent event;
  final bool canManage;
  final Future<List<CalendarEventChange>> history;

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.category);
    final start = _formatCalendarDate(event.startDate);
    final end = _formatCalendarDate(event.endDate);
    final dateRange = _dateOnly(event.startDate) == _dateOnly(event.endDate)
        ? start
        : '$start – $end';

    return AlertDialog(
      key: const ValueKey('calendar-event-details'),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_outlined, color: style.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CalendarDetailChip(
                  label: _eventTypeLabel(event.category),
                  color: style.foreground,
                  background: style.background,
                ),
                _CalendarDetailChip(
                  label: event.isSchoolDay ? 'School day' : 'Non-school day',
                  color: event.isSchoolDay ? AppColors.green : AppColors.red,
                  background: event.isSchoolDay
                      ? AppColors.greenSoft
                      : const Color(0xFFFFF0F0),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CalendarDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: dateRange,
            ),
            if (event.description.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Details',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 5),
              Text(event.description.trim()),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1),
            _CalendarChangeHistory(history: history),
          ],
        ),
      ),
      actions: [
        if (canManage && (event.id ?? '').trim().isNotEmpty)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () =>
                Navigator.of(context).pop(_CalendarEventDetailsAction.delete),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete event'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (canManage && (event.id ?? '').trim().isNotEmpty)
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_CalendarEventDetailsAction.edit),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit event'),
          ),
      ],
    );
  }
}

class _CalendarChangeHistory extends StatelessWidget {
  const _CalendarChangeHistory({required this.history});

  final Future<List<CalendarEventChange>> history;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CalendarEventChange>>(
      future: history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading change history…'),
          );
        }
        if (snapshot.hasError) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history_rounded, color: AppColors.muted),
            title: Text('Change history unavailable'),
          );
        }
        final changes = snapshot.data ?? const <CalendarEventChange>[];
        if (changes.isEmpty) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history_rounded, color: AppColors.muted),
            title: Text('Change history'),
            subtitle: Text('No recorded changes yet'),
          );
        }
        final visibleChanges = changes.take(5).toList();
        return ExpansionTile(
          key: const ValueKey('calendar-change-history'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded, color: AppColors.green),
          title: const Text(
            'Change history',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${changes.length} recorded ${changes.length == 1 ? 'change' : 'changes'}',
          ),
          children: [
            for (final change in visibleChanges)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 12),
                leading: Icon(
                  change.action.toUpperCase() == 'CREATED'
                      ? Icons.add_circle_outline_rounded
                      : Icons.edit_note_rounded,
                  size: 19,
                  color: AppColors.muted,
                ),
                title: Text(
                  change.summary,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    change.actorName,
                    if (change.actorRole.trim().isNotEmpty)
                      _calendarRoleLabel(change.actorRole),
                    if (change.changedAt != null)
                      _formatCalendarChangeTime(change.changedAt!),
                  ].join(' · '),
                ),
              ),
            if (changes.length > visibleChanges.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${changes.length - visibleChanges.length} earlier changes are available in Audit & Activity.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CalendarDayEventsDialog extends StatelessWidget {
  const _CalendarDayEventsDialog({required this.date, required this.events});

  final DateTime date;
  final List<SchoolEvent> events;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ValueKey('calendar-day-events-${_calendarDayKey(date)}'),
      title: Text('Events on ${_formatCalendarDate(date)}'),
      content: SizedBox(
        width: 500,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              final style = _eventStyle(event.category);
              return ListTile(
                key: ValueKey('calendar-day-event-${_calendarEventKey(event)}'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    color: style.foreground,
                    size: 20,
                  ),
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_eventTypeLabel(event.category)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(event),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _CalendarDetailChip extends StatelessWidget {
  const _CalendarDetailChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDetailRow extends StatelessWidget {
  const _CalendarDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
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
    required this.onOpenEvent,
    required this.onOpenDay,
    required this.onAddEvent,
    required this.onDeleteDay,
  });

  final DateTime visibleMonth;
  final List<SchoolEvent> events;
  final String? highlightedEventKey;
  final ValueChanged<SchoolEvent> onOpenEvent;
  final void Function(DateTime date, List<SchoolEvent> events) onOpenDay;
  final ValueChanged<DateTime>? onAddEvent;
  final void Function(DateTime date, List<SchoolEvent> events)? onDeleteDay;

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
              mainAxisExtent: 116,
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
                onOpenEvent: onOpenEvent,
                onOpenDay: () => onOpenDay(date, dateEvents),
                onAddEvent: onAddEvent == null ? null : () => onAddEvent!(date),
                onDelete: onDeleteDay == null || dateEvents.isEmpty
                    ? null
                    : () => onDeleteDay!(date, dateEvents),
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

class _CalendarDayCell extends StatefulWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.events,
    required this.highlightedEventKey,
    required this.onOpenEvent,
    required this.onOpenDay,
    required this.onAddEvent,
    required this.onDelete,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final List<SchoolEvent> events;
  final String? highlightedEventKey;
  final ValueChanged<SchoolEvent> onOpenEvent;
  final VoidCallback onOpenDay;
  final VoidCallback? onAddEvent;
  final VoidCallback? onDelete;

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = widget.events.take(2).toList();
    final extra = widget.events.length - visibleEvents.length;
    final showActions = _hovered || MediaQuery.sizeOf(context).width < 700;
    return MouseRegion(
      key: ValueKey('calendar-day-${_calendarDayKey(widget.date)}'),
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.green.withValues(alpha: .025)
              : Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.border),
            right: BorderSide(color: AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 22,
              child: Row(
                children: [
                  Text(
                    '${widget.date.day}',
                    style: TextStyle(
                      color: widget.isCurrentMonth
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IgnorePointer(
                    ignoring: !showActions || widget.onDelete == null,
                    child: AnimatedOpacity(
                      key: ValueKey(
                        'calendar-delete-visibility-${_calendarDayKey(widget.date)}',
                      ),
                      opacity: showActions && widget.onDelete != null ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: Tooltip(
                        message:
                            'Delete event on ${_formatCalendarDate(widget.date)}',
                        child: InkWell(
                          key: ValueKey(
                            'calendar-delete-${_calendarDayKey(widget.date)}',
                          ),
                          onTap: widget.onDelete,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: .1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onDelete != null) const SizedBox(width: 4),
                  IgnorePointer(
                    ignoring: !showActions || widget.onAddEvent == null,
                    child: AnimatedOpacity(
                      key: ValueKey(
                        'calendar-add-visibility-${_calendarDayKey(widget.date)}',
                      ),
                      opacity: showActions && widget.onAddEvent != null ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: Tooltip(
                        message:
                            'Add event on ${_formatCalendarDate(widget.date)}',
                        child: InkWell(
                          key: ValueKey(
                            'calendar-add-${_calendarDayKey(widget.date)}',
                          ),
                          onTap: widget.onAddEvent,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: .1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final event in visibleEvents) ...[
              _CalendarEventPill(
                event: event,
                isHighlighted:
                    widget.highlightedEventKey == _calendarEventKey(event),
                date: widget.date,
                onTap: () => widget.onOpenEvent(event),
              ),
              const SizedBox(height: 4),
            ],
            if (extra > 0)
              InkWell(
                key: ValueKey('calendar-more-${_calendarDayKey(widget.date)}'),
                onTap: widget.onOpenDay,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  child: Text(
                    '+$extra more',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventPill extends StatelessWidget {
  const _CalendarEventPill({
    required this.event,
    required this.isHighlighted,
    required this.date,
    required this.onTap,
  });

  final SchoolEvent event;
  final bool isHighlighted;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'calendar-event-${_calendarDayKey(date)}-${_calendarEventKey(event)}',
        ),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
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
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              _CalendarRowIcon(
                icon: Icons.edit_outlined,
                label: 'Edit event',
                onTap: () => onEdit!(event),
              ),
            ],
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              _CalendarRowIcon(
                icon: Icons.delete_outline_rounded,
                label: 'Delete event',
                onTap: () => onDelete!(event),
              ),
            ],
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
  if (normalized.contains('holiday') ||
      normalized.contains('vacation') ||
      normalized.contains('break')) {
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
  if (normalized.contains('vacation')) {
    return 'Vacation';
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

String _calendarDayKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatCalendarDate(DateTime value) {
  return '${value.day} ${_monthName(value.month).substring(0, 3)} ${value.year}';
}

String _formatCalendarChangeTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${_formatCalendarDate(value)} · $hour:$minute $period';
}

String _calendarRoleLabel(String role) => role
    .trim()
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
    .join(' ');

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

bool _isTeachingRole(String? role) {
  final value = role?.trim().toUpperCase() ?? '';
  return value == 'TEACHER' ||
      value == 'CLASS_TEACHER' ||
      value == 'SUBJECT_TEACHER';
}

bool _canManageLeave(String? role) => const {
  'ADMINISTRATOR',
  'HEAD_TEACHER',
  'ASSISTANT_HEAD_TEACHER',
  'BURSAR',
  'SECRETARY',
  'ADMIN',
  'HEADMASTER',
  'OWNER',
}.contains(role?.trim().toUpperCase());

bool _canAcknowledgeAttendance(String? role) => const {
  'ADMINISTRATOR',
  'HEAD_TEACHER',
  'ADMIN',
  'HEADMASTER',
}.contains(role?.trim().toUpperCase());

bool _canManageCalendar(String? role) => const {
  'ADMINISTRATOR',
  'ADMIN',
  'HEADMASTER',
  'HEAD_TEACHER',
}.contains(role?.trim().toUpperCase());

bool _canSeeFinancialNotices(String? role) {
  final normalized = role?.trim().toUpperCase() ?? '';
  return const {
    'ADMINISTRATOR',
    'HEAD_TEACHER',
    'HEADMASTER',
    'BURSAR',
    'ACCOUNTANT',
  }.contains(normalized);
}

class _TeacherWorkspaceLanding extends StatefulWidget {
  const _TeacherWorkspaceLanding({
    required this.displayName,
    required this.role,
    required this.schoolId,
    required this.loadSummary,
    required this.events,
    required this.onOpenClasses,
    required this.onOpenClass,
    required this.onOpenAttendance,
    required this.onOpenAssessments,
    required this.onOpenIncidents,
    required this.onOpenMyLeave,
    required this.onOpenCalendar,
    required this.onOpenTermReview,
    required this.approvalInbox,
    required this.onOpenApprovals,
  });

  final String displayName;
  final String? role;
  final String schoolId;
  final Future<TeacherDashboardSummary> Function() loadSummary;
  final List<SchoolEvent> events;
  final VoidCallback onOpenClasses;
  final ValueChanged<TeacherClassAssignment> onOpenClass;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenAssessments;
  final VoidCallback onOpenIncidents;
  final VoidCallback onOpenMyLeave;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenTermReview;
  final Future<ApprovalInbox?> approvalInbox;
  final VoidCallback onOpenApprovals;

  @override
  State<_TeacherWorkspaceLanding> createState() =>
      _TeacherWorkspaceLandingState();
}

class _TeacherWorkspaceLandingState extends State<_TeacherWorkspaceLanding> {
  late Future<TeacherDashboardSummary> _summary = widget.loadSummary();

  Future<void> _reload() async {
    final next = widget.loadSummary();
    setState(() => _summary = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your classes, attendance, grading and upcoming updates in one place.',
                  style: TextStyle(color: Color(0xFF718096), fontSize: 16),
                ),
                const SizedBox(height: 26),
                FutureBuilder<TeacherDashboardSummary>(
                  future: _summary,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _TeacherDashboardLoadError(onRetry: _reload);
                    }
                    return FutureBuilder<ApprovalInbox?>(
                      future: widget.approvalInbox,
                      builder: (context, approvalSnapshot) =>
                          _dashboard(snapshot.data!, approvalSnapshot.data),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboard(
    TeacherDashboardSummary summary,
    ApprovalInbox? approvalInbox,
  ) {
    final workspace = summary.workspace;
    final classes = workspace.assignedClasses;
    final classNames = classes.map((item) => item.label).toList();
    final classCaption = classNames.isEmpty
        ? 'No active classes assigned'
        : '${classNames.take(2).join(' · ')}${classNames.length > 2 ? ' · +${classNames.length - 2} more' : ''}';
    final attendance = summary.attendance;
    final classTeacherAssignments = workspace.classes
        .where((assignment) => assignment.active && assignment.classTeacher)
        .toList();
    final hasAttendanceResponsibility = attendance != null
        ? attendance.assignedClasses > 0
        : classTeacherAssignments.isNotEmpty;
    final attendanceTitle = hasAttendanceResponsibility
        ? 'Today’s attendance'
        : 'Class attendance';
    final attendanceValue = attendance == null
        ? hasAttendanceResponsibility
              ? '—'
              : 'View attendance'
        : attendance.assignedClasses == 0
        ? 'View attendance'
        : attendance.schoolDay
        ? '${attendance.submittedClasses}/${attendance.assignedClasses} submitted'
        : 'Non-school day';
    final attendanceCaption = attendance == null
        ? hasAttendanceResponsibility
              ? 'Attendance status unavailable'
              : 'Take attendance when properly authorized'
        : attendance.assignedClasses == 0
        ? 'Take attendance when properly authorized'
        : attendance.schoolDay
        ? attendance.pendingClasses == 0
              ? 'All assigned registers completed'
              : '${attendance.pendingClasses} register${attendance.pendingClasses == 1 ? '' : 's'} still pending'
        : attendance.calendarMessage.isEmpty
        ? 'Today is not an official school day'
        : attendance.calendarMessage;
    final assessments = summary.assessments;
    final assessmentValue = assessments == null
        ? '—'
        : '${assessments.incompleteAssessments} incomplete';
    final assessmentCaption = assessments == null
        ? 'Assessment status unavailable'
        : '${assessments.outstandingScores} scores outstanding · ${assessments.totalAssessments} assessments';
    final concerns = summary.lateConcerns;
    final concernValue = concerns == null ? '—' : '${concerns.length} students';
    final concernCaption = concerns == null
        ? 'Student attention status unavailable'
        : concerns.isEmpty
        ? 'No repeated-lateness concerns'
        : 'Late for 2 consecutive school days or more';

    final correctionRequests =
        approvalInbox?.myRequests
            .where((item) => _isReportCorrectionItem(item) && item.pending)
            .toList() ??
        const <ApprovalItem>[];
    final tasks = <Widget>[];
    if (correctionRequests.isNotEmpty) {
      final first = correctionRequests.first;
      tasks.add(
        _TeacherDashboardListItem(
          icon: Icons.rule_folder_outlined,
          color: AppColors.amber,
          title:
              '${correctionRequests.length} active report correction ${correctionRequests.length == 1 ? 'request needs' : 'requests need'} attention',
          subtitle: '${first.title} · ${first.subtitle}',
          onTap: widget.onOpenApprovals,
        ),
      );
    }
    if (attendance != null &&
        attendance.schoolDay &&
        attendance.pendingClasses > 0) {
      tasks.add(
        _TeacherDashboardListItem(
          icon: Icons.fact_check_outlined,
          color: AppColors.amber,
          title:
              'Submit attendance for ${attendance.pendingClasses} class${attendance.pendingClasses == 1 ? '' : 'es'}',
          subtitle: 'Today’s attendance is still incomplete.',
          onTap: widget.onOpenAttendance,
        ),
      );
    }
    if (assessments != null && assessments.incompleteAssessments > 0) {
      tasks.add(
        _TeacherDashboardListItem(
          icon: Icons.assignment_outlined,
          color: AppColors.blue,
          title:
              '${assessments.incompleteAssessments} assessment${assessments.incompleteAssessments == 1 ? '' : 's'} need scores',
          subtitle:
              '${assessments.outstandingScores} student score${assessments.outstandingScores == 1 ? '' : 's'} remaining.',
          onTap: widget.onOpenAssessments,
        ),
      );
    }
    if (concerns != null && concerns.isNotEmpty) {
      tasks.add(
        _TeacherDashboardListItem(
          icon: Icons.person_search_outlined,
          color: AppColors.red,
          title:
              '${concerns.length} student${concerns.length == 1 ? '' : 's'} need attendance follow-up',
          subtitle: 'Review repeated lateness and escalate when necessary.',
          onTap: widget.onOpenAttendance,
        ),
      );
    }
    final followUps =
        summary.myIncidents
            ?.where((incident) => incident.followUpRequired)
            .length ??
        0;
    if (followUps > 0) {
      tasks.add(
        _TeacherDashboardListItem(
          icon: Icons.report_problem_outlined,
          color: AppColors.purple,
          title:
              '$followUps incident follow-up${followUps == 1 ? '' : 's'} due',
          subtitle: 'Open your reported incidents to continue the follow-up.',
          onTap: widget.onOpenIncidents,
        ),
      );
    }

    late final IconData focusIcon;
    late final String focusTitle;
    late final String focusSubtitle;
    late final String focusActionLabel;
    late final VoidCallback focusAction;
    if (correctionRequests.isNotEmpty) {
      final first = correctionRequests.first;
      focusIcon = Icons.notification_important_outlined;
      focusTitle = correctionRequests.length == 1
          ? _scoreCorrectionAttentionTitle(first, assignedToMe: false)
          : '${correctionRequests.length} report corrections need attention';
      focusSubtitle = '${first.title} · ${first.subtitle}';
      focusActionLabel = 'View request';
      focusAction = widget.onOpenApprovals;
    } else if (attendance != null &&
        attendance.schoolDay &&
        attendance.pendingClasses > 0) {
      focusIcon = Icons.fact_check_outlined;
      focusTitle =
          'Attendance is pending for ${attendance.pendingClasses} class${attendance.pendingClasses == 1 ? '' : 'es'}';
      focusSubtitle =
          'Complete today’s class registers before moving to assessment work.';
      focusActionLabel = 'Take attendance';
      focusAction = widget.onOpenAttendance;
    } else if (assessments != null && assessments.incompleteAssessments > 0) {
      focusIcon = Icons.assignment_turned_in_outlined;
      focusTitle =
          '${assessments.incompleteAssessments} assessment${assessments.incompleteAssessments == 1 ? '' : 's'} still need scores';
      focusSubtitle =
          '${assessments.outstandingScores} student score${assessments.outstandingScores == 1 ? '' : 's'} remain before grading is complete.';
      focusActionLabel = 'Continue grading';
      focusAction = widget.onOpenAssessments;
    } else if (concerns != null && concerns.isNotEmpty) {
      focusIcon = Icons.person_search_outlined;
      focusTitle =
          '${concerns.length} student${concerns.length == 1 ? '' : 's'} need attendance follow-up';
      focusSubtitle =
          'Review repeated lateness and escalate only when follow-up is needed.';
      focusActionLabel = 'Review students';
      focusAction = widget.onOpenAttendance;
    } else {
      focusIcon = Icons.check_circle_outline_rounded;
      focusTitle = 'You are up to date';
      focusSubtitle =
          'There are no urgent attendance, grading or student follow-up tasks.';
      focusActionLabel = 'Open my classes';
      focusAction = widget.onOpenClasses;
    }

    final updates = <Widget>[];
    for (final leave
        in (summary.upcomingLeave ?? const <TeacherLeaveUpdate>[]).take(2)) {
      updates.add(
        _TeacherDashboardListItem(
          icon: Icons.event_available_outlined,
          color: AppColors.green,
          title: leave.typeName,
          subtitle:
              '${_teacherDateRange(leave.startDate, leave.endDate)} · ${_teacherStatusLabel(leave.status)}',
          onTap: widget.onOpenMyLeave,
        ),
      );
    }
    final openIncidents =
        summary.myIncidents
            ?.where((incident) => _teacherIncidentIsOpen(incident.status))
            .take(2) ??
        const Iterable.empty();
    for (final incident in openIncidents) {
      updates.add(
        _TeacherDashboardListItem(
          icon: Icons.report_outlined,
          color: AppColors.red,
          title: incident.title,
          subtitle:
              'Incident · ${_teacherStatusLabel(incident.status)} · ${_teacherShortDate(incident.incidentDate)}',
          onTap: widget.onOpenIncidents,
        ),
      );
    }
    final today = DateTime.now();
    final upcomingEvents =
        widget.events
            .where(
              (event) => !event.endDate.isBefore(
                DateTime(today.year, today.month, today.day),
              ),
            )
            .toList()
          ..sort((left, right) => left.startDate.compareTo(right.startDate));
    for (final event in upcomingEvents.take(2)) {
      updates.add(
        _TeacherDashboardListItem(
          icon: Icons.calendar_month_outlined,
          color: AppColors.blue,
          title: event.title,
          subtitle:
              '${_teacherDateRange(event.startDate, event.endDate)} · ${event.category}',
          onTap: widget.onOpenCalendar,
        ),
      );
    }

    final subjectsByStream = <int, List<String>>{};
    for (final subject in workspace.subjects.where((item) => item.active)) {
      subjectsByStream
          .putIfAbsent(subject.streamId, () => <String>[])
          .add(subject.subjectName);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => _TeacherSummaryGrid(
            width: constraints.maxWidth,
            cards: [
              _TeacherSummaryCard(
                icon: Icons.groups_2_outlined,
                title: 'Classes assigned',
                value: '${classes.length}',
                caption: classCaption,
                onTap: widget.onOpenClasses,
              ),
              _TeacherSummaryCard(
                icon: Icons.fact_check_outlined,
                title: attendanceTitle,
                value: attendanceValue,
                caption: attendanceCaption,
                onTap: widget.onOpenAttendance,
              ),
              _TeacherSummaryCard(
                icon: Icons.assignment_outlined,
                title: 'Assessment tasks',
                value: assessmentValue,
                caption: assessmentCaption,
                onTap: widget.onOpenAssessments,
              ),
              _TeacherSummaryCard(
                icon: Icons.person_search_outlined,
                title: 'Students needing attention',
                value: concernValue,
                caption: concernCaption,
                onTap: widget.onOpenAttendance,
              ),
              _TeacherSummaryCard(
                icon: Icons.approval_outlined,
                title: 'Requests & approvals',
                value: '${approvalInbox?.pendingTotal ?? 0}',
                caption:
                    '${approvalInbox?.pendingMyRequests ?? 0} requests · ${approvalInbox?.pendingMyApproval ?? 0} approvals',
                onTap: widget.onOpenApprovals,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _TeacherFocusBanner(
          icon: focusIcon,
          title: focusTitle,
          subtitle: focusSubtitle,
          actionLabel: focusActionLabel,
          onAction: focusAction,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final nextTasks = _TeacherDashboardSection(
              title: 'Your next tasks',
              actionLabel: 'Term review',
              onAction: widget.onOpenTermReview,
              emptyText: 'You are up to date. No immediate teaching tasks.',
              children: tasks.take(5).toList(),
            );
            final updateSection = _TeacherDashboardSection(
              title: 'Updates & notices',
              actionLabel: 'Calendar',
              onAction: widget.onOpenCalendar,
              emptyText: 'No upcoming leave, open incidents or events.',
              children: updates.take(5).toList(),
            );
            return stacked
                ? Column(
                    children: [
                      nextTasks,
                      const SizedBox(height: 18),
                      updateSection,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: nextTasks),
                      const SizedBox(width: 18),
                      Expanded(child: updateSection),
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        _TeacherClassesPanel(
          classes: classes,
          subjectsByStream: subjectsByStream,
          onOpenAll: widget.onOpenClasses,
          onOpenClass: widget.onOpenClass,
        ),
      ],
    );
  }
}

class _TeacherSummaryGrid extends StatelessWidget {
  const _TeacherSummaryGrid({required this.width, required this.cards});

  final double width;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 1080
        ? 4
        : width >= 620
        ? 2
        : 1;
    const gap = 16.0;
    final cardWidth = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: cards
          .map((card) => SizedBox(width: cardWidth, child: card))
          .toList(),
    );
  }
}

class _TeacherSummaryCard extends StatelessWidget {
  const _TeacherSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: AppColors.green, size: 21),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 17,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navyDark,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherFocusBanner extends StatelessWidget {
  const _TeacherFocusBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final message = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFB8C4D6),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(actionLabel),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 22),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _TeacherClassesPanel extends StatelessWidget {
  const _TeacherClassesPanel({
    required this.classes,
    required this.subjectsByStream,
    required this.onOpenAll,
    required this.onOpenClass,
  });

  final List<TeacherClassAssignment> classes;
  final Map<int, List<String>> subjectsByStream;
  final VoidCallback onOpenAll;
  final ValueChanged<TeacherClassAssignment> onOpenClass;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My classes',
                    style: TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: onOpenAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 8),
            if (classes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'No active classes are assigned.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 960
                      ? 3
                      : constraints.maxWidth >= 580
                      ? 2
                      : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: classes.map((assignment) {
                      final subjects =
                          subjectsByStream[assignment.streamId] ?? const [];
                      final detail = subjects.isNotEmpty
                          ? subjects.take(3).join(' · ')
                          : assignment.classTeacher
                          ? 'Class teacher'
                          : 'Subject teacher';
                      final gradeParts = assignment.gradeName
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .toList();
                      final initials = gradeParts.length > 1
                          ? gradeParts
                                .take(2)
                                .map((part) => part[0])
                                .join()
                                .toUpperCase()
                          : gradeParts.isEmpty
                          ? 'CL'
                          : gradeParts.first.length > 1
                          ? gradeParts.first.substring(0, 2).toUpperCase()
                          : gradeParts.first.toUpperCase();
                      return SizedBox(
                        width: width,
                        child: Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onOpenClass(assignment),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.greenSoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: AppColors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          assignment.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          detail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TeacherDashboardSection extends StatelessWidget {
  const _TeacherDashboardSection({
    required this.title,
    required this.emptyText,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _TeacherDashboardListItem extends StatelessWidget {
  const _TeacherDashboardListItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 36,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _TeacherDashboardLoadError extends StatelessWidget {
  const _TeacherDashboardLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
              const SizedBox(height: 10),
              const Text('Your dashboard summaries could not be loaded.'),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _teacherIncidentIsOpen(String status) => !const {
  'CLOSED',
  'RESOLVED',
  'CLOSED_RESOLVED',
  'CLOSED_UNRESOLVED',
}.contains(status.trim().toUpperCase());

String _teacherStatusLabel(String value) => value
    .trim()
    .toLowerCase()
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _teacherDateRange(DateTime start, DateTime end) {
  final first = _teacherShortDate(start);
  final last = _teacherShortDate(end);
  return first == last ? first : '$first – $last';
}

String _teacherShortDate(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.data,
    this.collapsed = false,
    this.isDrawer = false,
    this.schoolName,
    this.role,
    this.roles = const [],
    this.onRoleChanged,
    required this.selectedPage,
    this.approvalInbox,
    this.shopAccess,
    required this.onSelectPage,
    this.onLogout,
    this.onCollapse,
  });
  final DashboardSnapshot data;
  final bool collapsed;
  final bool isDrawer;
  final String? schoolName;
  final String? role;
  final List<String> roles;
  final ValueChanged<String>? onRoleChanged;
  final _SchoolAdminPage selectedPage;
  final Future<ApprovalInbox?>? approvalInbox;
  final Future<bool>? shopAccess;
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
    final isBursar = role?.trim().toUpperCase() == 'BURSAR';
    final isTeacher = _isTeachingRole(role);
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
            if (roles.length > 1 && !collapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: DropdownButtonFormField<String>(
                  value: role?.trim().toUpperCase(),
                  isExpanded: true,
                  dropdownColor: AppColors.navyDark,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Workspace',
                    labelStyle: const TextStyle(color: Color(0xFF9DA8B8)),
                    prefixIcon: const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.green,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF202C3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: roles
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_displayRole(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onRoleChanged?.call(value);
                  },
                ),
              ),
            if (roles.length > 1 && collapsed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: PopupMenuButton<String>(
                  tooltip: 'Switch workspace',
                  onSelected: (value) => onRoleChanged?.call(value),
                  itemBuilder: (context) => roles
                      .map(
                        (value) => PopupMenuItem(
                          value: value,
                          child: Text(_displayRole(value)),
                        ),
                      )
                      .toList(),
                  child: const SizedBox(
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
                  FutureBuilder<ApprovalInbox?>(
                    future: approvalInbox,
                    builder: (context, snapshot) {
                      final inbox = snapshot.data;
                      return _SidebarButton(
                        icon: Icons.approval_outlined,
                        label: 'Requests & Approvals',
                        collapsed: collapsed,
                        collapsedBadgeCount: inbox?.pendingTotal ?? 0,
                        active: selectedPage == _SchoolAdminPage.approvals,
                        onTap: () => onSelectPage(_SchoolAdminPage.approvals),
                      );
                    },
                  ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.manage_history_rounded,
                      label: 'Audit & Activity',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.auditActivity,
                      onTap: () => onSelectPage(_SchoolAdminPage.auditActivity),
                    ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.assignment_ind_rounded,
                      label: 'Admissions',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.admissions,
                      onTap: () => onSelectPage(_SchoolAdminPage.admissions),
                    ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.school_rounded,
                      label: 'Students',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.students,
                      onTap: () => onSelectPage(_SchoolAdminPage.students),
                    ),
                  if (isTeacher)
                    _SidebarButton(
                      icon: Icons.class_outlined,
                      label: 'Classes',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.classes,
                      onTap: () => onSelectPage(_SchoolAdminPage.classes),
                    ),
                  if (isTeacher) ...[
                    _SidebarButton(
                      icon: Icons.assessment_outlined,
                      label: 'Assessments',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.assessments,
                      onTap: () => onSelectPage(_SchoolAdminPage.assessments),
                    ),
                    _SidebarButton(
                      icon: Icons.fact_check_outlined,
                      label: 'Evaluations & Comments',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.evaluations,
                      onTap: () => onSelectPage(_SchoolAdminPage.evaluations),
                    ),
                  ],
                  if (!isTeacher)
                    _SidebarButton(
                      icon: Icons.fact_check_outlined,
                      label: 'Student Attendance',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.attendance,
                      onTap: () => onSelectPage(_SchoolAdminPage.attendance),
                    ),
                  _SidebarButton(
                    icon: Icons.calendar_month_outlined,
                    label: 'School Calendar',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.calendar,
                    onTap: () => onSelectPage(_SchoolAdminPage.calendar),
                  ),
                  if (!isBursar && !isTeacher) ...[
                    _SidebarButton(
                      icon: Icons.badge_outlined,
                      label: 'Staff Attendance',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.staffAttendance,
                      onTap: () =>
                          onSelectPage(_SchoolAdminPage.staffAttendance),
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
                      label: 'Classes & Sections',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.classes,
                      onTap: () => onSelectPage(_SchoolAdminPage.classes),
                    ),
                  ],
                  _SidebarButton(
                    icon: Icons.event_note_outlined,
                    label: 'My Leave',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.myLeave,
                    onTap: () => onSelectPage(_SchoolAdminPage.myLeave),
                  ),
                  if (_canManageLeave(role))
                    _SidebarButton(
                      icon: Icons.event_available_outlined,
                      label: 'Leave Management',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.leave,
                      onTap: () => onSelectPage(_SchoolAdminPage.leave),
                    ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.assessment_outlined,
                      label: 'Assessments',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.assessments,
                      onTap: () => onSelectPage(_SchoolAdminPage.assessments),
                    ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.fact_check_outlined,
                      label: 'Evaluations & Comments',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.evaluations,
                      onTap: () => onSelectPage(_SchoolAdminPage.evaluations),
                    ),
                  if (!isBursar && !isTeacher)
                    _SidebarButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Final Report Management',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.finalReports,
                      onTap: () => onSelectPage(_SchoolAdminPage.finalReports),
                    ),
                  if (!isTeacher)
                    _SidebarButton(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Fees & Requirements',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.fees,
                      onTap: () => onSelectPage(_SchoolAdminPage.fees),
                    ),
                  if (!isTeacher)
                    _SidebarButton(
                      icon: Icons.storefront_outlined,
                      label: 'School Shop',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.shop,
                      onTap: () => onSelectPage(_SchoolAdminPage.shop),
                    )
                  else
                    FutureBuilder<bool>(
                      future: shopAccess,
                      builder: (context, snapshot) => snapshot.data == true
                          ? _SidebarButton(
                              icon: Icons.storefront_outlined,
                              label: 'School Shop',
                              collapsed: collapsed,
                              active: selectedPage == _SchoolAdminPage.shop,
                              onTap: () => onSelectPage(_SchoolAdminPage.shop),
                            )
                          : const SizedBox.shrink(),
                    ),
                  _SidebarButton(
                    icon: Icons.receipt_long_rounded,
                    label: isTeacher
                        ? 'My Requisitions & Expenses'
                        : 'Expenses & Petty Cash',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.expenses,
                    onTap: () => onSelectPage(_SchoolAdminPage.expenses),
                  ),
                  if (!isBursar) ...[
                    _SidebarButton(
                      icon: Icons.warning_amber_rounded,
                      label: isTeacher ? 'My Incidents' : 'Incident Management',
                      collapsed: collapsed,
                      active: selectedPage == _SchoolAdminPage.incidents,
                      onTap: () => onSelectPage(_SchoolAdminPage.incidents),
                    ),
                    if (!isTeacher)
                      _SidebarButton(
                        icon: Icons.campaign_rounded,
                        label: 'Communication',
                        collapsed: collapsed,
                      ),
                  ],
                  if (!isTeacher)
                    _SidebarButton(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      collapsed: collapsed,
                    ),
                  _SidebarButton(
                    icon: Icons.event_available_outlined,
                    label: 'Term Review',
                    collapsed: collapsed,
                    active: selectedPage == _SchoolAdminPage.termReview,
                    onTap: () => onSelectPage(_SchoolAdminPage.termReview),
                  ),
                  if (!isBursar && !isTeacher)
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
    this.collapsedBadgeCount = 0,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final int collapsedBadgeCount;
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
                  if (collapsed && collapsedBadgeCount > 0)
                    Badge.count(
                      count: collapsedBadgeCount,
                      backgroundColor: const Color(0xFFF5A623),
                      textColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                      child: Icon(icon, size: 20, color: Colors.white),
                    )
                  else
                    Icon(icon, size: 20, color: Colors.white),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (collapsedBadgeCount > 0) ...[
                      const SizedBox(width: 8),
                      Badge.count(
                        key: const ValueKey(
                          'requests-approvals-navigation-badge',
                        ),
                        count: collapsedBadgeCount,
                        backgroundColor: AppColors.red,
                        textColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
