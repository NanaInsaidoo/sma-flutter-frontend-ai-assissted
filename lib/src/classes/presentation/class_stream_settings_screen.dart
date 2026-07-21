import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/classes_api_client.dart';
import '../domain/class_models.dart';

class ClassStreamSettingsScreen extends StatefulWidget {
  const ClassStreamSettingsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.repository,
    this.onBack,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final ClassesRepository? repository;
  final VoidCallback? onBack;

  @override
  State<ClassStreamSettingsScreen> createState() =>
      _ClassStreamSettingsScreenState();
}

class _ClassStreamSettingsScreenState extends State<ClassStreamSettingsScreen> {
  late final ClassesRepository _repository =
      widget.repository ??
      ClassesApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );

  final Map<int, TextEditingController> _capacityControllers = {};
  final Map<int, int> _originalCapacity = {};
  List<ClassGradeLevel> _levels = [];
  bool _loading = true;
  bool _savingCapacities = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _capacityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final levels = await _repository.getAllStreams(widget.customSchoolId);
      if (!mounted) return;
      _syncCapacityControllers(levels);
      setState(() {
        _levels = levels;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _syncCapacityControllers(List<ClassGradeLevel> levels) {
    final liveIds = <int>{};
    for (final level in levels) {
      for (final stream in level.streams) {
        liveIds.add(stream.id);
        final capacity = stream.capacity;
        if (capacity == null) {
          _originalCapacity.remove(stream.id);
        } else {
          _originalCapacity[stream.id] = capacity;
        }
        final controller = _capacityControllers.putIfAbsent(
          stream.id,
          () => TextEditingController(),
        );
        controller.text = capacity?.toString() ?? '';
      }
    }
    final staleIds = _capacityControllers.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _capacityControllers.remove(id)?.dispose();
      _originalCapacity.remove(id);
    }
  }

  List<ClassStreamSummary> get _streams =>
      _levels.expand((level) => level.streams).toList();

  bool get _hasCapacityChanges {
    for (final stream in _streams) {
      final value = int.tryParse(_capacityControllers[stream.id]?.text ?? '');
      if (value != _originalCapacity[stream.id]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveCapacities() async {
    final updates = <StreamCapacityUpdate>[];
    for (final stream in _streams) {
      final text = _capacityControllers[stream.id]?.text.trim() ?? '';
      final value = int.tryParse(text);
      if (value == null || value < 1) {
        _showMessage('Enter a valid capacity for ${stream.name}.');
        return;
      }
      if (value < stream.enrolled) {
        _showMessage(
          '${stream.name} already has ${stream.enrolled} students. Capacity cannot be lower.',
        );
        return;
      }
      if (value != _originalCapacity[stream.id]) {
        updates.add(StreamCapacityUpdate(streamId: stream.id, capacity: value));
      }
    }
    if (updates.isEmpty) {
      _showMessage('No capacity changes to save.');
      return;
    }
    setState(() => _savingCapacities = true);
    try {
      await _repository.updateStreamCapacities(
        customSchoolId: widget.customSchoolId,
        updates: updates,
      );
      await _load();
      if (!mounted) return;
      _showMessage('Stream capacities updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save capacities. $error');
    } finally {
      if (mounted) setState(() => _savingCapacities = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onBack != null) ...[
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to settings'),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stream Capacity',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Set maximum students per stream. Teacher assignment has its own settings page.',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_loading)
              const _SettingsSkeleton()
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else ...[
              _CapacitySection(
                levels: _levels,
                controllers: _capacityControllers,
                saving: _savingCapacities,
                hasChanges: _hasCapacityChanges,
                onChanged: () => setState(() {}),
                onSave: _saveCapacities,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ClassTeacherSettingsScreen extends StatefulWidget {
  const ClassTeacherSettingsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.repository,
    this.onBack,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final ClassesRepository? repository;
  final VoidCallback? onBack;

  @override
  State<ClassTeacherSettingsScreen> createState() =>
      _ClassTeacherSettingsScreenState();
}

class _ClassTeacherSettingsScreenState
    extends State<ClassTeacherSettingsScreen> {
  late final ClassesRepository _repository =
      widget.repository ??
      ClassesApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );

  final Map<int, List<ClassTeacherAssignment>> _teachersByStream = {};
  final Set<int> _loadingTeacherStreams = {};
  List<ClassGradeLevel> _levels = [];
  List<SchoolStaffOption>? _staffOptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _teachersByStream.clear();
      _loadingTeacherStreams.clear();
    });
    try {
      final levels = await _repository.getAllStreams(widget.customSchoolId);
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ensureTeachersLoaded(int streamId) async {
    if (_teachersByStream.containsKey(streamId) ||
        _loadingTeacherStreams.contains(streamId)) {
      return;
    }
    setState(() => _loadingTeacherStreams.add(streamId));
    try {
      final teachers = await _repository.getClassTeachers(
        customSchoolId: widget.customSchoolId,
        streamId: streamId,
      );
      if (!mounted) return;
      setState(() => _teachersByStream[streamId] = teachers);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not load class teachers. $error');
    } finally {
      if (mounted) setState(() => _loadingTeacherStreams.remove(streamId));
    }
  }

  Future<void> _reloadTeachers(int streamId) async {
    setState(() => _teachersByStream.remove(streamId));
    await _ensureTeachersLoaded(streamId);
  }

  Future<void> _showAddTeacherDialog(ClassStreamSummary stream) async {
    await _ensureTeachersLoaded(stream.id);
    try {
      _staffOptions ??= await _repository.getSchoolStaff(widget.customSchoolId);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not load staff list. $error');
      return;
    }
    if (!mounted) return;

    final assignedIds =
        (_teachersByStream[stream.id] ?? const <ClassTeacherAssignment>[])
            .map((teacher) => teacher.staffId)
            .toSet();
    final options = (_staffOptions ?? const <SchoolStaffOption>[])
        .where((staff) => !assignedIds.contains(staff.id))
        .toList();
    if (options.isEmpty) {
      _showMessage('All available staff are already assigned to this stream.');
      return;
    }

    var selectedStaff = options.first;
    var makePrimary = (_teachersByStream[stream.id] ?? const []).isEmpty;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add teacher to ${stream.name}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<SchoolStaffOption>(
                  value: selectedStaff,
                  decoration: const InputDecoration(labelText: 'Staff member'),
                  items: options
                      .map(
                        (staff) => DropdownMenuItem(
                          value: staff,
                          child: Text('${staff.name} · ${staff.role}'),
                        ),
                      )
                      .toList(),
                  onChanged: (staff) {
                    if (staff == null) return;
                    setDialogState(() => selectedStaff = staff);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as primary class teacher'),
                  value: makePrimary,
                  onChanged: (value) =>
                      setDialogState(() => makePrimary = value),
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
              child: const Text('Add teacher'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      await _repository.addClassTeacher(
        customSchoolId: widget.customSchoolId,
        streamId: stream.id,
        staffId: selectedStaff.id,
        isPrimary: makePrimary,
      );
      await _reloadTeachers(stream.id);
      if (!mounted) return;
      _showMessage('Class teacher added.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not add teacher. $error');
    }
  }

  Future<void> _setPrimaryTeacher(
    ClassStreamSummary stream,
    ClassTeacherAssignment teacher,
  ) async {
    try {
      await _repository.setPrimaryClassTeacher(
        customSchoolId: widget.customSchoolId,
        streamId: stream.id,
        classTeacherId: teacher.id,
      );
      await _reloadTeachers(stream.id);
      if (!mounted) return;
      _showMessage('${teacher.name} is now primary.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not set primary teacher. $error');
    }
  }

  Future<void> _toggleTeacher(
    ClassStreamSummary stream,
    ClassTeacherAssignment teacher,
  ) async {
    try {
      await _repository.updateClassTeacher(
        customSchoolId: widget.customSchoolId,
        classTeacherId: teacher.id,
        isPrimary: teacher.isPrimary,
        isActive: !teacher.isActive,
      );
      await _reloadTeachers(stream.id);
      if (!mounted) return;
      _showMessage('Teacher assignment updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update teacher. $error');
    }
  }

  Future<void> _removeTeacher(
    ClassStreamSummary stream,
    ClassTeacherAssignment teacher,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove class teacher?'),
        content: Text(
          '${teacher.name} will no longer be assigned to ${stream.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.removeClassTeacher(
        customSchoolId: widget.customSchoolId,
        classTeacherId: teacher.id,
      );
      await _reloadTeachers(stream.id);
      if (!mounted) return;
      _showMessage('Class teacher removed.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not remove teacher. $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onBack != null) ...[
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to settings'),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Teacher Assignments',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Assign primary and supporting class teachers to each stream.',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_loading)
              const _SettingsSkeleton()
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else
              _TeacherSection(
                levels: _levels,
                teachersByStream: _teachersByStream,
                loadingStreamIds: _loadingTeacherStreams,
                onExpanded: _ensureTeachersLoaded,
                onAddTeacher: _showAddTeacherDialog,
                onSetPrimary: _setPrimaryTeacher,
                onToggleTeacher: _toggleTeacher,
                onRemoveTeacher: _removeTeacher,
              ),
          ],
        ),
      ),
    );
  }
}

class _CapacitySection extends StatelessWidget {
  const _CapacitySection({
    required this.levels,
    required this.controllers,
    required this.saving,
    required this.hasChanges,
    required this.onChanged,
    required this.onSave,
  });

  final List<ClassGradeLevel> levels;
  final Map<int, TextEditingController> controllers;
  final bool saving;
  final bool hasChanges;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: 'Stream capacity',
                    subtitle:
                        'Set the maximum number of students each stream can hold.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: saving || !hasChanges ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (levels.every((level) => level.streams.isEmpty))
              const _EmptyState(
                icon: Icons.account_tree_outlined,
                title: 'No streams configured yet',
                message:
                    'Create streams from Classes & Streams before setting capacity.',
              )
            else
              Column(
                children: [
                  const _CapacityHeader(),
                  ...levels.expand<Widget>((level) {
                    if (level.streams.isEmpty) return const <Widget>[];
                    return <Widget>[
                      _GradeDivider(
                        name: level.name,
                        count: level.streams.length,
                      ),
                      ...level.streams.map(
                        (stream) => _CapacityRow(
                          stream: stream,
                          controller: controllers[stream.id]!,
                          onChanged: onChanged,
                        ),
                      ),
                    ];
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TeacherSection extends StatelessWidget {
  const _TeacherSection({
    required this.levels,
    required this.teachersByStream,
    required this.loadingStreamIds,
    required this.onExpanded,
    required this.onAddTeacher,
    required this.onSetPrimary,
    required this.onToggleTeacher,
    required this.onRemoveTeacher,
  });

  final List<ClassGradeLevel> levels;
  final Map<int, List<ClassTeacherAssignment>> teachersByStream;
  final Set<int> loadingStreamIds;
  final ValueChanged<int> onExpanded;
  final ValueChanged<ClassStreamSummary> onAddTeacher;
  final void Function(ClassStreamSummary, ClassTeacherAssignment) onSetPrimary;
  final void Function(ClassStreamSummary, ClassTeacherAssignment)
  onToggleTeacher;
  final void Function(ClassStreamSummary, ClassTeacherAssignment)
  onRemoveTeacher;

  @override
  Widget build(BuildContext context) {
    final streams = levels.expand((level) => level.streams).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Class teachers',
              subtitle:
                  'Assign one or more class teachers to each stream and choose the primary teacher.',
            ),
            const SizedBox(height: 16),
            if (streams.isEmpty)
              const _EmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No streams available',
                message: 'Teacher assignments will appear after streams exist.',
              )
            else
              Column(
                children: levels.expand<Widget>((level) {
                  if (level.streams.isEmpty) return const <Widget>[];
                  return <Widget>[
                    _GradeDivider(
                      name: level.name,
                      count: level.streams.length,
                    ),
                    ...level.streams.map(
                      (stream) => _TeacherTile(
                        stream: stream,
                        teachers: teachersByStream[stream.id],
                        loading: loadingStreamIds.contains(stream.id),
                        onExpanded: () => onExpanded(stream.id),
                        onAddTeacher: () => onAddTeacher(stream),
                        onSetPrimary: (teacher) =>
                            onSetPrimary(stream, teacher),
                        onToggleTeacher: (teacher) =>
                            onToggleTeacher(stream, teacher),
                        onRemoveTeacher: (teacher) =>
                            onRemoveTeacher(stream, teacher),
                      ),
                    ),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _CapacityHeader extends StatelessWidget {
  const _CapacityHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _HeaderText('Stream')),
          Expanded(flex: 2, child: _HeaderText('Enrolled')),
          Expanded(flex: 2, child: _HeaderText('Fill')),
          SizedBox(width: 120, child: _HeaderText('Capacity')),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({
    required this.stream,
    required this.controller,
    required this.onChanged,
  });

  final ClassStreamSummary stream;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final capacity = stream.capacity;
    final fill = capacity == null || capacity <= 0
        ? 0.0
        : stream.enrolled / capacity;
    final overCapacity = capacity != null && fill > 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              stream.name,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${stream.enrolled} students',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: fill.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overCapacity ? AppColors.red : AppColors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(fill * 100).round()}%',
                  style: TextStyle(
                    color: overCapacity ? AppColors.red : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 102,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Set',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  const _TeacherTile({
    required this.stream,
    required this.teachers,
    required this.loading,
    required this.onExpanded,
    required this.onAddTeacher,
    required this.onSetPrimary,
    required this.onToggleTeacher,
    required this.onRemoveTeacher,
  });

  final ClassStreamSummary stream;
  final List<ClassTeacherAssignment>? teachers;
  final bool loading;
  final VoidCallback onExpanded;
  final VoidCallback onAddTeacher;
  final ValueChanged<ClassTeacherAssignment> onSetPrimary;
  final ValueChanged<ClassTeacherAssignment> onToggleTeacher;
  final ValueChanged<ClassTeacherAssignment> onRemoveTeacher;

  @override
  Widget build(BuildContext context) {
    final loadedTeachers = teachers ?? const <ClassTeacherAssignment>[];
    final primaryTeachers = loadedTeachers
        .where((teacher) => teacher.isPrimary && teacher.isActive)
        .map((teacher) => teacher.name)
        .toList();
    final primary = primaryTeachers.isEmpty ? null : primaryTeachers.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) onExpanded();
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          stream.name,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          primary == null
              ? 'Open to manage assigned class teachers'
              : 'Primary: $primary',
          style: const TextStyle(color: AppColors.muted),
        ),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAddTeacher,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add teacher'),
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (loadedTeachers.isEmpty)
            const _EmptyState(
              icon: Icons.person_off_outlined,
              title: 'No teachers assigned',
              message: 'Add one or more teachers for this stream.',
            )
          else
            Column(
              children: loadedTeachers
                  .map(
                    (teacher) => _TeacherRow(
                      teacher: teacher,
                      onSetPrimary: () => onSetPrimary(teacher),
                      onToggle: () => onToggleTeacher(teacher),
                      onRemove: () => onRemoveTeacher(teacher),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
    required this.teacher,
    required this.onSetPrimary,
    required this.onToggle,
    required this.onRemove,
  });

  final ClassTeacherAssignment teacher;
  final VoidCallback onSetPrimary;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: teacher.isActive ? AppColors.background : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.greenSoft,
            child: Text(
              _initials(teacher.name),
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
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      teacher.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (teacher.isPrimary) const _SmallBadge('Primary'),
                    if (!teacher.isActive)
                      const _SmallBadge('Inactive', color: AppColors.muted),
                  ],
                ),
                if (teacher.email.isNotEmpty)
                  Text(
                    teacher.email,
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (!teacher.isPrimary && teacher.isActive)
            TextButton(
              onPressed: onSetPrimary,
              child: const Text('Set primary'),
            ),
          TextButton(
            onPressed: onToggle,
            child: Text(teacher.isActive ? 'Deactivate' : 'Activate'),
          ),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CT';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _GradeDivider extends StatelessWidget {
  const _GradeDivider({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.border)),
          const SizedBox(width: 10),
          Text(
            '$count ${count == 1 ? 'stream' : 'streams'}',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        letterSpacing: .7,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, {this.color = AppColors.green});

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
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load class settings',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
