import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/staff_attendance_models.dart';

class StaffAttendanceDashboard extends StatefulWidget {
  const StaffAttendanceDashboard({
    super.key,
    required this.schoolId,
    required this.repository,
    required this.onOpenRegister,
  });

  final String schoolId;
  final StaffAttendanceRepository repository;
  final ValueChanged<DateTime> onOpenRegister;

  @override
  State<StaffAttendanceDashboard> createState() =>
      _StaffAttendanceDashboardState();
}

class _StaffAttendanceDashboardState extends State<StaffAttendanceDashboard> {
  StaffAttendanceContext? _term;
  StaffAttendanceDashboardData? _data;
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
  int _page = 0;
  int _rowsPerPage = 10;
  int _sortColumn = 0;
  bool _ascending = false;

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
      final term = _term ?? await widget.repository.getContext(widget.schoolId);
      final data = await widget.repository.getDashboard(
        schoolId: widget.schoolId,
        termId: term.termId,
      );
      if (!mounted) return;
      setState(() {
        _term = term;
        _data = data;
        _page = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StaffAttendanceDayRecord> get _filtered {
    final rows =
        (_data?.days ?? const <StaffAttendanceDayRecord>[])
            .where((day) => _status == 'ALL' || day.status == _status)
            .toList()
          ..sort((a, b) {
            final comparison = switch (_sortColumn) {
              1 => a.expected.compareTo(b.expected),
              2 => a.present.compareTo(b.present),
              3 => a.late.compareTo(b.late),
              4 => a.excused.compareTo(b.excused),
              5 => a.unexcused.compareTo(b.unexcused),
              6 => _statusLabel(a.status).compareTo(_statusLabel(b.status)),
              _ => a.date.compareTo(b.date),
            };
            if (comparison != 0) return _ascending ? comparison : -comparison;
            final dateComparison = a.date.compareTo(b.date);
            return _ascending ? dateComparison : -dateComparison;
          });
    return rows;
  }

  void _sortRows(int column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _ascending = ascending;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final data = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 18),
          _metrics(data),
          if (data.missingRegisters > 0) ...[
            const SizedBox(height: 18),
            _attention(data),
          ],
          const SizedBox(height: 18),
          _registers(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header() => Wrap(
    spacing: 16,
    runSpacing: 12,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 650,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff attendance',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${_term?.termLabel ?? ''} · ${_term?.academicYear ?? ''} attendance registers and term performance.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('take-staff-attendance'),
        onPressed: () => widget.onOpenRegister(DateTime.now()),
        icon: const Icon(Icons.add),
        label: const Text('Take attendance'),
      ),
    ],
  );

  Widget _metrics(StaffAttendanceDashboardData data) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _metric(
        'Attendance',
        '${data.attendanceRate.toStringAsFixed(1)}%',
        'Present and late',
        AppColors.green,
      ),
      _metric(
        'Punctuality',
        '${data.punctualityRate.toStringAsFixed(1)}%',
        'On-time attendance',
        AppColors.blue,
      ),
      _metric(
        'Expected staff-days',
        '${data.expectedStaffDays}',
        'Term to date',
        AppColors.text,
      ),
      _metric('Late', '${data.lateDays}', 'Arrival records', AppColors.amber),
      _metric(
        'Excused',
        '${data.excusedAbsences}',
        'Approved absences',
        AppColors.blue,
      ),
      _metric(
        'Unexcused',
        '${data.unexcusedAbsences}',
        'Requires attention',
        AppColors.red,
      ),
    ],
  );

  Widget _metric(String label, String value, String note, Color color) =>
      Container(
        width: 205,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              note,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );

  Future<void> _showAllMissingRegisters(
    List<StaffAttendanceDayRecord> missing,
  ) async {
    final selected = await showModalBottomSheet<StaffAttendanceDayRecord>(
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
                        'Unresolved attendance days',
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
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: missing.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _missingRegisterRow(
                      missing[index],
                      key: ValueKey('all-missing-register-$index'),
                      onResolve: () =>
                          Navigator.of(context).pop(missing[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _resolve(selected);
  }

  Widget _attention(StaffAttendanceDashboardData data) {
    final missing = data.days.where((day) => day.status == 'MISSING').toList();
    final visible = missing.take(3).toList();
    final remainingCount = missing.length - visible.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: .07),
        border: Border.all(color: AppColors.amber.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attention required · ${data.missingRegisters} ${data.missingRegisters == 1 ? 'day' : 'days'} unresolved',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (remainingCount > 0)
                TextButton(
                  key: const ValueKey('more-missing-registers'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _showAllMissingRegisters(missing),
                  child: Text('+ $remainingCount more'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'These were expected school days but no attendance register was submitted.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < visible.length; index++)
            _missingRegisterRow(
              visible[index],
              key: ValueKey('dashboard-missing-register-$index'),
              compact: true,
              onResolve: () => _resolve(visible[index]),
            ),
        ],
      ),
    );
  }

  Widget _missingRegisterRow(
    StaffAttendanceDayRecord day, {
    Key? key,
    required VoidCallback onResolve,
    bool compact = false,
  }) => Padding(
    key: key,
    padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: AppColors.amber,
          size: compact ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_longDate(day.date)} · Attendance not taken',
            style: TextStyle(
              fontSize: compact ? 12.5 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onResolve,
          child: const Text('Resolve'),
        ),
      ],
    ),
  );

  Widget _registers() {
    final rows = _filtered;
    final start = (_page * _rowsPerPage).clamp(0, rows.length);
    final end = (start + _rowsPerPage).clamp(0, rows.length);
    final visible = rows.sublist(start, end);
    final pages = rows.isEmpty ? 1 : (rows.length / _rowsPerPage).ceil();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SizedBox(
                  width: 430,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance registers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'All school days for the selected term.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                    DropdownMenuItem(value: 'MISSING', child: Text('Missing')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'SUBMITTED',
                      child: Text('Submitted'),
                    ),
                    DropdownMenuItem(
                      value: 'NON_SCHOOL_DAY',
                      child: Text('Non-school day'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value ?? 'ALL';
                    _page = 0;
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('staff-attendance-table-scroll'),
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  key: const ValueKey('staff-attendance-register-table'),
                  showCheckboxColumn: false,
                  sortColumnIndex: _sortColumn,
                  sortAscending: _ascending,
                  headingRowHeight: 48,
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 58,
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
                  columns: [
                    _sortableColumn('Date', 0),
                    _sortableColumn('Expected', 1, numeric: true),
                    _sortableColumn('Present', 2, numeric: true),
                    _sortableColumn('Late', 3, numeric: true),
                    _sortableColumn('Excused', 4, numeric: true),
                    _sortableColumn('Unexcused', 5, numeric: true),
                    _sortableColumn('Status', 6),
                    const DataColumn(label: Text('ACTION')),
                  ],
                  rows: [
                    for (var index = 0; index < visible.length; index++)
                      _row(visible[index], index),
                  ],
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
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _rowsPerPage = value ?? 10;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 18),
                Text('${_page + 1} of $pages'),
                IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: _page + 1 < pages
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _sortableColumn(String label, int column, {bool numeric = false}) {
    return DataColumn(
      numeric: numeric,
      tooltip: 'Sort by ${label.toLowerCase()}',
      onSort: _sortRows,
      label: Row(
        key: ValueKey('staff-attendance-sort-${label.toLowerCase()}'),
        children: [
          Text(label.toUpperCase()),
          if (_sortColumn != column) ...[
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
  }

  DataRow _row(StaffAttendanceDayRecord day, int index) => DataRow(
    key: ValueKey('staff-attendance-row-${day.date.toIso8601String()}'),
    color: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered)
          ? AppColors.greenSoft
          : index.isOdd
          ? const Color(0xFFFAFCFC)
          : Colors.white,
    ),
    cells: [
      DataCell(
        Text(
          _shortDate(day.date),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      DataCell(Text('${day.expected}')),
      DataCell(Text('${day.present}')),
      DataCell(Text('${day.late}')),
      DataCell(Text('${day.excused}')),
      DataCell(Text('${day.unexcused}')),
      DataCell(_statusChip(day.status, day.eventName)),
      DataCell(
        TextButton(
          onPressed: day.status == 'MISSING'
              ? () => _resolve(day)
              : day.status == 'NON_SCHOOL_DAY'
              ? null
              : () => widget.onOpenRegister(day.date),
          child: Text(
            day.status == 'MISSING'
                ? 'Resolve'
                : day.status == 'DRAFT'
                ? 'Continue draft'
                : day.status == 'NON_SCHOOL_DAY'
                ? 'Resolved'
                : 'View register',
          ),
        ),
      ),
    ],
  );

  Widget _statusChip(String status, String? eventName) {
    final color = switch (status) {
      'SUBMITTED' => AppColors.green,
      'DRAFT' => AppColors.amber,
      'NON_SCHOOL_DAY' => AppColors.blue,
      _ => AppColors.red,
    };
    final label =
        eventName?.trim().isNotEmpty == true && status == 'NON_SCHOOL_DAY'
        ? eventName!
        : _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'SUBMITTED' => 'Submitted',
    'DRAFT' => 'Draft',
    'NON_SCHOOL_DAY' => 'Non-school day',
    _ => 'Missing',
  };

  Future<void> _resolve(StaffAttendanceDayRecord day) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolve ${_longDate(day.date)}'),
        content: const Text(
          'Take the missing attendance register, or record why this was not a school day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'NON_SCHOOL_DAY'),
            child: const Text('Mark as non-school day'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'ATTENDANCE'),
            child: const Text('Take attendance'),
          ),
        ],
      ),
    );
    if (action == 'ATTENDANCE') widget.onOpenRegister(day.date);
    if (action == 'NON_SCHOOL_DAY') await _nonSchoolDay(day.date);
  }

  Future<void> _nonSchoolDay(DateTime date) async {
    final name = TextEditingController();
    final description = TextEditingController();
    String type = 'Holiday';
    final input = await showDialog<NonSchoolDayInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Record non-school day'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Event name',
                    hintText: 'For example, Founders Day holiday',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['Holiday', 'Event', 'Other']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => type = value ?? type),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason or description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Date: ${_longDate(date)}',
                    style: const TextStyle(color: AppColors.muted),
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
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  NonSchoolDayInput(
                    termId: _term!.termId,
                    startDate: date,
                    endDate: date,
                    name: name.text.trim(),
                    type: type,
                    description: description.text.trim(),
                  ),
                );
              },
              child: const Text('Save and resolve'),
            ),
          ],
        ),
      ),
    );
    if (input == null) return;
    try {
      await widget.repository.markNonSchoolDay(
        schoolId: widget.schoolId,
        input: input,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non-school day recorded and resolved.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  static String _longDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
