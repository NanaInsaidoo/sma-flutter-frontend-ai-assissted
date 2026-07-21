import 'package:flutter/material.dart';

import '../domain/class_models.dart';
import '../../theme/app_theme.dart';

class GradeDetailScreen extends StatefulWidget {
  const GradeDetailScreen({
    super.key,
    required this.customSchoolId,
    required this.streamId,
    required this.gradeName,
    required this.streamName,
    required this.enrolled,
    required this.capacity,
    required this.active,
    this.classTeacherName,
    required this.repository,
    this.onClassTeachersChanged,
    required this.onBack,
  });

  final String customSchoolId;
  final int streamId;
  final String gradeName;
  final String streamName;
  final int enrolled;
  final int? capacity;
  final bool active;
  final String? classTeacherName;
  final ClassesRepository repository;
  final Future<void> Function()? onClassTeachersChanged;
  final VoidCallback onBack;

  @override
  State<GradeDetailScreen> createState() => _GradeDetailScreenState();
}

class _GradeDetailScreenState extends State<GradeDetailScreen> {
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

  int get _totalSubjects => _gesSubjects.length + _customSubjects.length;

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
  }

  @override
  Widget build(BuildContext context) {
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
                          classTeacherName: widget.classTeacherName,
                          enrolled: widget.enrolled,
                          capacity: widget.capacity,
                          active: widget.active,
                          totalSubjects: _totalSubjects,
                        ),
                        const SizedBox(height: 18),
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
                                enrolled: widget.enrolled,
                                capacityReady: widget.capacity != null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 290,
                              child: _SidePanel(
                                totalSubjects: _totalSubjects,
                                gesCount: _gesSubjects.length,
                                customCount: _customSubjects.length,
                                onManageSubjects: () {
                                  setState(() => _drawerOpen = true);
                                },
                              ),
                            ),
                          ],
                        ),
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
      final teachers = await widget.repository.getClassTeachers(
        customSchoolId: widget.customSchoolId,
        streamId: widget.streamId,
      );
      if (!mounted) return;
      setState(() {
        _classTeachers = teachers;
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

    await _performTeacherAction(
      successMessage: 'Class teacher assigned.',
      action: () => widget.repository.addClassTeacher(
        customSchoolId: widget.customSchoolId,
        streamId: widget.streamId,
        staffId: selection.staffId,
        isPrimary: selection.isPrimary,
      ),
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
          '$enrolled enrolled · ${capacity == null ? 'Capacity not set' : 'Capacity $capacity'} · $totalSubjects subjects',
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
                        style: const TextStyle(
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

class _StudentsCard extends StatelessWidget {
  const _StudentsCard({required this.enrolled, required this.capacityReady});

  final int enrolled;
  final bool capacityReady;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SectionHeader(title: 'Students', trailing: '$enrolled enrolled'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
            child: _ComingSoonState(
              icon: Icons.people_outline_rounded,
              title: 'Student roster will appear here',
              message:
                  'The stream summary confirms $enrolled enrolled student${enrolled == 1 ? '' : 's'}. We need a stream-students API before we can show names, balances, and quick actions here.',
            ),
          ),
        ],
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

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.totalSubjects,
    required this.gesCount,
    required this.customCount,
    required this.onManageSubjects,
  });

  final int totalSubjects;
  final int gesCount;
  final int customCount;
  final VoidCallback onManageSubjects;

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
                        'Manage Subjects',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalSubjects subjects · $gesCount GES + $customCount custom',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.green,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _QuickLinksCard(
          title: 'Quick Links',
          links: [
            _ClassQuickLink(
              icon: Icons.calendar_month_rounded,
              title: 'Timetable',
              subtitle: '',
              color: AppColors.amber,
            ),
            _ClassQuickLink(
              icon: Icons.fact_check_rounded,
              title: 'Attendance',
              subtitle: '',
              color: AppColors.green,
            ),
            _ClassQuickLink(
              icon: Icons.assessment_rounded,
              title: 'Assessments',
              subtitle: '',
              color: AppColors.blue,
            ),
            _ClassQuickLink(
              icon: Icons.warning_amber_rounded,
              title: 'Record Incident',
              subtitle: '',
              color: AppColors.amber,
            ),
            _ClassQuickLink(
              icon: Icons.star_border_rounded,
              title: 'Evaluations',
              subtitle: '',
              color: AppColors.purple,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({required this.link});

  final _ClassQuickLink link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${link.title} will be connected soon.')),
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

class _ComingSoonState extends StatelessWidget {
  const _ComingSoonState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.green, size: 23),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
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
                        '$gradeName · Term 1, 2024/2025',
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
