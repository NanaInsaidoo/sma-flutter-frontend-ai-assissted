import 'package:flutter/material.dart';

import '../../attendance/domain/attendance_models.dart';
import '../../theme/app_theme.dart';
import '../data/classes_api_client.dart';
import '../domain/class_models.dart';
import 'grade_detail_screen.dart';

bool _isSeniorSecondaryGrade(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.startsWith('SHS') ||
      normalized.startsWith('SENIOR HIGH') ||
      normalized.startsWith('SENIOR SECONDARY');
}

class ClassSubjectConfigurationScreen extends StatefulWidget {
  const ClassSubjectConfigurationScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.initialGradeId,
    this.onBack,
    this.onOpenAttendance,
    this.onOpenAssessments,
    this.onOpenIncidents,
    this.onOpenCalendar,
    this.attendanceRepository,
    ClassesRepository? repository,
  }) : _repository = repository;

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final int? initialGradeId;
  final VoidCallback? onBack;
  final VoidCallback? onOpenAttendance;
  final ValueChanged<int>? onOpenAssessments;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenCalendar;
  final AttendanceRepository? attendanceRepository;
  final ClassesRepository? _repository;

  @override
  State<ClassSubjectConfigurationScreen> createState() =>
      _ClassSubjectConfigurationScreenState();
}

