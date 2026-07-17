import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/mock_class_requirements_repository.dart';
import '../domain/class_requirement_models.dart';

class ClassRequirementsScreen extends StatefulWidget {
  const ClassRequirementsScreen({
    super.key,
    required this.repository,
    required this.termName,
  });

  final ClassRequirementsRepository repository;
  final String termName;

  @override
  State<ClassRequirementsScreen> createState() =>
      _ClassRequirementsScreenState();
}

class _ClassRequirementsScreenState extends State<ClassRequirementsScreen> {
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final selected = _selectedGroupId == null
            ? null
            : widget.repository.groups
                  .where((group) => group.id == _selectedGroupId)
                  .firstOrNull;
        if (selected != null) {
          return _ClassTracker(
            repository: widget.repository,
            group: selected,
            onBack: () => setState(() => _selectedGroupId = null),
            onAddRequirement: () => _showRequirementForm(selected.id),
            onEditRequirement: (item) =>
                _showRequirementForm(selected.id, initialItem: item),
            onDeleteRequirement: (item) =>
                _confirmDeleteRequirement(selected, item),
            onPublish: () => _showPublishDialog(selected),
            onOpenStudent: (student) => _showStudentDetails(selected, student),
          );
        }
        return _RequirementsOverview(
          repository: widget.repository,
          termName: widget.termName,
          onOpenClass: (group) => setState(() => _selectedGroupId = group.id),
          onAddClass: _showClassForm,
        );
      },
    );
  }

  Future<void> _showRequirementForm(
    String initialGroupId, {
    ClassRequirementItem? initialItem,
  }) async {
    final result = await showDialog<_RequirementFormResult>(
      context: context,
      builder: (context) => _AddRequirementDialog(
        groups: widget.repository.groups,
        initialGroupId: initialGroupId,
        initialItem: initialItem,
      ),
    );
    if (result == null) return;
    if (initialItem == null) {
      widget.repository.addRequirement(result.groupId, result.item);
    } else {
      widget.repository.updateRequirement(result.groupId, result.item);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          initialItem == null
              ? 'Requirement saved as a draft change.'
              : 'Requirement updated as a draft change.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRequirement(
    ClassRequirementGroup group,
    ClassRequirementItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete requirement?'),
        content: Text(
          'Remove ${item.name} from ${group.className}? This will be saved as a draft change and its student progress will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.repository.deleteRequirement(group.id, item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} removed as a draft change.')),
    );
  }

  Future<void> _showClassForm() async {
    final existingNames = widget.repository.groups
        .map((group) => group.className)
        .toSet();
    final group = await showDialog<ClassRequirementGroup>(
      context: context,
      builder: (context) => _AddClassDialog(existingNames: existingNames),
    );
    if (group == null) return;
    widget.repository.addClass(group);
    setState(() => _selectedGroupId = group.id);
  }

  Future<void> _showPublishDialog(ClassRequirementGroup group) async {
    final plan = await showDialog<RequirementNotificationPlan>(
      context: context,
      builder: (context) => _PublishRequirementsDialog(
        className: group.className,
        changeCount: widget.repository.draftChangeCountForClass(group.id),
      ),
    );
    if (plan == null) return;
    widget.repository.publishClass(group.id, plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${group.className} requirements published and guardian alerts queued.',
        ),
      ),
    );
  }

  Future<void> _showStudentDetails(
    ClassRequirementGroup group,
    StudentRequirementProgress student,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final updated = widget.repository
              .studentsForClass(group.id)
              .firstWhere((item) => item.id == student.id);
          return _StudentRequirementDialog(
            group: group,
            student: updated,
            onRecord: (item) => _recordReceived(updated, item),
            onAdjust: (item) => _adjustRequirement(updated, item),
            onAddCustom: () => _addCustomRequirement(updated),
          );
        },
      ),
    );
  }

  Future<void> _recordReceived(
    StudentRequirementProgress student,
    ClassRequirementItem item,
  ) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => _RecordReceivedDialog(
        item: item,
        current: student.receivedQuantities[item.id] ?? 0,
        target: _targetQuantity(student, item),
      ),
    );
    if (quantity == null) return;
    widget.repository.recordReceived(
      studentId: student.id,
      requirementId: item.id,
      quantity: quantity,
    );
  }

  Future<void> _adjustRequirement(
    StudentRequirementProgress student,
    ClassRequirementItem item,
  ) async {
    final adjustment = await showDialog<StudentRequirementAdjustment>(
      context: context,
      builder: (context) => _AdjustmentDialog(item: item),
    );
    if (adjustment == null) return;
    widget.repository.adjustRequirement(
      studentId: student.id,
      requirementId: item.id,
      adjustment: adjustment,
    );
  }

  Future<void> _addCustomRequirement(StudentRequirementProgress student) async {
    final requirement = await showDialog<StudentCustomRequirement>(
      context: context,
      builder: (context) => const _StudentCustomRequirementDialog(),
    );
    if (requirement == null) return;
    widget.repository.addStudentRequirement(
      studentId: student.id,
      requirement: requirement,
    );
  }
}

