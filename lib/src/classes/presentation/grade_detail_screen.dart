import 'package:flutter/material.dart';

import '../domain/class_models.dart';
import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../theme/app_theme.dart';

class GradeDetailScreen extends StatefulWidget {
  const GradeDetailScreen({
    super.key,
    required this.customSchoolId,
    required this.streamId,
    required this.gradeLevelId,
    required this.subjectGradeLevelId,
    required this.gradeName,
    required this.streamName,
    required this.enrolled,
    required this.capacity,
    required this.active,
    this.classTeacherName,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onOpenAttendance,
    this.onOpenAssessments,
    this.onOpenIncidents,
    this.onOpenCalendar,
    this.attendanceRepository,
    required this.repository,
    this.onClassTeachersChanged,
    required this.onBack,
  });

  final String customSchoolId;
  final int streamId;
  final int gradeLevelId;
  final int subjectGradeLevelId;
  final String gradeName;
  final String streamName;
  final int enrolled;
  final int? capacity;
  final bool active;
  final String? classTeacherName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenAssessments;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenCalendar;
  final AttendanceRepository? attendanceRepository;
  final ClassesRepository repository;
  final Future<void> Function()? onClassTeachersChanged;
  final VoidCallback onBack;

  @override
  State<GradeDetailScreen> createState() => _GradeDetailScreenState();
}

class _GradeDetailScreenState extends State<GradeDetailScreen> {
  _StreamDetailTab _selectedTab = _StreamDetailTab.overview;
  final List<_Subject> _gesSubjects = const [
    _Subject(
      name: 'Literacy (Ghanaian Language)',
      code: 'LIT-KG1-001',
      description: 'Reading, writing, and oral language',
      icon: '📖',
      type: _SubjectType.core,
      source: _SubjectSource.ges,
    ),
    _Subject(
      name: 'Numeracy / Mathematics',
      code: 'NUM-KG1-001',
      description: 'Number concepts and operations',
      icon: '🔢',
      type: _SubjectType.core,
      source: _SubjectSource.ges,
    ),
    _Subject(
      name: 'Our World, Our People',
      code: 'OWP-KG1-001',
      description: 'Environmental and social studies',
      icon: '🌍',
      type: _SubjectType.core,
      source: _SubjectSource.ges,
    ),
    _Subject(
      name: 'Creative Arts & Design',
      code: 'CAD-KG1-001',
      description: 'Arts, craft, and expression',
      icon: '🎨',
      type: _SubjectType.core,
      source: _SubjectSource.ges,
    ),
    _Subject(
      name: 'Physical Education & Health',
      code: 'PEH-KG1-001',
      description: 'Motor skills and health',
      icon: '⚽',
      type: _SubjectType.core,
      source: _SubjectSource.ges,
    ),
  ];

  final List<_Subject> _customSubjects = [
    const _Subject(
      name: 'French Language',
      code: 'FRN-KG1',
      description: 'Introductory French',
      icon: '🇫🇷',
      type: _SubjectType.elective,
      source: _SubjectSource.custom,
    ),
    const _Subject(
      name: 'Music',
      code: 'MUS-KG1',
      description: 'Rhythm and basic music',
      icon: '🎵',
      type: _SubjectType.core,
      source: _SubjectSource.custom,
    ),
  ];

  bool _drawerOpen = false;
  bool _showAddForm = false;
  _SubjectType _newSubjectType = _SubjectType.core;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<ClassTeacherAssignment> _classTeachers = const [];
  bool _loadingTeachers = true;
  bool _teacherActionBusy = false;
  String? _teacherError;
  List<ClassSubject> _subjects = const [];
  List<SubjectTeacherAssignment> _subjectTeachers = const [];
  List<SchoolStaffOption> _staff = const [];
  bool _loadingSubjects = true;
  bool _subjectActionBusy = false;
  String? _subjectError;
  late final AttendanceRepository _attendanceRepository =
      widget.attendanceRepository ??
      AttendanceApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
  late Future<AttendanceRoster> _rosterFuture;
  late Future<AttendanceTermHistory> _attendanceHistoryFuture;
  bool _attendanceRegisterOpen = false;
  DateTime? _attendanceRegisterDate;

