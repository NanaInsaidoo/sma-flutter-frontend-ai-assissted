import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/classes_api_client.dart';
import '../domain/class_models.dart';

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
    this.startWithAddCustomClass = false,
    ClassesRepository? repository,
  }) : _repository = repository;

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final bool startWithAddCustomClass;
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
  bool _initialAddClassOpened = false;

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
      if (widget.startWithAddCustomClass && !_initialAddClassOpened) {
        _initialAddClassOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _addCustomClass();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(ClassGradeLevel grade, bool active) async {
    if (active && grade.streams.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Activate ${grade.name}?'),
          content: Text(
            '${grade.name} does not have a section yet. Section 1 will be created because every active class must have at least one section.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create section and activate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
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
                    labelText: 'Position below KG1',
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
                title: 'Custom early-years classes',
                subtitle:
                    'Creche and nursery levels appear before KG1 and start with editable KG subject suggestions.',
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
                    onEdit: () => _editCustomClass(grade),
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
                  onSubjects: () => _manageSubjects(grade),
                  onEdit: null,
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
    required this.onEdit,
  });
  final ClassGradeLevel grade;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSubjects;
  final VoidCallback? onEdit;
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
                  '${grade.streams.length} section${grade.streams.length == 1 ? '' : 's'} · ${grade.studentCount} students',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (grade.custom) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Progresses to ${grade.nextGradeLevelName ?? 'the next active class'}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onSubjects,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Subjects'),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Edit class and progression',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
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
    final created = await widget.repository.createCustomSubject(
      customSchoolId: widget.customSchoolId,
      gradeLevelId: widget.grade.gradeLevelId,
      name: name.text.trim(),
      code: code.text.trim(),
      examinable: examinable,
    );
    await _load();
    if (mounted) await _editAvailability(created);
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
          return AlertDialog(
            title: Text('${subject.name} sections'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                term.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                configuration.copiedFromTermId != null &&
                                        configuration.status.toUpperCase() ==
                                            'DRAFT'
                                    ? 'Copied from the previous term · Review before activating'
                                    : readOnly
                                    ? 'Historical setup · Read-only'
                                    : 'Choose the sections that study this subject',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!readOnly && configuration.availableSections.isNotEmpty)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selected
                              ..clear()
                              ..addAll(
                                configuration.availableSections
                                    .where((section) => section.active)
                                    .map((section) => section.id),
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
                              return CheckboxListTile(
                                value: selected.contains(section.id),
                                onChanged: readOnly || !section.active
                                    ? null
                                    : (checked) => setDialogState(() {
                                        checked == true
                                            ? selected.add(section.id)
                                            : selected.remove(section.id);
                                      }),
                                title: Text(section.name),
                                subtitle: section.active
                                    ? null
                                    : const Text('Inactive section'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                  ),
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
                  child: const Text('Save as draft'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'ACTIVE'),
                  child: const Text('Make available'),
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
          if (_terms.isNotEmpty) ...[
            SizedBox(
              width: 340,
              child: DropdownButtonFormField<int>(
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
            ),
            const SizedBox(height: 16),
          ],
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
                  final subjectAvailability = subject.schoolSubjectId == null
                      ? null
                      : _availability[subject.schoolSubjectId!];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(subject.name.characters.first),
                    ),
                    title: Text(subject.name),
                    subtitle: Text(
                      subject.custom
                          ? '${subject.code.isEmpty ? 'No code' : subject.code} · Custom · '
                                '${subjectAvailability == null
                                    ? 'Section setup unavailable'
                                    : subjectAvailability.streamIds.isEmpty
                                    ? 'No sections'
                                    : '${subjectAvailability.streamIds.length} section${subjectAvailability.streamIds.length == 1 ? '' : 's'}'}'
                          : '${subject.code.isEmpty ? 'No code' : subject.code} · GES · All sections',
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
                          TextButton.icon(
                            onPressed: () => _editAvailability(subject),
                            icon: const Icon(
                              Icons.view_week_outlined,
                              size: 18,
                            ),
                            label: Text(
                              subjectAvailability?.status.toUpperCase() ==
                                      'DRAFT'
                                  ? 'Sections · Draft'
                                  : 'Sections',
                            ),
                          ),
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
