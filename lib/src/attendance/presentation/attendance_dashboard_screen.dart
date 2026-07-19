import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/attendance_models.dart';
import 'attendance_screen.dart';

enum _AttendancePeriod { today, week, month }

class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({
    super.key,
    required this.customSchoolId,
    required this.repository,
    this.academicYear,
    this.term,
  });

  final String customSchoolId;
  final String? academicYear;
  final String? term;
  final AttendanceRepository repository;

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  late Future<AttendanceDashboardOverview> _overviewFuture;
  AttendanceDashboardOverview? _overview;
  _AttendancePeriod _period = _AttendancePeriod.today;
  _ClassAttendanceSummary? _openClass;
  bool _showSubmissionBanner = true;
  bool _showAllClasses = false;

  @override
  void initState() {
    super.initState();
    _overviewFuture = widget.repository.getOverview(widget.customSchoolId);
  }

  void _reloadOverview() {
    setState(() {
      _overview = null;
      _overviewFuture = widget.repository.getOverview(widget.customSchoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _openClass;
    if (selected != null) {
      return AttendanceScreen(
        customSchoolId: widget.customSchoolId,
        academicYear: widget.academicYear,
        term: widget.term,
        repository: widget.repository,
        initialGradeLevelId: selected.gradeId,
        initialStreamId: selected.streamId,
        showClassSelectors: false,
        onBack: () => setState(() => _openClass = null),
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
                    if (_showSubmissionBanner &&
                        _liveClasses.any((item) => item.pending)) ...[
                      const SizedBox(height: 18),
                      _submissionBanner(),
                    ],
                    const SizedBox(height: 18),
                    _dateAndPeriod(),
                    const SizedBox(height: 14),
                    _stats(),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 980) {
                          return Column(
                            children: [
                              _classesCard(),
                              const SizedBox(height: 16),
                              _alertsCard(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _classesCard()),
                            const SizedBox(width: 16),
                            SizedBox(width: 350, child: _alertsCard()),
                          ],
                        );
                      },
                    ),
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

  List<_ClassAttendanceSummary> get _liveClasses =>
      (_overview?.classes ?? const <AttendanceClassSummary>[])
          .map(
            (item) => _ClassAttendanceSummary(
              group: _gradeGroup(item.gradeName),
              gradeId: item.gradeId,
              streamId: item.streamId,
              code: _classCode(item.gradeName, item.streamName),
              name: '${item.gradeName} · ${item.streamName}',
              teacher: item.teacherName.isEmpty
                  ? 'Class teacher not assigned'
                  : item.teacherName,
              present: item.present,
              absent: item.absent,
              late: item.late,
              percentage: item.attendanceRate,
              pending: !item.submitted,
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
                'School Attendance',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                'Track and manage attendance${_termScope.isEmpty ? '' : ' · $_termScope'}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('mark-attendance'),
          onPressed: _openClassChooser,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Mark attendance'),
        ),
      ],
    );
  }

  Widget _submissionBanner() {
    final pending = _liveClasses.where((item) => item.pending).toList();
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pending.length} classes have not submitted attendance today',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: pending
                      .map(
                        (item) => InkWell(
                          onTap: () => _openRegister(item),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: .3),
                              ),
                            ),
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                color: Color(0xFF9A6400),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _message('Reminders sent to the class teachers.'),
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Remind all'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _showSubmissionBanner = false),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _dateAndPeriod() {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: AppColors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _friendlyDate(_overview?.currentDate ?? DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        SegmentedButton<_AttendancePeriod>(
          segments: const [
            ButtonSegment(value: _AttendancePeriod.today, label: Text('Today')),
            ButtonSegment(
              value: _AttendancePeriod.week,
              label: Text('This week'),
            ),
            ButtonSegment(
              value: _AttendancePeriod.month,
              label: Text('This month'),
            ),
          ],
          selected: {_period},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _period = selection.first),
        ),
      ],
    );
  }

  Widget _stats() {
    final summary = switch (_period) {
      _AttendancePeriod.today => _overview!.today,
      _AttendancePeriod.week => _overview!.week,
      _AttendancePeriod.month => _overview!.month,
    };
    final periodDetail = _period == _AttendancePeriod.today
        ? 'Today'
        : _period == _AttendancePeriod.week
        ? 'Daily average this week'
        : 'Recorded this month';
    final items = [
      _DashboardStat(
        label: 'Overall attendance',
        value: '${summary.attendanceRate.toStringAsFixed(1)}%',
        detail: periodDetail,
        icon: Icons.insights_rounded,
        color: AppColors.green,
        accent: true,
      ),
      _DashboardStat(
        label: 'Present',
        value: '${summary.present}',
        detail: _period == _AttendancePeriod.today
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
    final visible = _showAllClasses
        ? _liveClasses
        : _liveClasses.take(7).toList();
    String? currentGroup;
    final rows = <Widget>[];
    for (final item in visible) {
      if (item.group != currentGroup) {
        currentGroup = item.group;
        rows.add(_groupHeader(item.group));
      }
      rows.add(_classRow(item));
    }
    return Card(
      child: Column(
        children: [
          _cardHeader(
            icon: Icons.menu_book_outlined,
            title: 'Attendance by grade and stream',
            action: TextButton(
              onPressed: () =>
                  setState(() => _showAllClasses = !_showAllClasses),
              child: Text(_showAllClasses ? 'Show less' : 'View all'),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _groupHeader(String group) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F9F8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Text(
        group.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ),
      ),
    );
  }

  Widget _classRow(_ClassAttendanceSummary item) {
    final color = item.pending
        ? AppColors.amber
        : item.percentage >= 95
        ? AppColors.green
        : item.percentage >= 90
        ? AppColors.amber
        : AppColors.red;
    return InkWell(
      key: ValueKey('attendance-class-${item.streamId}'),
      onTap: () => _openRegister(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.teacher,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.pending
                        ? 'Attendance not submitted'
                        : '${item.present} present · ${item.absent} absent · ${item.late} late',
                    style: TextStyle(
                      color: item.pending ? AppColors.amber : AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (item.pending)
              _smallPill('Pending', AppColors.amber)
            else
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: item.percentage / 100,
                      minHeight: 4,
                      color: color,
                      backgroundColor: AppColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _alertsCard() {
    final alerts = _overview?.alerts ?? const <AttendanceAlert>[];
    return Card(
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
          for (final alert in alerts)
            Container(
              padding: const EdgeInsets.all(15),
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
                    decoration: BoxDecoration(
                      color: alert.severity.toLowerCase() == 'high'
                          ? AppColors.red
                          : AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alert.title.isNotEmpty) ...[
                          Text(
                            alert.title,
                            style: const TextStyle(
                              fontSize: 13,
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
                          alert.timestamp == null
                              ? 'Attendance alert'
                              : _friendlyDate(alert.timestamp!),
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
            ),
          TextButton(
            onPressed: () => _message('All attendance alerts are shown.'),
            child: const Text('View all alerts →'),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
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
        () => _message('Attendance reports preview opened.'),
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
    final selected = await showDialog<_ClassAttendanceSummary>(
      context: context,
      builder: (context) => _ClassChooserDialog(classes: _liveClasses),
    );
    if (selected != null) _openRegister(selected);
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

  static String _gradeGroup(String gradeName) {
    final normalized = gradeName.toUpperCase();
    if (normalized.startsWith('KG')) return 'Kindergarten';
    if (normalized.startsWith('JHS')) return 'Junior High';
    final gradeNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(normalized)?.group(0) ?? '',
    );
    if (gradeNumber != null && gradeNumber <= 3) return 'Lower Primary';
    return 'Upper Primary';
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

class _ClassAttendanceSummary {
  const _ClassAttendanceSummary({
    required this.group,
    required this.gradeId,
    required this.streamId,
    required this.code,
    required this.name,
    required this.teacher,
    required this.present,
    required this.absent,
    required this.late,
    required this.percentage,
    this.pending = false,
  });

  final String group;
  final int gradeId;
  final int streamId;
  final String code;
  final String name;
  final String teacher;
  final int present;
  final int absent;
  final int late;
  final double percentage;
  final bool pending;
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