  int get _totalSubjects => _subjects.length;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadClassTeachers();
    _loadSubjects();
    _rosterFuture = _attendanceRepository.getRoster(
      customSchoolId: widget.customSchoolId,
      gradeLevelId: widget.gradeLevelId,
      streamId: widget.streamId,
      date: DateTime.now(),
    );
    _attendanceHistoryFuture = _loadAttendanceHistory();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _subjectError = null;
    });
    try {
      final result = await Future.wait([
        widget.repository.getGradeSubjects(
          customSchoolId: widget.customSchoolId,
          gradeLevelId: widget.subjectGradeLevelId,
        ),
        widget.repository.getSubjectTeacherAssignments(
          customSchoolId: widget.customSchoolId,
          streamId: widget.streamId,
        ),
        widget.repository.getSchoolStaff(widget.customSchoolId),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = result[0] as List<ClassSubject>;
        _subjectTeachers = result[1] as List<SubjectTeacherAssignment>;
        _staff = (result[2] as List<SchoolStaffOption>)
            .where((s) => s.active)
            .toList();
        _loadingSubjects = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _subjectError = '$e';
          _loadingSubjects = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_attendanceRegisterOpen) {
      return AttendanceScreen(
        customSchoolId: widget.customSchoolId,
        repository: _attendanceRepository,
        initialGradeLevelId: widget.gradeLevelId,
        initialStreamId: widget.streamId,
        initialDate: _attendanceRegisterDate,
        showClassSelectors: false,
        onBack: () {
          setState(() {
            _attendanceRegisterOpen = false;
            _rosterFuture = _attendanceRepository.getRoster(
              customSchoolId: widget.customSchoolId,
              gradeLevelId: widget.gradeLevelId,
              streamId: widget.streamId,
              date: DateTime.now(),
            );
            _attendanceHistoryFuture = _loadAttendanceHistory();
          });
        },
      );
    }
    return Stack(
      children: [
        Column(
          children: [
            _DetailTopBar(
              gradeName: widget.gradeName,
              streamName: widget.streamName,
              onBack: widget.onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ClassIntro(
                          streamName: widget.streamName,
                          classTeacherName: _displayClassTeacherName,
                          enrolled: widget.enrolled,
                          capacity: widget.capacity,
                          active: widget.active,
                          totalSubjects: _totalSubjects,
                        ),
                        const SizedBox(height: 18),
                        _StreamDetailTabs(
                          selected: _selectedTab,
                          pendingAttendance: 0,
                          onChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                        const SizedBox(height: 18),
                        switch (_selectedTab) {
                          _StreamDetailTab.overview => Column(
                            children: [
                              _ClassStats(
                                enrolled: widget.enrolled,
                                capacity: widget.capacity,
                                active: widget.active,
                              ),
                              const SizedBox(height: 18),
                              _ClassTeachersCard(
                                teachers: _classTeachers,
                                loading: _loadingTeachers,
                                error: _teacherError,
                                busy: _teacherActionBusy,
                                fallbackTeacherName: widget.classTeacherName,
                                onRetry: _loadClassTeachers,
                                onAddTeacher: _showAddClassTeacherDialog,
                                onSetPrimary: _setPrimaryClassTeacher,
                                onToggleActive: _toggleClassTeacher,
                                onRemove: _removeClassTeacher,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _StudentsCard(
                                      rosterFuture: _rosterFuture,
                                      onRetry: _reloadRoster,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 290,
                                    child: _SidePanel(
                                      totalSubjects: _totalSubjects,
                                      gesCount: _subjects
                                          .where((subject) => !subject.custom)
                                          .length,
                                      customCount: _subjects
                                          .where((subject) => subject.custom)
                                          .length,
                                      onManageSubjects: () => setState(
                                        () => _selectedTab =
                                            _StreamDetailTab.subjects,
                                      ),
                                      onOpenAttendance: () => setState(
                                        () => _selectedTab =
                                            _StreamDetailTab.attendance,
                                      ),
                                      onOpenAssessments:
                                          widget.onOpenAssessments,
                                      onOpenIncidents: widget.onOpenIncidents,
                                      onOpenCalendar: widget.onOpenCalendar,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          _StreamDetailTab.subjects => _StreamSubjectsCard(
                            subjects: _subjects,
                            assignments: _subjectTeachers,
                            loading: _loadingSubjects,
                            busy: _subjectActionBusy,
                            error: _subjectError,
                            onRetry: _loadSubjects,
                            onManage: _manageSubjectTeachers,
                          ),
                          _StreamDetailTab.attendance => _StreamAttendanceTab(
                            streamName: widget.streamName,
                            enrolled: widget.enrolled,
                            rosterFuture: _rosterFuture,
                            historyFuture: _attendanceHistoryFuture,
                            onTakeAttendance: () =>
                                _openAttendanceRegister(DateTime.now()),
                            onOpenDay: _openAttendanceRegister,
                            onResolveDay: _resolveNonSchoolDay,
                            onRetry: () => setState(
                              () => _attendanceHistoryFuture =
                                  _loadAttendanceHistory(),
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDrawer,
              child: Container(color: Colors.black.withValues(alpha: .34)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _drawerOpen ? 0 : -500,
          width: 480,
          child: _SubjectsDrawer(
            gradeName: widget.gradeName,
            totalCount: _totalSubjects,
            gesSubjects: _gesSubjects,
            customSubjects: _customSubjects,
            showAddForm: _showAddForm,
            newSubjectType: _newSubjectType,
            nameController: _nameController,
            codeController: _codeController,
            descriptionController: _descriptionController,
            onClose: _closeDrawer,
            onShowForm: () => setState(() => _showAddForm = true),
            onHideForm: () => setState(() => _showAddForm = false),
            onSubjectTypeChanged: (type) =>
                setState(() => _newSubjectType = type),
            onAddSubject: _addSubject,
            onRemoveSubject: _removeSubject,
          ),
        ),
      ],
    );
  }

  void _reloadRoster() => setState(() {
    _rosterFuture = _attendanceRepository.getRoster(
      customSchoolId: widget.customSchoolId,
      gradeLevelId: widget.gradeLevelId,
      streamId: widget.streamId,
      date: DateTime.now(),
    );
  });

  Future<AttendanceTermHistory> _loadAttendanceHistory() =>
      _attendanceRepository.getTermHistory(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: widget.gradeLevelId,
        streamId: widget.streamId,
      );

  void _openAttendanceRegister(DateTime date) => setState(() {
    _attendanceRegisterDate = date;
    _attendanceRegisterOpen = true;
  });

  Future<void> _resolveNonSchoolDay(
    AttendanceDaySummary day,
    int termId,
  ) async {
    final name = TextEditingController(text: 'No school');
    final description = TextEditingController();
    var type = 'Holiday';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Resolve as non-school day'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date: ${_attendanceDate(day.date)}'),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Event name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: const ['Holiday', 'Other']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setDialog(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason / description',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark as non-school day'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || name.text.trim().isEmpty) return;
    await _attendanceRepository.markNonSchoolDay(
      customSchoolId: widget.customSchoolId,
      termId: termId,
      date: day.date,
      name: name.text.trim(),
      type: type,
      description: description.text,
    );
    if (!mounted) return;
    setState(() => _attendanceHistoryFuture = _loadAttendanceHistory());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Date resolved as a non-school day.')),
    );
  }

  Future<void> _manageSubjectTeachers(ClassSubject subject) async {
    final current = _subjectTeachers
        .where(
          (a) =>
              a.active &&
              a.subjectId == subject.id &&
              a.subjectType == (subject.custom ? 'CUSTOM' : 'GES'),
        )
        .toList();
    final selected = current.map((a) => a.staffId).toSet();
    final reason = TextEditingController();
    var effectiveFrom = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('${subject.name} teachers'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select every teacher who teaches this subject in this stream.',
                  ),
                ),
                const SizedBox(height: 12),
                if (_staff.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No active staff members are available.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: _staff
                          .map(
                            (person) => CheckboxListTile(
                              value: selected.contains(person.id),
                              title: Text(person.name),
                              subtitle: Text(
                                '${person.role} · ${person.email}',
                              ),
                              onChanged: (v) => setDialog(() {
                                if (v == true) {
                                  selected.add(person.id);
                                } else {
                                  selected.remove(person.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Effective from'),
                  subtitle: Text(
                    '${effectiveFrom.day.toString().padLeft(2, '0')}/${effectiveFrom.month.toString().padLeft(2, '0')}/${effectiveFrom.year}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: effectiveFrom,
                      firstDate: DateTime(effectiveFrom.year - 1),
                      lastDate: DateTime(effectiveFrom.year + 1),
                    );
                    if (picked != null) {
                      setDialog(() => effectiveFrom = picked);
                    }
                  },
                ),
                const Text(
                  'Unselecting an assigned teacher deactivates the assignment from this date. Its history is retained.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: current.isEmpty
                        ? 'Assignment note (optional)'
                        : 'Reason for change',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save teachers'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final existingIds = current.map((a) => a.staffId).toSet();
    final hasChanges =
        selected.difference(existingIds).isNotEmpty ||
        existingIds.difference(selected).isNotEmpty;
    // The first teacher allocation is normal class setup. A reason becomes
    // mandatory only when changing an existing, auditable allocation.
    if (current.isNotEmpty && hasChanges && reason.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a reason for this teacher change.'),
          ),
        );
      }
      return;
    }
    final newlyAssigned = selected.difference(existingIds);
    final missingRole = <SchoolStaffOption>[
      for (final staffId in newlyAssigned)
        ..._staff.where(
          (member) =>
              member.id == staffId && !member.hasRole('SUBJECT_TEACHER'),
        ),
    ];
    for (final member in missingRole) {
      final confirmed = await _confirmTeacherRole(
        member,
        roleLabel: 'Subject Teacher',
      );
      if (!confirmed) return;
    }
    setState(() => _subjectActionBusy = true);
    try {
      for (final member in missingRole) {
        await widget.repository.grantStaffRole(
          customSchoolId: widget.customSchoolId,
          staff: member,
          role: 'SUBJECT_TEACHER',
        );
      }
      for (final staffId in newlyAssigned) {
        await widget.repository.addSubjectTeacherAssignment(
          customSchoolId: widget.customSchoolId,
          streamId: widget.streamId,
          gradeLevelId: widget.subjectGradeLevelId,
          subject: subject,
          staffId: staffId,
          effectiveFrom: effectiveFrom,
          reason: reason.text,
        );
      }
      for (final assignment in current.where(
        (a) => !selected.contains(a.staffId),
      )) {
        await widget.repository.removeSubjectTeacherAssignment(
          customSchoolId: widget.customSchoolId,
          streamId: widget.streamId,
          assignmentId: assignment.id,
          effectiveFrom: effectiveFrom,
          reason: reason.text,
        );
      }
      await _loadSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${subject.name} teachers updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _subjectActionBusy = false);
  }

  Future<bool> _confirmTeacherRole(
    SchoolStaffOption staff, {
    required String roleLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Teacher access required'),
            content: Text(
              '${staff.name} does not currently have $roleLabel access. Assign this role now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel assignment'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Assign role'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _closeDrawer() {
    setState(() {
      _drawerOpen = false;
      _showAddForm = false;
    });
  }

  Future<void> _loadClassTeachers() async {
    setState(() {
      _loadingTeachers = true;
      _teacherError = null;
    });
    try {
      final result = await Future.wait([
        widget.repository.getClassTeachers(
          customSchoolId: widget.customSchoolId,
          streamId: widget.streamId,
        ),
        widget.repository.getSchoolStaff(widget.customSchoolId),
      ]);
      final teachers = result[0] as List<ClassTeacherAssignment>;
      final staff = result[1] as List<SchoolStaffOption>;
      final staffById = {for (final member in staff) member.id: member};
      final hydratedTeachers = teachers.map((teacher) {
        final member = staffById[teacher.staffId];
        if (member == null) return teacher;
        return ClassTeacherAssignment(
          id: teacher.id,
          staffId: teacher.staffId,
          name: teacher.name.trim().isEmpty || teacher.name == 'Unnamed teacher'
              ? member.name
              : teacher.name,
          email: teacher.email.trim().isEmpty ? member.email : teacher.email,
          role: teacher.role.trim().isEmpty ? member.role : teacher.role,
          isPrimary: teacher.isPrimary,
          isActive: teacher.isActive,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _classTeachers = hydratedTeachers;
        _loadingTeachers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teacherError = '$error';
        _loadingTeachers = false;
      });
    }
  }

  String? get _displayClassTeacherName {
    final active = _classTeachers.where((teacher) => teacher.isActive).toList();
    if (active.isEmpty) return widget.classTeacherName;
    return active
        .firstWhere((teacher) => teacher.isPrimary, orElse: () => active.first)
        .name;
  }

  Future<void> _showAddClassTeacherDialog() async {
    setState(() => _teacherActionBusy = true);
    List<SchoolStaffOption> staff;
    try {
      staff = await widget.repository.getSchoolStaff(widget.customSchoolId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _teacherActionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load school staff. $error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _teacherActionBusy = false);

    final assignedStaffIds = _classTeachers.map((item) => item.staffId).toSet();
    final selection = await showDialog<_TeacherSelection>(
      context: context,
      builder: (context) => _AddClassTeacherDialog(
        staff: staff
            .where((member) => !assignedStaffIds.contains(member.id))
            .toList(),
        hasPrimaryTeacher: _classTeachers.any((teacher) => teacher.isPrimary),
      ),
    );
    if (selection == null) return;

    final selectedStaff = staff.firstWhere(
      (member) => member.id == selection.staffId,
    );
    final needsRole = !selectedStaff.hasRole('CLASS_TEACHER');
    if (needsRole &&
        !await _confirmTeacherRole(selectedStaff, roleLabel: 'Class Teacher')) {
      return;
    }

    await _performTeacherAction(
      successMessage: 'Class teacher assigned.',
      action: () async {
        if (needsRole) {
          await widget.repository.grantStaffRole(
            customSchoolId: widget.customSchoolId,
            staff: selectedStaff,
            role: 'CLASS_TEACHER',
          );
        }
        await widget.repository.addClassTeacher(
          customSchoolId: widget.customSchoolId,
          streamId: widget.streamId,
          staffId: selection.staffId,
          isPrimary: selection.isPrimary,
        );
      },
    );
  }

  Future<void> _setPrimaryClassTeacher(ClassTeacherAssignment teacher) async {
    await _performTeacherAction(
      successMessage: '${teacher.name} is now the primary class teacher.',
      action: () => widget.repository.setPrimaryClassTeacher(
        customSchoolId: widget.customSchoolId,
        streamId: widget.streamId,
        classTeacherId: teacher.id,
      ),
    );
  }

  Future<void> _toggleClassTeacher(ClassTeacherAssignment teacher) async {
    await _performTeacherAction(
      successMessage: teacher.isActive
          ? '${teacher.name} has been deactivated for this stream.'
          : '${teacher.name} has been reactivated for this stream.',
      action: () => widget.repository.updateClassTeacher(
        customSchoolId: widget.customSchoolId,
        classTeacherId: teacher.id,
        isPrimary: teacher.isPrimary,
        isActive: !teacher.isActive,
      ),
    );
  }

  Future<void> _removeClassTeacher(ClassTeacherAssignment teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove class teacher?'),
        content: Text(
          'This removes ${teacher.name} from ${widget.streamName}. The staff account will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _performTeacherAction(
      successMessage: '${teacher.name} removed from this stream.',
      action: () => widget.repository.removeClassTeacher(
        customSchoolId: widget.customSchoolId,
        classTeacherId: teacher.id,
      ),
    );
  }

  Future<void> _performTeacherAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    setState(() => _teacherActionBusy = true);
    try {
      await action();
      await _loadClassTeachers();
      await widget.onClassTeachersChanged?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Class teacher update failed. $error')),
      );
      setState(() => _teacherActionBusy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _teacherActionBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  void _addSubject() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final icons = ['📚', '🎯', '🔬', '🎭', '💻', '🌱', '🧮'];
    setState(() {
      _customSubjects.add(
        _Subject(
          name: name,
          code: _codeController.text.trim().isEmpty
              ? 'CUSTOM-${_customSubjects.length + 1}'
              : _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? 'Custom subject'
              : _descriptionController.text.trim(),
          icon: icons[_customSubjects.length % icons.length],
          type: _newSubjectType,
          source: _SubjectSource.custom,
        ),
      );
      _nameController.clear();
      _codeController.clear();
      _descriptionController.clear();
      _newSubjectType = _SubjectType.core;
      _showAddForm = false;
    });
  }

  void _removeSubject(_Subject subject) {
    setState(() => _customSubjects.remove(subject));
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.gradeName,
    required this.streamName,
    required this.onBack,
  });

  final String gradeName;
  final String streamName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Classes'),
          ),
          const Text('/', style: TextStyle(color: AppColors.muted)),
          const SizedBox(width: 10),
          Text(
            gradeName,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              streamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export Report'),
          ),
        ],
      ),
    );
  }
}

class _ClassIntro extends StatelessWidget {
  const _ClassIntro({
    required this.streamName,
    required this.classTeacherName,
    required this.enrolled,
    required this.capacity,
    required this.active,
    required this.totalSubjects,
  });

  final String streamName;
  final String? classTeacherName;
  final int enrolled;
  final int? capacity;
  final bool active;
  final int totalSubjects;

  @override
  Widget build(BuildContext context) {
    final teacher = classTeacherName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$enrolled enrolled · ${capacity == null ? 'Capacity not set' : 'Capacity $capacity'}',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _IntroPill(
              icon: Icons.groups_rounded,
              label: capacity == null
                  ? 'Capacity not set'
                  : '$enrolled / $capacity',
            ),
            _IntroPill(
              icon: Icons.person_outline_rounded,
              label: teacher.isEmpty ? 'No class teacher assigned' : teacher,
            ),
            _IntroPill(
              icon: active
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              label: active ? 'Active stream' : 'Inactive stream',
              color: active ? AppColors.green : AppColors.muted,
            ),
          ],
        ),
      ],
    );
  }
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({
    required this.icon,
    required this.label,
    this.color = AppColors.green,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ClassStats extends StatelessWidget {
  const _ClassStats({
    required this.enrolled,
    required this.capacity,
    required this.active,
  });

  final int enrolled;
  final int? capacity;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final capacityText = capacity == null ? 'Not set' : '$capacity';
    final fill = capacity == null || capacity! <= 0
        ? null
        : ((enrolled / capacity!) * 100).round();
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Enrolled',
            value: '$enrolled',
            sub: 'Active students in stream',
            icon: Icons.people_alt_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Capacity',
            value: capacityText,
            sub: 'Stream capacity',
            icon: Icons.event_seat_rounded,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Fill',
            value: fill == null ? 'N/A' : '$fill%',
            sub: fill == null
                ? 'Set capacity to calculate'
                : 'Current utilization',
            icon: Icons.stacked_line_chart_rounded,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Status',
            value: active ? 'Active' : 'Inactive',
            sub: 'Backend stream state',
            icon: active
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            color: active ? AppColors.green : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            left: 0,
            right: null,
            child: Container(width: 4, color: color),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          letterSpacing: .7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        sub,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StreamDetailTab { overview, subjects, attendance }

class _StreamDetailTabs extends StatelessWidget {
  const _StreamDetailTabs({
    required this.selected,
    required this.pendingAttendance,
    required this.onChanged,
  });

  final _StreamDetailTab selected;
  final int pendingAttendance;
  final ValueChanged<_StreamDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tab(
              _StreamDetailTab.overview,
              'Overview',
              Icons.dashboard_outlined,
            ),
            _tab(
              _StreamDetailTab.subjects,
              'Subjects',
              Icons.menu_book_outlined,
            ),
            _tab(
              _StreamDetailTab.attendance,
              'Attendance',
              Icons.fact_check_outlined,
              badge: pendingAttendance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    _StreamDetailTab value,
    String label,
    IconData icon, {
    int? badge,
  }) {
    final active = selected == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.green : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.green : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.green : AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badge != null && badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9BE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Color(0xFF946000),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreamAttendanceTab extends StatefulWidget {
  const _StreamAttendanceTab({
    required this.streamName,
    required this.enrolled,
    required this.rosterFuture,
    required this.historyFuture,
    required this.onTakeAttendance,
    required this.onOpenDay,
    required this.onResolveDay,
    required this.onRetry,
  });

  final String streamName;
  final int enrolled;
  final Future<AttendanceRoster> rosterFuture;
  final Future<AttendanceTermHistory> historyFuture;
  final VoidCallback onTakeAttendance;
  final ValueChanged<DateTime> onOpenDay;
  final void Function(AttendanceDaySummary day, int termId) onResolveDay;
  final VoidCallback onRetry;

  @override
  State<_StreamAttendanceTab> createState() => _StreamAttendanceTabState();
}

class _StreamAttendanceTabState extends State<_StreamAttendanceTab> {
  final _search = TextEditingController();
  AttendanceDayStatus? _filter;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance records',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Completed, missing, and non-school days for the current term.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onTakeAttendance,
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Take attendance'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FutureBuilder<AttendanceTermHistory>(
                  future: widget.historyFuture,
                  builder: (context, snapshot) {
                    final history = snapshot.data;
                    final days =
                        history?.days ?? const <AttendanceDaySummary>[];
                    final schoolDays = days
                        .where(
                          (day) =>
                              day.status != AttendanceDayStatus.nonSchoolDay,
                        )
                        .toList();
                    final completed = schoolDays
                        .where(
                          (day) => day.status == AttendanceDayStatus.completed,
                        )
                        .toList();
                    final missing = schoolDays.length - completed.length;
                    final expectedMarks = completed.fold<int>(
                      0,
                      (sum, day) => sum + day.expectedStudents,
                    );
                    final attended = completed.fold<int>(
                      0,
                      (sum, day) => sum + day.present + day.late,
                    );
                    final average = expectedMarks == 0
                        ? 0
                        : (attended / expectedMarks * 100).round();
                    return Row(
                      children: [
                        Expanded(
                          child: _AttendanceMetric(
                            'School days',
                            '${schoolDays.length}',
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _AttendanceMetric(
                            'Completed',
                            '${completed.length}',
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _AttendanceMetric(
                            'Missing',
                            '$missing',
                            warning: missing > 0,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _AttendanceMetric('Term average', '$average%'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _page = 0),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search attendance records',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: widget.onTakeAttendance,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Select date'),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<AttendanceDayStatus?>(
                      onSelected: (value) => setState(() {
                        _filter = value;
                        _page = 0;
                      }),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: null, child: Text('All statuses')),
                        PopupMenuItem(
                          value: AttendanceDayStatus.completed,
                          child: Text('Completed'),
                        ),
                        PopupMenuItem(
                          value: AttendanceDayStatus.missing,
                          child: Text('Missing'),
                        ),
                        PopupMenuItem(
                          value: AttendanceDayStatus.nonSchoolDay,
                          child: Text('Non-school day'),
                        ),
                      ],
                      child: _AttendanceFilterChip(
                        label: _filter == null
                            ? 'All statuses'
                            : _filter == AttendanceDayStatus.completed
                            ? 'Completed'
                            : _filter == AttendanceDayStatus.missing
                            ? 'Missing'
                            : 'Non-school day',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const _AttendanceTableHeader(),
              FutureBuilder<AttendanceTermHistory>(
                future: widget.historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Term attendance history could not be loaded.',
                          ),
                          TextButton(
                            onPressed: widget.onRetry,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  final history = snapshot.data!;
                  final query = _search.text.trim().toLowerCase();
                  final filtered = history.days.where((day) {
                    if (_filter != null && day.status != _filter) return false;
                    return query.isEmpty ||
                        _attendanceDate(
                          day.date,
                        ).toLowerCase().contains(query) ||
                        day.eventName.toLowerCase().contains(query);
                  }).toList();
                  final pages = filtered.isEmpty
                      ? 1
                      : (filtered.length / _pageSize).ceil();
                  final safePage = _page.clamp(0, pages - 1);
                  final visible = filtered
                      .skip(safePage * _pageSize)
                      .take(_pageSize)
                      .toList();
                  if (visible.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        history.days.isEmpty
                            ? 'No attendance is due yet. Teaching begins ${_attendanceDate(history.teachingStartDate)}.'
                            : 'No attendance days match the current search or status filter.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      ...visible.map((day) {
                        final completed =
                            day.status == AttendanceDayStatus.completed;
                        final nonSchool =
                            day.status == AttendanceDayStatus.nonSchoolDay;
                        return _AttendanceRecordRow(
                          date: _attendanceDate(day.date),
                          status: completed
                              ? 'Completed'
                              : nonSchool
                              ? 'Non-school day'
                              : 'Missing',
                          summary: completed
                              ? '${day.present + day.late}/${day.expectedStudents} present · ${day.absent} absent · ${day.late} late'
                              : nonSchool
                              ? '${day.eventName}${day.eventDescription.isEmpty ? '' : ' · ${day.eventDescription}'}'
                              : 'No register submitted for ${day.expectedStudents} students',
                          action: completed
                              ? 'View / Correct'
                              : nonSchool
                              ? 'View'
                              : 'Resolve',
                          warning: !completed && !nonSchool,
                          onPressed: () => nonSchool
                              ? _showNonSchoolDay(day)
                              : completed
                              ? widget.onOpenDay(day.date)
                              : _showMissingActions(day, history.termId),
                        );
                      }),
                      if (pages > 1)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${safePage + 1} of $pages'),
                              IconButton(
                                onPressed: safePage == 0
                                    ? null
                                    : () =>
                                          setState(() => _page = safePage - 1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              IconButton(
                                onPressed: safePage + 1 >= pages
                                    ? null
                                    : () =>
                                          setState(() => _page = safePage + 1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showMissingActions(AttendanceDaySummary day, int termId) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Take attendance'),
              subtitle: Text(_attendanceDate(day.date)),
              onTap: () => Navigator.pop(context, 'take'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Resolve as non-school day'),
              subtitle: const Text(
                'Creates a school calendar event for this date',
              ),
              onTap: () => Navigator.pop(context, 'resolve'),
            ),
          ],
        ),
      ),
    );
    if (action == 'take') widget.onOpenDay(day.date);
    if (action == 'resolve') widget.onResolveDay(day, termId);
  }

  Future<void> _showNonSchoolDay(AttendanceDaySummary day) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.event_busy_outlined, color: AppColors.green),
      title: Text(day.eventName.isEmpty ? 'Non-school day' : day.eventName),
      content: Text(
        '${_attendanceDate(day.date)}${day.eventDescription.isEmpty ? '' : '\n\n${day.eventDescription}'}',
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

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric(this.label, this.value, {this.warning = false});
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF7E7) : const Color(0xFFF7FAFA),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: warning ? const Color(0xFFB26A00) : AppColors.text,
          ),
        ),
      ],
    ),
  );
}

class _AttendanceFilterChip extends StatelessWidget {
  const _AttendanceFilterChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        const Icon(Icons.expand_more_rounded, size: 18),
      ],
    ),
  );
}

class _AttendanceTableHeader extends StatelessWidget {
  const _AttendanceTableHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        SizedBox(width: 150, child: Text('DATE')),
        SizedBox(width: 120, child: Text('STATUS')),
        Expanded(child: Text('REGISTER SUMMARY')),
        SizedBox(width: 100, child: Text('ACTION')),
      ],
    ),
  );
}

class _AttendanceRecordRow extends StatelessWidget {
  const _AttendanceRecordRow({
    required this.date,
    required this.status,
    required this.summary,
    required this.action,
    required this.onPressed,
    this.warning = false,
  });

  final String date;
  final String status;
  final String summary;
  final String action;
  final VoidCallback onPressed;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            date,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 120,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: warning ? const Color(0xFFFFEBC3) : AppColors.greenSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: warning ? const Color(0xFF8C5A00) : AppColors.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(summary, style: const TextStyle(color: AppColors.muted)),
        ),
        SizedBox(
          width: 100,
          child: TextButton(onPressed: onPressed, child: Text(action)),
        ),
      ],
    ),
  );
}