class _ClassSubjectConfigurationScreenState
    extends State<ClassSubjectConfigurationScreen> {
  late final ClassesRepository _repository =
      widget._repository ??
      ClassesApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
  List<ClassGradeLevel> _grades = const [];
  final ScrollController _scrollController = ScrollController();
  int? _selectedGradeId;
  int? _selectedStreamId;
  bool _loading = true;
  String? _error;

  ClassGradeLevel? get _selectedGrade {
    final selectedId = _selectedGradeId;
    if (selectedId == null) return null;
    for (final grade in _grades) {
      if (grade.id == selectedId) return grade;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedGradeId = widget.initialGradeId;
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final grades = await _repository.getAllGradeLevels(widget.customSchoolId);
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggle(ClassGradeLevel grade, bool active) async {
    if (active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Activate ${grade.name}?'),
          content: Text(
            grade.streams.isEmpty
                ? '${grade.name} does not have a section yet. Section 1 will be created because every active class must have at least one section.'
                : '${grade.name} and its sections will become available for admissions, teacher assignments, attendance, and assessments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                grade.streams.isEmpty
                    ? 'Create section and activate'
                    : 'Activate class',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    if (!active && grade.studentCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot make ${grade.name} inactive'),
          content: Text(
            '${grade.name} has ${grade.studentCount} actively enrolled student${grade.studentCount == 1 ? '' : 's'}. Transfer, promote, withdraw, or graduate them before making this class inactive.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Make ${grade.name} inactive?'),
          content: Text(
            '${grade.name} and its sections will no longer be available for new admissions, teacher assignments, attendance, or assessments. Existing records will remain available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep active'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Make inactive'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _repository.setGradeLevelActive(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.gradeLevelId,
        active: active,
      );
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _addCustomClass() async {
    final name = TextEditingController();
    var streams = 1;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add custom class'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a school-defined class. Examples include Creche, Nursery 1, and Nursery 2. Custom classes are placed before KG1.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Class name',
                    hintText: 'e.g. Creche or Nursery 1',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: streams,
                  decoration: const InputDecoration(labelText: 'Sections'),
                  items: List.generate(10, (index) => index + 1)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value section${value == 1 ? '' : 's'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => streams = value ?? 1),
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
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('Create class'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await _repository.createCustomGradeLevel(
        customSchoolId: widget.customSchoolId,
        name: name.text.trim(),
        streamCount: streams,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _addSection(ClassGradeLevel grade) async {
    final name = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add section to ${grade.name}'),
        content: SizedBox(
          width: 440,
          child: TextField(
            key: const ValueKey('class-workspace-section-name'),
            controller: name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Section name',
              hintText: 'e.g. Section 2 or B',
              prefixText: '${grade.name} - ',
              prefixStyle: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            onSubmitted: (_) {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add section'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    final sectionName = '${grade.name} - ${name.text.trim()}';
    try {
      await _repository.createStream(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: grade.gradeLevelId,
        streamName: sectionName,
      );
      await _load(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$sectionName was added.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add section. $error')));
    }
  }

  Future<void> _renameSection(
    ClassGradeLevel grade,
    ClassStreamSummary stream,
  ) async {
    final prefix = '${grade.name} - ';
    final currentName =
        stream.name.toLowerCase().startsWith(prefix.toLowerCase())
        ? stream.name.substring(prefix.length)
        : stream.name;
    final name = TextEditingController(text: currentName);
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename section'),
        content: SizedBox(
          width: 440,
          child: TextField(
            key: const ValueKey('rename-section-name'),
            controller: name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Section name',
              hintText: 'e.g. Section A or Gold',
              prefixText: prefix,
              prefixStyle: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            onSubmitted: (_) {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            child: const Text('Save name'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    final qualifiedName = '$prefix${name.text.trim()}';
    try {
      await _repository.renameStream(
        customSchoolId: widget.customSchoolId,
        streamId: stream.id,
        streamName: qualifiedName,
      );
      await _load(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Section renamed to $qualifiedName.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename the section. $error')),
      );
    }
  }

  Future<void> _deleteSection(
    ClassGradeLevel grade,
    ClassStreamSummary stream,
  ) async {
    if (stream.enrolled > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Section has students'),
          content: Text(
            '${stream.name} has ${stream.enrolled} enrolled student${stream.enrolled == 1 ? '' : 's'}. Move them to another section before deleting it.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }
    final activeSections = grade.streams
        .where((candidate) => candidate.active)
        .length;
    if (grade.active && stream.active && activeSections <= 1) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep one active section'),
          content: const Text(
            'An active class must keep at least one section. Add another section or make the class inactive first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${stream.name}?'),
        content: const Text(
          'This permanently removes the empty section. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep section'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete section'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteStreams(
        customSchoolId: widget.customSchoolId,
        streamIds: [stream.id],
      );
      await _load(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${stream.name} was deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the section. $error')),
      );
    }
  }

  Future<void> _editCustomClass(ClassGradeLevel grade) async {
    final name = TextEditingController(text: grade.name);
    final custom = _grades.where((item) => item.custom).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    var position = custom.indexWhere((item) => item.id == grade.id) + 1;
    if (position < 1) position = 1;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${grade.name}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Class name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: position,
                  decoration: const InputDecoration(
                    labelText: 'Position before KG1',
                  ),
                  items: List.generate(
                    custom.length,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('Position ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => position = value ?? position),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Promotion follows this order. The final custom class progresses to KG1.',
                  style: TextStyle(color: AppColors.muted),
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
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;

    try {
      // Reassign all custom positions so moving one class cannot leave ambiguous
      // progression ordering.
      custom.removeWhere((item) => item.id == grade.id);
      custom.insert(position - 1, grade);
      for (var index = 0; index < custom.length; index++) {
        final item = custom[index];
        await _repository.updateCustomGradeLevel(
          customSchoolId: widget.customSchoolId,
          grade: item,
          name: item.id == grade.id ? name.text.trim() : item.name,
          displayOrder: (index + 1) * 100,
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final selectedGrade = _selectedGrade;
    final selectedStreamId = _selectedStreamId;
    if (selectedGrade != null && selectedStreamId != null) {
      final selectedStream = selectedGrade.streams
          .where((stream) => stream.id == selectedStreamId)
          .firstOrNull;
      if (selectedStream != null) {
        return GradeDetailScreen(
          key: ValueKey('stream-details-${selectedStream.id}'),
          customSchoolId: widget.customSchoolId,
          streamId: selectedStream.id,
          gradeLevelId: selectedGrade.id,
          subjectGradeLevelId: selectedGrade.gradeLevelId,
          gradeName: selectedGrade.name,
          streamName: selectedStream.name,
          enrolled: selectedStream.enrolled,
          capacity: selectedStream.capacity,
          active: selectedStream.active,
          classTeacherName: selectedStream.teacherName,
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
          onOpenAttendance: widget.onOpenAttendance,
          onOpenAssessments: widget.onOpenAssessments == null
              ? null
              : () => widget.onOpenAssessments!(selectedStream.id),
          onOpenIncidents: widget.onOpenIncidents,
          onOpenCalendar: widget.onOpenCalendar,
          attendanceRepository: widget.attendanceRepository,
          repository: _repository,
          onClassTeachersChanged: () => _load(showLoading: false),
          onRenameSection: () => _renameSection(selectedGrade, selectedStream),
          onDeleteSection: () => _deleteSection(selectedGrade, selectedStream),
          onBack: () => setState(() => _selectedStreamId = null),
        );
      }
    }
    if (selectedGrade != null) {
      return _ClassWorkspace(
        grade: selectedGrade,
        onBack: widget.onBack ?? () => setState(() => _selectedGradeId = null),
        onActiveChanged: (value) => _toggle(selectedGrade, value),
        onAddSection: () => _addSection(selectedGrade),
        onOpenSection: (stream) =>
            setState(() => _selectedStreamId = stream.id),
        onRenameSection: (stream) => _renameSection(selectedGrade, stream),
        onDeleteSection: (stream) => _deleteSection(selectedGrade, stream),
        onEdit: selectedGrade.custom
            ? () => _editCustomClass(selectedGrade)
            : null,
      );
    }
    final ges =
        _grades
            .where(
              (grade) => !grade.custom && !_isSeniorSecondaryGrade(grade.name),
            )
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final custom = _grades.where((grade) => grade.custom).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classes',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'View every class, manage its status, and open it to manage sections.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addCustomClass,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add custom class'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Custom classes',
                subtitle:
                    'School-defined classes, such as Creche or Nursery, appear before KG1.',
                count: custom.length,
              ),
              const SizedBox(height: 12),
              if (custom.isEmpty)
                _EmptyCustom(onAdd: _addCustomClass)
              else
                ...custom.map(
                  (grade) => _GradeCard(
                    grade: grade,
                    onActiveChanged: (value) => _toggle(grade, value),
                    onOpen: () => setState(() => _selectedGradeId = grade.id),
                  ),
                ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'GES grade levels',
                subtitle:
                    'Permanent levels — they can be active or inactive, but never deleted.',
                count: ges.length,
              ),
              const SizedBox(height: 12),
              ...ges.map(
                (grade) => _GradeCard(
                  grade: grade,
                  onActiveChanged: (value) => _toggle(grade, value),
                  onOpen: () => setState(() => _selectedGradeId = grade.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.count,
  });
  final String title;
  final String subtitle;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
      Chip(label: Text('$count levels')),
    ],
  );
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.onActiveChanged,
    required this.onOpen,
  });
  final ClassGradeLevel grade;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final statusColor = grade.active ? AppColors.green : AppColors.muted;
    final backgroundColor = grade.active
        ? Colors.white
        : const Color(0xFFF3F5F7);
    return Card(
      key: ValueKey(
        'class-card-${grade.id}-${grade.active ? 'active' : 'inactive'}',
      ),
      margin: const EdgeInsets.only(bottom: 10),
      color: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: grade.active
              ? AppColors.green.withValues(alpha: .28)
              : const Color(0xFFD5DBE1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('open-class-${grade.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: .12),
                child: Icon(
                  grade.custom
                      ? Icons.auto_awesome_outlined
                      : Icons.school_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grade.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: grade.active
                            ? AppColors.text
                            : const Color(0xFF647184),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${grade.streams.length} section${grade.streams.length == 1 ? '' : 's'} · ${grade.studentCount} students',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                key: ValueKey(
                  'class-status-${grade.id}-${grade.active ? 'active' : 'inactive'}',
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      grade.active
                          ? Icons.check_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 15,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      grade.active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label:
                    '${grade.name} is ${grade.active ? 'active' : 'inactive'}',
                child: Switch(value: grade.active, onChanged: onActiveChanged),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassWorkspace extends StatelessWidget {
  const _ClassWorkspace({
    required this.grade,
    required this.onBack,
    required this.onActiveChanged,
    required this.onAddSection,
    required this.onOpenSection,
    required this.onRenameSection,
    required this.onDeleteSection,
    required this.onEdit,
  });

  final ClassGradeLevel grade;
  final VoidCallback onBack;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onAddSection;
  final ValueChanged<ClassStreamSummary> onOpenSection;
  final ValueChanged<ClassStreamSummary> onRenameSection;
  final ValueChanged<ClassStreamSummary> onDeleteSection;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final statusColor = grade.active ? AppColors.green : AppColors.muted;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const ValueKey('back-to-all-classes'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All classes'),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: grade.active ? Colors.white : const Color(0xFFF3F5F7),
                  border: Border.all(
                    color: grade.active
                        ? AppColors.green.withValues(alpha: .28)
                        : const Color(0xFFD5DBE1),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: statusColor.withValues(alpha: .12),
                      child: Icon(
                        grade.custom
                            ? Icons.auto_awesome_outlined
                            : Icons.school_outlined,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grade.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${grade.streams.length} section${grade.streams.length == 1 ? '' : 's'} · ${grade.studentCount} students',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null) ...[
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Class settings'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    _ClassStatusPill(active: grade.active),
                    const SizedBox(width: 8),
                    Semantics(
                      label:
                          '${grade.name} is ${grade.active ? 'active' : 'inactive'}',
                      child: Switch(
                        value: grade.active,
                        onChanged: onActiveChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _WorkspaceSection(
                icon: Icons.meeting_room_outlined,
                title: 'Sections',
                subtitle:
                    'Create and review the sections that belong to ${grade.name}.',
                action: FilledButton.icon(
                  key: ValueKey('workspace-add-section-${grade.id}'),
                  onPressed: onAddSection,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add section'),
                ),
                child: grade.streams.isEmpty
                    ? const _EmptyWorkspaceState(
                        icon: Icons.meeting_room_outlined,
                        title: 'No sections yet',
                        message: 'Add the first section for this class.',
                      )
                    : Column(
                        children: grade.streams
                            .map(
                              (stream) => _WorkspaceSectionRow(
                                stream: stream,
                                onOpen: () => onOpenSection(stream),
                                onRename: () => onRenameSection(stream),
                                onDelete: () => onDeleteSection(stream),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassStatusPill extends StatelessWidget {
  const _ClassStatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.green, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _WorkspaceSectionRow extends StatelessWidget {
  const _WorkspaceSectionRow({
    required this.stream,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });
  final ClassStreamSummary stream;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = stream.active ? AppColors.green : AppColors.muted;
    final capacity = stream.capacity == null
        ? 'No capacity set'
        : '${stream.capacity} capacity';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0xFFF9FBFA),
        child: InkWell(
          key: ValueKey('open-stream-${stream.id}'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.meeting_room_outlined, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stream.teacherName.trim().isEmpty
                            ? 'No class teacher assigned'
                            : 'Class teacher: ${stream.teacherName}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${stream.enrolled} students · $capacity',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(width: 16),
                _ClassStatusPill(active: stream.active),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                const SizedBox(width: 4),
                PopupMenuButton<_SectionAction>(
                  key: ValueKey('section-actions-${stream.id}'),
                  tooltip: 'Section actions',
                  onSelected: (action) {
                    switch (action) {
                      case _SectionAction.rename:
                        onRename();
                      case _SectionAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SectionAction.rename,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Rename section'),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: _SectionAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.red,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete section',
                            style: TextStyle(color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SectionAction { rename, delete }

class _EmptyWorkspaceState extends StatelessWidget {
  const _EmptyWorkspaceState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 30),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(message, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}

class _EmptyCustom extends StatelessWidget {
  const _EmptyCustom({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.child_care_rounded, size: 34, color: AppColors.green),
        const SizedBox(height: 8),
        const Text(
          'No custom classes yet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add custom class'),
        ),
      ],
    ),
  );
}

class _WorkspaceSubjectsList extends StatefulWidget {
  const _WorkspaceSubjectsList({
    required this.repository,
    required this.customSchoolId,
    required this.grade,
  });
  final ClassesRepository repository;
  final String customSchoolId;
  final ClassGradeLevel grade;
  @override
  State<_WorkspaceSubjectsList> createState() => _WorkspaceSubjectsListState();
}

class _WorkspaceSubjectsListState extends State<_WorkspaceSubjectsList> {
  List<ClassSubject>? _subjects;
  List<SubjectAcademicTerm> _terms = const [];
  int? _selectedTermId;
  final Map<int, SubjectTermAvailability> _availability = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.getGradeSubjects(
          customSchoolId: widget.customSchoolId,
          gradeLevelId: widget.grade.gradeLevelId,
        ),
        widget.repository.getSubjectAcademicTerms(widget.customSchoolId),
      ]);
      final value = results[0] as List<ClassSubject>;
      final terms = results[1] as List<SubjectAcademicTerm>;
      var selectedTermId = _selectedTermId;
      if (selectedTermId == null ||
          !terms.any((term) => term.id == selectedTermId)) {
        selectedTermId = terms
            .where((term) => term.current)
            .map((term) => term.id)
            .firstOrNull;
        selectedTermId ??= terms.firstOrNull?.id;
      }
      final availability = <int, SubjectTermAvailability>{};
      if (selectedTermId != null) {
        await Future.wait(
          value.where((subject) => subject.custom).map((subject) async {
            final schoolSubjectId = subject.schoolSubjectId;
            if (schoolSubjectId == null || schoolSubjectId <= 0) return;
            availability[schoolSubjectId] = await widget.repository
                .getSubjectTermAvailability(
                  customSchoolId: widget.customSchoolId,
                  schoolSubjectId: schoolSubjectId,
                  academicTermId: selectedTermId!,
                );
          }),
        );
      }
      if (mounted) {
        setState(() {
          _subjects = value;
          _terms = terms;
          _selectedTermId = selectedTermId;
          _availability
            ..clear()
            ..addAll(availability);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final term = _selectedTerm;
    final sections = [...widget.grade.streams]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedSectionIds = <int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add subject to ${widget.grade.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Subject name',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Subject code (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Examinable'),
                    subtitle: Text(
                      'School-added subjects are always non-examinable',
                    ),
                    trailing: Text(
                      'No',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Which sections study this subject?',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (term != null)
                        _ContextPill(
                          icon: Icons.calendar_month_outlined,
                          label: term.label,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select every active section where this subject is taught.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  if (sections.where((section) => section.active).isNotEmpty)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selectedSectionIds
                              ..clear()
                              ..addAll(
                                sections
                                    .where((section) => section.active)
                                    .map((section) => section.id),
                              );
                          }),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () =>
                              setDialogState(selectedSectionIds.clear),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  if (sections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Add a section to this class before adding a subject.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else
                    ...sections.map(
                      (section) => CheckboxListTile(
                        key: ValueKey('add-subject-section-${section.id}'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: selectedSectionIds.contains(section.id),
                        onChanged: section.active && term?.editable == true
                            ? (checked) => setDialogState(() {
                                checked == true
                                    ? selectedSectionIds.add(section.id)
                                    : selectedSectionIds.remove(section.id);
                              })
                            : null,
                        title: Text(section.name),
                        subtitle: section.active
                            ? null
                            : const Text('Inactive section'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-add-subject'),
              onPressed:
                  name.text.trim().isNotEmpty &&
                      selectedSectionIds.isNotEmpty &&
                      term?.editable == true
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Add subject'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final created = await widget.repository.createCustomSubject(
      customSchoolId: widget.customSchoolId,
      gradeLevelId: widget.grade.gradeLevelId,
      name: name.text.trim(),
      code: code.text.trim(),
      examinable: false,
    );
    final schoolSubjectId = created.schoolSubjectId;
    if (term != null && schoolSubjectId != null && schoolSubjectId > 0) {
      await widget.repository.saveSubjectTermAvailability(
        customSchoolId: widget.customSchoolId,
        schoolSubjectId: schoolSubjectId,
        academicTermId: term.id,
        streamIds: selectedSectionIds.toList(),
        status: 'ACTIVE',
      );
    }
    await _load();
  }

  Future<void> _edit(ClassSubject subject) async {
    final name = TextEditingController(text: subject.name);
    final code = TextEditingController(text: subject.code);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AlertDialog(
          title: const Text('Edit custom subject'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Subject name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Subject code'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Examinable'),
                  subtitle: Text(
                    'School-added subjects are always non-examinable',
                  ),
                  trailing: Text(
                    'No',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await widget.repository.updateCustomSubject(
      customSchoolId: widget.customSchoolId,
      subject: ClassSubject(
        id: subject.id,
        name: name.text.trim(),
        code: code.text.trim(),
        custom: true,
        active: subject.active,
        examinable: false,
        schoolSubjectId: subject.schoolSubjectId,
        definitionId: subject.definitionId,
      ),
    );
    await _load();
  }

  SubjectAcademicTerm? get _selectedTerm {
    for (final term in _terms) {
      if (term.id == _selectedTermId) return term;
    }
    return null;
  }

  Future<void> _changeTerm(int? termId) async {
    if (termId == null || termId == _selectedTermId) return;
    setState(() {
      _selectedTermId = termId;
      _subjects = null;
    });
    await _load();
  }

  Future<void> _editAvailability(ClassSubject subject) async {
    final term = _selectedTerm;
    final schoolSubjectId = subject.schoolSubjectId;
    if (term == null || schoolSubjectId == null || schoolSubjectId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The subject term could not be resolved.'),
          ),
        );
      }
      return;
    }
    SubjectTermAvailability configuration;
    try {
      configuration =
          _availability[schoolSubjectId] ??
          await widget.repository.getSubjectTermAvailability(
            customSchoolId: widget.customSchoolId,
            schoolSubjectId: schoolSubjectId,
            academicTermId: term.id,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted) return;
    final selected = configuration.streamIds.toSet();
    String? action;
    action = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final readOnly = !term.editable;
          final activeSections = configuration.availableSections
              .where((section) => section.active)
              .toList();
          final selectedActiveCount = activeSections
              .where((section) => selected.contains(section.id))
              .length;
          return AlertDialog(
            title: Text(
              'Which ${widget.grade.name} sections study ${subject.name}?',
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select every section where ${subject.name} is taught. This applies only to ${term.label}.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ContextPill(
                        icon: Icons.calendar_month_outlined,
                        label: term.label,
                      ),
                      _ContextPill(
                        icon: Icons.view_week_outlined,
                        label:
                            '$selectedActiveCount of ${activeSections.length} selected',
                      ),
                      if (readOnly)
                        const _ContextPill(
                          icon: Icons.lock_outline,
                          label: 'Read-only',
                        )
                      else if (configuration.copiedFromTermId != null &&
                          configuration.status.toUpperCase() == 'DRAFT')
                        const _ContextPill(
                          icon: Icons.content_copy_outlined,
                          label: 'Copied draft',
                        ),
                    ],
                  ),
                  if (!readOnly && activeSections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selected
                              ..clear()
                              ..addAll(
                                activeSections.map((section) => section.id),
                              );
                          }),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(selected.clear),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                  Flexible(
                    child: configuration.availableSections.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'This class has no sections yet. Add a section first, then return here.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: configuration.availableSections.map((
                              section,
                            ) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: selected.contains(section.id)
                                      ? AppColors.green.withValues(alpha: .07)
                                      : Colors.white,
                                  border: Border.all(
                                    color: selected.contains(section.id)
                                        ? AppColors.green.withValues(alpha: .35)
                                        : AppColors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CheckboxListTile(
                                  value: selected.contains(section.id),
                                  onChanged: readOnly || !section.active
                                      ? null
                                      : (checked) => setDialogState(() {
                                          checked == true
                                              ? selected.add(section.id)
                                              : selected.remove(section.id);
                                        }),
                                  title: Text(
                                    section.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: section.active
                                      ? const Text(
                                          'Subject will be taught here',
                                        )
                                      : const Text('Inactive section'),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Applying this makes the subject available to teachers and assessment setup for the selected sections.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(readOnly ? 'Close' : 'Cancel'),
              ),
              if (!readOnly) ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'DRAFT'),
                  child: const Text('Save for later'),
                ),
                FilledButton(
                  onPressed: selectedActiveCount == 0
                      ? null
                      : () => Navigator.pop(context, 'ACTIVE'),
                  child: const Text('Apply to selected sections'),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (action == null) return;
    try {
      final saved = await widget.repository.saveSubjectTermAvailability(
        customSchoolId: widget.customSchoolId,
        schoolSubjectId: schoolSubjectId,
        academicTermId: term.id,
        streamIds: selected.toList(),
        status: action,
      );
      if (!mounted) return;
      setState(() => _availability[schoolSubjectId] = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'ACTIVE'
                ? '${subject.name} is available in ${selected.length} section${selected.length == 1 ? '' : 's'} for ${term.name}.'
                : '${subject.name} section choices were saved as draft.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _delete(ClassSubject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${subject.name}?'),
        content: const Text(
          'Only custom subjects can be removed. If the subject is already used by assessments, the server will preserve it and report the dependency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep subject'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteCustomSubject(
      customSchoolId: widget.customSchoolId,
      subjectId: subject.id,
    );
    await _load();
  }

  String _subjectCode(ClassSubject subject) =>
      subject.code.trim().isEmpty ? 'No subject code' : subject.code.trim();

  String _sectionSummary(SubjectTermAvailability? availability) {
    if (availability == null) return 'Section assignment unavailable';
    final activeIds = availability.availableSections
        .where((section) => section.active)
        .map((section) => section.id)
        .toSet();
    final assigned = availability.streamIds.where(activeIds.contains).length;
    final total = activeIds.length;
    if (availability.status.toUpperCase() == 'DRAFT') {
      return 'Draft · $assigned of $total sections selected';
    }
    if (assigned == 0) return 'Not assigned to any section';
    return 'Applies to $assigned of $total sections';
  }

  Widget _subjectGroupHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
  }) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _subjectCard(ClassSubject subject) {
    final availability = subject.schoolSubjectId == null
        ? null
        : _availability[subject.schoolSubjectId!];
    final draft = availability?.status.toUpperCase() == 'DRAFT';
    final detail = subject.custom
        ? _sectionSummary(availability)
        : 'Applies to every active ${widget.grade.name} section';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: subject.custom
                    ? AppColors.greenSoft
                    : const Color(0xFFF0F3F8),
                foregroundColor: subject.custom
                    ? AppColors.green
                    : AppColors.muted,
                child: Text(
                  subject.name.trim().isEmpty
                      ? '?'
                      : subject.name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_subjectCode(subject)} · $detail',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            subject.custom &&
                                (availability == null ||
                                    availability.streamIds.isEmpty)
                            ? AppColors.amber
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SubjectTypePill(
                examinable: subject.custom ? false : subject.examinable,
              ),
            ],
          ),
          if (subject.custom) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  key: ValueKey('assign-sections-${subject.id}'),
                  onPressed: () => _editAvailability(subject),
                  icon: Icon(
                    draft
                        ? Icons.pending_actions_outlined
                        : Icons.view_week_outlined,
                    size: 18,
                  ),
                  label: Text(
                    draft ? 'Review section draft' : 'Assign sections',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _edit(subject),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                IconButton(
                  tooltip: 'Remove subject',
                  onPressed: () => _delete(subject),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (_terms.isNotEmpty)
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedTermId,
                decoration: const InputDecoration(
                  labelText: 'Academic term',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: _terms
                    .map(
                      (term) => DropdownMenuItem<int>(
                        value: term.id,
                        child: Text(
                          '${term.label}${term.current ? ' · Current' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _changeTerm,
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: ValueKey('workspace-add-subject-${widget.grade.id}'),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add subject'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (_error != null)
        Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Subjects could not be loaded. $_error',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        )
      else if (_subjects == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_subjects!.isEmpty)
        _EmptyWorkspaceState(
          icon: Icons.menu_book_outlined,
          title: 'No subjects yet',
          message: widget.grade.custom
              ? 'Add a subject or use the KG suggestions created with this class.'
              : 'Add the first school subject for this class.',
        )
      else
        Builder(
          builder: (context) {
            final curriculum = _subjects!
                .where((subject) => !subject.custom)
                .toList();
            final school = _subjects!
                .where((subject) => subject.custom)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (curriculum.isNotEmpty) ...[
                  _subjectGroupHeader(
                    icon: Icons.account_balance_outlined,
                    title: 'Curriculum subjects',
                    subtitle:
                        'Official curriculum subjects · available to every active section',
                    count: curriculum.length,
                  ),
                  ...curriculum.map(_subjectCard),
                  const SizedBox(height: 14),
                ],
                _subjectGroupHeader(
                  icon: Icons.auto_awesome_outlined,
                  title: 'School-added subjects',
                  subtitle:
                      'Add subjects here, then choose the sections where they are taught',
                  count: school.length,
                ),
                if (school.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBFA),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No school-added subjects yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  ...school.map(_subjectCard),
              ],
            );
          },
        ),
    ],
  );
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F6),
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.green),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SubjectTypePill extends StatelessWidget {
  const _SubjectTypePill({required this.examinable});
  final bool examinable;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: examinable
          ? AppColors.green.withValues(alpha: .08)
          : const Color(0xFFF4F5F7),
      border: Border.all(
        color: examinable
            ? AppColors.green.withValues(alpha: .3)
            : AppColors.border,
      ),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      examinable ? 'Examinable' : 'Non-examinable',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: examinable ? AppColors.green : AppColors.muted,
      ),
    ),
  );
}
