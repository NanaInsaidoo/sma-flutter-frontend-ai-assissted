import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/demo_attendance_repository.dart';
import 'attendance_screen.dart';

enum _AttendancePeriod { today, week, month }

class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({
    super.key,
    required this.customSchoolId,
    this.academicYear,
    this.term,
    this.repository,
  });

  final String customSchoolId;
  final String? academicYear;
  final String? term;
  final DemoAttendanceRepository? repository;

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  late final DemoAttendanceRepository _repository;
  _AttendancePeriod _period = _AttendancePeriod.today;
  _ClassAttendanceSummary? _openClass;
  bool _showSubmissionBanner = true;
  bool _showAllClasses = false;

  static const _classes = [
    _ClassAttendanceSummary(
      group: 'Kindergarten',
      gradeId: 1,
      streamId: 11,
      code: 'KG1-A',
      name: 'KG 1 · Stream A',
      teacher: 'Mrs. Grace Johnson',
      present: 42,
      absent: 2,
      late: 1,
      percentage: 95.6,
    ),
    _ClassAttendanceSummary(
      group: 'Kindergarten',
      gradeId: 2,
      streamId: 22,
      code: 'KG2-B',
      name: 'KG 2 · Stream B',
      teacher: 'Mr. James Osei',
      present: 40,
      absent: 3,
      late: 1,
      percentage: 94.2,
    ),
    _ClassAttendanceSummary(
      group: 'Lower Primary',
      gradeId: 3,
      streamId: 31,
      code: 'B1-A',
      name: 'Basic 1 · Stream A',
      teacher: 'Mr. Kwame Asante',
      present: 47,
      absent: 1,
      late: 1,
      percentage: 97.9,
    ),
    _ClassAttendanceSummary(
      group: 'Lower Primary',
      gradeId: 3,
      streamId: 32,
      code: 'B1-B',
      name: 'Basic 1 · Stream B',
      teacher: 'Mrs. Ama Mensah',
      present: 0,
      absent: 0,
      late: 0,
      percentage: 0,
      pending: true,
    ),
    _ClassAttendanceSummary(
      group: 'Lower Primary',
      gradeId: 4,
      streamId: 41,
      code: 'B2-A',
      name: 'Basic 2 · Stream A',
      teacher: 'Ms. Abena Frimpong',
      present: 48,
      absent: 2,
      late: 0,
      percentage: 96,
    ),
    _ClassAttendanceSummary(
      group: 'Upper Primary',
      gradeId: 6,
      streamId: 61,
      code: 'B4-A',
      name: 'Basic 4 · Stream A',
      teacher: 'Mr. Emmanuel Ofori',
      present: 46,
      absent: 4,
      late: 2,
      percentage: 92.3,
    ),
    _ClassAttendanceSummary(
      group: 'Upper Primary',
      gradeId: 6,
      streamId: 62,
      code: 'B4-B',
      name: 'Basic 4 · Stream B',
      teacher: 'Ms. Serwa Tetteh',
      present: 0,
      absent: 0,
      late: 0,
      percentage: 0,
      pending: true,
    ),
    _ClassAttendanceSummary(
      group: 'Upper Primary',
      gradeId: 8,
      streamId: 81,
      code: 'B6-A',
      name: 'Basic 6 · Stream A',
      teacher: 'Mr. Fiifi Antwi',
      present: 49,
      absent: 2,
      late: 1,
      percentage: 94.2,
    ),
    _ClassAttendanceSummary(
      group: 'Junior High',
      gradeId: 9,
      streamId: 91,
      code: 'J1-A',
      name: 'JHS 1 · Stream A',
      teacher: 'Mr. Kwabena Amponsah',
      present: 43,
      absent: 3,
      late: 1,
      percentage: 91.5,
    ),
    _ClassAttendanceSummary(
      group: 'Junior High',
      gradeId: 10,
      streamId: 101,
      code: 'J2-A',
      name: 'JHS 2 · Stream A',
      teacher: 'Mrs. Maame Sarpong',
      present: 0,
      absent: 0,
      late: 0,
      percentage: 0,
      pending: true,
    ),
    _ClassAttendanceSummary(
      group: 'Junior High',
      gradeId: 11,
      streamId: 111,
      code: 'J3-A',
      name: 'JHS 3 · Stream A',
      teacher: 'Mr. Kweku Boadu',
      present: 41,
      absent: 4,
      late: 2,
      percentage: 87.2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DemoAttendanceRepository();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _openClass;
    if (selected != null) {
      return AttendanceScreen(
        customSchoolId: widget.customSchoolId,
        academicYear: widget.academicYear,
        term: widget.term,
        repository: _repository,
        initialGradeLevelId: selected.gradeId,
        initialStreamId: selected.streamId,
        showClassSelectors: false,
        onBack: () => setState(() => _openClass = null),
      );
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
                if (_showSubmissionBanner) ...[
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
  }

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
    final pending = _classes.where((item) => item.pending).toList();
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
            _friendlyDate(DateTime.now()),
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
    final multiplier = switch (_period) {
      _AttendancePeriod.today => 1,
      _AttendancePeriod.week => 5,
      _AttendancePeriod.month => 18,
    };
    final items = [
      _DashboardStat(
        label: 'Overall attendance',
        value: _period == _AttendancePeriod.today ? '94.8%' : '94.1%',
        detail: '↑ 2.3% from previous period',
        icon: Icons.insights_rounded,
        color: AppColors.green,
        accent: true,
      ),
      _DashboardStat(
        label: 'Present',
        value: '${518 * multiplier}',
        detail: _period == _AttendancePeriod.today
            ? 'of 552 students'
            : 'attendance marks',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.green,
      ),
      _DashboardStat(
        label: 'Absent',
        value: '${26 * multiplier}',
        detail: 'Requires follow-up',
        icon: Icons.person_off_outlined,
        color: AppColors.red,
      ),
      _DashboardStat(
        label: 'Late',
        value: '${8 * multiplier}',
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
    final visible = _showAllClasses ? _classes : _classes.take(7).toList();
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
    const alerts = [
      (
        'KG 1 Stream B has 3 students absent for 3 consecutive days',
        'Last week',
        AppColors.red,
      ),
      (
        'Basic 1 Stream B attendance has not been submitted',
        'Today',
        AppColors.amber,
      ),
      (
        'JHS 2 Stream A has 5 students below 80% attendance',
        '2 days ago',
        AppColors.red,
      ),
      (
        'Basic 4 Stream B was not submitted yesterday',
        'Yesterday',
        AppColors.amber,
      ),
    ];
    return Card(
      child: Column(
        children: [
          _cardHeader(
            icon: Icons.notifications_none_rounded,
            title: 'Recent alerts',
            action: _smallPill('4 active', AppColors.red),
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
                      color: alert.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.$1, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          alert.$2,
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
      builder: (context) => const _ClassChooserDialog(classes: _classes),
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
