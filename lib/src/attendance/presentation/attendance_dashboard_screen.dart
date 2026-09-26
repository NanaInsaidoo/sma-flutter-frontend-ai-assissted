import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/attendance_models.dart';
import 'attendance_report_export.dart';
import 'attendance_screen.dart';

enum _AttendancePeriod { today, recent, custom }

enum _AttendanceClassSort {
  className,
  students,
  present,
  absent,
  late,
  status,
  submittedAt,
}

class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({
    super.key,
    required this.customSchoolId,
    required this.repository,
    this.academicYear,
    this.term,
    this.schoolName,
    this.viewerRole,
    this.onOpenCalendar,
    this.canAcknowledge = false,
  });

  final String customSchoolId;
  final String? academicYear;
  final String? term;
  final String? schoolName;
  final String? viewerRole;
  final AttendanceRepository repository;
  final VoidCallback? onOpenCalendar;
  final bool canAcknowledge;

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  late Future<AttendanceDashboardOverview> _overviewFuture;
  AttendanceDashboardOverview? _overview;
  _AttendancePeriod _period = _AttendancePeriod.today;
  DateTime? _todayDate;
  DateTime? _selectedDate;
  DateTime? _customDate;
  List<DateTime> _recentSchoolDates = const [];
  _ClassAttendanceSummary? _openClass;
  bool _showSubmissionBanner = true;
  bool _acknowledging = false;
  bool _showReports = false;
  bool _openAuthorizedClass = false;
  String _classQuery = '';
  String? _levelFilter;
  AttendanceRegisterStatus? _statusFilter;
  _AttendanceClassSort _classSort = _AttendanceClassSort.status;
  bool _classSortAscending = true;
  final Set<int> _selectedClassIds = {};

  @override
  void initState() {
    super.initState();
    _overviewFuture = widget.repository.getOverview(widget.customSchoolId);
  }

  void _reloadOverview() {
    _loadOverview(date: _selectedDate);
  }

  void _loadOverview({DateTime? date}) {
    setState(() {
      _overview = null;
      _selectedDate = date;
      _selectedClassIds.clear();
      _overviewFuture = date == null
          ? widget.repository.getOverview(widget.customSchoolId)
          : widget.repository.getOverviewForDate(widget.customSchoolId, date);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_openAuthorizedClass) {
      return AttendanceScreen(
        customSchoolId: widget.customSchoolId,
        academicYear: widget.academicYear,
        term: widget.term,
        repository: widget.repository,
        initialDate: _selectedDate ?? _overview?.currentDate,
        showClassSelectors: true,
        onOpenCalendar: widget.onOpenCalendar,
        onBack: () => setState(() => _openAuthorizedClass = false),
      );
    }
    final selected = _openClass;
    if (selected != null) {
      return AttendanceScreen(
        customSchoolId: widget.customSchoolId,
        academicYear: widget.academicYear,
        term: widget.term,
        repository: widget.repository,
        initialGradeLevelId: selected.gradeId,
        initialStreamId: selected.streamId,
        initialDate: _selectedDate ?? _overview?.currentDate,
        showClassSelectors: false,
        onOpenCalendar: widget.onOpenCalendar,
        onBack: () => setState(() => _openClass = null),
      );
    }

    if (_showReports && _overview != null) {
      return _AttendanceReportsView(
        customSchoolId: widget.customSchoolId,
        schoolName: widget.schoolName,
        repository: widget.repository,
        classes: _liveClasses,
        term: _overview!.term,
        termScope: _termScope,
        onBack: () => setState(() => _showReports = false),
      );
    }

    return FutureBuilder<AttendanceDashboardOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: AppColors.background,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ColoredBox(
            color: AppColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.red,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reloadOverview,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        _overview = snapshot.data;
        _todayDate ??= snapshot.data!.currentDate;
        _selectedDate ??= snapshot.data!.currentDate;
        if (_recentSchoolDates.isEmpty &&
            snapshot.data!.recentSchoolDates.isNotEmpty) {
          _recentSchoolDates = snapshot.data!.recentSchoolDates;
        }
        return ColoredBox(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 14),
                    _termAttendanceSummary(),
                    if (_overview?.schoolDay == false) ...[
                      const SizedBox(height: 18),
                      _nonSchoolDayBanner(),
                    ],
                    if (_showSubmissionBanner &&
                        _liveClasses.any((item) => item.pending)) ...[
                      const SizedBox(height: 18),
                      _submissionBanner(),
                    ],
                    const SizedBox(height: 18),
                    _dateAndPeriod(),
                    const SizedBox(height: 14),
                    _workflowSummary(),
                    const SizedBox(height: 14),
                    _stats(),
                    const SizedBox(height: 16),
                    _classesCard(),
                    const SizedBox(height: 16),
                    _alertsCard(),
                    const SizedBox(height: 16),
                    _quickActions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _termAttendanceSummary() {
    final summary = _overview!.term;
    final attendanceRate = summary.attendanceRate.clamp(0, 100).toDouble();
    final hasAttendance = summary.totalStudents > 0;
    final concerns = summary.studentsNeedingAttention;
    final termLabel = widget.term?.trim().isNotEmpty == true
        ? widget.term!.trim()
        : 'Current term';

    final statusColor = !hasAttendance
        ? AppColors.muted
        : concerns == 0
        ? AppColors.green
        : AppColors.amber;
    final statusIcon = !hasAttendance
        ? Icons.info_outline_rounded
        : concerns == 0
        ? Icons.check_circle_outline_rounded
        : Icons.warning_amber_rounded;
    final statusText = !hasAttendance
        ? 'No term attendance recorded yet'
        : concerns == 0
        ? 'No attendance concerns'
        : '$concerns ${concerns == 1 ? 'student needs' : 'students need'} follow-up';

    final heading = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.fact_check_outlined, color: AppColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Term attendance summary',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                termLabel,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );

    final metric = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${attendanceRate.toStringAsFixed(1)}%',
          key: const ValueKey('term-attendance-rate'),
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text(
          'Term-to-date attendance',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: attendanceRate / 100,
            backgroundColor: const Color(0xFFE8EEEC),
            valueColor: const AlwaysStoppedAnimation(AppColors.green),
          ),
        ),
      ],
    );

    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 17, color: statusColor),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      key: const ValueKey('term-attendance-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 14),
                  metric,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: status),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 260, child: heading),
                const SizedBox(width: 24),
                Expanded(child: metric),
                const SizedBox(width: 24),
                status,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _nonSchoolDayBanner() {
    return Container(
      key: const ValueKey('attendance-dashboard-non-school-day'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: AppColors.red.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Icon(Icons.event_busy_outlined, color: AppColors.red),
          Text(
            _overview?.calendarMessage.trim().isNotEmpty == true
                ? _overview!.calendarMessage.replaceFirst(
                    'This date',
                    _isShowingToday ? 'Today' : 'This date',
                  )
                : _isShowingToday
                ? 'Today is not an official school day per the school calendar.'
                : 'This date is not an official school day per the school calendar.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextButton.icon(
            key: const ValueKey('dashboard-view-non-school-days'),
            onPressed: widget.onOpenCalendar,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('View non-school days'),
          ),
        ],
      ),
    );
  }

  List<_ClassAttendanceSummary>
  get _liveClasses => (_overview?.classes ?? const <AttendanceClassSummary>[])
      .map(
        (item) => _ClassAttendanceSummary(
          group: _gradeGroup(item.gradeName),
          gradeId: item.gradeId,
          streamId: item.streamId,
          code: _classCode(item.gradeName, item.streamName),
          name:
              '${item.gradeName} · ${_sectionLabel(item.gradeName, item.streamName)}',
          teacher: item.teacherName.isEmpty
              ? 'Class teacher not assigned'
              : item.teacherName,
          totalStudents: item.totalStudents,
          present: item.present,
          absent: item.absent,
          late: item.late,
          percentage: item.totalStudents == 0
              ? 0
              : ((item.present + item.late) / item.totalStudents) * 100,
          status: _overview?.schoolDay == false
              ? AttendanceRegisterStatus.nonSchoolDay
              : (!item.submitted ||
                    item.present + item.absent + item.late < item.totalStudents)
              ? AttendanceRegisterStatus.notSubmitted
              : item.registerStatus,
          acknowledgedBy: item.acknowledgedBy,
          acknowledgmentNote: item.acknowledgmentNote,
          submittedBy: item.submittedBy,
          submittedAt: item.submittedAt,
        ),
      )
      .toList();

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _teacherView ? 'My Class Attendance' : 'School Attendance',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '${_teacherView ? 'Assigned class registers and authorized cover' : 'Track and manage attendance'}${_termScope.isEmpty ? '' : ' · $_termScope'}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (widget.canAcknowledge &&
                _liveClasses.any((item) => item.awaitingAcknowledgment))
              OutlinedButton.icon(
                key: const ValueKey('acknowledge-attendance-registers'),
                onPressed: _acknowledging ? null : _openAcknowledgmentDialog,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Acknowledge registers'),
              ),
            FilledButton.icon(
              key: const ValueKey('mark-attendance'),
              onPressed: _openClassChooser,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_teacherView ? 'Mark my class' : 'Mark attendance'),
            ),
            if (_teacherView)
              OutlinedButton.icon(
                key: const ValueKey('take-authorized-class-attendance'),
                onPressed: _openAuthorizedClassRegister,
                icon: const Icon(Icons.add_moderator_outlined),
                label: const Text('Take another class'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _submissionBanner() {
    final pending = _liveClasses.where((item) => item.pending).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        border: Border.all(color: AppColors.amber.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              '${pending.length} classes have not submitted attendance ${_isShowingToday ? 'today' : 'for this date'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            key: const ValueKey('view-pending-attendance-classes'),
            onPressed: () => _showPendingClasses(pending),
            child: const Text('View classes'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _showSubmissionBanner = false),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _workflowSummary() {
    if (_overview?.schoolDay == false) {
      return Container(
        key: const ValueKey('attendance-workflow-non-school-day'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_outlined, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Non-school day · no class registers are expected',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }
    final classes = _liveClasses;
    final notSubmitted = classes.where((item) => item.pending).length;
    final awaiting = classes
        .where((item) => item.awaitingAcknowledgment)
        .length;
    final complete = classes
        .where((item) => item.status == AttendanceRegisterStatus.complete)
        .length;
    return Wrap(
      key: const ValueKey('attendance-workflow-summary'),
      spacing: 10,
      runSpacing: 10,
      children: [
        _workflowCount('Not submitted', notSubmitted, AppColors.amber),
        _workflowCount('Awaiting acknowledgment', awaiting, AppColors.blue),
        _workflowCount('Complete', complete, AppColors.green),
      ],
    );
  }

  Widget _workflowCount(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _showPendingClasses(
    List<_ClassAttendanceSummary> pending,
  ) async {
    final selected = await showDialog<_ClassAttendanceSummary>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pending attendance (${pending.length})'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: ListView.separated(
            itemCount: pending.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = pending[index];
              return ListTile(
                key: ValueKey('pending-attendance-${item.streamId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(item.teacher),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _message('Reminders sent to the class teachers.');
            },
            child: const Text('Remind all'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selected != null) _openRegister(selected);
  }

  Future<void> _openAcknowledgmentDialog({Set<int>? initialSelection}) async {
    final awaiting = _liveClasses
        .where((item) => item.awaitingAcknowledgment)
        .toList();
    if (awaiting.isEmpty) return;
    final selection = await showDialog<_AcknowledgmentSelection>(
      context: context,
      builder: (_) => _AttendanceAcknowledgmentDialog(
        classes: awaiting,
        initialSelection: initialSelection ?? const <int>{},
      ),
    );
    if (selection == null || !mounted) return;
    setState(() => _acknowledging = true);
    try {
      await widget.repository.acknowledgeAttendance(
        customSchoolId: widget.customSchoolId,
        date: _overview!.currentDate,
        streamIds: selection.streamIds,
        note: selection.note,
      );
      if (!context.mounted) return;
      _message(
        '${selection.streamIds.length} attendance register${selection.streamIds.length == 1 ? '' : 's'} acknowledged.',
      );
      _selectedClassIds.clear();
      _reloadOverview();
    } catch (error) {
      if (mounted) _message('Could not acknowledge attendance. $error');
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Widget _dateAndPeriod() {
    final date = Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: AppColors.muted,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _friendlyDate(
              _selectedDate ?? _overview?.currentDate ?? DateTime.now(),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    Widget tabs() => SegmentedButton<_AttendancePeriod>(
      key: const ValueKey('attendance-period-tabs'),
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(value: _AttendancePeriod.today, label: Text('Today')),
        ButtonSegment(
          value: _AttendancePeriod.recent,
          label: Text('Recent days'),
        ),
        ButtonSegment(
          value: _AttendancePeriod.custom,
          label: Text('Choose date'),
        ),
      ],
      selected: {_period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => _selectPeriod(selection.first),
    );
    Widget compactTabs() {
      const items = [
        (_AttendancePeriod.today, 'Today'),
        (_AttendancePeriod.recent, 'Recent days'),
        (_AttendancePeriod.custom, 'Choose date'),
      ];
      return Container(
        key: const ValueKey('attendance-period-tabs'),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: items.map((item) {
            final selected = _period == item.$1;
            return Expanded(
              child: TextButton(
                onPressed: () => _selectPeriod(item.$1),
                style: TextButton.styleFrom(
                  foregroundColor: selected ? Colors.white : AppColors.text,
                  backgroundColor: selected ? AppColors.green : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(
                  item.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  date,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: compactTabs()),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: date),
                const SizedBox(width: 16),
                tabs(),
              ],
            );
          },
        ),
        if (_period != _AttendancePeriod.today) ...[
          const SizedBox(height: 12),
          _dateSelector(),
        ],
      ],
    );
  }

  Future<void> _selectPeriod(_AttendancePeriod period) async {
    if (period == _AttendancePeriod.today) {
      setState(() {
        _period = period;
        _customDate = null;
      });
      _loadOverview();
      return;
    }

    if (period == _AttendancePeriod.recent) {
      final recent = _recentSchoolDates.isNotEmpty
          ? _recentSchoolDates
          : _fallbackRecentDates(_todayDate ?? DateTime.now());
      setState(() {
        _period = period;
        _customDate = null;
      });
      if (recent.isNotEmpty) _loadOverview(date: recent.first);
      return;
    }

    final today = DateUtils.dateOnly(_todayDate ?? DateTime.now());
    final firstDate = DateTime(today.year - 1, today.month, today.day);
    var initialDate = DateUtils.dateOnly(_customDate ?? _selectedDate ?? today);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(today)) initialDate = today;
    final date = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today,
      currentDate: today,
      initialDate: initialDate,
      helpText: 'Select attendance date',
      confirmText: 'Show attendance',
    );
    if (date == null || !mounted) return;
    if (_sameDate(date, today)) {
      setState(() {
        _period = _AttendancePeriod.today;
        _customDate = null;
      });
      _loadOverview();
      return;
    }
    setState(() {
      _period = period;
      _customDate = date;
    });
    _loadOverview(date: date);
  }

  Widget _dateSelector() {
    final dates = _period == _AttendancePeriod.recent
        ? (_recentSchoolDates.isNotEmpty
              ? _recentSchoolDates
              : _fallbackRecentDates(_todayDate ?? DateTime.now()))
        : _customDate == null
        ? const <DateTime>[]
        : <DateTime>[_customDate!];
    final description = _period == _AttendancePeriod.recent
        ? 'Select one of the five most recent school days'
        : _customDate == null
        ? 'Select a date'
        : 'Selected date: ${_shortDate(_customDate!)}';
    return Container(
      key: const ValueKey('attendance-date-selector'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_period == _AttendancePeriod.custom)
                TextButton.icon(
                  key: const ValueKey('change-attendance-date'),
                  onPressed: () => _selectPeriod(_AttendancePeriod.custom),
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: const Text('Change date'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in dates) ...[
                  ChoiceChip(
                    key: ValueKey('attendance-date-${_dateKey(item)}'),
                    label: Text(
                      _sameDate(item, _todayDate)
                          ? 'Today · ${_dateChipLabel(item)}'
                          : _dateChipLabel(item),
                    ),
                    selected: _sameDate(item, _selectedDate),
                    onSelected: (_) {
                      if (!_sameDate(item, _selectedDate)) {
                        _loadOverview(date: item);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<DateTime> _fallbackRecentDates(DateTime today) {
    final result = <DateTime>[];
    var date = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    while (result.length < 5) {
      if (date.weekday <= DateTime.friday) result.add(date);
      date = date.subtract(const Duration(days: 1));
    }
    return result;
  }

  Widget _stats() {
    final summary = _overview!.today;
    final periodDetail = _isShowingToday ? 'Today' : 'Selected date';
    final displayedAttendanceRate = summary.totalStudents == 0
        ? 0.0
        : ((summary.present + summary.late) / summary.totalStudents) * 100;
    final items = [
      _DashboardStat(
        label: 'Overall attendance',
        value: '${displayedAttendanceRate.toStringAsFixed(1)}%',
        detail: periodDetail,
        icon: Icons.insights_rounded,
        color: AppColors.green,
        accent: true,
      ),
      _DashboardStat(
        label: 'Present',
        value: '${summary.present}',
        detail: _isShowingToday
            ? 'of ${summary.totalStudents} students'
            : periodDetail,
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.green,
      ),
      _DashboardStat(
        label: 'Absent',
        value: '${summary.absent}',
        detail: 'Requires follow-up',
        icon: Icons.person_off_outlined,
        color: AppColors.red,
      ),
      _DashboardStat(
        label: 'Late',
        value: '${summary.late}',
        detail: 'Arrived after roll call',
        icon: Icons.schedule_outlined,
        color: AppColors.amber,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 2 : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(width: width, child: _statCard(item)))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(_DashboardStat item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: item.accent
            ? const LinearGradient(colors: [AppColors.green, Color(0xFF18786D)])
            : null,
        color: item.accent ? null : Colors.white,
        border: Border.all(
          color: item.accent ? Colors.transparent : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accent
                  ? Colors.white.withValues(alpha: .16)
                  : item.color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              item.icon,
              color: item.accent ? Colors.white : item.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.accent
                        ? Colors.white.withValues(alpha: .75)
                        : AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  item.value,
                  style: TextStyle(
                    color: item.accent ? Colors.white : item.color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.accent
                        ? Colors.white.withValues(alpha: .65)
                        : AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classesCard() {
    final classes = _filteredClasses;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            icon: Icons.menu_book_outlined,
            title: 'Attendance by grade and stream',
            action: _smallPill(
              '${classes.length} of ${_liveClasses.length} classes',
              AppColors.green,
            ),
          ),
          _classTableFilters(),
          if (_selectedClassIds.isNotEmpty) _selectedClassesBar(),
          const Divider(height: 1),
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 34,
                    color: AppColors.muted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No classes match these filters.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 760
                  ? Column(children: classes.map(_classCardRow).toList())
                  : _classTable(classes, constraints.maxWidth),
            ),
        ],
      ),
    );
  }

  List<_ClassAttendanceSummary> get _filteredClasses {
    final query = _classQuery.trim().toLowerCase();
    final result = _liveClasses.where((item) {
      if (_levelFilter != null && item.group != _levelFilter) return false;
      if (_statusFilter != null && item.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.code.toLowerCase().contains(query);
    }).toList();
    result.sort((first, second) {
      final comparison = switch (_classSort) {
        _AttendanceClassSort.className => first.name.compareTo(second.name),
        _AttendanceClassSort.students => first.totalStudents.compareTo(
          second.totalStudents,
        ),
        _AttendanceClassSort.present => first.present.compareTo(second.present),
        _AttendanceClassSort.absent => first.absent.compareTo(second.absent),
        _AttendanceClassSort.late => first.late.compareTo(second.late),
        _AttendanceClassSort.status => _statusRank(
          first.status,
        ).compareTo(_statusRank(second.status)),
        _AttendanceClassSort.submittedAt => _nullableDateCompare(
          first.submittedAt,
          second.submittedAt,
        ),
      };
      final ordered = _classSortAscending ? comparison : -comparison;
      return ordered == 0 ? first.name.compareTo(second.name) : ordered;
    });
    return result;
  }

  Widget _classTableFilters() {
    final levels = _liveClasses.map((item) => item.group).toSet().toList()
      ..sort(
        (first, second) => _levelRank(first).compareTo(_levelRank(second)),
      );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('attendance-class-search'),
            onChanged: (value) => setState(() => _classQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search classes',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          );
          final level = DropdownButtonFormField<String?>(
            key: const ValueKey('attendance-level-filter'),
            value: _levelFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'School level'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All levels', overflow: TextOverflow.ellipsis),
              ),
              ...levels.map(
                (item) => DropdownMenuItem<String?>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _levelFilter = value),
          );
          final status = DropdownButtonFormField<AttendanceRegisterStatus?>(
            key: const ValueKey('attendance-status-filter'),
            value: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem<AttendanceRegisterStatus?>(
                value: null,
                child: Text('All statuses', overflow: TextOverflow.ellipsis),
              ),
              ...AttendanceRegisterStatus.values.map(
                (item) => DropdownMenuItem<AttendanceRegisterStatus?>(
                  value: item,
                  child: Text(
                    _statusLabel(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          );
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: level),
                    const SizedBox(width: 10),
                    Expanded(child: status),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 12),
              Expanded(child: level),
              const SizedBox(width: 12),
              Expanded(child: status),
            ],
          );
        },
      ),
    );
  }

  Widget _selectedClassesBar() {
    return Container(
      key: const ValueKey('attendance-selected-classes-bar'),
      color: AppColors.greenSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedClassIds.length} register${_selectedClassIds.length == 1 ? '' : 's'} selected',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => setState(_selectedClassIds.clear),
            child: const Text('Clear'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            key: const ValueKey('acknowledge-selected-attendance'),
            onPressed: _acknowledging
                ? null
                : () => _openAcknowledgmentDialog(
                    initialSelection: _selectedClassIds,
                  ),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Acknowledge selected'),
          ),
        ],
      ),
    );
  }

  Widget _classTable(
    List<_ClassAttendanceSummary> classes,
    double availableWidth,
  ) {
    final reviewableIds = classes
        .where((item) => item.awaitingAcknowledgment)
        .map((item) => item.streamId)
        .toSet();
    final selectedVisible = reviewableIds.intersection(_selectedClassIds);
    final allSelected =
        reviewableIds.isNotEmpty &&
        selectedVisible.length == reviewableIds.length;
    return SingleChildScrollView(
      key: const ValueKey('attendance-class-table-scroll'),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: availableWidth),
        child: DataTable(
          key: const ValueKey('attendance-class-table'),
          showCheckboxColumn: false,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _classSortAscending,
          headingRowHeight: 48,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 64,
          horizontalMargin: 16,
          columnSpacing: 24,
          dividerThickness: .6,
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF3F7F6)),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: .3,
          ),
          columns: [
            DataColumn(
              label: widget.canAcknowledge && reviewableIds.isNotEmpty
                  ? SizedBox(
                      width: 36,
                      child: Checkbox(
                        key: const ValueKey(
                          'select-all-visible-attendance-registers',
                        ),
                        tristate: true,
                        value: selectedVisible.isEmpty
                            ? false
                            : allSelected
                            ? true
                            : null,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selectedClassIds.addAll(reviewableIds);
                          } else {
                            _selectedClassIds.removeAll(reviewableIds);
                          }
                        }),
                      ),
                    )
                  : const SizedBox(width: 36),
            ),
            _classSortColumn('Class', _AttendanceClassSort.className),
            _classSortColumn(
              'Students',
              _AttendanceClassSort.students,
              numeric: true,
            ),
            _classSortColumn(
              'Present',
              _AttendanceClassSort.present,
              numeric: true,
            ),
            _classSortColumn(
              'Absent',
              _AttendanceClassSort.absent,
              numeric: true,
            ),
            _classSortColumn('Late', _AttendanceClassSort.late, numeric: true),
            _classSortColumn('Status', _AttendanceClassSort.status),
            _classSortColumn('Time', _AttendanceClassSort.submittedAt),
            const DataColumn(label: Text('ACTION')),
          ],
          rows: [
            for (var index = 0; index < classes.length; index++)
              _classTableRow(classes[index], index),
          ],
        ),
      ),
    );
  }

  DataColumn _classSortColumn(
    String label,
    _AttendanceClassSort sort, {
    bool numeric = false,
  }) {
    return DataColumn(
      numeric: numeric,
      tooltip: 'Sort by ${label.toLowerCase()}',
      onSort: (_, ascending) => setState(() {
        if (_classSort == sort) {
          _classSortAscending = ascending;
        } else {
          _classSort = sort;
          _classSortAscending = true;
        }
      }),
      label: Text(label.toUpperCase()),
    );
  }

  DataRow _classTableRow(_ClassAttendanceSummary item, int index) {
    final selected = _selectedClassIds.contains(item.streamId);
    final canSelect = widget.canAcknowledge && item.awaitingAcknowledgment;
    void open() => _openRegister(item);
    return DataRow(
      selected: selected,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.greenSoft
            : states.contains(WidgetState.hovered)
            ? AppColors.greenSoft.withValues(alpha: .55)
            : index.isOdd
            ? const Color(0xFFFAFCFC)
            : Colors.white,
      ),
      cells: [
        DataCell(
          SizedBox(
            width: 36,
            child: canSelect
                ? Checkbox(
                    key: ValueKey(
                      'select-attendance-register-${item.streamId}',
                    ),
                    value: selected,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selectedClassIds.add(item.streamId);
                      } else {
                        _selectedClassIds.remove(item.streamId);
                      }
                    }),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        DataCell(
          Row(
            key: ValueKey('attendance-class-${item.streamId}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      item.code,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          onTap: open,
        ),
        DataCell(Text('${item.totalStudents}'), onTap: open),
        DataCell(Text('${item.present}'), onTap: open),
        DataCell(Text('${item.absent}'), onTap: open),
        DataCell(Text('${item.late}'), onTap: open),
        DataCell(
          _smallPill(_statusLabel(item.status), _statusColor(item.status)),
          onTap: open,
        ),
        DataCell(Text(_submissionTime(item.submittedAt)), onTap: open),
        DataCell(
          TextButton(onPressed: open, child: Text(_classActionLabel(item))),
        ),
      ],
    );
  }

  Widget _classCardRow(_ClassAttendanceSummary item) {
    final color = _statusColor(item.status);
    final selected = _selectedClassIds.contains(item.streamId);
    final canSelect = widget.canAcknowledge && item.awaitingAcknowledgment;
    return InkWell(
      key: ValueKey('attendance-class-${item.streamId}'),
      onTap: () => _openRegister(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (canSelect) ...[
              Checkbox(
                value: selected,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedClassIds.add(item.streamId);
                  } else {
                    _selectedClassIds.remove(item.streamId);
                  }
                }),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _classStatusDetail(item),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _smallPill(_statusLabel(item.status), color),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  String _classStatusDetail(_ClassAttendanceSummary item) {
    return switch (item.status) {
      AttendanceRegisterStatus.notSubmitted =>
        '${item.present + item.absent + item.late} of ${item.totalStudents} students marked',
      AttendanceRegisterStatus.awaitingAcknowledgment =>
        '${item.present} present · ${item.absent} absent · ${item.late} late',
      AttendanceRegisterStatus.complete =>
        item.acknowledgedBy.isEmpty
            ? '${item.present} present · ${item.absent} absent · ${item.late} late · acknowledged'
            : 'Acknowledged by ${item.acknowledgedBy}',
      AttendanceRegisterStatus.nonSchoolDay =>
        'No attendance is required for this date',
    };
  }

  String _statusLabel(AttendanceRegisterStatus status) => switch (status) {
    AttendanceRegisterStatus.notSubmitted => 'Not submitted',
    AttendanceRegisterStatus.awaitingAcknowledgment =>
      'Awaiting acknowledgment',
    AttendanceRegisterStatus.complete => 'Complete',
    AttendanceRegisterStatus.nonSchoolDay => 'Non-school day',
  };

  Color _statusColor(AttendanceRegisterStatus status) => switch (status) {
    AttendanceRegisterStatus.notSubmitted => AppColors.amber,
    AttendanceRegisterStatus.awaitingAcknowledgment => AppColors.blue,
    AttendanceRegisterStatus.complete => AppColors.green,
    AttendanceRegisterStatus.nonSchoolDay => AppColors.muted,
  };

  Widget _alertsCard() {
    final alerts = (_overview?.alerts ?? const <AttendanceAlert>[])
        .where((alert) => !_isSubmissionAlert(alert))
        .toList();
    final visibleAlerts = alerts.take(3).toList();
    return Card(
      key: const ValueKey('attendance-alerts-card'),
      child: Column(
        children: [
          _cardHeader(
            icon: Icons.notifications_none_rounded,
            title: 'Recent alerts',
            action: _smallPill('${alerts.length} active', AppColors.red),
          ),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No attendance alerts for this period.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final alert in visibleAlerts) _alertRow(alert),
          if (alerts.length > visibleAlerts.length)
            TextButton(
              key: const ValueKey('view-all-attendance-alerts'),
              onPressed: () => _showAllAlerts(alerts),
              child: Text('View all ${alerts.length} alerts →'),
            ),
        ],
      ),
    );
  }

  Widget _alertRow(AttendanceAlert alert) {
    final color = alert.severity.toLowerCase() == 'high'
        ? AppColors.red
        : AppColors.amber;
    return InkWell(
      onTap: () => _openAlert(alert),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title.isEmpty ? 'Attendance alert' : alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  if (alert.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _friendlyDate(alert.timestamp!),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  bool _isSubmissionAlert(AttendanceAlert alert) {
    final text = '${alert.title} ${alert.message}'.toLowerCase();
    return text.contains('not submitted') ||
        text.contains('not been submitted') ||
        text.contains('pending submission') ||
        text.contains('attendance pending') ||
        text.contains('submit attendance');
  }

  void _openAlert(AttendanceAlert alert) {
    _ClassAttendanceSummary? target;
    for (final item in _liveClasses) {
      if (item.gradeId == alert.gradeId && item.streamId == alert.streamId) {
        target = item;
        break;
      }
    }
    if (target != null) {
      _openRegister(target);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title.isEmpty ? 'Attendance alert' : alert.title),
        content: Text(alert.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllAlerts(List<AttendanceAlert> alerts) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance alerts (${alerts.length})'),
        content: SizedBox(
          width: 520,
          height: 440,
          child: ListView.separated(
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  alert.title.isEmpty ? 'Attendance alert' : alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  alert.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _openAlert(alert);
                },
              );
            },
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

  Widget _quickActions() {
    final actions = _teacherView
        ? [
            (
              _subjectTeacherView ? 'Take attendance' : 'My class attendance',
              _subjectTeacherView
                  ? 'Use confirmed authorization'
                  : 'Open an assigned class register',
              Icons.fact_check_outlined,
              AppColors.green,
              _subjectTeacherView
                  ? _openAuthorizedClassRegister
                  : _openClassChooser,
            ),
            (
              'Another class',
              'Confirm authorization before submitting',
              Icons.add_moderator_outlined,
              AppColors.amber,
              _openAuthorizedClassRegister,
            ),
            if (!_subjectTeacherView)
              (
                'My reports',
                'Assigned-class attendance only',
                Icons.bar_chart_rounded,
                AppColors.blue,
                () => setState(() => _showReports = true),
              ),
          ]
        : [
            (
              'Take attendance',
              'Mark a class register',
              Icons.fact_check_outlined,
              AppColors.green,
              _openClassChooser,
            ),
            (
              'View reports',
              'Detailed analytics',
              Icons.bar_chart_rounded,
              AppColors.blue,
              () => setState(() => _showReports = true),
            ),
            (
              'Absent students',
              'Review and contact guardians',
              Icons.person_off_outlined,
              AppColors.red,
              () => _message('Absent students view opened.'),
            ),
            (
              'Trends',
              'Review attendance patterns',
              Icons.trending_up_rounded,
              AppColors.amber,
              () => _message('Attendance trends view opened.'),
            ),
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 2 : 4;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    child: InkWell(
                      onTap: item.$5,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: item.$4.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(item.$3, color: item.$4),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _cardHeader({
    required IconData icon,
    required String title,
    required Widget action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          action,
        ],
      ),
    );
  }

  Widget _smallPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
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

  Future<void> _openClassChooser() async {
    if (_liveClasses.isEmpty) {
      _message(
        _teacherView
            ? 'No active class assignment is configured. Use Take another class if you have authorization.'
            : 'No active classes are available.',
      );
      return;
    }
    final selected = await showDialog<_ClassAttendanceSummary>(
      context: context,
      builder: (context) => _ClassChooserDialog(classes: _liveClasses),
    );
    if (selected != null) _openRegister(selected);
  }

  void _openAuthorizedClassRegister() {
    setState(() => _openAuthorizedClass = true);
  }

  void _openRegister(_ClassAttendanceSummary selected) {
    setState(() => _openClass = selected);
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _termScope => [
    widget.term,
    widget.academicYear,
  ].where((value) => value?.trim().isNotEmpty == true).join(' · ');

  bool get _isShowingToday => _sameDate(_selectedDate, _todayDate);

  bool get _teacherView {
    final role = widget.viewerRole?.trim().toUpperCase();
    return role == 'CLASS_TEACHER' || role == 'SUBJECT_TEACHER';
  }

  bool get _subjectTeacherView =>
      widget.viewerRole?.trim().toUpperCase() == 'SUBJECT_TEACHER';

  int get _sortColumnIndex => switch (_classSort) {
    _AttendanceClassSort.className => 1,
    _AttendanceClassSort.students => 2,
    _AttendanceClassSort.present => 3,
    _AttendanceClassSort.absent => 4,
    _AttendanceClassSort.late => 5,
    _AttendanceClassSort.status => 6,
    _AttendanceClassSort.submittedAt => 7,
  };

  String _classActionLabel(_ClassAttendanceSummary item) =>
      item.status == AttendanceRegisterStatus.notSubmitted
      ? 'Take attendance'
      : 'View';

  static int _statusRank(AttendanceRegisterStatus status) => switch (status) {
    AttendanceRegisterStatus.notSubmitted => 0,
    AttendanceRegisterStatus.awaitingAcknowledgment => 1,
    AttendanceRegisterStatus.complete => 2,
    AttendanceRegisterStatus.nonSchoolDay => 3,
  };

  static int _levelRank(String level) => switch (level) {
    'Early Years' => 0,
    'Lower Primary' => 1,
    'Upper Primary' => 2,
    'Junior High' => 3,
    _ => 4,
  };

  static int _nullableDateCompare(DateTime? first, DateTime? second) {
    if (first == null && second == null) return 0;
    if (first == null) return 1;
    if (second == null) return -1;
    return first.compareTo(second);
  }

  static String _submissionTime(DateTime? value) {
    if (value == null) return '—';
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  static String _gradeGroup(String gradeName) {
    final normalized = gradeName.toUpperCase();
    if (normalized.contains('CRECHE') ||
        normalized.contains('CRÈCHE') ||
        normalized.contains('NURSERY') ||
        normalized.contains('PRE-K') ||
        normalized.startsWith('KG')) {
      return 'Early Years';
    }
    if (normalized.startsWith('JHS')) return 'Junior High';
    final gradeNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(normalized)?.group(0) ?? '',
    );
    if (gradeNumber != null && gradeNumber <= 3) return 'Lower Primary';
    return 'Upper Primary';
  }

  static String _sectionLabel(String gradeName, String streamName) {
    final stream = streamName.trim();
    if (stream.isEmpty) return 'Section';
    final compactStream = stream.toLowerCase().replaceAll(' ', '');
    final variants = <String>{
      gradeName.trim().toLowerCase(),
      gradeName.trim().toLowerCase().replaceAll(' ', ''),
    };
    for (final grade in variants) {
      if (grade.isEmpty) continue;
      final comparable = grade.contains(' ')
          ? stream.toLowerCase()
          : compactStream;
      if (!comparable.startsWith(grade)) continue;
      var remainder = comparable == compactStream
          ? stream.substring(_prefixLengthIgnoringSpaces(stream, grade))
          : stream.substring(grade.length);
      remainder = remainder.replaceFirst(RegExp(r'^\s*[-–—·:]\s*'), '');
      if (remainder.trim().isNotEmpty) return remainder.trim();
    }
    return stream;
  }

  static int _prefixLengthIgnoringSpaces(String value, String compactPrefix) {
    var matched = 0;
    var index = 0;
    while (index < value.length && matched < compactPrefix.length) {
      if (value[index] != ' ') matched++;
      index++;
    }
    return index;
  }

  static String _classCode(String gradeName, String streamName) {
    final grade = gradeName
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final section = RegExp(r'(\d+)\s*$').firstMatch(streamName)?.group(1);
    return section == null ? grade : '$grade-$section';
  }

  static String _friendlyDate(DateTime value) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String _shortDate(DateTime value) {
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

  static String _dateChipLabel(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[value.weekday - 1]} ${value.day} ${months[value.month - 1]}';
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static bool _sameDate(DateTime? first, DateTime? second) =>
      first != null &&
      second != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _ClassChooserDialog extends StatefulWidget {
  const _ClassChooserDialog({required this.classes});

  final List<_ClassAttendanceSummary> classes;

  @override
  State<_ClassChooserDialog> createState() => _ClassChooserDialogState();
}

class _ClassChooserDialogState extends State<_ClassChooserDialog> {
  String? _group;
  _ClassAttendanceSummary? _selected;

  @override
  Widget build(BuildContext context) {
    final groups = widget.classes.map((item) => item.group).toSet().toList();
    final classes = _group == null
        ? const <_ClassAttendanceSummary>[]
        : widget.classes.where((item) => item.group == _group).toList();
    return AlertDialog(
      title: const Text('Take attendance'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a school level, then choose the class register.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _group,
              decoration: const InputDecoration(labelText: 'School level'),
              hint: const Text('Select school level'),
              items: groups
                  .map(
                    (group) =>
                        DropdownMenuItem(value: group, child: Text(group)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _group = value;
                _selected = null;
              }),
            ),
            const SizedBox(height: 14),
            if (_group != null) ...[
              const Text(
                'Class and stream',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: classes
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.name),
                        selected: _selected == item,
                        onSelected: (_) => setState(() => _selected = item),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}

class _AttendanceReportsView extends StatefulWidget {
  const _AttendanceReportsView({
    required this.customSchoolId,
    this.schoolName,
    required this.repository,
    required this.classes,
    required this.term,
    required this.termScope,
    required this.onBack,
  });

  final String customSchoolId;
  final String? schoolName;
  final AttendanceRepository repository;
  final List<_ClassAttendanceSummary> classes;
  final AttendancePeriodSummary term;
  final String termScope;
  final VoidCallback onBack;

  @override
  State<_AttendanceReportsView> createState() => _AttendanceReportsViewState();
}

class _AttendanceReportsViewState extends State<_AttendanceReportsView> {
  _ClassAttendanceSummary? _selectedClass;
  Future<AttendanceTermHistory>? _history;
  late Future<List<AttendanceReportOption>> _reportOptions;
  Future<AttendanceGeneratedReport>? _generatedReport;
  final Set<int> _reportStreamIds = {};
  final Set<String> _reportStudentIds = {};
  final TextEditingController _reportRuleValue = TextEditingController(
    text: '80',
  );
  String _reportType = 'STUDENT';
  String _reportPeriod = 'TERM';
  String _reportMetric = 'ATTENDANCE_PERCENTAGE';
  String _reportOperator = 'LT';
  String _reportOutput = 'PREVIEW';
  String _generatedReportType = 'STUDENT';
  String _generatedReportMetric = 'ATTENDANCE_PERCENTAGE';
  String _generatedReportOperator = 'LT';
  double _generatedReportRuleValue = 80;
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;
  bool _showReportBuilder = false;

  @override
  void dispose() {
    _reportRuleValue.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final reportRepository = widget.repository;
    _reportOptions = reportRepository is AttendanceReportRepository
        ? (reportRepository as AttendanceReportRepository)
              .getAttendanceReportOptions(customSchoolId: widget.customSchoolId)
        : Future.value(const []);
    if (widget.classes.isNotEmpty) {
      _selectedClass = widget.classes.first;
      _history = _loadHistory(widget.classes.first);
    }
  }

  Future<AttendanceTermHistory> _loadHistory(
    _ClassAttendanceSummary selected,
  ) => widget.repository.getTermHistory(
    customSchoolId: widget.customSchoolId,
    gradeLevelId: selected.gradeId,
    streamId: selected.streamId,
  );

  void _selectClass(int? streamId) {
    if (streamId == null) return;
    final selected = widget.classes.firstWhere(
      (item) => item.streamId == streamId,
    );
    setState(() {
      _selectedClass = selected;
      _history = _loadHistory(selected);
    });
  }

  void _retry() {
    final selected = _selectedClass;
    if (selected == null) return;
    setState(() => _history = _loadHistory(selected));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('attendance-reports-page'),
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = constraints.maxWidth < 700
              ? constraints.maxWidth * .96
              : 640.0;
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context),
                        const SizedBox(height: 18),
                        _termOverview(context),
                        const SizedBox(height: 18),
                        _reportBuilderLauncher(context),
                        if (_generatedReport != null) ...[
                          const SizedBox(height: 18),
                          _generatedReportView(context),
                        ],
                        const SizedBox(height: 18),
                        _classReport(context),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showReportBuilder,
                  child: AnimatedOpacity(
                    opacity: _showReportBuilder ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: GestureDetector(
                      key: const ValueKey('attendance-report-panel-scrim'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showReportBuilder = false),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: .34),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                key: const ValueKey('attendance-report-side-panel'),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: _showReportBuilder ? 0 : -panelWidth,
                width: panelWidth,
                child: _reportBuilderPanel(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reportBuilderLauncher(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _generatedReport == null
                        ? 'Create an attendance report'
                        : 'Create another report',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Build a focused student or class report using dates and measurable rules.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('open-attendance-report-builder'),
              onPressed: () => setState(() => _showReportBuilder = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportBuilderPanel(BuildContext context) {
    return Material(
      color: AppColors.background,
      elevation: 18,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create attendance report',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Choose who, when, and what you want to review.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('close-attendance-report-builder'),
                    tooltip: 'Close report builder',
                    onPressed: () => setState(() => _showReportBuilder = false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _detailedReportBuilderForm(context),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showReportBuilder = false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('generate-attendance-report'),
                    onPressed: () => _generateReport(context, closePanel: true),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Generate report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailedReportBuilderForm(BuildContext context) {
    return FutureBuilder<List<AttendanceReportOption>>(
      future: _reportOptions,
      builder: (context, snapshot) {
        final options = snapshot.data ?? const <AttendanceReportOption>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportBuilderSection(
              context,
              number: 1,
              title: 'Report type and records',
              subtitle: 'Choose the grouping, then select the records.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    key: const ValueKey('report-type-selector'),
                    showSelectedIcon: true,
                    segments: const [
                      ButtonSegment(
                        value: 'STUDENT',
                        icon: Icon(Icons.person_outline_rounded),
                        label: Text('By student'),
                      ),
                      ButtonSegment(
                        value: 'CLASS',
                        icon: Icon(Icons.school_outlined),
                        label: Text('By class'),
                      ),
                    ],
                    selected: {_reportType},
                    onSelectionChanged: (value) => setState(() {
                      _reportType = value.first;
                      _reportStudentIds.clear();
                      _reportStreamIds.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_reportType == 'STUDENT')
                    _reportSelectorButton(
                      key: const ValueKey('report-student-selector'),
                      label: 'Students',
                      value: _reportStudentIds.isEmpty
                          ? 'All students — search to select'
                          : '${_reportStudentIds.length} students selected',
                      icon: Icons.people_outline_rounded,
                      onPressed:
                          snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () => _chooseReportStudents(context, options),
                      expand: true,
                    )
                  else
                    _reportSelectorButton(
                      key: const ValueKey('report-class-selector'),
                      label: 'Classes',
                      value: _reportStreamIds.isEmpty
                          ? 'All classes — search to select'
                          : '${_reportStreamIds.length} classes selected',
                      icon: Icons.school_outlined,
                      onPressed: () => _chooseReportClasses(context),
                      expand: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _reportBuilderSection(
              context,
              number: 2,
              title: 'Date reference',
              subtitle: 'Use the current term or define exact dates.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    key: const ValueKey('report-period-selector'),
                    showSelectedIcon: true,
                    segments: const [
                      ButtonSegment(
                        value: 'TERM',
                        icon: Icon(Icons.flag_outlined),
                        label: Text('This term'),
                      ),
                      ButtonSegment(
                        value: 'DATES',
                        icon: Icon(Icons.date_range_outlined),
                        label: Text('Date range'),
                      ),
                    ],
                    selected: {_reportPeriod},
                    onSelectionChanged: (value) =>
                        setState(() => _reportPeriod = value.first),
                  ),
                  if (_reportPeriod == 'DATES') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _reportSelectorButton(
                            key: const ValueKey('report-from-date-selector'),
                            label: 'From',
                            value: _reportStartDate == null
                                ? 'Select date'
                                : _reportDate(_reportStartDate!),
                            icon: Icons.calendar_today_outlined,
                            onPressed: () => _chooseReportDate(
                              context,
                              selectingStart: true,
                            ),
                            expand: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _reportSelectorButton(
                            key: const ValueKey('report-to-date-selector'),
                            label: 'To',
                            value: _reportEndDate == null
                                ? 'Select date'
                                : _reportDate(_reportEndDate!),
                            icon: Icons.event_available_outlined,
                            onPressed: () => _chooseReportDate(
                              context,
                              selectingStart: false,
                            ),
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _reportBuilderSection(
              context,
              number: 3,
              title: 'Report criteria',
              subtitle: 'Only results that match this rule will appear.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('report-metric-selector'),
                    value: _reportMetric,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Measure'),
                    items: [
                      const DropdownMenuItem(
                        value: 'ATTENDANCE_PERCENTAGE',
                        child: Text('Attendance percentage'),
                      ),
                      DropdownMenuItem(
                        value: 'ABSENT_DAYS',
                        child: Text(
                          _reportType == 'STUDENT'
                              ? 'Number of days absent'
                              : 'Total student-days absent',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'LATE_DAYS',
                        child: Text(
                          _reportType == 'STUDENT'
                              ? 'Number of days late'
                              : 'Total student-days late',
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'LATE_HOURS',
                        child: Text('Total hours late'),
                      ),
                      DropdownMenuItem(
                        value: 'PRESENT_DAYS',
                        child: Text(
                          _reportType == 'STUDENT'
                              ? 'Number of days present'
                              : 'Total student-days present',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _reportMetric = value;
                        _reportRuleValue.text = value == 'ATTENDANCE_PERCENTAGE'
                            ? '80'
                            : '2';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey('report-operator-selector'),
                          value: _reportOperator,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Condition',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'GT',
                              child: Text('More than (>)'),
                            ),
                            DropdownMenuItem(
                              value: 'LT',
                              child: Text('Less than (<)'),
                            ),
                            DropdownMenuItem(
                              value: 'EQ',
                              child: Text('Exactly (=)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _reportOperator = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('report-rule-value'),
                          controller: _reportRuleValue,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Value',
                            suffixText: _reportMetricUnit,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _reportRuleDescription,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _reportBuilderSection(
              context,
              number: 4,
              title: 'Output',
              subtitle: 'Choose what Generate report should produce.',
              child: SegmentedButton<String>(
                key: const ValueKey('report-output-selector'),
                showSelectedIcon: true,
                segments: const [
                  ButtonSegment(
                    value: 'PREVIEW',
                    icon: Icon(Icons.visibility_outlined),
                    label: Text('On-screen'),
                  ),
                  ButtonSegment(
                    value: 'PDF',
                    icon: Icon(Icons.picture_as_pdf_outlined),
                    label: Text('PDF'),
                  ),
                  ButtonSegment(
                    value: 'EXCEL',
                    icon: Icon(Icons.table_view_outlined),
                    label: Text('Excel'),
                  ),
                ],
                selected: {_reportOutput},
                onSelectionChanged: (value) =>
                    setState(() => _reportOutput = value.first),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _reportBuilderSection(
    BuildContext context, {
    required int number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.green,
                  child: Text(
                    '$number',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  String get _reportMetricUnit => switch (_reportMetric) {
    'ATTENDANCE_PERCENTAGE' => '%',
    'LATE_HOURS' => 'hours',
    _ => 'days',
  };

  String get _reportRuleDescription {
    final measure = switch (_reportMetric) {
      'ATTENDANCE_PERCENTAGE' => 'attendance',
      'ABSENT_DAYS' => 'days absent',
      'LATE_DAYS' => 'days late',
      'LATE_HOURS' => 'total hours late',
      _ => 'days present',
    };
    final condition = switch (_reportOperator) {
      'GT' => 'more than',
      'EQ' => 'exactly',
      _ => 'less than',
    };
    final value = _reportRuleValue.text.trim().isEmpty
        ? 'the entered value'
        : '${_reportRuleValue.text.trim()} $_reportMetricUnit';
    return 'Include ${_reportType == 'STUDENT' ? 'students' : 'classes'} with $measure $condition $value.';
  }

  Widget _reportSelectorButton({
    required Key key,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onPressed,
    bool expand = false,
  }) {
    return SizedBox(
      key: key,
      width: expand ? double.infinity : 250,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
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
                    ),
                  ),
                  Text(value, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseReportClasses(BuildContext context) async {
    final working = Set<int>.from(_reportStreamIds);
    var query = '';
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = widget.classes
              .where(
                (item) => item.name.toLowerCase().contains(
                  query.trim().toLowerCase(),
                ),
              )
              .toList();
          return AlertDialog(
            title: const Text('Select classes'),
            content: SizedBox(
              width: 480,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('report-class-search'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Search classes',
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${working.length} selected'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setDialogState(
                          () => working.addAll(
                            widget.classes.map((item) => item.streamId),
                          ),
                        ),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(working.clear),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('No classes found.'))
                        : ListView(
                            children: matches
                                .map(
                                  (item) => CheckboxListTile(
                                    value: working.contains(item.streamId),
                                    title: Text(item.name),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (checked) => setDialogState(() {
                                      checked == true
                                          ? working.add(item.streamId)
                                          : working.remove(item.streamId);
                                    }),
                                  ),
                                )
                                .toList(),
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
                onPressed: () => Navigator.pop(dialogContext, working),
                child: Text(
                  working.isEmpty
                      ? 'Use all classes'
                      : 'Apply ${working.length}',
                ),
              ),
            ],
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _reportStreamIds
        ..clear()
        ..addAll(selected);
      _reportStudentIds.clear();
    });
  }

  Future<void> _chooseReportStudents(
    BuildContext context,
    List<AttendanceReportOption> options,
  ) async {
    final available = List<AttendanceReportOption>.from(options)
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
    final working = Set<String>.from(_reportStudentIds);
    var query = '';
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedQuery = query.trim().toLowerCase();
          final matches = available
              .where(
                (item) =>
                    item.studentName.toLowerCase().contains(normalizedQuery) ||
                    item.customStudentId.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    _reportClassLabel(
                      item.gradeName,
                      item.streamName,
                    ).toLowerCase().contains(normalizedQuery),
              )
              .toList();
          return AlertDialog(
            title: const Text('Select students'),
            content: SizedBox(
              width: 520,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('report-student-search'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Search by student, ID, or class',
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${working.length} selected'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setDialogState(
                          () => working.addAll(
                            available.map((item) => item.customStudentId),
                          ),
                        ),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(working.clear),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('No students found.'))
                        : ListView(
                            children: matches
                                .map(
                                  (item) => CheckboxListTile(
                                    value: working.contains(
                                      item.customStudentId,
                                    ),
                                    title: Text(item.studentName),
                                    subtitle: Text(
                                      '${item.customStudentId} · ${_reportClassLabel(item.gradeName, item.streamName)}',
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (checked) => setDialogState(() {
                                      checked == true
                                          ? working.add(item.customStudentId)
                                          : working.remove(
                                              item.customStudentId,
                                            );
                                    }),
                                  ),
                                )
                                .toList(),
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
                onPressed: () => Navigator.pop(dialogContext, working),
                child: Text(
                  working.isEmpty
                      ? 'Use all students'
                      : 'Apply ${working.length}',
                ),
              ),
            ],
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _reportStudentIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _chooseReportDate(
    BuildContext context, {
    required bool selectingStart,
  }) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: selectingStart
          ? (_reportStartDate ?? _reportEndDate ?? now)
          : (_reportEndDate ?? _reportStartDate ?? now),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selectingStart) {
        _reportStartDate = selected;
      } else {
        _reportEndDate = selected;
      }
    });
  }

  Future<void> _generateReport(
    BuildContext context, {
    bool closePanel = false,
  }) async {
    final reportRepository = widget.repository;
    if (reportRepository is! AttendanceReportRepository) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generation is unavailable.')),
      );
      return;
    }
    final generator = reportRepository as AttendanceReportRepository;
    if (_reportPeriod == 'DATES' &&
        (_reportStartDate == null || _reportEndDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose both From and To dates.')),
      );
      return;
    }
    if (_reportPeriod == 'DATES' &&
        _reportStartDate!.isAfter(_reportEndDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The From date must be before To.')),
      );
      return;
    }
    final ruleValue = double.tryParse(_reportRuleValue.text.trim());
    if (ruleValue == null ||
        ruleValue < 0 ||
        (_reportMetric == 'ATTENDANCE_PERCENTAGE' && ruleValue > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reportMetric == 'ATTENDANCE_PERCENTAGE'
                ? 'Enter a percentage from 0 to 100.'
                : 'Enter a valid report criteria value.',
          ),
        ),
      );
      return;
    }
    late final Future<AttendanceGeneratedReport> reportFuture;
    setState(() {
      _generatedReportType = _reportType;
      _generatedReportMetric = _reportMetric;
      _generatedReportOperator = _reportOperator;
      _generatedReportRuleValue = ruleValue;
      reportFuture = generator.generateAttendanceReport(
        customSchoolId: widget.customSchoolId,
        criterion: 'ALL',
        streamIds: _reportType == 'CLASS'
            ? _reportStreamIds.toList()
            : const [],
        studentIds: _reportType == 'STUDENT'
            ? _reportStudentIds.toList()
            : const [],
        startDate: _reportPeriod == 'DATES' ? _reportStartDate : null,
        endDate: _reportPeriod == 'DATES' ? _reportEndDate : null,
      );
      _generatedReport = reportFuture;
      if (closePanel) _showReportBuilder = false;
    });
    if (_reportOutput == 'PREVIEW') return;
    try {
      final report = await reportFuture;
      if (!context.mounted) return;
      final students = report.students.where(_matchesReportRule).toList();
      final classes = _classReportRows(
        report.students,
      ).where(_matchesClassReportRule).toList();
      await _exportReport(
        context,
        report,
        students,
        classes,
        pdf: _reportOutput == 'PDF',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to prepare this report output.')),
      );
    }
  }

  Widget _generatedReportView(BuildContext context) {
    return FutureBuilder<AttendanceGeneratedReport>(
      future: _generatedReport,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.red),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Unable to generate this report.'),
                  ),
                  TextButton(
                    onPressed: () => _generateReport(context),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final report = snapshot.data!;
        final studentRows = report.students.where(_matchesReportRule).toList();
        final classRows = _classReportRows(
          report.students,
        ).where(_matchesClassReportRule).toList();
        final isStudentReport = _generatedReportType == 'STUDENT';
        final rowCount = isStudentReport
            ? studentRows.length
            : classRows.length;
        final totals = isStudentReport
            ? _reportTotalsFromStudents(studentRows)
            : _reportTotalsFromClasses(classRows);
        return Card(
          key: const ValueKey('generated-attendance-report'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isStudentReport
                            ? 'Student report results'
                            : 'Class report results',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('export-attendance-report-pdf'),
                      onPressed: () => _exportReport(
                        context,
                        report,
                        studentRows,
                        classRows,
                        pdf: true,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('PDF'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('export-attendance-report-excel'),
                      onPressed: () => _exportReport(
                        context,
                        report,
                        studentRows,
                        classRows,
                        pdf: false,
                      ),
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: const Text('Excel'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_reportDate(report.startDate)} – ${_reportDate(report.endDate)} · ${_generatedRuleDescription()}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 720 ? 2 : 4;
                    final width =
                        (constraints.maxWidth - 10 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _AttendanceReportMetric(
                          width: width,
                          label: isStudentReport ? 'Students' : 'Classes',
                          value: '$rowCount',
                          color: AppColors.blue,
                        ),
                        _AttendanceReportMetric(
                          width: width,
                          label: 'Attendance rate',
                          value: '${totals.rate.toStringAsFixed(1)}%',
                          color: AppColors.green,
                        ),
                        _AttendanceReportMetric(
                          width: width,
                          label: 'Absences',
                          value: '${totals.absent}',
                          color: AppColors.red,
                        ),
                        _AttendanceReportMetric(
                          width: width,
                          label: 'Late arrivals',
                          value: '${totals.late}',
                          color: AppColors.amber,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (rowCount == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No results match this report rule.'),
                    ),
                  )
                else if (isStudentReport)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      key: const ValueKey('generated-attendance-report-table'),
                      columns: const [
                        DataColumn(label: Text('STUDENT')),
                        DataColumn(label: Text('CLASS')),
                        DataColumn(numeric: true, label: Text('DAYS')),
                        DataColumn(numeric: true, label: Text('PRESENT')),
                        DataColumn(numeric: true, label: Text('ABSENT')),
                        DataColumn(numeric: true, label: Text('LATE')),
                        DataColumn(numeric: true, label: Text('RATE')),
                      ],
                      rows: studentRows
                          .map(
                            (student) => DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(student.studentName),
                                      Text(
                                        student.customStudentId,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _reportClassLabel(
                                      student.gradeName,
                                      student.streamName,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${student.markedDays}')),
                                DataCell(Text('${student.present}')),
                                DataCell(Text('${student.absent}')),
                                DataCell(Text('${student.late}')),
                                DataCell(
                                  Text(
                                    '${student.attendanceRate.toStringAsFixed(1)}%',
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      key: const ValueKey(
                        'generated-attendance-class-report-table',
                      ),
                      columns: const [
                        DataColumn(label: Text('CLASS')),
                        DataColumn(numeric: true, label: Text('STUDENTS')),
                        DataColumn(numeric: true, label: Text('DAYS')),
                        DataColumn(numeric: true, label: Text('PRESENT')),
                        DataColumn(numeric: true, label: Text('ABSENT')),
                        DataColumn(numeric: true, label: Text('LATE')),
                        DataColumn(numeric: true, label: Text('RATE')),
                      ],
                      rows: classRows
                          .map(
                            (row) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    _reportClassLabel(
                                      row.gradeName,
                                      row.streamName,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${row.students}')),
                                DataCell(Text('${row.markedDays}')),
                                DataCell(Text('${row.present}')),
                                DataCell(Text('${row.absent}')),
                                DataCell(Text('${row.late}')),
                                DataCell(
                                  Text(
                                    '${row.attendanceRate.toStringAsFixed(1)}%',
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _matchesReportRule(AttendanceReportStudent student) =>
      _matchesGeneratedRule(
        attendanceRate: student.attendanceRate,
        markedDays: student.markedDays,
        present: student.present,
        absent: student.absent,
        late: student.late,
        lateMinutes: student.lateMinutes,
      );

  bool _matchesClassReportRule(_AttendanceClassReportRow row) =>
      _matchesGeneratedRule(
        attendanceRate: row.attendanceRate,
        markedDays: row.markedDays,
        present: row.present,
        absent: row.absent,
        late: row.late,
        lateMinutes: row.lateMinutes,
      );

  bool _matchesGeneratedRule({
    required double attendanceRate,
    required int markedDays,
    required int present,
    required int absent,
    required int late,
    required int lateMinutes,
  }) {
    if (markedDays == 0) return false;
    final actual = switch (_generatedReportMetric) {
      'ATTENDANCE_PERCENTAGE' => attendanceRate,
      'ABSENT_DAYS' => absent.toDouble(),
      'LATE_DAYS' => late.toDouble(),
      'LATE_HOURS' => lateMinutes / 60,
      _ => present.toDouble(),
    };
    return switch (_generatedReportOperator) {
      'GT' => actual > _generatedReportRuleValue,
      'EQ' => (actual - _generatedReportRuleValue).abs() < .001,
      _ => actual < _generatedReportRuleValue,
    };
  }

  List<_AttendanceClassReportRow> _classReportRows(
    List<AttendanceReportStudent> students,
  ) {
    final grouped = <String, List<AttendanceReportStudent>>{};
    for (final student in students) {
      final key = student.streamId == 0
          ? '${student.gradeName}\u0000${student.streamName}'
          : '${student.streamId}';
      grouped.putIfAbsent(key, () => []).add(student);
    }
    final rows = grouped.values.map((members) {
      final first = members.first;
      final markedDays = members.fold<int>(
        0,
        (total, student) => total + student.markedDays,
      );
      final present = members.fold<int>(
        0,
        (total, student) => total + student.present,
      );
      final absent = members.fold<int>(
        0,
        (total, student) => total + student.absent,
      );
      final late = members.fold<int>(
        0,
        (total, student) => total + student.late,
      );
      final lateMinutes = members.fold<int>(
        0,
        (total, student) => total + student.lateMinutes,
      );
      return _AttendanceClassReportRow(
        gradeName: first.gradeName,
        streamName: first.streamName,
        students: members.length,
        markedDays: markedDays,
        present: present,
        absent: absent,
        late: late,
        lateMinutes: lateMinutes,
        attendanceRate: markedDays == 0
            ? 0
            : ((present + late) * 100) / markedDays,
      );
    }).toList();
    rows.sort((a, b) {
      final grade = a.gradeName.compareTo(b.gradeName);
      return grade != 0 ? grade : a.streamName.compareTo(b.streamName);
    });
    return rows;
  }

  ({int absent, int late, double rate}) _reportTotalsFromStudents(
    List<AttendanceReportStudent> rows,
  ) {
    final marked = rows.fold<int>(0, (total, row) => total + row.markedDays);
    final present = rows.fold<int>(0, (total, row) => total + row.present);
    final absent = rows.fold<int>(0, (total, row) => total + row.absent);
    final late = rows.fold<int>(0, (total, row) => total + row.late);
    return (
      absent: absent,
      late: late,
      rate: marked == 0 ? 0 : ((present + late) * 100) / marked,
    );
  }

  ({int absent, int late, double rate}) _reportTotalsFromClasses(
    List<_AttendanceClassReportRow> rows,
  ) {
    final marked = rows.fold<int>(0, (total, row) => total + row.markedDays);
    final present = rows.fold<int>(0, (total, row) => total + row.present);
    final absent = rows.fold<int>(0, (total, row) => total + row.absent);
    final late = rows.fold<int>(0, (total, row) => total + row.late);
    return (
      absent: absent,
      late: late,
      rate: marked == 0 ? 0 : ((present + late) * 100) / marked,
    );
  }

  String _generatedRuleDescription() {
    final measure = switch (_generatedReportMetric) {
      'ATTENDANCE_PERCENTAGE' => 'attendance percentage',
      'ABSENT_DAYS' => 'days absent',
      'LATE_DAYS' => 'days late',
      'LATE_HOURS' => 'total hours late',
      _ => 'days present',
    };
    final operator = switch (_generatedReportOperator) {
      'GT' => 'more than',
      'EQ' => 'exactly',
      _ => 'less than',
    };
    final unit = switch (_generatedReportMetric) {
      'ATTENDANCE_PERCENTAGE' => '%',
      'LATE_HOURS' => ' hours',
      _ => ' days',
    };
    final value = _generatedReportRuleValue % 1 == 0
        ? _generatedReportRuleValue.toInt().toString()
        : _generatedReportRuleValue.toStringAsFixed(1);
    return '$measure $operator $value$unit';
  }

  String _reportClassLabel(String gradeName, String streamName) {
    final section = _AttendanceDashboardScreenState._sectionLabel(
      gradeName,
      streamName,
    );
    return '$gradeName · $section';
  }

  Future<void> _exportReport(
    BuildContext context,
    AttendanceGeneratedReport report,
    List<AttendanceReportStudent> students,
    List<_AttendanceClassReportRow> classes, {
    required bool pdf,
  }) async {
    final studentReport = _generatedReportType == 'STUDENT';
    final headers = studentReport
        ? <String>[
            'Student',
            'Student ID',
            'Class',
            'Days',
            'Present',
            'Absent',
            'Late',
            'Late minutes',
            'Attendance rate',
          ]
        : <String>[
            'Class',
            'Students',
            'Days',
            'Present',
            'Absent',
            'Late',
            'Late minutes',
            'Attendance rate',
          ];
    final rows = studentReport
        ? students
              .map(
                (row) => <String>[
                  row.studentName,
                  row.customStudentId,
                  _reportClassLabel(row.gradeName, row.streamName),
                  '${row.markedDays}',
                  '${row.present}',
                  '${row.absent}',
                  '${row.late}',
                  '${row.lateMinutes}',
                  '${row.attendanceRate.toStringAsFixed(1)}%',
                ],
              )
              .toList()
        : classes
              .map(
                (row) => <String>[
                  _reportClassLabel(row.gradeName, row.streamName),
                  '${row.students}',
                  '${row.markedDays}',
                  '${row.present}',
                  '${row.absent}',
                  '${row.late}',
                  '${row.lateMinutes}',
                  '${row.attendanceRate.toStringAsFixed(1)}%',
                ],
              )
              .toList();
    final fileStem =
        'attendance-${studentReport ? 'students' : 'classes'}-${_reportDate(report.startDate)}-${_reportDate(report.endDate)}';
    final totals = studentReport
        ? _reportTotalsFromStudents(students)
        : _reportTotalsFromClasses(classes);
    final success = pdf
        ? await exportAttendanceReportPdf(
            fileName: '$fileStem.pdf',
            schoolName: widget.schoolName?.trim().isNotEmpty == true
                ? widget.schoolName!.trim()
                : widget.customSchoolId,
            title: studentReport
                ? 'Student attendance report'
                : 'Class attendance report',
            subtitle:
                '${_reportDate(report.startDate)} to ${_reportDate(report.endDate)} · ${_generatedRuleDescription()}',
            headers: headers,
            rows: rows,
            summary: {
              studentReport ? 'Students' : 'Classes': '${rows.length}',
              'Attendance rate': '${totals.rate.toStringAsFixed(1)}%',
              'Absences': '${totals.absent}',
              'Late arrivals': '${totals.late}',
            },
          )
        : await exportAttendanceReportSpreadsheet(
            fileName: '$fileStem.csv',
            headers: headers,
            rows: rows,
          );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${pdf ? 'PDF' : 'Excel-compatible'} report downloaded.'
              : 'Downloads are unavailable on this device.',
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          tooltip: 'Back to attendance dashboard',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance reports',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.termScope.isEmpty
                    ? 'Term attendance and class history'
                    : '${widget.termScope} · Term attendance and class history',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _termOverview(BuildContext context) {
    final term = widget.term;
    final enrolledStudents = widget.classes.fold<int>(
      0,
      (total, item) => total + item.totalStudents,
    );
    return Card(
      key: const ValueKey('term-attendance-report-overview'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Term overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'School-wide indicators for the current term.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 720 ? 2 : 3;
                final width =
                    (constraints.maxWidth - (12 * (columns - 1))) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AttendanceReportMetric(
                      width: width,
                      label: 'Attendance rate',
                      value: '${term.attendanceRate.toStringAsFixed(1)}%',
                      color: AppColors.green,
                    ),
                    _AttendanceReportMetric(
                      width: width,
                      label: 'Students enrolled',
                      value: '$enrolledStudents',
                      color: AppColors.blue,
                    ),
                    _AttendanceReportMetric(
                      width: width,
                      label: 'Students needing attention',
                      value: '${term.studentsNeedingAttention}',
                      color: term.studentsNeedingAttention > 0
                          ? AppColors.amber
                          : AppColors.green,
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

  Widget _classReport(BuildContext context) {
    if (widget.classes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No classes are available for attendance reporting.'),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class term report',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Daily register completion and attendance outcomes.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('attendance-report-class-selector'),
                    value: _selectedClass?.streamId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: widget.classes
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.streamId,
                            child: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _selectClass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<AttendanceTermHistory>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return SizedBox(
                    height: 240,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: AppColors.red,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text('Unable to load this class report.'),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _historyBody(context, snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyBody(BuildContext context, AttendanceTermHistory history) {
    final completed = history.days
        .where((day) => day.status == AttendanceDayStatus.completed)
        .toList();
    final missing = history.days
        .where((day) => day.status == AttendanceDayStatus.missing)
        .length;
    final nonSchool = history.days
        .where((day) => day.status == AttendanceDayStatus.nonSchoolDay)
        .length;
    final present = completed.fold<int>(0, (sum, day) => sum + day.present);
    final late = completed.fold<int>(0, (sum, day) => sum + day.late);
    final marked = completed.fold<int>(
      0,
      (sum, day) => sum + day.present + day.absent + day.late,
    );
    final rate = marked == 0 ? 0.0 : ((present + late) / marked) * 100;
    final days = [...history.days]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_reportDate(history.teachingStartDate)} – ${_reportDate(history.teachingEndDate)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720 ? 2 : 4;
            final width =
                (constraints.maxWidth - (10 * (columns - 1))) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AttendanceReportMetric(
                  width: width,
                  label: 'Class attendance',
                  value: '${rate.toStringAsFixed(1)}%',
                  color: AppColors.green,
                ),
                _AttendanceReportMetric(
                  width: width,
                  label: 'Completed days',
                  value: '${completed.length}',
                  color: AppColors.blue,
                ),
                _AttendanceReportMetric(
                  width: width,
                  label: 'Missing days',
                  value: '$missing',
                  color: AppColors.red,
                ),
                _AttendanceReportMetric(
                  width: width,
                  label: 'Non-school days',
                  value: '$nonSchool',
                  color: AppColors.muted,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Daily register history',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No term attendance days to report.')),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey('attendance-report-days-table'),
              columns: const [
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(numeric: true, label: Text('MARKED')),
                DataColumn(numeric: true, label: Text('PRESENT')),
                DataColumn(numeric: true, label: Text('ABSENT')),
                DataColumn(numeric: true, label: Text('LATE')),
              ],
              rows: days
                  .map(
                    (day) => DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_reportDate(day.date)),
                              if (day.eventName.trim().isNotEmpty)
                                Text(
                                  day.eventName.trim(),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(_AttendanceReportStatus(status: day.status)),
                        DataCell(Text('${day.markedStudents}')),
                        DataCell(Text('${day.present}')),
                        DataCell(Text('${day.absent}')),
                        DataCell(Text('${day.late}')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  String _reportDate(DateTime value) {
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
}

class _AttendanceClassReportRow {
  const _AttendanceClassReportRow({
    required this.gradeName,
    required this.streamName,
    required this.students,
    required this.markedDays,
    required this.present,
    required this.absent,
    required this.late,
    required this.lateMinutes,
    required this.attendanceRate,
  });

  final String gradeName;
  final String streamName;
  final int students;
  final int markedDays;
  final int present;
  final int absent;
  final int late;
  final int lateMinutes;
  final double attendanceRate;
}

class _AttendanceReportMetric extends StatelessWidget {
  const _AttendanceReportMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceReportStatus extends StatelessWidget {
  const _AttendanceReportStatus({required this.status});

  final AttendanceDayStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceDayStatus.completed => ('Complete', AppColors.green),
      AttendanceDayStatus.missing => ('Missing', AppColors.red),
      AttendanceDayStatus.nonSchoolDay => ('Non-school day', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
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

class _ClassAttendanceSummary {
  const _ClassAttendanceSummary({
    required this.group,
    required this.gradeId,
    required this.streamId,
    required this.code,
    required this.name,
    required this.teacher,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.late,
    required this.percentage,
    required this.status,
    this.acknowledgedBy = '',
    this.acknowledgmentNote = '',
    this.submittedBy = '',
    this.submittedAt,
  });

  final String group;
  final int gradeId;
  final int streamId;
  final String code;
  final String name;
  final String teacher;
  final int totalStudents;
  final int present;
  final int absent;
  final int late;
  final double percentage;
  final AttendanceRegisterStatus status;
  final String acknowledgedBy;
  final String acknowledgmentNote;
  final String submittedBy;
  final DateTime? submittedAt;

  bool get pending => status == AttendanceRegisterStatus.notSubmitted;
  bool get awaitingAcknowledgment =>
      status == AttendanceRegisterStatus.awaitingAcknowledgment;
}

class _AcknowledgmentSelection {
  const _AcknowledgmentSelection({required this.streamIds, this.note});

  final List<int> streamIds;
  final String? note;
}

class _AttendanceAcknowledgmentDialog extends StatefulWidget {
  const _AttendanceAcknowledgmentDialog({
    required this.classes,
    this.initialSelection = const <int>{},
  });

  final List<_ClassAttendanceSummary> classes;
  final Set<int> initialSelection;

  @override
  State<_AttendanceAcknowledgmentDialog> createState() =>
      _AttendanceAcknowledgmentDialogState();
}

class _AttendanceAcknowledgmentDialogState
    extends State<_AttendanceAcknowledgmentDialog> {
  final TextEditingController _noteController = TextEditingController();
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    final allowed = widget.classes.map((item) => item.streamId).toSet();
    _selected = widget.initialSelection.intersection(allowed);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == widget.classes.length;
    return AlertDialog(
      title: const Text('Acknowledge attendance registers'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select submitted class registers that you have reviewed.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              key: const ValueKey('select-all-attendance-acknowledgments'),
              contentPadding: EdgeInsets.zero,
              value: allSelected,
              title: const Text(
                'Select all',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onChanged: (value) => setState(() {
                _selected
                  ..clear()
                  ..addAll(
                    value == true
                        ? widget.classes.map((item) => item.streamId)
                        : const <int>[],
                  );
              }),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(
                shrinkWrap: true,
                children: widget.classes
                    .map(
                      (item) => CheckboxListTile(
                        key: ValueKey('acknowledge-stream-${item.streamId}'),
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(item.streamId),
                        title: Text(item.name),
                        subtitle: Text(item.teacher),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(item.streamId);
                          } else {
                            _selected.remove(item.streamId);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('attendance-acknowledgment-note'),
              controller: _noteController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional note',
                hintText: 'Add a management note for the selected registers',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirm-attendance-acknowledgment'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _AcknowledgmentSelection(
                    streamIds: _selected.toList(),
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  ),
                ),
          icon: const Icon(Icons.verified_outlined),
          label: Text('Acknowledge ${_selected.length}'),
        ),
      ],
    );
  }
}

class _DashboardStat {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.accent = false,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final bool accent;
}
