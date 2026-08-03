import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/classes_api_client.dart';
import '../domain/class_models.dart';

class ClassSubjectConfigurationScreen extends StatefulWidget {
  const ClassSubjectConfigurationScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    ClassesRepository? repository,
  }) : _repository = repository;

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
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
    });
    try {
      final grades = await _repository.getAllGradeLevels(widget.customSchoolId);
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(ClassGradeLevel grade, bool active) async {
    if (!active && grade.studentCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Make ${grade.name} inactive?'),
          content: Text(
            '${grade.name} has ${grade.studentCount} enrolled student${grade.studentCount == 1 ? '' : 's'}. Existing records will remain available, but new admissions and assignments will be stopped.',
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
      await _load();
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
          title: const Text('Add custom early-years class'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom classes are placed below KG1. KG subjects will be suggested and can be edited after creation.',
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
                  decoration: const InputDecoration(labelText: 'Streams'),
                  items: [1, 2, 3, 4]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value stream${value == 1 ? '' : 's'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => streams = value ?? 1),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.vertical_align_bottom_rounded,
                      size: 18,
                      color: AppColors.green,
                    ),
                    SizedBox(width: 8),
                    Text('Level position: Below KG1'),
                  ],
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

  Future<void> _manageSubjects(ClassGradeLevel grade) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SubjectManager(
        repository: _repository,
        customSchoolId: widget.customSchoolId,
        grade: grade,
      ),
    );
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
    final ges = _grades.where((grade) => !grade.custom).toList();
    final custom = _grades.where((grade) => grade.custom).toList();
    return SingleChildScrollView(
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
                          'Classes and subjects',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Review onboarding selections, enable GES levels, and add school-specific classes or subjects.',
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
                  onSubjects: () => _manageSubjects(grade),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Custom early-years classes',
                subtitle:
                    'Creche and nursery levels are ordered below KG1 and start with editable KG subject suggestions.',
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
                    onSubjects: () => _manageSubjects(grade),
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
    required this.onSubjects,
  });
  final ClassGradeLevel grade;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSubjects;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (grade.active ? AppColors.green : AppColors.muted)
                .withValues(alpha: .12),
            child: Icon(
              grade.custom
                  ? Icons.auto_awesome_outlined
                  : Icons.school_outlined,
              color: grade.active ? AppColors.green : AppColors.muted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      grade.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      grade.custom ? 'CUSTOM · BELOW KG1' : 'GES',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${grade.streams.length} stream${grade.streams.length == 1 ? '' : 's'} · ${grade.studentCount} students',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onSubjects,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Subjects'),
          ),
          const SizedBox(width: 14),
          const Text('Active'),
          Switch(value: grade.active, onChanged: onActiveChanged),
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
          'No custom early-years classes yet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Creche or Nursery'),
        ),
      ],
    ),
  );
}

class _SubjectManager extends StatefulWidget {
  const _SubjectManager({
    required this.repository,
    required this.customSchoolId,
    required this.grade,
  });
  final ClassesRepository repository;
  final String customSchoolId;
  final ClassGradeLevel grade;
  @override
  State<_SubjectManager> createState() => _SubjectManagerState();
}

class _SubjectManagerState extends State<_SubjectManager> {
  List<ClassSubject>? _subjects;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.getGradeSubjects(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: widget.grade.gradeLevelId,
      );
      if (mounted) {
        setState(() {
          _subjects = value;
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
    var examinable = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add subject to ${widget.grade.name}'),
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
                  decoration: const InputDecoration(
                    labelText: 'Subject code (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Examinable'),
                  subtitle: const Text(
                    'Include scores and grades on report cards',
                  ),
                  value: examinable,
                  onChanged: (v) => setState(() => examinable = v),
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
              child: const Text('Add subject'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.repository.createCustomSubject(
      customSchoolId: widget.customSchoolId,
      gradeLevelId: widget.grade.gradeLevelId,
      name: name.text.trim(),
      code: code.text.trim(),
      examinable: examinable,
    );
    await _load();
  }

  Future<void> _edit(ClassSubject subject) async {
    final name = TextEditingController(text: subject.name);
    final code = TextEditingController(text: subject.code);
    var examinable = subject.examinable;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Examinable'),
                  subtitle: const Text(
                    'Include scores and grades on report cards',
                  ),
                  value: examinable,
                  onChanged: (value) =>
                      setDialogState(() => examinable = value),
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
        examinable: examinable,
      ),
    );
    await _load();
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

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.grade.name} subjects',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Add school subjects and choose whether each one is examinable.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add subject'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.red))
          else if (_subjects == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_subjects!.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.grade.custom
                      ? 'No subjects found. Add a subject or use the KG suggestions created with this class.'
                      : 'No subjects configured for this grade.',
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _subjects!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final subject = _subjects![index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(subject.name.characters.first),
                    ),
                    title: Text(subject.name),
                    subtitle: Text(
                      '${subject.code.isEmpty ? 'No code' : subject.code} · ${subject.custom ? 'Custom' : 'GES'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            subject.examinable
                                ? 'Examinable'
                                : 'Non-examinable',
                          ),
                        ),
                        if (subject.custom) ...[
                          IconButton(
                            tooltip: 'Edit subject',
                            onPressed: () => _edit(subject),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remove subject',
                            onPressed: () => _delete(subject),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
