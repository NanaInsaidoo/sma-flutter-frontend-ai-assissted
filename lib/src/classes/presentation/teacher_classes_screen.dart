import 'package:flutter/material.dart';

import '../../attendance/domain/attendance_models.dart';
import '../../dashboard/data/teacher_workspace_api_client.dart';
import '../../theme/app_theme.dart';
import '../data/classes_api_client.dart';
import '../domain/class_models.dart';
import 'grade_detail_screen.dart';

typedef TeacherWorkspaceLoader =
    Future<TeacherWorkspaceSnapshot> Function(String schoolId);

Future<TeacherClassAssignment?> showTeacherClassChooser({
  required BuildContext context,
  required List<TeacherClassAssignment> classes,
  int? selectedStreamId,
  String title = 'My classes',
  String message = 'Choose a class to open its dashboard.',
}) {
  return showDialog<TeacherClassAssignment>(
    context: context,
    builder: (context) => _TeacherClassChooser(
      classes: classes,
      selectedStreamId: selectedStreamId,
      title: title,
      message: message,
    ),
  );
}

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({
    super.key,
    required this.schoolId,
    required this.displayName,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onOpenAttendance,
    this.onOpenAssessments,
    this.onOpenEvaluations,
    this.onOpenIncidents,
    this.onOpenCalendar,
    this.onBack,
    this.initialStreamId,
    this.workspaceLoader,
    this.repository,
    this.attendanceRepository,
  });

  final String schoolId;
  final String displayName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onOpenAttendance;
  final ValueChanged<int>? onOpenAssessments;
  final VoidCallback? onOpenEvaluations;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onBack;
  final int? initialStreamId;
  final TeacherWorkspaceLoader? workspaceLoader;
  final ClassesRepository? repository;
  final AttendanceRepository? attendanceRepository;

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  late final ClassesRepository _repository =
      widget.repository ??
      ClassesApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
  late Future<TeacherWorkspaceSnapshot> _workspace = _loadWorkspace();
  TeacherClassAssignment? _selectedClass;
  bool _initialChoiceScheduled = false;

  Future<TeacherWorkspaceSnapshot> _loadWorkspace() {
    final loader = widget.workspaceLoader;
    if (loader != null) return loader(widget.schoolId);
    return TeacherWorkspaceApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    ).get(widget.schoolId);
  }

  void _retry() {
    setState(() {
      _initialChoiceScheduled = false;
      _selectedClass = null;
      _workspace = _loadWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherWorkspaceSnapshot>(
      future: _workspace,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TeacherClassesMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Classes could not be loaded',
            message: '${snapshot.error}',
            actionLabel: 'Try again',
            onAction: _retry,
          );
        }

        final classes = snapshot.data?.assignedClasses ?? const [];
        if (classes.isEmpty) {
          return _TeacherClassesMessage(
            icon: Icons.class_outlined,
            title: 'No assigned classes',
            message:
                'An administrator or head teacher must assign you to a class or subject before it appears here.',
            actionLabel: 'Back to dashboard',
            onAction: widget.onBack,
          );
        }

        if (_selectedClass == null && widget.initialStreamId != null) {
          for (final assignment in classes) {
            if (assignment.streamId == widget.initialStreamId) {
              _selectedClass = assignment;
              break;
            }
          }
        }
        if (_selectedClass == null && classes.length == 1) {
          _selectedClass = classes.first;
        } else if (_selectedClass == null && !_initialChoiceScheduled) {
          _initialChoiceScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _chooseClass(classes);
          });
        }

        final selected = _selectedClass;
        if (selected != null) {
          return GradeDetailScreen(
            key: ValueKey('teacher-class-${selected.streamId}'),
            customSchoolId: widget.schoolId,
            streamId: selected.streamId,
            gradeLevelId: selected.gradeLevelId,
            subjectGradeLevelId: selected.gradeLevelId,
            gradeName: selected.gradeName,
            streamName: selected.streamName,
            enrolled: selected.studentCount,
            capacity: selected.capacity,
            active: selected.active,
            classTeacherName: selected.classTeacher ? widget.displayName : null,
            accessToken: widget.accessToken,
            onRefreshAccessToken: widget.onRefreshAccessToken,
            repository: _repository,
            attendanceRepository: widget.attendanceRepository,
            teacherView: true,
            onOpenAttendance: widget.onOpenAttendance,
            onOpenAssessments: widget.onOpenAssessments == null
                ? null
                : () => widget.onOpenAssessments!(selected.streamId),
            onOpenEvaluations: widget.onOpenEvaluations,
            onOpenIncidents: widget.onOpenIncidents,
            onOpenCalendar: widget.onOpenCalendar,
            onBack: classes.length > 1
                ? () => _chooseClass(classes)
                : (widget.onBack ?? () {}),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _chooseClass(List<TeacherClassAssignment> classes) async {
    final selected = await showTeacherClassChooser(
      context: context,
      classes: classes,
      selectedStreamId: _selectedClass?.streamId,
    );
    if (!mounted) return;
    if (selected == null) {
      if (_selectedClass == null) widget.onBack?.call();
      return;
    }
    setState(() => _selectedClass = selected);
  }
}

class _TeacherClassChooser extends StatelessWidget {
  const _TeacherClassChooser({
    required this.classes,
    required this.selectedStreamId,
    required this.title,
    required this.message,
  });

  final List<TeacherClassAssignment> classes;
  final int? selectedStreamId;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 600 ? 16 : 40,
        vertical: 24,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppColors.green,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(message, style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F5F4),
                      foregroundColor: AppColors.text,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ColoredBox(
                color: const Color(0xFFF8FAF9),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AssignedClassCount(count: classes.length),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: classes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = classes[index];
                            return _TeacherClassChoiceCard(
                              item: item,
                              selected: item.streamId == selectedStreamId,
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignedClassCount extends StatelessWidget {
  const _AssignedClassCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count assigned class${count == 1 ? '' : 'es'}',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeacherClassChoiceCard extends StatelessWidget {
  const _TeacherClassChoiceCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TeacherClassAssignment item;
  final bool selected;
  final VoidCallback onTap;

  String get _shortName {
    final words = item.gradeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'CL';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length.clamp(0, 2)).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.green : AppColors.border;
    return Material(
      color: selected ? const Color(0xFFF1FAF8) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _shortName,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? AppColors.green : AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: selected ? Colors.white : AppColors.green,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherClassesMessage extends StatelessWidget {
  const _TeacherClassesMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: AppColors.green),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
