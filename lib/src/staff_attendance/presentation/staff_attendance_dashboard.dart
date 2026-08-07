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
          ..sort((a, b) => a.date.compareTo(b.date));
    return _ascending ? rows : rows.reversed.toList();
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

  Widget _attention(StaffAttendanceDashboardData data) {
    final missing = data.days.where((day) => day.status == 'MISSING').toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: .07),
        border: Border.all(color: AppColors.amber.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attention required · ${data.missingRegisters} ${data.missingRegisters == 1 ? 'day' : 'days'} unresolved',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'These were expected school days but no attendance register was submitted.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ...missing
              .take(3)
              .map(
                (day) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_longDate(day.date)} · Attendance not taken',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _resolve(day),
                        child: const Text('Resolve'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: 0,
              sortAscending: _ascending,
              columns: [
                DataColumn(
                  label: const Text('Date'),
                  onSort: (_, ascending) => setState(() {
                    _ascending = ascending;
                    _page = 0;
                  }),
                ),
                const DataColumn(label: Text('Expected')),
                const DataColumn(label: Text('Present')),
                const DataColumn(label: Text('Late')),
                const DataColumn(label: Text('Excused')),
                const DataColumn(label: Text('Unexcused')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Action')),
              ],
              rows: visible.map(_row).toList(),
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

  DataRow _row(StaffAttendanceDayRecord day) => DataRow(
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
    final (label, color) = switch (status) {
      'SUBMITTED' => ('Submitted', AppColors.green),
      'DRAFT' => ('Draft', AppColors.amber),
      'NON_SCHOOL_DAY' => (eventName ?? 'Non-school day', AppColors.blue),
      _ => ('Missing', AppColors.red),
    };
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