String _attendanceDate(DateTime value) {
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

class _StudentsCard extends StatelessWidget {
  const _StudentsCard({required this.rosterFuture, required this.onRetry});

  final Future<AttendanceRoster> rosterFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AttendanceRoster>(
      future: rosterFuture,
      builder: (context, snapshot) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _SectionHeader(
              title: 'Students',
              trailing: '${snapshot.data?.students.length ?? 0} enrolled',
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              )
            else if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('Unable to load the student roster.'),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (snapshot.data?.students.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.all(42),
                child: Text('No active students are assigned to this stream.'),
              )
            else
              ...snapshot.data!.students.map(
                (student) => ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      student.fullName.isEmpty
                          ? '?'
                          : student.fullName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(student.customStudentId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassTeachersCard extends StatelessWidget {
  const _ClassTeachersCard({
    required this.teachers,
    required this.loading,
    required this.error,
    required this.busy,
    required this.fallbackTeacherName,
    required this.onRetry,
    required this.onAddTeacher,
    required this.onSetPrimary,
    required this.onToggleActive,
    required this.onRemove,
  });

  final List<ClassTeacherAssignment> teachers;
  final bool loading;
  final String? error;
  final bool busy;
  final String? fallbackTeacherName;
  final VoidCallback onRetry;
  final VoidCallback onAddTeacher;
  final ValueChanged<ClassTeacherAssignment> onSetPrimary;
  final ValueChanged<ClassTeacherAssignment> onToggleActive;
  final ValueChanged<ClassTeacherAssignment> onRemove;

  @override
  Widget build(BuildContext context) {
    final fallback = fallbackTeacherName?.trim() ?? '';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SectionHeader(
            title: 'Class teachers',
            trailing: teachers.isEmpty
                ? 'No active assignment'
                : '${teachers.length} assigned',
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(22),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.red,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not load class teachers. $error',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (teachers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fallback.isEmpty
                          ? 'Assign one or more teachers to this stream. You can mark one as primary.'
                          : 'Backend summary shows $fallback, but the multi-teacher assignment list is empty. Add the teacher here to manage it going forward.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : onAddTeacher,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add teacher'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final teacher in teachers)
                  _ClassTeacherRow(
                    teacher: teacher,
                    busy: busy,
                    onSetPrimary: () => onSetPrimary(teacher),
                    onToggleActive: () => onToggleActive(teacher),
                    onRemove: () => onRemove(teacher),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Only one teacher can be primary for a stream.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onAddTeacher,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add teacher'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ClassTeacherRow extends StatelessWidget {
  const _ClassTeacherRow({
    required this.teacher,
    required this.busy,
    required this.onSetPrimary,
    required this.onToggleActive,
    required this.onRemove,
  });

  final ClassTeacherAssignment teacher;
  final bool busy;
  final VoidCallback onSetPrimary;
  final VoidCallback onToggleActive;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _TeacherAvatar(name: teacher.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      teacher.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (teacher.isPrimary)
                      const _MiniBadge(
                        label: 'Primary',
                        color: AppColors.green,
                      ),
                    _MiniBadge(
                      label: teacher.isActive ? 'Active' : 'Inactive',
                      color: teacher.isActive
                          ? AppColors.green
                          : AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (teacher.role.trim().isNotEmpty) teacher.role,
                    if (teacher.email.trim().isNotEmpty) teacher.email,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!teacher.isPrimary)
            TextButton(
              onPressed: busy || !teacher.isActive ? null : onSetPrimary,
              child: const Text('Make primary'),
            ),
          TextButton(
            onPressed: busy ? null : onToggleActive,
            child: Text(teacher.isActive ? 'Deactivate' : 'Reactivate'),
          ),
          IconButton(
            tooltip: 'Remove teacher',
            onPressed: busy ? null : onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'T'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AddClassTeacherDialog extends StatefulWidget {
  const _AddClassTeacherDialog({
    required this.staff,
    required this.hasPrimaryTeacher,
  });

  final List<SchoolStaffOption> staff;
  final bool hasPrimaryTeacher;

  @override
  State<_AddClassTeacherDialog> createState() => _AddClassTeacherDialogState();
}

class _AddClassTeacherDialogState extends State<_AddClassTeacherDialog> {
  String _query = '';
  SchoolStaffOption? _selected;
  late bool _isPrimary = !widget.hasPrimaryTeacher;

  List<SchoolStaffOption> get _visibleStaff {
    final query = _query.trim().toLowerCase();
    return widget.staff.where((staff) {
      if (!staff.active) return false;
      if (query.isEmpty) return true;
      return staff.name.toLowerCase().contains(query) ||
          staff.email.toLowerCase().contains(query) ||
          staff.role.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStaff;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Class Teacher',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Search active school staff and assign them to this stream.',
                          style: TextStyle(color: AppColors.muted),
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
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by name, email, or role',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'No active unassigned staff found.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final staff = visible[index];
                        final selected = _selected?.id == staff.id;
                        return InkWell(
                          onTap: () => setState(() => _selected = staff),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.greenSoft
                                  : const Color(0xFFF8FAF9),
                              border: Border.all(
                                color: selected
                                    ? AppColors.green
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _TeacherAvatar(name: staff.name),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (staff.role.isNotEmpty) staff.role,
                                          if (staff.email.isNotEmpty)
                                            staff.email,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.green,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Switch(
                    value: _isPrimary,
                    onChanged: (value) => setState(() => _isPrimary = value),
                  ),
                  const Expanded(
                    child: Text(
                      'Make primary class teacher',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(
                            _TeacherSelection(
                              staffId: _selected!.id,
                              isPrimary: _isPrimary,
                            ),
                          ),
                    child: const Text('Assign teacher'),
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

class _TeacherSelection {
  const _TeacherSelection({required this.staffId, required this.isPrimary});

  final String staffId;
  final bool isPrimary;
}

class _StreamSubjectsCard extends StatelessWidget {
  const _StreamSubjectsCard({
    required this.subjects,
    required this.assignments,
    required this.loading,
    required this.busy,
    required this.error,
    required this.onRetry,
    required this.onManage,
  });
  final List<ClassSubject> subjects;
  final List<SubjectTeacherAssignment> assignments;
  final bool loading, busy;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<ClassSubject> onManage;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.green),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects and teachers',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Each subject belongs to this grade. Assign one or more teachers for this stream.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (!loading)
                Text(
                  '${subjects.length} subjects',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No subjects are configured for this grade level.'),
            )
          else
            ...subjects.map((subject) {
              final type = subject.custom ? 'CUSTOM' : 'GES';
              final assigned = assignments
                  .where(
                    (a) =>
                        a.active &&
                        a.subjectId == subject.id &&
                        a.subjectType == type,
                  )
                  .toList();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.green.withValues(alpha: .12),
                  child: Text(
                    subject.name.isEmpty ? '?' : subject.name[0],
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  assigned.isEmpty
                      ? 'No subject teacher assigned'
                      : assigned.map((a) => a.staffName).join(', '),
                ),
                trailing: OutlinedButton.icon(
                  onPressed: busy ? null : () => onManage(subject),
                  icon: Icon(
                    assigned.isEmpty
                        ? Icons.person_add_alt_1
                        : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(assigned.isEmpty ? 'Assign teachers' : 'Manage'),
                ),
              );
            }),
          if (assignments.any((a) => !a.active)) ...[
            const Divider(height: 28),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Inactive assignment history (${assignments.where((a) => !a.active).length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              children: assignments
                  .where((a) => !a.active)
                  .map(
                    (a) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded),
                      title: Text('${a.subjectName} · ${a.staffName}'),
                      subtitle: Text(
                        [
                          if (a.effectiveFrom != null)
                            'Effective ${a.effectiveFrom!.day.toString().padLeft(2, '0')}/${a.effectiveFrom!.month.toString().padLeft(2, '0')}/${a.effectiveFrom!.year}',
                          if (a.changeReason.trim().isNotEmpty) a.changeReason,
                        ].join(' · '),
                      ),
                      trailing: const Chip(label: Text('Inactive')),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.totalSubjects,
    required this.gesCount,
    required this.customCount,
    required this.onManageSubjects,
    required this.onOpenAttendance,
    this.onOpenAssessments,
    this.onOpenIncidents,
    this.onOpenCalendar,
  });

  final int totalSubjects;
  final int gesCount;
  final int customCount;
  final VoidCallback onManageSubjects;
  final VoidCallback onOpenAttendance;
  final VoidCallback? onOpenAssessments;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onManageSubjects,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.green.withValues(alpha: .18)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.green,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subject overview',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalSubjects subjects · $gesCount GES · $customCount custom',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _QuickLinksCard(
          title: 'Quick Links',
          links: [
            _ClassQuickLink(
              icon: Icons.calendar_month_rounded,
              title: 'Timetable',
              subtitle: '',
              color: AppColors.amber,
              onTap: onOpenCalendar,
            ),
            _ClassQuickLink(
              icon: Icons.fact_check_rounded,
              title: 'Attendance',
              subtitle: '',
              color: AppColors.green,
              onTap: onOpenAttendance,
            ),
            _ClassQuickLink(
              icon: Icons.assessment_rounded,
              title: 'Assessments',
              subtitle: '',
              color: AppColors.blue,
              onTap: onOpenAssessments,
            ),
            _ClassQuickLink(
              icon: Icons.warning_amber_rounded,
              title: 'Record Incident',
              subtitle: '',
              color: AppColors.amber,
              onTap: onOpenIncidents,
            ),
            _ClassQuickLink(
              icon: Icons.star_border_rounded,
              title: 'Evaluations',
              subtitle: '',
              color: AppColors.purple,
              onTap: onOpenAssessments,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _QuickLinksCard(
          title: 'GES Resources',
          links: [
            _ClassQuickLink(
              icon: Icons.school_rounded,
              title: 'Curriculum Guide',
              subtitle: 'Official GES learning outcomes',
              badge: 'PDF · GES',
              color: AppColors.blue,
            ),
            _ClassQuickLink(
              icon: Icons.folder_copy_rounded,
              title: 'SBA Framework',
              subtitle: 'Assessment guidelines & rubrics',
              badge: 'PDF · SBA',
              color: AppColors.green,
            ),
            _ClassQuickLink(
              icon: Icons.public_rounded,
              title: 'GES Official Portal',
              subtitle: 'ges.gov.gh',
              color: AppColors.purple,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({required this.title, required this.links});

  final String title;
  final List<_ClassQuickLink> links;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final link in links) _QuickLinkRow(link: link),
        ],
      ),
    );
  }
}

class _ClassQuickLink {
  const _ClassQuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({required this.link});

  final _ClassQuickLink link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          link.onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${link.title} is not available yet.')),
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: link.color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(link.icon, color: link.color, size: 17),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (link.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (link.badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: link.color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        link.badge!,
                        style: TextStyle(
                          color: link.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectsDrawer extends StatelessWidget {
  const _SubjectsDrawer({
    required this.gradeName,
    required this.totalCount,
    required this.gesSubjects,
    required this.customSubjects,
    required this.showAddForm,
    required this.newSubjectType,
    required this.nameController,
    required this.codeController,
    required this.descriptionController,
    required this.onClose,
    required this.onShowForm,
    required this.onHideForm,
    required this.onSubjectTypeChanged,
    required this.onAddSubject,
    required this.onRemoveSubject,
  });

  final String gradeName;
  final int totalCount;
  final List<_Subject> gesSubjects;
  final List<_Subject> customSubjects;
  final bool showAddForm;
  final _SubjectType newSubjectType;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final VoidCallback onClose;
  final VoidCallback onShowForm;
  final VoidCallback onHideForm;
  final ValueChanged<_SubjectType> onSubjectTypeChanged;
  final VoidCallback onAddSubject;
  final ValueChanged<_Subject> onRemoveSubject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Subjects',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$gradeName subjects',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: _DrawerStat(label: 'Total', value: '$totalCount'),
              ),
              Expanded(
                child: _DrawerStat(
                  label: 'GES',
                  value: '${gesSubjects.length}',
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _DrawerStat(
                  label: 'Custom',
                  value: '${customSubjects.length}',
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DrawerSectionHeader(
                    title: 'GES Mandatory',
                    count: '${gesSubjects.length} subjects',
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 8),
                  _Notice(
                    text:
                        'Mandated by GES for $gradeName. These subjects cannot be removed.',
                  ),
                  const SizedBox(height: 10),
                  _SubjectList(
                    subjects: gesSubjects,
                    removable: false,
                    onRemove: onRemoveSubject,
                  ),
                  const SizedBox(height: 18),
                  _DrawerSectionHeader(
                    title: 'Custom Subjects',
                    count:
                        '${customSubjects.length} subject${customSubjects.length == 1 ? '' : 's'}',
                    color: AppColors.purple,
                  ),
                  const SizedBox(height: 10),
                  _SubjectList(
                    subjects: customSubjects,
                    removable: true,
                    onRemove: onRemoveSubject,
                  ),
                  const SizedBox(height: 12),
                  if (showAddForm)
                    _AddSubjectForm(
                      nameController: nameController,
                      codeController: codeController,
                      descriptionController: descriptionController,
                      selectedType: newSubjectType,
                      onTypeChanged: onSubjectTypeChanged,
                      onCancel: onHideForm,
                      onAdd: onAddSubject,
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onShowForm,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Custom Subject'),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Changes apply to this class only',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSubjectForm extends StatelessWidget {
  const _AddSubjectForm({
    required this.nameController,
    required this.codeController,
    required this.descriptionController,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onCancel,
    required this.onAdd,
  });

  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final _SubjectType selectedType;
  final ValueChanged<_SubjectType> onTypeChanged;
  final VoidCallback onCancel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Custom Subject',
            style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Subject name *'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Subject code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SubjectTypeButton(
                  label: 'Core',
                  selected: selectedType == _SubjectType.core,
                  color: AppColors.amber,
                  onTap: () => onTypeChanged(_SubjectType.core),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SubjectTypeButton(
                  label: 'Elective',
                  selected: selectedType == _SubjectType.elective,
                  color: AppColors.blue,
                  onTap: () => onTypeChanged(_SubjectType.elective),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onAdd, child: const Text('Add Subject')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectTypeButton extends StatelessWidget {
  const _SubjectTypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color.withValues(alpha: .12) : Colors.white,
        side: BorderSide(color: selected ? color : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : AppColors.muted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SubjectList extends StatelessWidget {
  const _SubjectList({
    required this.subjects,
    required this.removable,
    required this.onRemove,
  });

  final List<_Subject> subjects;
  final bool removable;
  final ValueChanged<_Subject> onRemove;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No custom subjects yet.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: subjects
            .map(
              (subject) => _SubjectRow(
                subject: subject,
                removable: removable,
                onRemove: () => onRemove(subject),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.removable,
    required this.onRemove,
  });

  final _Subject subject;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: subject.source == _SubjectSource.ges
                  ? AppColors.greenSoft
                  : AppColors.purple.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(child: Text(subject.icon)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.code} · ${subject.description}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          _TinyBadge(
            label: subject.type == _SubjectType.core ? 'Core' : 'Elective',
            color: subject.type == _SubjectType.core
                ? AppColors.amber
                : AppColors.blue,
          ),
          const SizedBox(width: 6),
          if (subject.source == _SubjectSource.custom)
            const _TinyBadge(label: 'Custom', color: AppColors.purple)
          else
            const Icon(Icons.lock_rounded, size: 15, color: AppColors.muted),
          if (removable) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Remove subject',
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.red,
                size: 17,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerStat extends StatelessWidget {
  const _DrawerStat({
    required this.label,
    required this.value,
    this.color = AppColors.text,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: .7,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            letterSpacing: .8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          count,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Subject {
  const _Subject({
    required this.name,
    required this.code,
    required this.description,
    required this.icon,
    required this.type,
    required this.source,
  });

  final String name;
  final String code;
  final String description;
  final String icon;
  final _SubjectType type;
  final _SubjectSource source;
}

enum _SubjectType { core, elective }

enum _SubjectSource { ges, custom }
