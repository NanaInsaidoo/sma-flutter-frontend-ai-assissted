import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/attendance_api_client.dart';
import '../domain/attendance_models.dart';

enum _AttendanceFilter { all, present, absent, late, unmarked }

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
    this.initialDate,
    this.onBack,
    this.onOpenCalendar,
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
  final DateTime? initialDate;
  final VoidCallback? onBack;
  final VoidCallback? onOpenCalendar;
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
  List<AttendanceEntry> _originalEntries = const [];
  List<AttendanceLateConcern> _lateConcerns = const [];
  AttendanceGradeLevel? _selectedGrade;
  AttendanceStream? _selectedStream;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  _AttendanceFilter _filter = _AttendanceFilter.all;
  bool _loadingOptions = true;
  bool _loadingRoster = false;
  bool _loadingAttention = false;
  bool _saving = false;
  bool _hasExistingAttendance = false;
  bool _editingSubmitted = false;
  AttendanceEntryContext? _entryContext;
  String? _optionsError;
  String? _rosterError;
  String? _attentionError;
  final Set<String> _escalatingStudentIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateUtils.dateOnly(widget.initialDate!);
    }
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
      _originalEntries = const [];
      _lateConcerns = const [];
      _editingSubmitted = false;
      _entryContext = null;
      _attentionError = null;
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
      final results = await Future.wait([
        _repository.getRoster(
          customSchoolId: widget.customSchoolId,
          gradeLevelId: grade.id,
          streamId: stream.id,
          date: _selectedDate,
        ),
        _repository.getEntryContext(
          customSchoolId: widget.customSchoolId,
          streamId: stream.id,
          date: _selectedDate,
        ),
      ]);
      final roster = results[0] as AttendanceRoster;
      final entryContext = results[1] as AttendanceEntryContext;
      final records = {
        for (final record in roster.records) record.customStudentId: record,
      };
      if (!mounted) return;
      setState(() {
        _hasExistingAttendance =
            roster.hasExistingAttendance || entryContext.submitted;
        _editingSubmitted = false;
        _entryContext = entryContext;
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
        _originalEntries = [..._entries];
      });
      await _loadLateConcerns(grade, stream);
    } catch (error) {
      if (!mounted) return;
      setState(() => _rosterError = '$error');
    } finally {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  Future<void> _loadLateConcerns(
    AttendanceGradeLevel grade,
    AttendanceStream stream,
  ) async {
    if (mounted) {
      setState(() {
        _loadingAttention = true;
        _attentionError = null;
      });
    }
    try {
      final concerns = await _repository.getLateConcerns(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.id,
        streamId: stream.id,
        date: _selectedDate,
      );
      if (!mounted ||
          _selectedGrade?.id != grade.id ||
          _selectedStream?.id != stream.id) {
        return;
      }
      setState(() => _lateConcerns = concerns);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lateConcerns = const [];
        _attentionError = '$error';
      });
    } finally {
      if (mounted) setState(() => _loadingAttention = false);
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
                const SizedBox(height: 14),
                _attendanceDateBanner(),
                if (_entryContext?.schoolDay == false) ...[
                  const SizedBox(height: 12),
                  _nonSchoolDayBanner(),
                ],
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
          _StatusPill(
            label: _registerStatusLabel,
            color: _registerStatusColor,
            background: _registerStatusColor.withValues(alpha: .1),
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

  Widget _attendanceDateBanner() {
    final today = DateUtils.dateOnly(
      _entryContext?.currentDate ?? DateTime.now(),
    );
    final selected = DateUtils.dateOnly(_selectedDate);
    final future = selected.isAfter(today);
    final relation = selected == today
        ? 'Today'
        : selected.isBefore(today)
        ? 'Past attendance date'
        : 'Future attendance date';
    final color = future ? AppColors.amber : AppColors.green;
    final background = future ? const Color(0xFFFFF7E7) : AppColors.greenSoft;
    return Semantics(
      container: true,
      label: 'Attendance date ${_friendlyDate(_selectedDate)}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: color, size: 26),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAKING ATTENDANCE FOR',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _friendlyDate(_selectedDate),
                    key: const ValueKey('prominent-attendance-date'),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    relation,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (future) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'You can view the class, but attendance cannot be marked or submitted for a future date.',
                      key: ValueKey('future-attendance-blocked-message'),
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('change-attendance-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Change date'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nonSchoolDayBanner() {
    final message = _entryContext?.calendarMessage.trim();
    return Container(
      key: const ValueKey('non-school-day-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Text(
              message?.isNotEmpty == true
                  ? message!
                  : 'This date is not an official school day per the school calendar.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('view-non-school-days'),
            onPressed: widget.onOpenCalendar,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('View non-school days'),
          ),
        ],
      ),
    );
  }

  Widget _gradeDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey('grade-${_selectedGrade?.id}'),
      isExpanded: true,
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
      isExpanded: true,
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
    final canEdit = _canEditAttendance;
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
                if (_hasExistingAttendance) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: _editingSubmitted
                          ? const Color(0xFFFFF7E8)
                          : const Color(0xFFF3F6F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _editingSubmitted
                              ? Icons.edit_outlined
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: _editingSubmitted
                              ? AppColors.amber
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _editingSubmitted
                                    ? 'Editing submitted attendance. A reason is required when you save changes.'
                                    : 'Submitted attendance is read-only. Select Edit attendance before making changes.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!_editingSubmitted &&
                                  _entryContext?.registerStatus ==
                                      AttendanceRegisterStatus.complete) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _entryContext!.acknowledgedBy.isEmpty
                                      ? 'Acknowledged by school management.'
                                      : 'Acknowledged by ${_entryContext!.acknowledgedBy}.',
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_entryContext!
                                    .acknowledgmentNote
                                    .isNotEmpty)
                                  Text(
                                    'Note: ${_entryContext!.acknowledgmentNote}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _entries.isEmpty || !canEdit
                          ? null
                          : () => _markAll(AttendanceMark.present),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all present'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _entries.isEmpty || !canEdit
                          ? null
                          : () => _markAll(AttendanceMark.absent),
                      icon: const Icon(Icons.person_off_outlined, size: 18),
                      label: const Text('Mark all absent'),
                    ),
                    TextButton.icon(
                      onPressed: _entries.isEmpty || !canEdit
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
            onTap: _canEditAttendance
                ? () => _setMark(index, AttendanceMark.present)
                : null,
          ),
          const SizedBox(width: 7),
          _MarkButton(
            label: 'A',
            tooltip: 'Absent',
            color: AppColors.red,
            selected: entry.mark == AttendanceMark.absent,
            onTap: _canEditAttendance
                ? () => _setMark(index, AttendanceMark.absent)
                : null,
          ),
          const SizedBox(width: 7),
          _MarkButton(
            label: 'L',
            tooltip: 'Late',
            color: AppColors.amber,
            selected: entry.mark == AttendanceMark.late,
            onTap: _canEditAttendance ? () => _markLate(index) : null,
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    final complete = _unmarkedCount() == 0;
    final readOnly = _hasExistingAttendance && !_editingSubmitted;
    final blockedMessage = _entryContext == null
        ? 'Checking attendance rules...'
        : _entryContext!.futureDate
        ? 'Attendance cannot be taken for a future date.'
        : !_entryContext!.schoolDay
        ? 'Attendance cannot be taken because this is not an official school day.'
        : readOnly
        ? 'This submitted register is read-only.'
        : _hasExistingAttendance && !_hasAttendanceChanges
        ? 'Make a change before saving this register.'
        : null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blockedMessage ??
                      (complete
                          ? 'All students have been marked.'
                          : 'Mark ${_unmarkedCount()} more student${_unmarkedCount() == 1 ? '' : 's'} to submit.'),
                  style: TextStyle(
                    color: complete ? AppColors.green : AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'This register will be saved for ${_friendlyDate(_selectedDate)}.',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (readOnly)
            FilledButton.icon(
              key: const ValueKey('edit-submitted-attendance'),
              onPressed: _canOpenSubmittedForEditing
                  ? () => setState(() => _editingSubmitted = true)
                  : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit attendance'),
            )
          else ...[
            if (_hasExistingAttendance)
              OutlinedButton(
                onPressed: _saving ? null : _cancelSubmittedEdit,
                child: const Text('Cancel edit'),
              )
            else
              OutlinedButton(
                onPressed: _entries.isEmpty || !_canEditAttendance
                    ? null
                    : _retainDraft,
                child: const Text('Save draft'),
              ),
            const SizedBox(width: 10),
            FilledButton.icon(
              key: const ValueKey('submit-attendance'),
              onPressed:
                  complete &&
                      !_saving &&
                      _canEditAttendance &&
                      (!_hasExistingAttendance || _hasAttendanceChanges)
                  ? () => _prepareAttendanceSubmission()
                  : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _hasExistingAttendance
                          ? Icons.save_outlined
                          : Icons.check_rounded,
                    ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : _hasExistingAttendance
                    ? 'Save changes'
                    : 'Submit attendance',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _prepareAttendanceSubmission() async {
    final entryContext = _entryContext;
    if (entryContext == null ||
        entryContext.futureDate ||
        !entryContext.schoolDay) {
      return;
    }
    if (_hasExistingAttendance &&
        (!_editingSubmitted || !_hasAttendanceChanges)) {
      return;
    }

    var permissionAffirmed = false;
    String? authorizationStatement;
    if (entryContext.permissionAffirmationRequired) {
      final affirmed = await _requestPermissionAffirmation();
      if (affirmed != true || !mounted) return;
      permissionAffirmed = true;
      authorizationStatement =
          'I confirm that I have the proper authorization to take attendance for this class.';
    }

    String? correctionReason;
    if (_hasExistingAttendance) {
      correctionReason = await _requestCorrectionReason();
      if (correctionReason == null || !mounted) return;
    } else if (_selectedDate.isBefore(
      DateUtils.dateOnly(entryContext.currentDate),
    )) {
      correctionReason = await _requestPastAttendanceReason();
      if (correctionReason == null || !mounted) return;
    }

    await _saveAttendance(
      permissionAffirmed: permissionAffirmed,
      authorizationStatement: authorizationStatement,
      correctionReason: correctionReason,
    );
  }

  Future<void> _saveAttendance({
    String? vacationOverrideReason,
    bool permissionAffirmed = false,
    String? authorizationStatement,
    String? correctionReason,
  }) async {
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
        vacationOverrideReason: vacationOverrideReason,
        permissionAffirmed: permissionAffirmed,
        authorizationStatement: authorizationStatement,
        correctionReason: correctionReason,
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
      if (vacationOverrideReason == null &&
          error.toString().toLowerCase().contains('teaching begins')) {
        setState(() => _saving = false);
        final reason = await _requestVacationOverrideReason(error.toString());
        if (reason != null && mounted) {
          await _saveAttendance(
            vacationOverrideReason: reason,
            permissionAffirmed: permissionAffirmed,
            authorizationStatement: authorizationStatement,
            correctionReason: correctionReason,
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save attendance. $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _requestPermissionAffirmation() async {
    var affirmed = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: AppColors.green,
          ),
          title: const Text('Confirm authorization'),
          content: SizedBox(
            width: 480,
            child: CheckboxListTile(
              key: const ValueKey('attendance-permission-affirmation'),
              value: affirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I confirm that I have the proper authorization to take attendance for this class.',
              ),
              onChanged: (value) =>
                  setDialogState(() => affirmed = value == true),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-attendance-permission'),
              onPressed: affirmed
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Confirm and Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _requestPastAttendanceReason() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _AttendanceReasonDialog(
        icon: Icons.history_rounded,
        iconColor: AppColors.amber,
        title: 'Reason for past attendance',
        fieldKey: ValueKey('past-attendance-reason'),
        confirmKey: ValueKey('confirm-past-attendance-reason'),
        label: 'Reason for late entry or correction',
        helper: 'This reason will be kept in the audit trail.',
        actionLabel: 'Continue',
      ),
    );
  }

  Future<String?> _requestCorrectionReason() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _AttendanceReasonDialog(
        icon: Icons.edit_note_rounded,
        iconColor: AppColors.amber,
        title: 'Reason for attendance change',
        fieldKey: ValueKey('attendance-change-reason'),
        confirmKey: ValueKey('confirm-attendance-change-reason'),
        label: 'What changed and why?',
        helper:
            'The reason, changes, your identity, and time will be kept in the audit trail.',
        actionLabel: 'Save changes',
      ),
    );
  }

  Future<String?> _requestVacationOverrideReason(String warning) {
    return showDialog<String>(
      context: context,
      builder: (_) => _AttendanceReasonDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        title: 'Teaching has not started',
        warning: warning.replaceFirst('AttendanceApiException: ', ''),
        label: 'Reason for recording attendance early',
        actionLabel: 'Continue and record',
      ),
    );
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

  void _cancelSubmittedEdit() {
    setState(() {
      _entries = [..._originalEntries];
      _editingSubmitted = false;
    });
  }

  Widget _attentionPanel({bool horizontal = false}) {
    final cards = _lateConcerns.map((concern) {
      return Container(
        width: horizontal ? 250 : double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.amber,
                  child: Text(
                    _initials(concern.fullName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    concern.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Late for ${concern.consecutiveLateDays} consecutive school days',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: concern.escalated
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Escalated'),
                    )
                  : OutlinedButton.icon(
                      key: ValueKey(
                        'escalate-lateness-${concern.customStudentId}',
                      ),
                      onPressed:
                          _escalatingStudentIds.contains(
                            concern.customStudentId,
                          )
                          ? null
                          : () => _escalateLateness(concern),
                      icon:
                          _escalatingStudentIds.contains(
                            concern.customStudentId,
                          )
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 17),
                      label: const Text('Escalate to headmaster'),
                    ),
            ),
          ],
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
              'Only students late on 2 or more consecutive school days.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (_loadingAttention)
              const LinearProgressIndicator(minHeight: 2)
            else if (_attentionError != null)
              TextButton.icon(
                onPressed: () {
                  final grade = _selectedGrade;
                  final stream = _selectedStream;
                  if (grade != null && stream != null) {
                    _loadLateConcerns(grade, stream);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry repeated lateness'),
              )
            else if (cards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const Text(
                  'No repeated lateness.',
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

  Future<void> _escalateLateness(AttendanceLateConcern concern) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _AttendanceReasonDialog(
        icon: Icons.arrow_upward_rounded,
        iconColor: AppColors.amber,
        title: 'Escalate to headmaster',
        fieldKey: ValueKey('lateness-escalation-note'),
        confirmKey: ValueKey('confirm-lateness-escalation'),
        label: 'Note for the headmaster',
        helper:
            'Briefly explain the repeated lateness or any follow-up already made.',
        actionLabel: 'Escalate',
      ),
    );
    if (note == null || !mounted) return;
    final grade = _selectedGrade;
    final stream = _selectedStream;
    if (grade == null || stream == null) return;
    setState(() => _escalatingStudentIds.add(concern.customStudentId));
    try {
      final updated = await _repository.escalateLateConcern(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.id,
        streamId: stream.id,
        customStudentId: concern.customStudentId,
        date: _selectedDate,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _lateConcerns = [
          for (final item in _lateConcerns)
            if (item.customStudentId == updated.customStudentId)
              updated
            else
              item,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escalated to the headmaster.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not escalate repeated lateness. $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _escalatingStudentIds.remove(concern.customStudentId));
      }
    }
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

  bool get _canEditAttendance {
    final entryContext = _entryContext;
    return entryContext != null &&
        !entryContext.futureDate &&
        entryContext.schoolDay &&
        (!_hasExistingAttendance || _editingSubmitted);
  }

  bool get _canOpenSubmittedForEditing {
    final entryContext = _entryContext;
    return entryContext != null &&
        !entryContext.futureDate &&
        entryContext.schoolDay &&
        !_saving;
  }

  bool get _hasAttendanceChanges {
    if (_entries.length != _originalEntries.length) return true;
    for (var index = 0; index < _entries.length; index++) {
      final current = _entries[index];
      final original = _originalEntries[index];
      if (current.student.customStudentId != original.student.customStudentId ||
          current.mark != original.mark ||
          current.minutesLate != original.minutesLate ||
          current.remarks != original.remarks) {
        return true;
      }
    }
    return false;
  }

  String get _registerStatusLabel => switch (_entryContext?.registerStatus) {
    AttendanceRegisterStatus.complete => 'Complete',
    AttendanceRegisterStatus.nonSchoolDay => 'Non-school day',
    AttendanceRegisterStatus.awaitingAcknowledgment =>
      'Awaiting acknowledgment',
    _ => 'Submitted',
  };

  Color get _registerStatusColor => switch (_entryContext?.registerStatus) {
    AttendanceRegisterStatus.complete => AppColors.green,
    AttendanceRegisterStatus.nonSchoolDay => AppColors.muted,
    AttendanceRegisterStatus.awaitingAcknowledgment => AppColors.amber,
    _ => AppColors.blue,
  };

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
  final VoidCallback? onTap;

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
            color: onTap == null
                ? const Color(0xFFF4F5F5)
                : selected
                ? color
                : Colors.white,
            border: Border.all(
              color: onTap == null
                  ? AppColors.border
                  : selected
                  ? color
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? AppColors.muted.withValues(alpha: .55)
                  : selected
                  ? Colors.white
                  : AppColors.muted,
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

class _AttendanceReasonDialog extends StatefulWidget {
  const _AttendanceReasonDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.label,
    required this.actionLabel,
    this.warning,
    this.helper,
    this.fieldKey,
    this.confirmKey,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String label;
  final String actionLabel;
  final String? warning;
  final String? helper;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_AttendanceReasonDialog> createState() =>
      _AttendanceReasonDialogState();
}

class _AttendanceReasonDialogState extends State<_AttendanceReasonDialog> {
  final _controller = TextEditingController();
  String? _validation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(widget.icon, color: widget.iconColor),
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.warning?.isNotEmpty == true) ...[
              Text(widget.warning!),
              const SizedBox(height: 16),
            ],
            TextField(
              key: widget.fieldKey,
              controller: _controller,
              autofocus: true,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: widget.helper,
                errorText: _validation,
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
          key: widget.confirmKey,
          onPressed: () {
            final value = _controller.text.trim();
            if (value.length < 5) {
              setState(() => _validation = 'Enter a clear reason.');
              return;
            }
            Navigator.pop(context, value);
          },
          child: Text(widget.actionLabel),
        ),
      ],
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
