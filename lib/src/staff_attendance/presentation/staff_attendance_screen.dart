import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/staff_attendance_models.dart';
import 'staff_attendance_dashboard.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({
    super.key,
    required this.schoolId,
    required this.repository,
  });
  final String schoolId;
  final StaffAttendanceRepository repository;
  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _date = DateTime.now();
  StaffAttendanceContext? _term;
  List<StaffAttendanceEntry> _entries = const [];
  bool _loading = false, _saving = false, _submitted = false;
  bool _showRegister = false;
  String? _error;
  int get _marked =>
      _entries.where((e) => e.mark != StaffAttendanceMark.unmarked).length;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openRegister(DateTime date) async {
    setState(() {
      _date = DateTime(date.year, date.month, date.day);
      _showRegister = true;
    });
    await _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _term ??= await widget.repository.getContext(widget.schoolId);
      final people = initial || _entries.isEmpty
          ? await widget.repository.getActiveStaff(widget.schoolId)
          : _entries.map((e) => e.person).toList();
      final entries = await widget.repository.getDailyRegister(
        schoolId: widget.schoolId,
        date: _date,
        people: people,
      );
      if (!mounted) return;
      final markedEntries = entries
          .where((entry) => entry.mark != StaffAttendanceMark.unmarked)
          .toList();
      setState(() {
        _entries = entries;
        _submitted =
            markedEntries.isNotEmpty &&
            markedEntries.every((entry) => entry.registerStatus == 'SUBMITTED');
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => !_showRegister
      ? StaffAttendanceDashboard(
          schoolId: widget.schoolId,
          repository: widget.repository,
          onOpenRegister: _openRegister,
        )
      : _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null
      ? _errorPanel()
      : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    _metrics(),
                    const SizedBox(height: 18),
                    _register(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        );

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => setState(() => _showRegister = false),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to attendance registers'),
      ),
      const SizedBox(height: 8),
      Wrap(
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff attendance',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mark the daily register for every active staff member. ${_term?.termLabel ?? ''} · ${_term?.academicYear ?? ''}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_formatDate(_date)),
          ),
        ],
      ),
    ],
  );

  // Kept temporarily as a reusable visual reference while the dashboard
  // aggregation is connected through StaffAttendanceDashboard.
  // ignore: unused_element
  Widget _termOverview() {
    final staffCount = _entries.isEmpty ? 1 : _entries.length;
    final expectedDays = 48 * staffCount;
    final presentDays = 43 * staffCount;
    final lateDays = 4 * staffCount;
    final excusedDays = staffCount;
    final attendanceRate = ((presentDays + lateDays) / expectedDays * 100)
        .toStringAsFixed(1);
    final punctualityRate = (presentDays / (presentDays + lateDays) * 100)
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Term attendance overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Design preview · representative term figures',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('All staff'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _termMetric(
                'Attendance rate',
                '$attendanceRate%',
                'Present and late',
                Icons.how_to_reg_outlined,
                AppColors.green,
              ),
              _termMetric(
                'Punctuality',
                '$punctualityRate%',
                'On time when present',
                Icons.schedule_outlined,
                AppColors.blue,
              ),
              _termMetric(
                'Expected staff-days',
                '$expectedDays',
                'Term to date',
                Icons.calendar_month_outlined,
                AppColors.text,
              ),
              _termMetric(
                'Late',
                '$lateDays',
                'Arrival records',
                Icons.access_time,
                AppColors.amber,
              ),
              _termMetric(
                'Excused absence',
                '$excusedDays',
                'Approved reasons',
                Icons.event_available_outlined,
                AppColors.blue,
              ),
              _termMetric(
                'Unexcused absence',
                '0',
                'Requires attention',
                Icons.error_outline,
                AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Staff breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('Staff member')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Present')),
                DataColumn(label: Text('Late')),
                DataColumn(label: Text('Excused')),
                DataColumn(label: Text('Unexcused')),
                DataColumn(label: Text('Attendance')),
                DataColumn(label: Text('Punctuality')),
              ],
              rows:
                  (_entries.isEmpty
                          ? const [
                              StaffAttendanceEntry(
                                person: StaffAttendancePerson(
                                  id: 'preview',
                                  name: 'Staff member',
                                  role: 'Teacher',
                                ),
                              ),
                            ]
                          : _entries)
                      .map(
                        (entry) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                entry.person.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(Text(entry.person.role)),
                            DataCell(Text('$presentDays')),
                            DataCell(Text('$lateDays')),
                            DataCell(Text('$excusedDays')),
                            const DataCell(Text('0')),
                            DataCell(Text('$attendanceRate%')),
                            DataCell(Text('$punctualityRate%')),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _termMetric(
    String label,
    String value,
    String supportingText,
    IconData icon,
    Color color,
  ) => Container(
    width: 222,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.20)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          supportingText,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _metrics() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _metric('Expected', _entries.length, AppColors.blue),
      _metric('Present', _count(StaffAttendanceMark.present), AppColors.green),
      _metric('Late', _count(StaffAttendanceMark.late), AppColors.amber),
      _metric('Absent', _count(StaffAttendanceMark.absent), AppColors.red),
      _metric('Not marked', _entries.length - _marked, AppColors.muted),
    ],
  );
  Widget _metric(String label, int value, Color color) => Container(
    width: 172,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _register() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily register · $_marked of ${_entries.length} marked',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _submitted
                          ? 'Submitted — changes require a correction reason'
                          : 'Save as draft or complete every row and submit',
                      style: TextStyle(
                        color: _submitted ? AppColors.amber : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _markAllPresent,
                icon: const Icon(Icons.done_all),
                label: const Text('Mark all present'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Text('No active staff records are available.'),
          )
        else
          ..._entries.asMap().entries.map(
            (row) => _staffRow(row.key, row.value),
          ),
      ],
    ),
  );

  Widget _staffRow(int index, StaffAttendanceEntry entry) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final identity = Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.greenSoft,
              child: Text(
                entry.person.initials,
                style: const TextStyle(
                  color: AppColors.green,
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
                    entry.person.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    entry.person.role,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (entry.mark == StaffAttendanceMark.absent)
                    Text(
                      '${entry.excused == true ? 'Excused' : 'Unexcused'} · ${entry.absenceReason}',
                      style: TextStyle(
                        color: entry.excused == true
                            ? AppColors.blue
                            : AppColors.red,
                        fontSize: 12,
                      ),
                    ),
                  if (entry.mark == StaffAttendanceMark.late)
                    Text(
                      'Arrival ${entry.timeIn}',
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 12,
                      ),
                    ),
                  if (entry.note.isNotEmpty)
                    Text(
                      entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        final controls = Wrap(
          spacing: 7,
          children: [
            for (final item in [
              (StaffAttendanceMark.present, 'Present', AppColors.green),
              (StaffAttendanceMark.late, 'Late', AppColors.amber),
              (StaffAttendanceMark.absent, 'Absent', AppColors.red),
            ])
              _markButton(index, entry, item.$1, item.$2, item.$3),
          ],
        );
        return box.maxWidth < 720
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 12), controls],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  controls,
                ],
              );
      },
    ),
  );

  Widget _markButton(
    int index,
    StaffAttendanceEntry entry,
    StaffAttendanceMark mark,
    String label,
    Color color,
  ) {
    final selected = entry.mark == mark;
    return OutlinedButton(
      onPressed: () => _selectMark(index, mark),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? color : AppColors.muted,
        backgroundColor: selected ? color.withValues(alpha: .1) : Colors.white,
        side: BorderSide(color: selected ? color : AppColors.border),
      ),
      child: Text(label),
    );
  }

  Widget _actions() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_entries.length - _marked} not marked',
            style: TextStyle(
              color: _marked == _entries.length
                  ? AppColors.green
                  : AppColors.amber,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        OutlinedButton(
          key: const ValueKey('save-staff-attendance-draft'),
          onPressed: _saving ? null : () => _save(false),
          child: const Text('Save draft'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          key: const ValueKey('submit-staff-attendance'),
          onPressed: _saving ? null : () => _save(true),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_submitted ? 'Submit correction' : 'Submit register'),
        ),
      ],
    ),
  );

  Future<void> _selectMark(int index, StaffAttendanceMark mark) async {
    var entry = _entries[index];
    if (mark == StaffAttendanceMark.absent) {
      final result = await _absenceDialog(entry);
      if (result == null) return;
      entry = result;
    } else if (mark == StaffAttendanceMark.late) {
      final result = await _lateDialog(entry);
      if (result == null) return;
      entry = result;
    } else {
      entry = entry.copyWith(
        mark: mark,
        clearTimeIn: true,
        clearExcused: true,
        clearAbsenceReason: true,
      );
    }
    setState(() {
      final next = [..._entries];
      next[index] = entry;
      _entries = next;
    });
  }

  Future<StaffAttendanceEntry?> _absenceDialog(
    StaffAttendanceEntry entry,
  ) async {
    bool? excused = entry.excused;
    String? reason = entry.absenceReason;
    final note = TextEditingController(text: entry.note);
    return showDialog<StaffAttendanceEntry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Absence details'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Is this absence excused?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Excused')),
                    ButtonSegment(value: false, label: Text('Unexcused')),
                  ],
                  selected: excused == null ? {} : {excused!},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (v) => setLocal(() => excused = v.first),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Approved leave',
                            'Sick',
                            'Official duty / training',
                            'Emergency',
                            'Other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => setLocal(() => reason = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
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
              onPressed: excused == null || reason == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      entry.copyWith(
                        mark: StaffAttendanceMark.absent,
                        excused: excused,
                        absenceReason: reason,
                        note: note.text,
                        clearTimeIn: true,
                      ),
                    ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<StaffAttendanceEntry?> _lateDialog(StaffAttendanceEntry entry) async {
    final now = TimeOfDay.now();
    final initialTime =
        entry.timeIn ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final arrivalTime = TextEditingController(text: initialTime)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialTime.length,
      );
    final note = TextEditingController(text: entry.note);
    String? timeError;
    final result = await showDialog<StaffAttendanceEntry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Late arrival'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('late-arrival-time'),
                  controller: arrivalTime,
                  autofocus: true,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Arrival time',
                    hintText: 'HH:mm',
                    helperText:
                        'Enter the actual arrival time, for example 08:25.',
                    errorText: timeError,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.schedule),
                  ),
                  onChanged: (_) {
                    if (timeError != null) {
                      setLocal(() => timeError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
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
                final value = arrivalTime.text.trim();
                final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
                final hour = match == null
                    ? null
                    : int.tryParse(match.group(1)!);
                final minute = match == null
                    ? null
                    : int.tryParse(match.group(2)!);
                if (hour == null ||
                    minute == null ||
                    hour > 23 ||
                    minute > 59) {
                  setLocal(
                    () => timeError = 'Enter a valid time in HH:mm format.',
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  entry.copyWith(
                    mark: StaffAttendanceMark.late,
                    timeIn:
                        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                    note: note.text,
                    clearExcused: true,
                    clearAbsenceReason: true,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _save(bool submit) async {
    if (submit && _marked != _entries.length) {
      _message(
        '${_entries.length - _marked} staff members are not marked.',
        error: true,
      );
      return;
    }
    String? correction;
    if (_submitted) {
      correction = await _correctionDialog();
      if (correction == null) return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveDailyRegister(
        schoolId: widget.schoolId,
        termId: _term!.termId,
        date: _date,
        entries: _entries,
        submit: submit,
        correctionReason: correction,
      );
      if (!mounted) return;
      setState(() {
        _entries = saved;
        _submitted = submit || _submitted;
      });
      _message(submit ? 'Staff attendance submitted.' : 'Draft saved.');
    } catch (e) {
      _message(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _correctionDialog() {
    final text = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for correction'),
        content: TextField(
          controller: text,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Explain why the submitted register is changing',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (text.text.trim().isNotEmpty) {
                Navigator.pop(context, text.text.trim());
              }
            },
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value != null) {
      setState(() => _date = value);
      await _load();
    }
  }

  void _markAllPresent() => setState(
    () => _entries = _entries
        .map(
          (e) => e.copyWith(
            mark: StaffAttendanceMark.present,
            clearTimeIn: true,
            clearExcused: true,
            clearAbsenceReason: true,
          ),
        )
        .toList(),
  );
  int _count(StaffAttendanceMark mark) =>
      _entries.where((e) => e.mark == mark).length;
  Widget _errorPanel() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, style: const TextStyle(color: AppColors.red)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _load(initial: true),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
  void _message(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? AppColors.red : AppColors.green,
        ),
      );
  static String _formatDate(DateTime date) =>
      '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1]}, ${date.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}