class _RequirementsOverview extends StatelessWidget {
  const _RequirementsOverview({
    required this.repository,
    required this.termName,
    required this.onOpenClass,
    required this.onAddClass,
  });

  final ClassRequirementsRepository repository;
  final String termName;
  final ValueChanged<ClassRequirementGroup> onOpenClass;
  final VoidCallback onAddClass;

  @override
  Widget build(BuildContext context) {
    final groups = repository.groups;
    final totalStudents = groups.fold<int>(0, (sum, g) => sum + g.studentCount);
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    final completion = groups.isEmpty
        ? 0
        : (groups
                      .map((g) => _groupCompletion(repository, g))
                      .reduce((a, b) => a + b) /
                  groups.length *
                  100)
              .round();
    final updatedItems = groups.fold<int>(
      0,
      (sum, g) =>
          sum + g.items.where((item) => item.updatedSincePublished).length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          title: 'Class Requirements',
          subtitle:
              '$termName · Add a class, then define the items its students must supply.',
          actions: [
            FilledButton.icon(
              onPressed: onAddClass,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add class'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 620
                ? 1
                : constraints.maxWidth < 980
                ? 2
                : 4;
            final width =
                (constraints.maxWidth - (16 * (columns - 1))) / columns;
            final cards = [
              _SummaryCardData(
                'Classes configured',
                '${groups.length}',
                '$totalItems required items',
                Icons.class_outlined,
                AppColors.green,
              ),
              _SummaryCardData(
                'Students covered',
                '$totalStudents',
                'Across configured classes',
                Icons.groups_outlined,
                AppColors.blue,
              ),
              _SummaryCardData(
                'Overall completion',
                '$completion%',
                'Items received or waived',
                Icons.task_alt_rounded,
                AppColors.green,
              ),
              _SummaryCardData(
                'Updated items',
                '$updatedItems',
                updatedItems == 0
                    ? 'No unpublished updates'
                    : 'Changed since last publish',
                Icons.notifications_active_outlined,
                AppColors.amber,
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map(
                    (data) => SizedBox(width: width, child: _SummaryCard(data)),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Requirements by class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${groups.length} classes',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720
                ? 1
                : constraints.maxWidth < 1100
                ? 2
                : 3;
            final width =
                (constraints.maxWidth - (18 * (columns - 1))) / columns;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: groups
                  .map(
                    (group) => SizedBox(
                      width: width,
                      child: _ClassRequirementCard(
                        repository: repository,
                        group: group,
                        onTap: () => onOpenClass(group),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ClassTracker extends StatelessWidget {
  const _ClassTracker({
    required this.repository,
    required this.group,
    required this.onBack,
    required this.onAddRequirement,
    required this.onEditRequirement,
    required this.onDeleteRequirement,
    required this.onPublish,
    required this.onOpenStudent,
  });

  final ClassRequirementsRepository repository;
  final ClassRequirementGroup group;
  final VoidCallback onBack;
  final VoidCallback onAddRequirement;
  final ValueChanged<ClassRequirementItem> onEditRequirement;
  final ValueChanged<ClassRequirementItem> onDeleteRequirement;
  final VoidCallback onPublish;
  final ValueChanged<StudentRequirementProgress> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final students = repository.studentsForClass(group.id);
    final hasItems = group.items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to class requirements'),
        ),
        const SizedBox(height: 8),
        _PageHeading(
          title: '${group.className} requirements',
          subtitle:
              '${group.items.length} items · ${group.studentCount} students · ${(100 * _groupCompletion(repository, group)).round()}% complete',
          actions: [
            OutlinedButton.icon(
              onPressed: onAddRequirement,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add class item'),
            ),
            FilledButton.icon(
              onPressed: group.draftChangeCount == 0 ? null : onPublish,
              icon: Icon(
                hasItems ? Icons.campaign_outlined : Icons.inventory_2_outlined,
              ),
              label: Text(
                !hasItems
                    ? 'Add items to publish'
                    : group.draftChangeCount == 0
                    ? 'Published'
                    : 'Review & publish (${group.draftChangeCount})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!hasItems) ...[
          _EmptyClassSetup(onAddRequirement: onAddRequirement),
          const SizedBox(height: 20),
        ],
        _ClassChecklistTable(
          items: group.items,
          onEdit: onEditRequirement,
          onDelete: onDeleteRequirement,
        ),
        const SizedBox(height: 20),
        const Text(
          'Student progress',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (students.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 34,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 32,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasItems
                              ? 'No students are enrolled in this class yet.'
                              : 'Student tracking will appear here after class items are configured.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Enrolled students will be linked automatically from the class register.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...students.map(
                  (student) => _StudentProgressRow(
                    group: group,
                    student: student,
                    onTap: () => onOpenStudent(student),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassChecklistTable extends StatelessWidget {
  const _ClassChecklistTable({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClassRequirementItem> items;
  final ValueChanged<ClassRequirementItem> onEdit;
  final ValueChanged<ClassRequirementItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Text(
              'Class checklist',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'No class items have been added yet.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else ...[
            const Divider(height: 1),
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 1160
                    ? 1160.0
                    : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        const _ChecklistHeader(),
                        ...items.map(
                          (item) => _ChecklistRow(
                            item,
                            onEdit: () => onEdit(item),
                            onDelete: () => onDelete(item),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistHeader extends StatelessWidget {
  const _ChecklistHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.background,
      child: const Row(
        children: [
          _TableHeading('Item', flex: 28),
          _TableHeading('Category', flex: 17),
          _TableHeading('Required', flex: 13),
          _TableHeading('Due date', flex: 14),
          _TableHeading('Unit estimate', flex: 14),
          _TableHeading('Total / student', flex: 15),
          _TableHeading('Status', flex: 14),
          _TableHeading('Actions', flex: 11),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow(
    this.item, {
    required this.onEdit,
    required this.onDelete,
  });

  final ClassRequirementItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Row(
              children: [
                _RequirementIcon(category: item.category),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (item.instructions.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.instructions,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _TableValue(item.category, flex: 17),
          _TableValue('${item.quantity} ${item.unit}', flex: 13),
          _TableValue(_date(item.dueDate), flex: 14),
          _TableValue(
            '${_money(item.estimatedUnitPrice)} / ${_singularUnit(item.unit)}',
            flex: 14,
            color: AppColors.green,
          ),
          _TableValue(
            _money(item.estimatedUnitPrice * item.quantity),
            flex: 15,
            bold: true,
          ),
          Expanded(
            flex: 14,
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                if (item.updatedSincePublished)
                  const _SmallPill(label: 'Updated', color: AppColors.amber),
                if (item.isOptional)
                  const _SmallPill(label: 'Optional', color: AppColors.blue),
                if (!item.updatedSincePublished && !item.isOptional)
                  const _SmallPill(label: 'Current', color: AppColors.green),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit requirement',
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.green,
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete requirement',
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _TableValue extends StatelessWidget {
  const _TableValue(
    this.value, {
    required this.flex,
    this.color,
    this.bold = false,
  });

  final String value;
  final int flex;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ClassRequirementCard extends StatelessWidget {
  const _ClassRequirementCard({
    required this.repository,
    required this.group,
    required this.onTap,
  });

  final ClassRequirementsRepository repository;
  final ClassRequirementGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completion = _groupCompletion(repository, group);
    final estimatedTotal = group.items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.estimatedUnitPrice),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.className,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _SmallPill(
                    label: group.draftChangeCount == 0
                        ? 'Published'
                        : '${group.draftChangeCount} draft change${group.draftChangeCount == 1 ? '' : 's'}',
                    color: group.draftChangeCount == 0
                        ? AppColors.green
                        : AppColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${group.studentCount} students · ${group.items.length} items',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              ...group.items
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.checklist_rounded,
                            size: 17,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.name)),
                          SizedBox(
                            width: 142,
                            child: Text(
                              '${item.quantity} ${item.unit} · ${_money(item.estimatedUnitPrice)}/${_singularUnit(item.unit)}',
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (group.items.isNotEmpty) ...[
                const Divider(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Estimated value per student',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Text(
                      _money(estimatedTotal),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: completion,
                        minHeight: 7,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(completion * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClassSetup extends StatelessWidget {
  const _EmptyClassSetup({required this.onAddRequirement});

  final VoidCallback onAddRequirement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.playlist_add_rounded,
              color: AppColors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class created. Add its first requirement.',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(
                  'Add all required items, review the estimated cash values, then publish this class checklist.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          FilledButton.icon(
            onPressed: onAddRequirement,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add first item'),
          ),
        ],
      ),
    );
  }
}

class _StudentProgressRow extends StatelessWidget {
  const _StudentProgressRow({
    required this.group,
    required this.student,
    required this.onTap,
  });

  final ClassRequirementGroup group;
  final StudentRequirementProgress student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = group.items
        .where((item) => _isComplete(student, item))
        .length;
    final total = group.items.length + student.customRequirements.length;
    final rate = total == 0 ? 0.0 : completed / total;
    final color = rate >= 1
        ? AppColors.green
        : rate > 0
        ? AppColors.amber
        : AppColors.red;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.greenSoft,
              foregroundColor: AppColors.green,
              child: Text(_initials(student.name)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed of $total requirements complete',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            _SmallPill(
              label: rate >= 1
                  ? 'Complete'
                  : rate > 0
                  ? 'In progress'
                  : 'Not started',
              color: color,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _StudentRequirementDialog extends StatelessWidget {
  const _StudentRequirementDialog({
    required this.group,
    required this.student,
    required this.onRecord,
    required this.onAdjust,
    required this.onAddCustom,
  });

  final ClassRequirementGroup group;
  final StudentRequirementProgress student;
  final ValueChanged<ClassRequirementItem> onRecord;
  final ValueChanged<ClassRequirementItem> onAdjust;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.greenSoft,
                    foregroundColor: AppColors.green,
                    child: Text(_initials(student.name)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${group.className} · Requirement tracker',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Class requirements',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAddCustom,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Add student-only item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...group.items.map(
                    (item) => _StudentRequirementItemCard(
                      item: item,
                      student: student,
                      onRecord: () => onRecord(item),
                      onAdjust: () => onAdjust(item),
                    ),
                  ),
                  if (student.customRequirements.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Individual requirements',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...student.customRequirements.map(
                      (item) => Card(
                        color: AppColors.blue.withValues(alpha: .08),
                        child: ListTile(
                          leading: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.blue,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${item.quantity} ${item.unit} · Due ${_date(item.dueDate)}\n${item.notes}',
                          ),
                          isThreeLine: item.notes.isNotEmpty,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRequirementItemCard extends StatelessWidget {
  const _StudentRequirementItemCard({
    required this.item,
    required this.student,
    required this.onRecord,
    required this.onAdjust,
  });

  final ClassRequirementItem item;
  final StudentRequirementProgress student;
  final VoidCallback onRecord;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final received = student.receivedQuantities[item.id] ?? 0;
    final target = _targetQuantity(student, item);
    final adjustment = student.adjustments[item.id];
    final complete = received >= target;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RequirementIcon(category: item.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$received of $target ${item.unit} received',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if (adjustment != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_adjustmentLabel(adjustment.type)} · ${adjustment.reason}',
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _SmallPill(
                  label: complete ? 'Complete' : 'Outstanding',
                  color: complete ? AppColors.green : AppColors.amber,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onAdjust,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Adjust / waive'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Record received'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddClassDialog extends StatefulWidget {
  const _AddClassDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<_AddClassDialog> {
  static const _classNames = [
    'KG 1',
    'KG 2',
    'Basic 1',
    'Basic 2',
    'Basic 3',
    'Basic 4',
    'Basic 5',
    'Basic 6',
    'JHS 1',
    'JHS 2',
    'JHS 3',
  ];

  String? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final available = _classNames
        .where((name) => !widget.existingNames.contains(name))
        .toList();
    return AlertDialog(
      title: const Text('Set up class requirements'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose one class. You will add its items and publish its checklist separately.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (available.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'All available classes are already configured.',
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  labelText: 'Class *',
                  hintText: 'Select class',
                ),
                items: available
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedClass = value),
              ),
            const SizedBox(height: 12),
            const Text(
              'Enrolled students will be linked from the class register when the backend is connected.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
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
          onPressed: _selectedClass == null
              ? null
              : () {
                  final name = _selectedClass!;
                  Navigator.pop(
                    context,
                    ClassRequirementGroup(
                      id: '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().microsecondsSinceEpoch}',
                      className: name,
                      studentCount: 0,
                      items: const [],
                      status: RequirementStatus.draft,
                    ),
                  );
                },
          child: const Text('Continue to class'),
        ),
      ],
    );
  }
}

class _AddRequirementDialog extends StatefulWidget {
  const _AddRequirementDialog({
    required this.groups,
    required this.initialGroupId,
    this.initialItem,
  });

  final List<ClassRequirementGroup> groups;
  final String initialGroupId;
  final ClassRequirementItem? initialItem;

  @override
  State<_AddRequirementDialog> createState() => _AddRequirementDialogState();
}

class _AddRequirementDialogState extends State<_AddRequirementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _unitPrice;
  late final TextEditingController _instructions;
  late final String _groupId;
  late String _category;
  late DateTime _dueDate;
  late bool _optional;

  static const _commonItems = [
    'Toilet rolls',
    'Box of tissues',
    'Liquid soap',
    'Disinfectant',
    'Exercise books',
    'HB pencils',
    'Pens',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _groupId = widget.initialGroupId;
    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(text: '${item?.quantity ?? 1}');
    _unit = TextEditingController(text: item?.unit ?? 'pieces');
    _unitPrice = TextEditingController(
      text: item == null ? '' : '${item.estimatedUnitPrice}',
    );
    _instructions = TextEditingController(text: item?.instructions ?? '');
    _category = item?.category ?? 'Hygiene';
    _dueDate = item?.dueDate ?? DateTime.now().add(const Duration(days: 14));
    _optional = item?.isOptional ?? false;
    _quantity.addListener(_refreshEstimate);
    _unitPrice.addListener(_refreshEstimate);
  }

  void _refreshEstimate() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _unitPrice.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.groups.firstWhere((group) => group.id == _groupId);
    final quantity = int.tryParse(_quantity.text) ?? 0;
    final unitPrice = double.tryParse(_unitPrice.text) ?? 0;
    return AlertDialog(
      title: Text(
        widget.initialItem == null
            ? 'Add item to ${group.className}'
            : 'Edit ${widget.initialItem!.name}',
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.initialItem == null
                      ? 'Create an item that every student in this class should supply.'
                      : 'Update this class requirement. The change will remain a draft until the class is published.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.class_outlined, color: AppColors.green),
                      const SizedBox(width: 10),
                      Text(
                        group.className,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Common items',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonItems
                      .map(
                        (item) => ActionChip(
                          label: Text(item),
                          onPressed: () => _name.text = item,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    hintText: 'e.g. Toilet rolls',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items:
                      const [
                            'Hygiene',
                            'Learning materials',
                            'Uniform & clothing',
                            'Boarding supplies',
                            'Other',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value ?? '');
                          return number == null || number < 1
                              ? 'Enter a valid quantity'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit *',
                          hintText: 'rolls, boxes, pieces',
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unitPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Estimated price / unit *',
                          prefixText: 'GH₵ ',
                        ),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');
                          return number == null || number <= 0
                              ? 'Enter a valid price'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: .2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Estimated cash equivalent per student'),
                      ),
                      Text(
                        _money(quantity * unitPrice),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: 'Due date',
                  date: _dueDate,
                  onChanged: (date) => setState(() => _dueDate = date),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _instructions,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _optional,
                  title: const Text('Optional item'),
                  onChanged: (value) => setState(() => _optional = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(
            widget.initialItem == null ? 'Save draft' : 'Save changes',
          ),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _RequirementFormResult(
        groupId: _groupId,
        item: ClassRequirementItem(
          id:
              widget.initialItem?.id ??
              'req-${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          category: _category,
          quantity: int.parse(_quantity.text),
          unit: _unit.text.trim(),
          estimatedUnitPrice: double.parse(_unitPrice.text),
          dueDate: _dueDate,
          instructions: _instructions.text.trim(),
          isOptional: _optional,
        ),
      ),
    );
  }
}

class _RecordReceivedDialog extends StatefulWidget {
  const _RecordReceivedDialog({
    required this.item,
    required this.current,
    required this.target,
  });

  final ClassRequirementItem item;
  final int current;
  final int target;

  @override
  State<_RecordReceivedDialog> createState() => _RecordReceivedDialogState();
}

class _RecordReceivedDialogState extends State<_RecordReceivedDialog> {
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.current}',
  );

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record item received'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Required: ${widget.target} ${widget.item.unit}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Total quantity received',
                suffixText: widget.item.unit,
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
            final value = int.tryParse(_quantity.text);
            if (value == null || value < 0) return;
            Navigator.pop(context, value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.item});

  final ClassRequirementItem item;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  final _paymentReference = TextEditingController();
  RequirementAdjustmentType _type = RequirementAdjustmentType.reducedQuantity;
  String _reason = 'Administrator decision';
  DateTime _extendedDate = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    _paymentReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsQuantity =
        _type == RequirementAdjustmentType.increasedQuantity ||
        _type == RequirementAdjustmentType.reducedQuantity ||
        _type == RequirementAdjustmentType.partialWaiver;
    final cashEquivalent = _reason == 'Cash equivalent paid';
    return AlertDialog(
      title: const Text('Adjust or waive requirement'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.item.name} · Standard quantity ${widget.item.quantity} ${widget.item.unit}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RequirementAdjustmentType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Adjustment type *',
                  ),
                  items: RequirementAdjustmentType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_adjustmentLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value!),
                ),
                if (needsQuantity) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'New required quantity *',
                      suffixText: widget.item.unit,
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      if (_type ==
                          RequirementAdjustmentType.increasedQuantity) {
                        if (number == null || number <= widget.item.quantity) {
                          return 'Enter a quantity above ${widget.item.quantity}';
                        }
                        return null;
                      }
                      if (number == null ||
                          number < 0 ||
                          number >= widget.item.quantity) {
                        return 'Enter a quantity below ${widget.item.quantity}';
                      }
                      return null;
                    },
                  ),
                ],
                if (_type == RequirementAdjustmentType.dueDateExtension) ...[
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Extended due date',
                    date: _extendedDate,
                    onChanged: (date) => setState(() => _extendedDate = date),
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _reason,
                  decoration: const InputDecoration(labelText: 'Reason *'),
                  items:
                      const [
                            'Administrator decision',
                            'Financial assistance',
                            'Cash equivalent paid',
                            'Medical or personal circumstance',
                            'Other',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _reason = value!),
                ),
                if (cashEquivalent) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Suggested cash equivalent'),
                        ),
                        Text(
                          _money(
                            widget.item.quantity *
                                widget.item.estimatedUnitPrice,
                          ),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This estimate is guidance only. Record the actual payment through the school payment flow.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _paymentReference,
                    decoration: const InputDecoration(
                      labelText: 'Payment or receipt reference *',
                    ),
                    validator: _required,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes *'),
                  validator: _required,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply adjustment')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudentRequirementAdjustment(
        type: _type,
        reason: _reason,
        notes: _notes.text.trim(),
        adjustedQuantity:
            _type == RequirementAdjustmentType.fullWaiver ||
                _type == RequirementAdjustmentType.dueDateExtension
            ? null
            : int.parse(_quantity.text),
        extendedDueDate: _type == RequirementAdjustmentType.dueDateExtension
            ? _extendedDate
            : null,
        paymentReference: _paymentReference.text.trim().isEmpty
            ? null
            : _paymentReference.text.trim(),
      ),
    );
  }
}

class _StudentCustomRequirementDialog extends StatefulWidget {
  const _StudentCustomRequirementDialog();

  @override
  State<_StudentCustomRequirementDialog> createState() =>
      _StudentCustomRequirementDialogState();
}

class _StudentCustomRequirementDialogState
    extends State<_StudentCustomRequirementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'piece');
  final _notes = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add student-only requirement'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name *'),
                validator: _required,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                      ),
                      validator: (value) =>
                          int.tryParse(value ?? '') == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit *'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'Due date',
                date: _dueDate,
                onChanged: (value) => setState(() => _dueDate = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason or instructions *',
                ),
                validator: _required,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              StudentCustomRequirement(
                id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                name: _name.text.trim(),
                quantity: int.parse(_quantity.text),
                unit: _unit.text.trim(),
                dueDate: _dueDate,
                notes: _notes.text.trim(),
              ),
            );
          },
          child: const Text('Add requirement'),
        ),
      ],
    );
  }
}

class _PublishRequirementsDialog extends StatefulWidget {
  const _PublishRequirementsDialog({
    required this.className,
    required this.changeCount,
  });

  final String className;
  final int changeCount;

  @override
  State<_PublishRequirementsDialog> createState() =>
      _PublishRequirementsDialogState();
}

class _PublishRequirementsDialogState
    extends State<_PublishRequirementsDialog> {
  bool _useDefault = true;
  final Set<String> _methods = {'WhatsApp', 'Email'};
  final _message = TextEditingController(
    text:
        'Your child’s class requirements have been updated. Please review the new checklist and due dates.',
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const methods = [
      'WhatsApp',
      'Email',
      'SMS',
      'Phone call',
      'Physical letter',
    ];
    return AlertDialog(
      title: Text('Publish ${widget.className} requirements'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.changeCount} ${widget.className} draft change${widget.changeCount == 1 ? '' : 's'} will become visible to school staff and guardians. Other classes are not affected.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Guardian notification',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useDefault,
                title: const Text('Use each guardian’s preferred method'),
                subtitle: const Text(
                  'Recommended. The saved WhatsApp, email, SMS or phone preference will be used.',
                ),
                onChanged: (value) => setState(() => _useDefault = value!),
              ),
              if (!_useDefault) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: methods.map((method) {
                    return FilterChip(
                      selected: _methods.contains(method),
                      label: Text(method),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _methods.add(method)
                            : _methods.remove(method);
                      }),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _message,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep as draft'),
        ),
        FilledButton.icon(
          onPressed: (!_useDefault && _methods.isEmpty)
              ? null
              : () => Navigator.pop(
                  context,
                  RequirementNotificationPlan(
                    useDefaultPreference: _useDefault,
                    methods: Set.unmodifiable(_methods),
                    message: _message.text.trim(),
                  ),
                ),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Publish & notify'),
        ),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      },
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData(
    this.label,
    this.value,
    this.caption,
    this.icon,
    this.color,
  );

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.data);

  final _SummaryCardData data;

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
                Expanded(
                  child: Text(
                    data.label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, color: data.color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              data.value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(data.caption, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _RequirementIcon extends StatelessWidget {
  const _RequirementIcon({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final learning = category == 'Learning materials';
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: learning
            ? AppColors.blue.withValues(alpha: .08)
            : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        learning ? Icons.menu_book_outlined : Icons.inventory_2_outlined,
        color: learning ? AppColors.blue : AppColors.green,
        size: 19,
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(_date(date)),
      ),
    );
  }
}

class _RequirementFormResult {
  const _RequirementFormResult({required this.groupId, required this.item});

  final String groupId;
  final ClassRequirementItem item;
}

double _groupCompletion(
  ClassRequirementsRepository repository,
  ClassRequirementGroup group,
) {
  final students = repository.studentsForClass(group.id);
  if (students.isEmpty || group.items.isEmpty) return 0;
  var completed = 0;
  final total = students.length * group.items.length;
  for (final student in students) {
    for (final item in group.items) {
      if (_isComplete(student, item)) completed++;
    }
  }
  return completed / total;
}

bool _isComplete(
  StudentRequirementProgress student,
  ClassRequirementItem item,
) {
  return (student.receivedQuantities[item.id] ?? 0) >=
      _targetQuantity(student, item);
}

int _targetQuantity(
  StudentRequirementProgress student,
  ClassRequirementItem item,
) {
  final adjustment = student.adjustments[item.id];
  if (adjustment == null) return item.quantity;
  return switch (adjustment.type) {
    RequirementAdjustmentType.fullWaiver => 0,
    RequirementAdjustmentType.increasedQuantity ||
    RequirementAdjustmentType.reducedQuantity ||
    RequirementAdjustmentType.partialWaiver =>
      adjustment.adjustedQuantity ?? item.quantity,
    RequirementAdjustmentType.dueDateExtension => item.quantity,
  };
}

String _adjustmentLabel(RequirementAdjustmentType type) {
  return switch (type) {
    RequirementAdjustmentType.increasedQuantity => 'Increased quantity',
    RequirementAdjustmentType.reducedQuantity => 'Reduced quantity',
    RequirementAdjustmentType.partialWaiver => 'Partial waiver',
    RequirementAdjustmentType.fullWaiver => 'Full waiver',
    RequirementAdjustmentType.dueDateExtension => 'Due date extension',
  };
}

String _date(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _money(double amount) {
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return 'GH₵ $formatted';
}

String _singularUnit(String unit) {
  if (unit.endsWith('ies')) return '${unit.substring(0, unit.length - 3)}y';
  if (unit.endsWith('s') && unit.length > 1) {
    return unit.substring(0, unit.length - 1);
  }
  return unit;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'This field is required'
      : null;
}
