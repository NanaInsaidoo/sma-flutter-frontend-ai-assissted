import 'package:flutter/material.dart';
import '../../attendance/presentation/attendance_report_export.dart';
import '../../common/display_formatters.dart';
import '../../theme/app_theme.dart';
import '../domain/staff_attendance_models.dart';

class StaffAttendanceDashboard extends StatefulWidget {
  const StaffAttendanceDashboard({
    super.key,
    required this.schoolId,
    required this.repository,
    required this.onOpenRegister,
    this.schoolName,
  });

  final String schoolId;
  final String? schoolName;
  final StaffAttendanceRepository repository;
  final ValueChanged<DateTime> onOpenRegister;

  @override
  State<StaffAttendanceDashboard> createState() =>
      _StaffAttendanceDashboardState();
}

class _StaffReportConfig {
  const _StaffReportConfig({
    required this.staffIds,
    required this.startDate,
    required this.endDate,
    required this.output,
  });

  final Set<String> staffIds;
  final DateTime startDate;
  final DateTime endDate;
  final String output;
}

class _StaffAttendanceReportRow {
  const _StaffAttendanceReportRow({
    required this.person,
    required this.recordedDays,
    required this.present,
    required this.late,
    required this.excused,
    required this.unexcused,
    required this.attendanceRate,
    required this.punctualityRate,
  });

  final StaffAttendancePerson person;
  final int recordedDays;
  final int present;
  final int late;
  final int excused;
  final int unexcused;
  final double attendanceRate;
  final double punctualityRate;
}

