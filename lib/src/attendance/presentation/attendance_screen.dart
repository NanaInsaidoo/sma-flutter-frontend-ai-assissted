import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/attendance_api_client.dart';
import '../domain/attendance_models.dart';

enum _AttendanceFilter { all, present, absent, late, unmarked }

class _StudentAttentionItem {
  const _StudentAttentionItem({
    required this.student,
    required this.label,
    required this.detail,
    required this.color,
  });

  final AttendanceStudent student;
  final String label;
  final String detail;
  final Color color;
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.academicYear,
    this.term,
    this.repository,
    this.initialGradeLevelId,
    this.initialStreamId,
    this.onBack,
    this.showClassSelectors = true,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String? academicYear;
  final String? term;
  final AttendanceRepository? repository;
  final int? initialGradeLevelId;
  final int? initialStreamId;
  final VoidCallback? onBack;
  final bool showClassSelectors;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceRepository _repository;
  final _searchController = TextEditingController();

  List<AttendanceGradeLevel> _grades = const [];
  List<AttendanceStream> _streams = const [];
  List<AttendanceEntry> _entries = const [];
  AttendanceGradeLevel? _selectedGrade;
  AttendanceStream? _selectedStream;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  _AttendanceFilter _filter = _AttendanceFilter.all;
  bool _loadingOptions = true;
  bool _loadingRoster = false;
  bool _saving = false;
  bool _hasExistingAttendance = false;
  String? _optionsError;
  String? _rosterError;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        AttendanceApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _searchController.addListener(_refreshSearch);
    _loadGrades();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> _loadGrades() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final grades = await _repository.getGradeLevels(widget.customSchoolId);
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _selectedGrade = grades.isEmpty
            ? null
            : grades
                      .where((grade) => grade.id == widget.initialGradeLevelId)
                      .firstOrNull ??
                  grades.first;
      });
      if (_selectedGrade != null) await _loadStreams(_selectedGrade!.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _optionsError = '$error');
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _loadStreams(int gradeLevelId) async {
    setState(() {
      _streams = const [];
      _selectedStream = null;
      _entries = const [];
      _rosterError = null;
      _loadingOptions = true;
    });
    try {
      final streams = await _repository.getStreams(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: gradeLevelId,
      );
      if (!mounted) return;
      setState(() {
        _streams = streams;
        _selectedStream = streams.isEmpty
            ? null
            : streams
                      .where((stream) => stream.id == widget.initialStreamId)
                      .firstOrNull ??
                  streams.first;
      });
      if (_selectedStream != null) await _loadRoster();
    } catch (error) {
      if (!mounted) return;
      setState(() => _optionsError = '$error');
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _loadRoster() async {
    final grade = _selectedGrade;
    final stream = _selectedStream;
    if (grade == null || stream == null) return;
    setState(() {
      _loadingRoster = true;
      _rosterError = null;
      _entries = const [];
    });
    try {
      final roster = await _repository.getRoster(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.id,
        streamId: stream.id,
        date: _selectedDate,
      );
      final records = {
        for (final record in roster.records) record.customStudentId: record,
      };
      if (!mounted) return;
      setState(() {
        _hasExistingAttendance = roster.hasExistingAttendance;
        _entries = roster.students.map((student) {
          final record = records[student.customStudentId];
          return AttendanceEntry(
            student: student,
            mark: record?.mark ?? AttendanceMark.unmarked,
            attendanceId: record?.attendanceId,
            minutesLate: record?.minutesLate ?? 0,
            remarks: record?.remarks ?? '',
          );
        }).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _rosterError = '$error');
    } finally {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                if (widget.showClassSelectors) ...[
                  const SizedBox(height: 20),
                  _selectionCard(),
                ] else if (_loadingOptions || _optionsError != null) ...[
                  const SizedBox(height: 20),
                  if (_optionsError != null)
                    _inlineError(_optionsError!, _loadGrades)
                  else
                    const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 18),
                if (_selectedStream != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showRail = constraints.maxWidth >= 1180;
                      final main = Column(
                        children: [
                          _summaryGrid(),
                          const SizedBox(height: 14),
                          _rosterCard(),
                        ],
                      );
                      if (!showRail) {
                        return Column(
                          children: [
                            main,
                            const SizedBox(height: 14),
                            _attentionPanel(horizontal: true),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 16),
                          SizedBox(width: 270, child: _attentionPanel()),
                        ],
                      );
                    },
                  ),
                ] else if (!_loadingOptions && _optionsError == null)
                  _emptyCard(
                    icon: Icons.account_tree_outlined,
                    title: 'No class stream available',
                    message:
                        'Create a stream for this grade before taking attendance.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final scope = [
      widget.term,
      widget.academicYear,
    ].where((value) => value?.trim().isNotEmpty == true).join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onBack != null) ...[
          IconButton.outlined(
            tooltip: 'Back to attendance dashboard',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedGrade == null || _selectedStream == null
                    ? 'Attendance'
                    : '${_selectedGrade!.name} · ${_selectedStream!.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '${_entries.length} students${scope.isEmpty ? '' : ' · $scope'}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (_hasExistingAttendance && !_loadingRoster)
          const _StatusPill(
            label: 'Attendance recorded',
            color: AppColors.green,
            background: AppColors.greenSoft,
          ),
      ],
    );
  }

  Widget _selectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class and date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (_optionsError != null) ...[
              _inlineError(_optionsError!, _loadGrades),
              const SizedBox(height: 14),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 700;
                final fields = [
                  _gradeDropdown(),
                  _streamDropdown(),
                  _dateField(),
                ];
                if (stacked) {
                  return Column(
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        fields[i],
                        if (i != fields.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      Expanded(child: fields[i]),
                      if (i != fields.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            if (_loadingOptions) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gradeDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey('grade-${_selectedGrade?.id}'),
      value: _selectedGrade?.id,
      decoration: const InputDecoration(labelText: 'Grade level'),
      hint: const Text('Select grade level'),
      items: _grades
          .map(
            (grade) =>
                DropdownMenuItem(value: grade.id, child: Text(grade.name)),
          )
          .toList(),
      onChanged: _loadingOptions
          ? null
          : (id) {
              final grade = _grades.where((item) => item.id == id).firstOrNull;
              if (grade == null) return;
              setState(() => _selectedGrade = grade);
              _loadStreams(grade.id);
            },
    );
  }

  Widget _streamDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey('stream-${_selectedStream?.id}-${_streams.length}'),
      value: _selectedStream?.id,
      decoration: const InputDecoration(labelText: 'Class stream'),
      hint: Text(
        _selectedGrade == null ? 'Select grade first' : 'Select stream',
      ),
      items: _streams
          .map(
            (stream) =>
                DropdownMenuItem(value: stream.id, child: Text(stream.name)),
          )
          .toList(),
      onChanged: _loadingOptions
          ? null
          : (id) {
              final stream = _streams
                  .where((item) => item.id == id)
                  .firstOrNull;
              if (stream == null) return;
              setState(() => _selectedStream = stream);
              _loadRoster();
            },
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(9),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Attendance date',
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 19),
        ),
        child: Text(_friendlyDate(_selectedDate)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (value == null || DateUtils.isSameDay(value, _selectedDate)) return;
    setState(() => _selectedDate = DateUtils.dateOnly(value));
    await _loadRoster();
  }

  Widget _summaryGrid() {
    final total = _entries.length;
    final present = _count(AttendanceMark.present);
    final absent = _count(AttendanceMark.absent);
    final late = _count(AttendanceMark.late);
    final percent = total == 0 ? 0 : ((present + late) / total * 100).round();
    final items = [
      ('Total students', '$total', AppColors.blue, Icons.groups_outlined),
      ('Present', '$present', AppColors.green, Icons.check_circle_outline),
      ('Absent', '$absent', AppColors.red, Icons.cancel_outlined),
      ('Late', '$late', AppColors.amber, Icons.schedule_outlined),
      ('Attendance', '$percent%', AppColors.purple, Icons.insights_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 48) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width < 150 ? 190 : width,
                  child: _SummaryCard(
                    label: item.$1,
                    value: item.$2,
                    color: item.$3,
                    icon: item.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _rosterCard() {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Class register',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_unmarkedCount()} unmarked',
                      style: TextStyle(
                        color: _unmarkedCount() == 0
                            ? AppColors.green
                            : AppColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _markAll(AttendanceMark.present),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all present'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _markAll(AttendanceMark.absent),
                      icon: const Icon(Icons.person_off_outlined, size: 18),
                      label: const Text('Mark all absent'),
                    ),
                    TextButton.icon(
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _markAll(AttendanceMark.unmarked),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Clear marks'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final search = TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search student name or ID',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    );
                    final filters = Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _AttendanceFilter.values
                          .map(
                            (filter) => ChoiceChip(
                              label: Text(_filterLabel(filter)),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          )
                          .toList(),
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [search, const SizedBox(height: 12), filters],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 14),
                        filters,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loadingRoster)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: CircularProgressIndicator(),
            )
          else if (_rosterError != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: _inlineError(_rosterError!, _loadRoster),
            )
          else if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: _emptyCard(
                icon: Icons.groups_outlined,
                title: 'No students in this class',
                message:
                    'Enrolled students assigned to this stream will appear here.',
                bordered: false,
              ),
            )
          else if (_visibleEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Text(
                'No students match this search or filter.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ..._visibleEntries.map(_studentRow),
          if (_entries.isNotEmpty) ...[const Divider(height: 1), _submitBar()],
        ],
      ),
    );
  }

  Widget _studentRow(AttendanceEntry entry) {
    final index = _entries.indexWhere(
      (item) => item.student.customStudentId == entry.student.customStudentId,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: switch (entry.mark) {
          AttendanceMark.present => const Color(0xFFF0FBF7),
          AttendanceMark.absent => const Color(0xFFFFF3F3),
          AttendanceMark.late => const Color(0xFFFFFAEC),
          AttendanceMark.unmarked => Colors.white,
        },
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.greenSoft,
            child: Text(
              _initials(entry.student.fullName),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.student.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.student.customStudentId,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (entry.mark == AttendanceMark.late)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${entry.minutesLate} min',
                style: const TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (entry.mark != AttendanceMark.unmarked) ...[
            _StatusPill(
              label: switch (entry.mark) {
                AttendanceMark.present => 'Present',
                AttendanceMark.absent => 'Absent',
                AttendanceMark.late => 'Late ${entry.minutesLate}m',
                AttendanceMark.unmarked => 'Unmarked',
              },
              color: _markColor(entry.mark),
              background: _markColor(entry.mark).withValues(alpha: .1),
            ),
            const SizedBox(width: 10),
          ],
          _MarkButton(
            label: 'P',
            tooltip: 'Present',
            color: AppColors.green,
            selected: entry.mark == AttendanceMark.present,
            onTap: () => _setMark(index, AttendanceMark.present),
          ),
          const SizedBox(width: 7),
          _MarkButton(
            label: 'A',
            tooltip: 'Absent',
            color: AppColors.red,
            selected: entry.mark == AttendanceMark.absent,
            onTap: () => _setMark(index, AttendanceMark.absent),
          ),
          const SizedBox(width: 7),
          _MarkButton(
            label: 'L',
            tooltip: 'Late',
            color: AppColors.amber,
            selected: entry.mark == AttendanceMark.late,
            onTap: () => _markLate(index),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    final complete = _unmarkedCount() == 0;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              complete
                  ? 'All students have been marked.'
                  : 'Mark ${_unmarkedCount()} more student${_unmarkedCount() == 1 ? '' : 's'} to submit.',
              style: TextStyle(
                color: complete ? AppColors.green : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _entries.isEmpty ? null : _retainDraft,
            child: const Text('Save draft'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('submit-attendance'),
            onPressed: complete && !_saving ? _saveAttendance : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _hasExistingAttendance
                        ? Icons.sync_rounded
                        : Icons.check_rounded,
                  ),
            label: Text(
              _saving
                  ? 'Saving...'
                  : _hasExistingAttendance
                  ? 'Update attendance'
                  : 'Submit attendance',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final grade = _selectedGrade;
    final stream = _selectedStream;
    if (grade == null || stream == null || _unmarkedCount() != 0) return;
    setState(() => _saving = true);
    try {
      await _repository.saveAttendance(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.id,
        streamId: stream.id,
        date: _selectedDate,
        entries: _entries,
        updateExisting: _hasExistingAttendance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasExistingAttendance
                ? 'Attendance updated successfully.'
                : 'Attendance submitted successfully.',
          ),
        ),
      );
      await _loadRoster();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save attendance. $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markAll(AttendanceMark mark) {
    setState(() {
      _entries = _entries
          .map(
            (entry) => entry.copyWith(
              mark: mark,
              minutesLate: mark == AttendanceMark.late ? 5 : 0,
            ),
          )
          .toList();
    });
  }

  void _retainDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft retained on this page until you submit it.'),
      ),
    );
  }

  Widget _attentionPanel({bool horizontal = false}) {
    final concerns = _attentionItems();
    final cards = concerns.map((concern) {
      return Container(
        width: horizontal ? 250 : double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          key: ValueKey(
            'attention-${concern.student.customStudentId}-${concern.label}',
          ),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _focusStudent(concern.student),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: concern.color,
                  child: Text(
                    _initials(concern.student.fullName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        concern.student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: concern.color.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          concern.label,
                          style: TextStyle(
                            color: concern.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        concern.detail,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Students needing attention',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Attendance patterns that may need follow-up.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (cards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const Text(
                  'No concerns yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else if (horizontal)
              Wrap(spacing: 10, runSpacing: 10, children: cards)
            else
              ...cards.expand((card) => [card, const SizedBox(height: 10)]),
          ],
        ),
      ),
    );
  }

  List<_StudentAttentionItem> _attentionItems() {
    if (_entries.isEmpty) return const [];

    final items = <_StudentAttentionItem>[];
    final currentConcernIds = <String>{};
    for (final entry in _entries) {
      if (entry.mark != AttendanceMark.absent &&
          entry.mark != AttendanceMark.late) {
        continue;
      }
      currentConcernIds.add(entry.student.customStudentId);
      final absent = entry.mark == AttendanceMark.absent;
      items.add(
        _StudentAttentionItem(
          student: entry.student,
          label: absent ? 'Absent today' : 'Late today',
          detail: absent
              ? 'Marked absent in today\'s register.'
              : 'Arrived ${entry.minutesLate} minutes late today.',
          color: absent ? AppColors.red : AppColors.amber,
        ),
      );
    }

    return items;
  }

  void _focusStudent(AttendanceStudent student) {
    _searchController.text = student.fullName;
    setState(() => _filter = _AttendanceFilter.all);
  }

  static Color _markColor(AttendanceMark mark) => switch (mark) {
    AttendanceMark.present => AppColors.green,
    AttendanceMark.absent => AppColors.red,
    AttendanceMark.late => AppColors.amber,
    AttendanceMark.unmarked => AppColors.muted,
  };

  void _setMark(int index, AttendanceMark mark, {int minutesLate = 0}) {
    if (index < 0) return;
    final updated = [..._entries];
    updated[index] = updated[index].copyWith(
      mark: mark,
      minutesLate: mark == AttendanceMark.late ? minutesLate : 0,
    );
    setState(() => _entries = updated);
  }

  Future<void> _markLate(int index) async {
    final current = _entries[index].minutesLate;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => _LateMinutesDialog(initialMinutes: current),
    );
    if (minutes != null) {
      _setMark(index, AttendanceMark.late, minutesLate: minutes);
    }
  }

  List<AttendanceEntry> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    return _entries.where((entry) {
      final matchesQuery =
          query.isEmpty ||
          entry.student.fullName.toLowerCase().contains(query) ||
          entry.student.customStudentId.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _AttendanceFilter.all => true,
        _AttendanceFilter.present => entry.mark == AttendanceMark.present,
        _AttendanceFilter.absent => entry.mark == AttendanceMark.absent,
        _AttendanceFilter.late => entry.mark == AttendanceMark.late,
        _AttendanceFilter.unmarked => entry.mark == AttendanceMark.unmarked,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  int _count(AttendanceMark mark) =>
      _entries.where((entry) => entry.mark == mark).length;
  int _unmarkedCount() => _count(AttendanceMark.unmarked);

  Widget _inlineError(String message, VoidCallback retry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
    bool bordered = true,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 38, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
    return bordered ? Card(child: child) : child;
  }

  static String _filterLabel(_AttendanceFilter filter) => switch (filter) {
    _AttendanceFilter.all => 'All',
    _AttendanceFilter.present => 'Present',
    _AttendanceFilter.absent => 'Absent',
    _AttendanceFilter.late => 'Late',
    _AttendanceFilter.unmarked => 'Unmarked',
  };

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  static String _friendlyDate(DateTime value) {
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
    final suffix = value.day >= 11 && value.day <= 13
        ? 'th'
        : switch (value.day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '${value.day}$suffix ${months[value.month - 1]} ${value.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            border: Border.all(color: selected ? color : AppColors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LateMinutesDialog extends StatefulWidget {
  const _LateMinutesDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_LateMinutesDialog> createState() => _LateMinutesDialogState();
}

class _LateMinutesDialogState extends State<_LateMinutesDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialMinutes > 0 ? '${widget.initialMinutes}' : '5',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = int.tryParse(_controller.text) ?? 0;
    return AlertDialog(
      title: const Text('How late was the student?'),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('late-minutes'),
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes late',
                suffixText: 'minutes',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 30]
                  .map(
                    (value) => ActionChip(
                      label: Text('$value min'),
                      onPressed: () =>
                          setState(() => _controller.text = '$value'),
                    ),
                  )
                  .toList(),
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
          onPressed: minutes > 0 ? () => Navigator.pop(context, minutes) : null,
          child: const Text('Mark late'),
        ),
      ],
    );
  }
}