class _StaffAttendanceReport {
  const _StaffAttendanceReport({
    required this.startDate,
    required this.endDate,
    required this.termLabel,
    required this.rows,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String termLabel;
  final List<_StaffAttendanceReportRow> rows;

  ({
    int recorded,
    int present,
    int late,
    int excused,
    int unexcused,
    double attendanceRate,
    double punctualityRate,
  })
  get summary {
    final recorded = rows.fold<int>(0, (sum, row) => sum + row.recordedDays);
    final present = rows.fold<int>(0, (sum, row) => sum + row.present);
    final late = rows.fold<int>(0, (sum, row) => sum + row.late);
    final excused = rows.fold<int>(0, (sum, row) => sum + row.excused);
    final unexcused = rows.fold<int>(0, (sum, row) => sum + row.unexcused);
    return (
      recorded: recorded,
      present: present,
      late: late,
      excused: excused,
      unexcused: unexcused,
      attendanceRate: recorded == 0 ? 0 : ((present + late) * 100) / recorded,
      punctualityRate: present + late == 0
          ? 0
          : (present * 100) / (present + late),
    );
  }
}

class _StaffReportDialog extends StatefulWidget {
  const _StaffReportDialog({
    required this.people,
    required this.termStart,
    required this.termEnd,
  });

  final List<StaffAttendancePerson> people;
  final DateTime termStart;
  final DateTime termEnd;

  @override
  State<_StaffReportDialog> createState() => _StaffReportDialogState();
}

class _StaffReportDialogState extends State<_StaffReportDialog> {
  final Set<String> _selected = {};
  String _query = '';
  String _period = 'TERM';
  String _output = 'PREVIEW';
  DateTime? _from;
  DateTime? _to;

  List<StaffAttendancePerson> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.people;
    return widget.people
        .where(
          (person) =>
              person.name.toLowerCase().contains(query) ||
              person.id.toLowerCase().contains(query) ||
              person.role.toLowerCase().contains(query),
        )
        .toList();
  }

  bool get _validDates =>
      _period == 'TERM' ||
      (_from != null && _to != null && !_from!.isAfter(_to!));

  Future<void> _pickDate({required bool from}) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDate: from
          ? (_from ?? _to ?? widget.termStart)
          : (_to ?? _from ?? widget.termEnd),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create staff attendance report'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading('1', 'Staff records'),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('staff-report-search'),
                decoration: const InputDecoration(
                  labelText: 'Search staff by name, ID, or role',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              Row(
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'All staff included'
                        : '${_selected.length} staff selected',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(
                      () => _selected.addAll(
                        widget.people.map((person) => person.id),
                      ),
                    ),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              Container(
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _visible.isEmpty
                    ? const Center(child: Text('No staff found.'))
                    : ListView(
                        children: _visible
                            .map(
                              (person) => CheckboxListTile(
                                dense: true,
                                value: _selected.contains(person.id),
                                title: Text(person.name),
                                subtitle: Text(
                                  '${displayRoleName(person.role)} · ${person.id}',
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) => setState(() {
                                  checked == true
                                      ? _selected.add(person.id)
                                      : _selected.remove(person.id);
                                }),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 18),
              _heading('2', 'Date reference'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'TERM', label: Text('This term')),
                  ButtonSegment(value: 'DATES', label: Text('Date range')),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.first),
              ),
              if (_period == 'DATES') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          _from == null ? 'From' : _dateLabel(_from!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(_to == null ? 'To' : _dateLabel(_to!)),
                      ),
                    ),
                  ],
                ),
                if (!_validDates)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Choose a valid From and To date.',
                      style: TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              _heading('3', 'Output'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const ValueKey('staff-report-output'),
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
                selected: {_output},
                onSelectionChanged: (value) =>
                    setState(() => _output = value.first),
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
          key: const ValueKey('generate-staff-attendance-report'),
          onPressed: !_validDates
              ? null
              : () => Navigator.pop(
                  context,
                  _StaffReportConfig(
                    staffIds: Set.unmodifiable(_selected),
                    startDate: _period == 'TERM' ? widget.termStart : _from!,
                    endDate: _period == 'TERM' ? widget.termEnd : _to!,
                    output: _output,
                  ),
                ),
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Generate report'),
        ),
      ],
    );
  }

  Widget _heading(String number, String title) => Row(
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.green,
        child: Text(
          number,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
  bool _reportLoading = false;
  _StaffAttendanceReport? _report;

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
          if (_report != null) ...[
            const SizedBox(height: 18),
            _reportPreview(_report!),
          ],
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
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('create-staff-attendance-report'),
            onPressed: _reportLoading ? null : _openReportBuilder,
            icon: _reportLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined),
            label: const Text('Create report'),
          ),
          FilledButton.icon(
            key: const ValueKey('take-staff-attendance'),
            onPressed: () => widget.onOpenRegister(DateTime.now()),
            icon: const Icon(Icons.add),
            label: const Text('Take attendance'),
          ),
        ],
      ),
    ],
  );

  Future<void> _openReportBuilder() async {
    setState(() => _reportLoading = true);
    try {
      final people = await widget.repository.getActiveStaff(widget.schoolId);
      if (!mounted) return;
      setState(() => _reportLoading = false);
      final dates =
          (_data?.days ?? const <StaffAttendanceDayRecord>[])
              .where((day) => day.status != 'NON_SCHOOL_DAY')
              .map((day) => day.date)
              .toList()
            ..sort();
      final today = DateTime.now();
      final config = await showDialog<_StaffReportConfig>(
        context: context,
        builder: (_) => _StaffReportDialog(
          people: people,
          termStart: dates.isEmpty ? today : dates.first,
          termEnd: dates.isEmpty ? today : dates.last,
        ),
      );
      if (config == null || !mounted) return;
      setState(() => _reportLoading = true);
      await _generateReport(config, people);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create report. $error')),
      );
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _generateReport(
    _StaffReportConfig config,
    List<StaffAttendancePerson> people,
  ) async {
    final selectedPeople = config.staffIds.isEmpty
        ? people
        : people
              .where((person) => config.staffIds.contains(person.id))
              .toList();
    final recordedDays = (_data?.days ?? const <StaffAttendanceDayRecord>[])
        .where(
          (day) =>
              !day.date.isBefore(config.startDate) &&
              !day.date.isAfter(config.endDate) &&
              const {'SUBMITTED', 'DRAFT'}.contains(day.status),
        )
        .toList();
    final registers = await Future.wait(
      recordedDays.map(
        (day) => widget.repository.getDailyRegister(
          schoolId: widget.schoolId,
          date: day.date,
          people: people,
        ),
      ),
    );
    final entriesByStaff = <String, List<StaffAttendanceEntry>>{
      for (final person in selectedPeople) person.id: [],
    };
    for (final register in registers) {
      for (final entry in register) {
        entriesByStaff[entry.person.id]?.add(entry);
      }
    }
    final rows = selectedPeople.map((person) {
      final entries = entriesByStaff[person.id] ?? const [];
      final present = entries
          .where((entry) => entry.mark == StaffAttendanceMark.present)
          .length;
      final late = entries
          .where((entry) => entry.mark == StaffAttendanceMark.late)
          .length;
      final excused = entries
          .where(
            (entry) =>
                entry.mark == StaffAttendanceMark.absent &&
                entry.excused == true,
          )
          .length;
      final unexcused = entries
          .where(
            (entry) =>
                entry.mark == StaffAttendanceMark.absent &&
                entry.excused != true,
          )
          .length;
      final marked = present + late + excused + unexcused;
      return _StaffAttendanceReportRow(
        person: person,
        recordedDays: marked,
        present: present,
        late: late,
        excused: excused,
        unexcused: unexcused,
        attendanceRate: marked == 0 ? 0 : ((present + late) * 100) / marked,
        punctualityRate: present + late == 0
            ? 0
            : (present * 100) / (present + late),
      );
    }).toList()..sort((a, b) => a.person.name.compareTo(b.person.name));
    final report = _StaffAttendanceReport(
      startDate: config.startDate,
      endDate: config.endDate,
      termLabel: '${_term?.termLabel ?? ''} · ${_term?.academicYear ?? ''}',
      rows: rows,
    );
    if (!mounted) return;
    setState(() => _report = report);
    if (config.output != 'PREVIEW') {
      await _exportStaffReport(report, pdf: config.output == 'PDF');
    }
  }

  Future<void> _exportStaffReport(
    _StaffAttendanceReport report, {
    required bool pdf,
  }) async {
    final headers = <String>[
      'Staff member',
      'Role',
      'Recorded days',
      'Present',
      'Late',
      'Excused',
      'Unexcused',
      'Attendance',
      'Punctuality',
    ];
    final rows = report.rows
        .map(
          (row) => <String>[
            row.person.name,
            displayRoleName(row.person.role),
            '${row.recordedDays}',
            '${row.present}',
            '${row.late}',
            '${row.excused}',
            '${row.unexcused}',
            '${row.attendanceRate.toStringAsFixed(1)}%',
            '${row.punctualityRate.toStringAsFixed(1)}%',
          ],
        )
        .toList();
    final summary = report.summary;
    final fileStem =
        'staff-attendance-${_isoDate(report.startDate)}-${_isoDate(report.endDate)}';
    final success = pdf
        ? await exportAttendanceReportPdf(
            fileName: '$fileStem.pdf',
            schoolName: widget.schoolName?.trim().isNotEmpty == true
                ? widget.schoolName!.trim()
                : widget.schoolId,
            title: 'Staff attendance report',
            subtitle:
                '${report.termLabel} · ${_longDate(report.startDate)} to ${_longDate(report.endDate)}',
            headers: headers,
            rows: rows,
            summary: {
              'Staff': '${report.rows.length}',
              'Attendance rate':
                  '${summary.attendanceRate.toStringAsFixed(1)}%',
              'Punctuality': '${summary.punctualityRate.toStringAsFixed(1)}%',
              'Absences': '${summary.excused + summary.unexcused}',
            },
          )
        : await exportAttendanceReportSpreadsheet(
            fileName: '$fileStem.csv',
            headers: headers,
            rows: rows,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${pdf ? 'PDF' : 'Excel-compatible'} staff report downloaded.'
              : 'Downloads are unavailable on this device.',
        ),
      ),
    );
  }

  Widget _reportPreview(_StaffAttendanceReport report) {
    final summary = report.summary;
    return Container(
      key: const ValueKey('staff-attendance-report-preview'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff attendance report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Individual attendance and punctuality summary.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportStaffReport(report, pdf: true),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _exportStaffReport(report, pdf: false),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '${_longDate(report.startDate)} – ${_longDate(report.endDate)} · ${report.termLabel}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _reportMetric('Staff', '${report.rows.length}', AppColors.blue),
                _reportMetric(
                  'Attendance',
                  '${summary.attendanceRate.toStringAsFixed(1)}%',
                  AppColors.green,
                ),
                _reportMetric(
                  'Punctuality',
                  '${summary.punctualityRate.toStringAsFixed(1)}%',
                  AppColors.blue,
                ),
                _reportMetric(
                  'Absences',
                  '${summary.excused + summary.unexcused}',
                  AppColors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (report.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No staff match this report.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('STAFF MEMBER')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(numeric: true, label: Text('DAYS')),
                  DataColumn(numeric: true, label: Text('PRESENT')),
                  DataColumn(numeric: true, label: Text('LATE')),
                  DataColumn(numeric: true, label: Text('EXCUSED')),
                  DataColumn(numeric: true, label: Text('UNEXCUSED')),
                  DataColumn(numeric: true, label: Text('ATTENDANCE')),
                  DataColumn(numeric: true, label: Text('PUNCTUALITY')),
                ],
                rows: report.rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.person.name)),
                          DataCell(Text(displayRoleName(row.person.role))),
                          DataCell(Text('${row.recordedDays}')),
                          DataCell(Text('${row.present}')),
                          DataCell(Text('${row.late}')),
                          DataCell(Text('${row.excused}')),
                          DataCell(Text('${row.unexcused}')),
                          DataCell(
                            Text('${row.attendanceRate.toStringAsFixed(1)}%'),
                          ),
                          DataCell(
                            Text('${row.punctualityRate.toStringAsFixed(1)}%'),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _reportMetric(String label, String value, Color color) => Container(
    width: 180,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
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
  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
