import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/class_requirements_repository.dart';
import '../domain/class_requirement_models.dart';
import '../domain/fee_models.dart';
import 'prior_term_requirements_screen.dart';

class ClassRequirementsScreen extends StatefulWidget {
  const ClassRequirementsScreen({
    super.key,
    required this.repository,
    required this.termName,
    this.gradeLevels = const [],
    this.canPublish = true,
    this.currentUserId = 0,
    this.onWorkflowChanged,
  });

  final ClassRequirementsRepository repository;
  final String termName;
  final List<FeeGradeLevel> gradeLevels;
  final bool canPublish;
  final int currentUserId;
  final VoidCallback? onWorkflowChanged;

  @override
  State<ClassRequirementsScreen> createState() =>
      _ClassRequirementsScreenState();
}

class _ClassRequirementsScreenState extends State<ClassRequirementsScreen> {
  String? _selectedGroupId;
  bool _showPriorTerm = false;
  _RequirementsView _requirementsView = _RequirementsView.classes;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        if (widget.repository.isLoading && widget.repository.groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 96),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (widget.repository.errorMessage != null &&
            widget.repository.groups.isEmpty) {
          return _RequirementLoadError(
            message: widget.repository.errorMessage!,
            onRetry: widget.repository.load,
          );
        }
        if (_showPriorTerm) {
          return PriorTermRequirementsScreen(
            repository: widget.repository,
            onBack: () => setState(() => _showPriorTerm = false),
          );
        }
        final selected = _selectedGroupId == null
            ? null
            : widget.repository.groups
                  .where((group) => group.id == _selectedGroupId)
                  .firstOrNull;
        if (selected != null) {
          return _ClassTracker(
            repository: widget.repository,
            group: selected,
            currentUserId: widget.currentUserId,
            onBack: () => setState(() => _selectedGroupId = null),
            onAddRequirement: () => _showRequirementForm(selected.id),
            onEditRequirement: (item) =>
                _showRequirementForm(selected.id, initialItem: item),
            onDeleteRequirement: (item) =>
                _confirmDeleteRequirement(selected, item),
            onPublish: () => _handleWorkflow(selected),
            onOpenStudent: (student) => _showStudentDetails(selected, student),
          );
        }
        return _RequirementsOverview(
          repository: widget.repository,
          termName: widget.termName,
          selectedView: _requirementsView,
          onViewChanged: (value) => setState(() => _requirementsView = value),
          onOpenClass: _openClass,
          onAddClass: _showClassForm,
          onAddStudentRequirement: () => _showStudentRequirementForm(),
          onEditStudentRequirement: (item) =>
              _showStudentRequirementForm(initial: item),
          onDeleteStudentRequirement: _deleteStudentRequirement,
          onSubmitStudentRequirement: _submitStudentRequirement,
          onWithdrawStudentRequirement: _withdrawStudentRequirement,
          onReviewStudentRequirement: _reviewStudentRequirement,
          onOpenPriorTerm: _openPriorTerm,
        );
      },
    );
  }

  Future<void> _openPriorTerm() async {
    try {
      await widget.repository.loadPriorTermRequirements();
      if (mounted) setState(() => _showPriorTerm = true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openClass(ClassRequirementGroup group) async {
    setState(() => _selectedGroupId = group.id);
    try {
      await widget.repository.loadStudentsForClass(group.id);
    } catch (error) {
      if (mounted) setState(() => _selectedGroupId = null);
      _showError(error);
    }
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
    final targetGroup = widget.repository.groups.firstWhere(
      (group) => group.id == result.groupId,
    );
    final revisionReason = await _revisionReasonFor(targetGroup);
    if (targetGroup.status == RequirementStatus.published &&
        revisionReason == null) {
      return;
    }
    if (initialItem == null) {
      try {
        final saved = await widget.repository.addRequirement(
          result.groupId,
          result.item,
          revisionReason: revisionReason,
        );
        _selectedGroupId = saved.id;
      } catch (error) {
        _showError(error);
        return;
      }
    } else {
      try {
        final saved = await widget.repository.updateRequirement(
          result.groupId,
          result.item,
          revisionReason: revisionReason,
        );
        _selectedGroupId = saved.id;
      } catch (error) {
        _showError(error);
        return;
      }
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
    final revisionReason = await _revisionReasonFor(group);
    if (group.status == RequirementStatus.published && revisionReason == null) {
      return;
    }
    try {
      final saved = await widget.repository.deleteRequirement(
        group.id,
        item.id,
        revisionReason: revisionReason,
      );
      _selectedGroupId = saved.id;
    } catch (error) {
      _showError(error);
      return;
    }
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
      builder: (context) => _AddClassDialog(
        existingNames: existingNames,
        gradeLevels: widget.gradeLevels,
      ),
    );
    if (group == null) return;
    try {
      final saved = await widget.repository.addClass(group);
      setState(() => _selectedGroupId = saved.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _revisionReasonFor(ClassRequirementGroup group) async {
    if (group.status != RequirementStatus.published) return null;
    final controller = TextEditingController();
    String? errorText;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Revise published items'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The current published list will remain active. This change creates a new draft that must be approved and published.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Reason for change',
                  hintText: 'Explain why the published list is being revised',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(
                    () => errorText = 'Enter the reason for this revision',
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Create revision draft'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _showPublishDialog(ClassRequirementGroup group) async {
    final plan = await showGeneralDialog<RequirementNotificationPlan>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      barrierLabel: 'Close requirements publication review',
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PublishRequirementsPanel(group: group),
    );
    if (plan == null) return;
    try {
      final published = await widget.repository.publishClass(group.id, plan);
      _selectedGroupId = published.id;
    } catch (error) {
      _showError(error);
      return;
    }
    if (!mounted) return;
    widget.onWorkflowChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${group.className} requirements published and guardian alerts queued.',
        ),
      ),
    );
  }

  Future<void> _handleWorkflow(ClassRequirementGroup group) async {
    try {
      switch (group.status) {
        case RequirementStatus.draft:
          if (!group.creatorOwned) {
            _showError(
              StateError('Only the creator can submit these required items.'),
            );
            return;
          }
          final approvers = await widget.repository.getApprovers();
          if (!mounted) return;
          if (approvers.isEmpty) {
            throw StateError(
              'Add another active Administrator or Headmaster before submitting.',
            );
          }
          var selectedApproverId = 0;
          final note = TextEditingController();
          final submission = await showDialog<_RequirementSubmission>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                icon: const Icon(
                  Icons.approval_outlined,
                  color: AppColors.green,
                  size: 32,
                ),
                title: const Text('Submit for approval'),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose who should review the required items for ${group.className}.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        value: selectedApproverId > 0
                            ? selectedApproverId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Approver',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: approvers
                            .map(
                              (approver) => DropdownMenuItem(
                                value: approver.id,
                                child: Text(
                                  '${approver.name} · ${approver.role}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(
                          () => selectedApproverId = value ?? 0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: note,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Note for approver (optional)',
                          hintText: 'Add context the approver should know',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: selectedApproverId <= 0
                        ? null
                        : () => Navigator.pop(
                            dialogContext,
                            _RequirementSubmission(
                              selectedApproverId,
                              note.text.trim(),
                            ),
                          ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit'),
                  ),
                ],
              ),
            ),
          );
          note.dispose();
          if (submission == null) return;
          final saved = await widget.repository.submitClass(
            group.id,
            submission.approverId,
            note: submission.note,
          );
          _selectedGroupId = saved.id;
          widget.onWorkflowChanged?.call();
          _showMessage('Required items submitted for approval.');
        case RequirementStatus.pendingApproval:
          if (group.assignedApproverId == widget.currentUserId) {
            final action = await showDialog<String>(
              context: context,
              builder: (context) => _RequirementApprovalDialog(group: group),
            );
            if (action == 'approve') {
              final saved = await widget.repository.approveClass(group.id);
              _selectedGroupId = saved.id;
              widget.onWorkflowChanged?.call();
              _showMessage(
                'Required items approved. They are ready to publish.',
              );
            } else if (action == 'reject') {
              final reason = await _askReason();
              if (reason == null) return;
              final saved = await widget.repository.rejectClass(
                group.id,
                reason,
              );
              _selectedGroupId = saved.id;
              widget.onWorkflowChanged?.call();
              _showMessage('Required items returned to Draft.');
            }
          } else if (group.creatorOwned) {
            final saved = await widget.repository.withdrawClass(group.id);
            _selectedGroupId = saved.id;
            widget.onWorkflowChanged?.call();
            _showMessage('Approval request withdrawn.');
          } else {
            _showError(
              StateError('This request is assigned to another approver.'),
            );
          }
        case RequirementStatus.approved:
          await _showPublishDialog(group);
        case RequirementStatus.published:
          return;
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Why are these items being rejected?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) {
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Reason',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(
                    () => errorText = 'Enter a reason before rejecting.',
                  );
                  return;
                }
                Navigator.pop(context, reason);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.green),
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
              .where((item) => item.id == student.id)
              .firstOrNull;
          if (updated == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _StudentRequirementDialog(
            group: group,
            student: updated,
            onAddCustom: () => _addCustomRequirement(updated),
          );
        },
      ),
    );
  }

  Future<void> _addCustomRequirement(StudentRequirementProgress student) async {
    final result = await showDialog<_StudentRequirementFormResult>(
      context: context,
      builder: (context) => _StudentCustomRequirementDialog(
        lockedStudentId: student.id,
        lockedStudentName: student.name,
        lockedClassName: widget.repository.groups
            .where((group) => group.id == student.classGroupId)
            .map((group) => group.className)
            .firstOrNull,
      ),
    );
    if (result == null) return;
    try {
      await widget.repository.addStudentRequirement(
        studentId: student.id,
        requirement: result.requirement,
      );
      widget.onWorkflowChanged?.call();
      _showMessage('Student-specific requirement saved as Draft.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showStudentRequirementForm({
    StudentCustomRequirement? initial,
  }) async {
    final result = await showDialog<_StudentRequirementFormResult>(
      context: context,
      builder: (context) => _StudentCustomRequirementDialog(
        candidates: widget.repository.studentCandidates,
        initialRequirement: initial,
      ),
    );
    if (result == null) return;
    try {
      if (initial == null) {
        await widget.repository.addStudentRequirement(
          studentId: result.studentId,
          requirement: result.requirement,
        );
      } else {
        await widget.repository.updateStudentRequirement(result.requirement);
      }
      widget.onWorkflowChanged?.call();
      _showMessage(
        initial == null
            ? 'Student-specific requirement saved as Draft.'
            : 'Student-specific requirement updated.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteStudentRequirement(
    StudentCustomRequirement requirement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student-specific requirement?'),
        content: Text(
          'Remove ${requirement.name} from ${requirement.studentName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteStudentRequirement(requirement.id);
      widget.onWorkflowChanged?.call();
      _showMessage('Student-specific requirement removed.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _submitStudentRequirement(
    StudentCustomRequirement requirement,
  ) async {
    try {
      final approvers = await widget.repository
          .getStudentRequirementApprovers();
      if (!mounted) return;
      if (approvers.isEmpty) {
        throw StateError(
          'Add another active Administrator or Headmaster before submitting.',
        );
      }
      final submission = await showDialog<_RequirementSubmission>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _StudentRequirementSubmissionDialog(
          requirement: requirement,
          approvers: approvers,
        ),
      );
      if (submission == null) return;
      await widget.repository.submitStudentRequirement(
        requirement.id,
        submission.approverId,
        note: submission.note,
      );
      widget.onWorkflowChanged?.call();
      _showMessage('Student-specific requirement submitted for approval.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _withdrawStudentRequirement(
    StudentCustomRequirement requirement,
  ) async {
    try {
      await widget.repository.withdrawStudentRequirement(requirement.id);
      widget.onWorkflowChanged?.call();
      _showMessage('Approval request withdrawn. The item is now Draft.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reviewStudentRequirement(
    StudentCustomRequirement requirement,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) =>
          _StudentRequirementReviewDialog(requirement: requirement),
    );
    if (action == null) return;
    try {
      if (action == 'approve') {
        await widget.repository.approveStudentRequirement(requirement.id);
        widget.onWorkflowChanged?.call();
        _showMessage(
          'Requirement approved and made visible on the student record.',
        );
      } else if (action == 'reject') {
        final reason = await _askReason();
        if (reason == null) return;
        await widget.repository.rejectStudentRequirement(
          requirement.id,
          reason,
        );
        widget.onWorkflowChanged?.call();
        _showMessage('Requirement returned for changes.');
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
    );
  }
}

enum _RequirementsView { classes, students }

class _RequirementSubmission {
  const _RequirementSubmission(this.approverId, this.note);
  final int approverId;
  final String note;
}

class _RequirementLoadError extends StatelessWidget {
  const _RequirementLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.red,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load items & supplies',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementsOverview extends StatelessWidget {
  const _RequirementsOverview({
    required this.repository,
    required this.termName,
    required this.selectedView,
    required this.onViewChanged,
    required this.onOpenClass,
    required this.onAddClass,
    required this.onAddStudentRequirement,
    required this.onEditStudentRequirement,
    required this.onDeleteStudentRequirement,
    required this.onSubmitStudentRequirement,
    required this.onWithdrawStudentRequirement,
    required this.onReviewStudentRequirement,
    required this.onOpenPriorTerm,
  });

  final ClassRequirementsRepository repository;
  final String termName;
  final _RequirementsView selectedView;
  final ValueChanged<_RequirementsView> onViewChanged;
  final ValueChanged<ClassRequirementGroup> onOpenClass;
  final VoidCallback onAddClass;
  final VoidCallback onAddStudentRequirement;
  final ValueChanged<StudentCustomRequirement> onEditStudentRequirement;
  final ValueChanged<StudentCustomRequirement> onDeleteStudentRequirement;
  final ValueChanged<StudentCustomRequirement> onSubmitStudentRequirement;
  final ValueChanged<StudentCustomRequirement> onWithdrawStudentRequirement;
  final ValueChanged<StudentCustomRequirement> onReviewStudentRequirement;
  final VoidCallback onOpenPriorTerm;

  @override
  Widget build(BuildContext context) {
    final groups = repository.groups;
    final totalStudents = groups.fold<int>(0, (sum, g) => sum + g.studentCount);
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    final completionSummary = repository.completionSummary;
    final completion = completionSummary.completionPercentage.round();
    final updatedItems = groups.fold<int>(
      0,
      (sum, g) =>
          sum + g.items.where((item) => item.updatedSincePublished).length,
    );
    final priorTerm = repository.priorTermRequirements
        .where((item) => item.status == PriorTermRequirementStatus.pending)
        .toList();
    final priorStudents = priorTerm
        .map((item) => item.studentId)
        .toSet()
        .length;
    final priorUnits = priorTerm.fold<int>(
      0,
      (sum, item) => sum + item.remainingQuantity,
    );
    final priorValue = priorTerm.fold<double>(
      0,
      (sum, item) => sum + item.estimatedOutstandingValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          title: 'Items & Supplies',
          subtitle:
              '$termName · Manage class-wide and student-specific requirements.',
          actions: [
            FilledButton.icon(
              onPressed: selectedView == _RequirementsView.classes
                  ? onAddClass
                  : onAddStudentRequirement,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                selectedView == _RequirementsView.classes
                    ? 'Add class'
                    : 'Add student requirement',
              ),
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
                completionSummary.activeObligations == 0
                    ? 'No active published student items'
                    : '${completionSummary.completedObligations} of ${completionSummary.activeObligations} fully resolved · partial receipts included',
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
        _PriorTermBanner(
          studentCount: priorStudents,
          itemCount: priorTerm.length,
          unitCount: priorUnits,
          estimatedValue: priorValue,
          onOpen: onOpenPriorTerm,
        ),
        const SizedBox(height: 24),
        _RequirementViewTabs(
          selected: selectedView,
          classActionCount: repository.unpublishedClassRequirementCount,
          studentActionCount: repository.unpublishedStudentRequirementCount,
          onChanged: onViewChanged,
        ),
        const SizedBox(height: 18),
        if (selectedView == _RequirementsView.classes)
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
          )
        else
          _StudentSpecificRequirementsPanel(
            requirements: repository.studentSpecificRequirements,
            onAdd: onAddStudentRequirement,
            onEdit: onEditStudentRequirement,
            onDelete: onDeleteStudentRequirement,
            onSubmit: onSubmitStudentRequirement,
            onWithdraw: onWithdrawStudentRequirement,
            onReview: onReviewStudentRequirement,
          ),
      ],
    );
  }
}

class _RequirementViewTabs extends StatelessWidget {
  const _RequirementViewTabs({
    required this.selected,
    required this.classActionCount,
    required this.studentActionCount,
    required this.onChanged,
  });

  final _RequirementsView selected;
  final int classActionCount;
  final int studentActionCount;
  final ValueChanged<_RequirementsView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final tabs = [
            _RequirementTabButton(
              label: 'Class requirements',
              icon: Icons.groups_2_outlined,
              count: classActionCount,
              selected: selected == _RequirementsView.classes,
              onTap: () => onChanged(_RequirementsView.classes),
            ),
            _RequirementTabButton(
              label: 'Student-specific requirements',
              icon: Icons.person_outline_rounded,
              count: studentActionCount,
              selected: selected == _RequirementsView.students,
              onTap: () => onChanged(_RequirementsView.students),
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tabs,
            );
          }
          return Row(
            children: tabs.map((tab) => Expanded(child: tab)).toList(),
          );
        },
      ),
    );
  }
}

class _RequirementTabButton extends StatelessWidget {
  const _RequirementTabButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: selected ? AppColors.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('requirements-tab-${label.toLowerCase()}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: selected ? AppColors.green : AppColors.text,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 9),
                  Tooltip(
                    message: '$count not published',
                    child: Container(
                      key: Key('requirements-unpublished-$label'),
                      constraints: const BoxConstraints(minWidth: 25),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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

class _StudentSpecificRequirementsPanel extends StatefulWidget {
  const _StudentSpecificRequirementsPanel({
    required this.requirements,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmit,
    required this.onWithdraw,
    required this.onReview,
  });

  final List<StudentCustomRequirement> requirements;
  final VoidCallback onAdd;
  final ValueChanged<StudentCustomRequirement> onEdit;
  final ValueChanged<StudentCustomRequirement> onDelete;
  final ValueChanged<StudentCustomRequirement> onSubmit;
  final ValueChanged<StudentCustomRequirement> onWithdraw;
  final ValueChanged<StudentCustomRequirement> onReview;

  @override
  State<_StudentSpecificRequirementsPanel> createState() =>
      _StudentSpecificRequirementsPanelState();
}

class _StudentSpecificRequirementsPanelState
    extends State<_StudentSpecificRequirementsPanel> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  StudentSpecificRequirementStatus? _status;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StudentCustomRequirement> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final values = widget.requirements.where((item) {
      final matchesStatus = _status == null || item.status == _status;
      final matchesQuery =
          query.isEmpty ||
          item.studentName.toLowerCase().contains(query) ||
          item.name.toLowerCase().contains(query) ||
          item.className.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
    values.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? a.dueDate;
      final bDate = b.updatedAt ?? b.createdAt ?? b.dueDate;
      return bDate.compareTo(aDate);
    });
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: _search,
              onChanged: (_) => setState(() => _page = 0),
              decoration: const InputDecoration(
                hintText: 'Search student, class or item',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final status =
                DropdownButtonFormField<StudentSpecificRequirementStatus?>(
                  value: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...StudentSpecificRequirementStatus.values.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_studentRequirementStatusLabel(value)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 0;
                  }),
                );
            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 12), status],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: status),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          _StudentRequirementsEmptyState(onAdd: widget.onAdd)
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 850
                ? Column(
                    children: visible
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StudentRequirementCard(
                              requirement: item,
                              onAction: (action) => _handleAction(item, action),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : _StudentRequirementTable(
                    requirements: visible,
                    onAction: _handleAction,
                  ),
          ),
        if (filtered.length > _pageSize) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${start + 1}–${start + visible.length} of ${filtered.length}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Previous page',
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Next page',
                onPressed: _page + 1 >= pageCount
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _handleAction(StudentCustomRequirement item, String action) {
    switch (action) {
      case 'edit':
        widget.onEdit(item);
      case 'delete':
        widget.onDelete(item);
      case 'submit':
        widget.onSubmit(item);
      case 'withdraw':
        widget.onWithdraw(item);
      case 'review':
      case 'view':
        widget.onReview(item);
    }
  }
}

class _StudentRequirementsEmptyState extends StatelessWidget {
  const _StudentRequirementsEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_add_alt_1_outlined,
            size: 38,
            color: AppColors.green,
          ),
          const SizedBox(height: 12),
          const Text(
            'No student-specific requirements',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add an item needed by one student only.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add student requirement'),
          ),
        ],
      ),
    );
  }
}

class _StudentRequirementTable extends StatelessWidget {
  const _StudentRequirementTable({
    required this.requirements,
    required this.onAction,
  });

  final List<StudentCustomRequirement> requirements;
  final void Function(StudentCustomRequirement, String) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _StudentRequirementTableRow(header: true),
          ...requirements.map(
            (item) => _StudentRequirementTableRow(
              requirement: item,
              onAction: (action) => onAction(item, action),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRequirementTableRow extends StatelessWidget {
  const _StudentRequirementTableRow({
    this.requirement,
    this.onAction,
    this.header = false,
  });

  final StudentCustomRequirement? requirement;
  final ValueChanged<String>? onAction;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final item = requirement;
    final style = TextStyle(
      color: header ? AppColors.muted : AppColors.text,
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w800 : FontWeight.w600,
    );
    Widget cell(String value, int flex, {Widget? child}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child:
            child ?? Text(value, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
    return Container(
      constraints: BoxConstraints(minHeight: header ? 46 : 66),
      decoration: BoxDecoration(
        color: header ? AppColors.background : Colors.white,
        border: header
            ? null
            : const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          cell(
            header ? 'STUDENT' : item!.studentName,
            22,
            child: header
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item!.studentName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.className,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
          cell(header ? 'ITEM' : item!.name, 22),
          cell(
            header ? 'QUANTITY' : '${item!.quantity} ${item.unit}',
            14,
            child: header
                ? null
                : Text(
                    '${item!.quantity} ${item.unit}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          cell(header ? 'DUE DATE' : _date(item!.dueDate), 15),
          cell(
            header ? 'STATUS' : '',
            17,
            child: header ? null : _StudentRequirementStatusChip(item!.status),
          ),
          cell(
            header ? 'ACTIONS' : '',
            10,
            child: header
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: _StudentRequirementActions(
                      requirement: item!,
                      onAction: onAction!,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentRequirementCard extends StatelessWidget {
  const _StudentRequirementCard({
    required this.requirement,
    required this.onAction,
  });
  final StudentCustomRequirement requirement;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${requirement.name} · ${requirement.quantity} ${requirement.unit}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                _StudentRequirementStatusChip(requirement.status),
              ],
            ),
          ),
          _StudentRequirementActions(
            requirement: requirement,
            onAction: onAction,
          ),
        ],
      ),
    );
  }
}

class _StudentRequirementActions extends StatelessWidget {
  const _StudentRequirementActions({
    required this.requirement,
    required this.onAction,
  });
  final StudentCustomRequirement requirement;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = <PopupMenuEntry<String>>[];
    final editable =
        requirement.creatorOwned &&
        (requirement.status == StudentSpecificRequirementStatus.draft ||
            requirement.status ==
                StudentSpecificRequirementStatus.changesRequested);
    if (editable) {
      actions.addAll(const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'submit', child: Text('Submit for approval')),
        PopupMenuItem(value: 'delete', child: Text('Remove')),
      ]);
    } else if (requirement.canApprove &&
        requirement.status ==
            StudentSpecificRequirementStatus.pendingApproval) {
      actions.add(
        const PopupMenuItem(value: 'review', child: Text('Review request')),
      );
    } else if (requirement.canWithdraw) {
      actions.add(
        const PopupMenuItem(
          value: 'withdraw',
          child: Text('Withdraw approval request'),
        ),
      );
    } else if (requirement.status == StudentSpecificRequirementStatus.active &&
        requirement.receivedQuantity < requirement.quantity) {
      actions.add(
        const PopupMenuItem(value: 'view', child: Text('View details')),
      );
    } else {
      actions.add(
        const PopupMenuItem(value: 'view', child: Text('View details')),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: onAction,
      itemBuilder: (context) => actions,
      icon: const Icon(Icons.more_horiz_rounded),
    );
  }
}

class _StudentRequirementStatusChip extends StatelessWidget {
  const _StudentRequirementStatusChip(this.status);
  final StudentSpecificRequirementStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      StudentSpecificRequirementStatus.active => (
        AppColors.green,
        AppColors.greenSoft,
      ),
      StudentSpecificRequirementStatus.pendingApproval => (
        AppColors.amber,
        AppColors.amber.withValues(alpha: .12),
      ),
      StudentSpecificRequirementStatus.changesRequested => (
        AppColors.red,
        AppColors.red.withValues(alpha: .09),
      ),
      StudentSpecificRequirementStatus.draft => (
        AppColors.blue,
        AppColors.blue.withValues(alpha: .09),
      ),
      StudentSpecificRequirementStatus.inactive => (
        AppColors.muted,
        AppColors.background,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _studentRequirementStatusLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PriorTermBanner extends StatelessWidget {
  const _PriorTermBanner({
    required this.studentCount,
    required this.itemCount,
    required this.unitCount,
    required this.estimatedValue,
    required this.onOpen,
  });

  final int studentCount;
  final int itemCount;
  final int unitCount;
  final double estimatedValue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final clear = itemCount == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: clear
            ? AppColors.greenSoft
            : AppColors.amber.withValues(alpha: .08),
        border: Border.all(
          color: clear
              ? AppColors.green.withValues(alpha: .24)
              : AppColors.amber.withValues(alpha: .32),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final icon = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              clear ? Icons.task_alt_rounded : Icons.history_rounded,
              color: clear ? AppColors.green : AppColors.amber,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clear
                    ? 'Prior-term requirements are clear'
                    : 'Prior-term outstanding requirements',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                clear
                    ? 'There are no unresolved physical items from completed terms.'
                    : '$studentCount students · $itemCount item types · $unitCount units outstanding · ${_money(estimatedValue)} estimated value',
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          );
          final button = OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(clear ? 'View history' : 'Review outstanding items'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 16),
                button,
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: copy),
              const SizedBox(width: 18),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _RequirementApprovalDialog extends StatelessWidget {
  const _RequirementApprovalDialog({required this.group});

  final ClassRequirementGroup group;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review required items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${group.className} · ${group.items.length} item${group.items.length == 1 ? '' : 's'}',
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
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: group.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = group.items[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 92,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${item.quantity}',
                                key: Key('approval-quantity-${item.id}'),
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.unit,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${item.category} · Due ${_date(item.dueDate)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              if (item.instructions.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  item.instructions,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Estimated price: ${_money(item.estimatedUnitPrice)} per ${_singularUnit(item.unit)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('reject-requirement-list'),
                    onPressed: () => Navigator.pop(context, 'reject'),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const Key('approve-requirement-list'),
                    onPressed: () => Navigator.pop(context, 'approve'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve items'),
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

class _ApprovedRequirementsBanner extends StatelessWidget {
  const _ApprovedRequirementsBanner({required this.canPublish});

  final bool canPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: .38)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.publish_rounded,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Approved — publication required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canPublish
                          ? 'Next step: publish these items so they appear in student records, reports and guardian portals.'
                          : 'These items are approved but still hidden. The creator must publish them before they appear in student records, reports and guardian portals.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          return content;
        },
      ),
    );
  }
}

class _UnpublishedRequirementChangesBanner extends StatelessWidget {
  const _UnpublishedRequirementChangesBanner({
    required this.group,
    required this.changeCount,
  });

  final ClassRequirementGroup group;
  final int changeCount;

  @override
  Widget build(BuildContext context) {
    final pending = group.status == RequirementStatus.pendingApproval;
    final count = changeCount;
    final changeLabel = '$count ${count == 1 ? 'change' : 'changes'}';
    final approver = group.assignedApproverName.trim();
    return Container(
      key: const Key('unpublished-requirement-changes-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (pending ? AppColors.blue : AppColors.amber).withValues(
          alpha: .09,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (pending ? AppColors.blue : AppColors.amber).withValues(
            alpha: .38,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              pending
                  ? Icons.hourglass_top_rounded
                  : Icons.notification_important_outlined,
              color: pending ? AppColors.blue : AppColors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? 'Changes submitted — awaiting approval'
                      : 'New or changed items are not active',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pending
                      ? '$changeLabel ${count == 1 ? 'is' : 'are'} waiting${approver.isEmpty ? '' : ' for $approver'} to approve. The previously published list remains active until this revision is approved and published.'
                      : '$changeLabel ${count == 1 ? 'is' : 'are'} saved as Draft and ${count == 1 ? 'has' : 'have'} not been submitted or approved. Submit the revised list for approval. The previously published list remains active for students and guardians.',
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassTracker extends StatelessWidget {
  const _ClassTracker({
    required this.repository,
    required this.group,
    required this.currentUserId,
    required this.onBack,
    required this.onAddRequirement,
    required this.onEditRequirement,
    required this.onDeleteRequirement,
    required this.onPublish,
    required this.onOpenStudent,
  });

  final ClassRequirementsRepository repository;
  final ClassRequirementGroup group;
  final int currentUserId;
  final VoidCallback onBack;
  final VoidCallback onAddRequirement;
  final ValueChanged<ClassRequirementItem> onEditRequirement;
  final ValueChanged<ClassRequirementItem> onDeleteRequirement;
  final VoidCallback? onPublish;
  final ValueChanged<StudentRequirementProgress> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final students = repository.studentsForClass(group.id);
    final hasItems = group.items.isNotEmpty;
    final publishedItems = _publishedRequirementItems(group);
    final changes = _requirementChanges(group);
    final visibleDraftChanges = group.draftChangeCount > 0
        ? group.draftChangeCount
        : group.items.where((item) => item.updatedSincePublished).length;
    final canEdit =
        group.status == RequirementStatus.published ||
        (group.status == RequirementStatus.approved && group.creatorOwned) ||
        (group.status == RequirementStatus.draft && group.creatorOwned);
    final canUseWorkflow = switch (group.status) {
      RequirementStatus.draft => group.creatorOwned,
      RequirementStatus.pendingApproval =>
        group.creatorOwned || group.assignedApproverId == currentUserId,
      RequirementStatus.approved => group.creatorOwned,
      RequirementStatus.published => false,
    };
    final workflowAction = group.status == RequirementStatus.published
        ? null
        : FilledButton.icon(
            key: group.status == RequirementStatus.approved
                ? const Key('publish-approved-requirements')
                : const Key('requirements-workflow-action'),
            onPressed: !hasItems || !canUseWorkflow ? null : onPublish,
            icon: Icon(
              group.status == RequirementStatus.approved
                  ? Icons.publish_rounded
                  : Icons.campaign_outlined,
            ),
            label: Text(
              !hasItems
                  ? 'Add items first'
                  : switch (group.status) {
                      RequirementStatus.draft => 'Submit for approval',
                      RequirementStatus.pendingApproval =>
                        group.creatorOwned
                            ? 'Withdraw approval request'
                            : group.assignedApproverId == currentUserId
                            ? 'Review approval'
                            : 'Pending · ${group.assignedApproverName}',
                      RequirementStatus.approved => 'Publish items',
                      RequirementStatus.published => 'Published',
                    },
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to items & supplies'),
        ),
        const SizedBox(height: 8),
        _PageHeading(
          title: '${group.className} requirements',
          subtitle:
              '${group.items.length} items · ${group.studentCount} students · ${(100 * _groupCompletion(repository, group)).round()}% complete',
          actions: [
            if (canEdit)
              OutlinedButton.icon(
                onPressed: onAddRequirement,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add class item'),
              ),
            if (!canEdit && group.status == RequirementStatus.draft)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: _SmallPill(
                  label: 'Awaiting creator',
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        if (group.hasPublishedVersion &&
            visibleDraftChanges > 0 &&
            (group.status == RequirementStatus.draft ||
                group.status == RequirementStatus.pendingApproval)) ...[
          const SizedBox(height: 14),
          _UnpublishedRequirementChangesBanner(
            group: group,
            changeCount: visibleDraftChanges,
          ),
        ],
        if (group.status == RequirementStatus.approved) ...[
          const SizedBox(height: 14),
          _ApprovedRequirementsBanner(canPublish: canUseWorkflow),
        ],
        if (group.status == RequirementStatus.draft &&
            group.rejectionReason.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red.withValues(alpha: .3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Returned for changes: ${group.rejectionReason}',
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (!hasItems) ...[
          _EmptyClassSetup(onAddRequirement: canEdit ? onAddRequirement : null),
          const SizedBox(height: 20),
        ],
        if (publishedItems.isNotEmpty) ...[
          _ClassChecklistTable(
            key: const Key('published-requirements-section'),
            title: 'Currently published',
            subtitle:
                'This published list is visible to parents, students and reports.',
            items: publishedItems,
            isRevision: false,
            status: RequirementStatus.published,
            onEdit: group.status == RequirementStatus.published && canEdit
                ? onEditRequirement
                : null,
            onDelete: group.status == RequirementStatus.published && canEdit
                ? onDeleteRequirement
                : null,
          ),
          if (group.status != RequirementStatus.published)
            const SizedBox(height: 16),
        ],
        if (group.status != RequirementStatus.published ||
            publishedItems.isEmpty)
          _ClassChecklistTable(
            key: const Key('working-requirements-section'),
            title: group.hasPublishedVersion
                ? 'Changes in progress'
                : group.status == RequirementStatus.draft
                ? 'Draft items'
                : 'Items in this request',
            subtitle: group.hasPublishedVersion
                ? 'Only these proposed changes are awaiting completion of the workflow.'
                : 'These items are not visible to parents until they are approved and published.',
            items: group.hasPublishedVersion ? changes : group.items,
            isRevision: group.hasPublishedVersion,
            status: group.status,
            onEdit: canEdit ? onEditRequirement : null,
            onDelete: canEdit ? onDeleteRequirement : null,
            headerAction: workflowAction,
            emptyMessage: group.hasPublishedVersion
                ? 'No differences from the currently published list.'
                : 'No class items have been added yet.',
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
              if (repository.isLoading && students.isEmpty)
                const SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (students.isEmpty)
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
                          group.status == RequirementStatus.draft && hasItems
                              ? 'Student tracking begins after this checklist is published.'
                              : hasItems
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

List<ClassRequirementItem> _publishedRequirementItems(
  ClassRequirementGroup group,
) {
  if (!group.hasPublishedVersion) return const [];
  if (group.publishedItems.isNotEmpty) return group.publishedItems;
  if (group.status == RequirementStatus.published) return group.items;
  return group.items
      .where((item) => !item.updatedSincePublished)
      .toList(growable: false);
}

List<ClassRequirementItem> _requirementChanges(ClassRequirementGroup group) {
  if (!group.hasPublishedVersion) return group.items;
  final published = _publishedRequirementItems(group);
  final publishedByKey = {for (final item in published) item.identityKey: item};
  final workingKeys = group.items.map((item) => item.identityKey).toSet();
  final changes = <ClassRequirementItem>[
    ...group.items.where((item) {
      final previous = publishedByKey[item.identityKey];
      return item.updatedSincePublished ||
          previous == null ||
          !_sameRequirementItem(item, previous);
    }),
    ...published
        .where((item) => !workingKeys.contains(item.identityKey))
        .map(
          (item) => item.copyWith(
            updatedSincePublished: true,
            changeType: RequirementItemChange.removed,
          ),
        ),
  ];
  return changes;
}

bool _sameRequirementItem(
  ClassRequirementItem current,
  ClassRequirementItem previous,
) =>
    current.name == previous.name &&
    current.category == previous.category &&
    current.quantity == previous.quantity &&
    current.unit == previous.unit &&
    current.estimatedUnitPrice == previous.estimatedUnitPrice &&
    _date(current.dueDate) == _date(previous.dueDate) &&
    current.instructions == previous.instructions &&
    current.isOptional == previous.isOptional;

enum _RequirementPublicationKind { newItem, modified, same, removed }

class _RequirementPublicationItem {
  const _RequirementPublicationItem({
    required this.item,
    required this.kind,
    this.previous,
  });

  final ClassRequirementItem item;
  final ClassRequirementItem? previous;
  final _RequirementPublicationKind kind;
}

List<_RequirementPublicationItem> _publicationReviewItems(
  ClassRequirementGroup group,
) {
  final published = _publishedRequirementItems(group);
  final publishedByKey = {for (final item in published) item.identityKey: item};
  final workingKeys = group.items.map((item) => item.identityKey).toSet();

  return [
    ...group.items.map((item) {
      final previous = publishedByKey[item.identityKey];
      final kind = previous == null
          ? _RequirementPublicationKind.newItem
          : _sameRequirementItem(item, previous)
          ? _RequirementPublicationKind.same
          : _RequirementPublicationKind.modified;
      return _RequirementPublicationItem(
        item: item,
        previous: previous,
        kind: kind,
      );
    }),
    ...published
        .where((item) => !workingKeys.contains(item.identityKey))
        .map(
          (item) => _RequirementPublicationItem(
            item: item,
            previous: item,
            kind: _RequirementPublicationKind.removed,
          ),
        ),
  ];
}

class _ClassChecklistTable extends StatelessWidget {
  const _ClassChecklistTable({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.isRevision,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    this.headerAction,
    this.emptyMessage = 'No class items have been added yet.',
  });

  final String title;
  final String subtitle;
  final List<ClassRequirementItem> items;
  final bool isRevision;
  final RequirementStatus status;
  final ValueChanged<ClassRequirementItem>? onEdit;
  final ValueChanged<ClassRequirementItem>? onDelete;
  final Widget? headerAction;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                  if (headerAction == null) return details;
                  if (constraints.maxWidth < 700) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: headerAction!,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 16),
                      headerAction!,
                    ],
                  );
                },
              ),
            ),
            if (items.isEmpty)
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(color: AppColors.muted),
                  ),
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
                              isRevision: isRevision,
                              status: status,
                              onEdit:
                                  onEdit == null ||
                                      item.changeType ==
                                          RequirementItemChange.removed
                                  ? null
                                  : () => onEdit!(item),
                              onDelete:
                                  onDelete == null ||
                                      item.changeType ==
                                          RequirementItemChange.removed
                                  ? null
                                  : () => onDelete!(item),
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
          _TableHeading('Item', flex: 30),
          _TableHeading('Required quantity', flex: 20),
          _TableHeading('Category', flex: 16),
          _TableHeading('Due date', flex: 16),
          _TableHeading('Estimated price', flex: 14),
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
    required this.isRevision,
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassRequirementItem item;
  final bool isRevision;
  final RequirementStatus status;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isAdded =
        isRevision &&
        item.updatedSincePublished &&
        item.changeType == RequirementItemChange.added;
    final isRemoved =
        isRevision && item.changeType == RequirementItemChange.removed;
    final isModified =
        isRevision && item.changeType == RequirementItemChange.modified;
    final lifecycleText = _publishedItemAuditText(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isRemoved
            ? AppColors.red.withValues(alpha: .045)
            : isAdded
            ? AppColors.blue.withValues(alpha: .055)
            : isModified
            ? AppColors.amber.withValues(alpha: .045)
            : null,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 30,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          decoration: isRemoved
                              ? TextDecoration.lineThrough
                              : null,
                        ),
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
                      if (lifecycleText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lifecycleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted.withValues(alpha: .85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 20,
            child: Row(
              children: [
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.unit,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _TableValue(item.category, flex: 16),
          _TableValue(_date(item.dueDate), flex: 16),
          _TableValue(
            '${_money(item.estimatedUnitPrice)} / ${_singularUnit(item.unit)}',
            flex: 14,
            color: AppColors.muted,
          ),
          Expanded(
            flex: 14,
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                if (item.updatedSincePublished && isRevision)
                  _SmallPill(
                    label: isRemoved
                        ? 'Removing'
                        : isAdded
                        ? 'New item'
                        : 'Modified',
                    color: isRemoved
                        ? AppColors.red
                        : isAdded
                        ? AppColors.blue
                        : AppColors.amber,
                  ),
                if (item.isOptional)
                  const _SmallPill(label: 'Optional', color: AppColors.blue),
                if (!item.updatedSincePublished || !isRevision)
                  _SmallPill(
                    label: isRevision
                        ? 'Current'
                        : switch (status) {
                            RequirementStatus.draft => 'Draft',
                            RequirementStatus.pendingApproval =>
                              'Pending approval',
                            RequirementStatus.approved => 'Approved',
                            RequirementStatus.published => 'Published',
                          },
                    color: isRevision
                        ? AppColors.green
                        : switch (status) {
                            RequirementStatus.draft => AppColors.muted,
                            RequirementStatus.pendingApproval =>
                              AppColors.amber,
                            RequirementStatus.approved => AppColors.blue,
                            RequirementStatus.published => AppColors.green,
                          },
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: onEdit == null && onDelete == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          onPressed: onEdit,
                          tooltip: 'Edit requirement',
                          icon: const Icon(Icons.edit_outlined),
                          color: AppColors.green,
                        ),
                      if (onDelete != null)
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
  const _TableValue(this.value, {required this.flex, this.color});

  final String value;
  final int flex;
  final Color? color;

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
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
                    label: switch (group.status) {
                      RequirementStatus.published => 'Published',
                      RequirementStatus.approved => 'Approved',
                      RequirementStatus.pendingApproval => 'Pending approval',
                      RequirementStatus.draft =>
                        group.hasPublishedVersion ? 'Modified draft' : 'Draft',
                    },
                    color: switch (group.status) {
                      RequirementStatus.published => AppColors.green,
                      RequirementStatus.approved => AppColors.blue,
                      RequirementStatus.pendingApproval => AppColors.amber,
                      RequirementStatus.draft => AppColors.muted,
                    },
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
                            width: 154,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Est. ${_money(item.estimatedUnitPrice)} / ${_singularUnit(item.unit)}',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (group.items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 3),
                  child: Row(
                    children: [
                      const SizedBox(width: 25),
                      Text(
                        '+ ${group.items.length - 3} more item${group.items.length - 3 == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.green,
                      ),
                    ],
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

  final VoidCallback? onAddRequirement;

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
    required this.onAddCustom,
  });

  final ClassRequirementGroup group;
  final StudentRequirementProgress student;
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
  });

  final ClassRequirementItem item;
  final StudentRequirementProgress student;

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
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Manage delivery and exemptions from the student profile.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddClassDialog extends StatefulWidget {
  const _AddClassDialog({
    required this.existingNames,
    required this.gradeLevels,
  });

  final Set<String> existingNames;
  final List<FeeGradeLevel> gradeLevels;

  @override
  State<_AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<_AddClassDialog> {
  FeeGradeLevel? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final available = widget.gradeLevels
        .where((grade) => !widget.existingNames.contains(grade.name))
        .toList();
    return AlertDialog(
      title: const Text('Set up items & supplies'),
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
              DropdownButtonFormField<FeeGradeLevel>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  labelText: 'Class *',
                  hintText: 'Select class',
                ),
                items: available
                    .map(
                      (grade) => DropdownMenuItem(
                        value: grade,
                        child: Text(grade.name),
                      ),
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
                  final grade = _selectedClass!;
                  Navigator.pop(
                    context,
                    ClassRequirementGroup(
                      id: 'new-${grade.id}',
                      className: grade.name,
                      gradeLevelId: grade.id,
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

  static const _commonItemCategories = {
    'Toilet rolls': 'Hygiene',
    'Box of tissues': 'Hygiene',
    'Liquid soap': 'Hygiene',
    'Disinfectant': 'Hygiene',
    'Exercise books': 'Learning materials',
    'HB pencils': 'Learning materials',
    'Pens': 'Learning materials',
  };

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
                          onPressed: () => setState(() {
                            _name.text = item;
                            _category =
                                _commonItemCategories[item] ?? _category;
                          }),
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
    final cashEquivalent = _type == RequirementAdjustmentType.cashEquivalent;
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
                  onChanged: (value) => setState(() {
                    _type = value!;
                    if (_type == RequirementAdjustmentType.cashEquivalent) {
                      _reason = 'Cash equivalent paid';
                    } else if (_reason == 'Cash equivalent paid') {
                      _reason = 'Administrator decision';
                    }
                  }),
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
                _type == RequirementAdjustmentType.dueDateExtension ||
                _type == RequirementAdjustmentType.cashEquivalent
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

class _StudentRequirementFormResult {
  const _StudentRequirementFormResult({
    required this.studentId,
    required this.requirement,
  });

  final String studentId;
  final StudentCustomRequirement requirement;
}

class _StudentCustomRequirementDialog extends StatefulWidget {
  const _StudentCustomRequirementDialog({
    this.candidates = const [],
    this.initialRequirement,
    this.lockedStudentId = '',
    this.lockedStudentName,
    this.lockedClassName,
  });

  final List<StudentRequirementCandidate> candidates;
  final StudentCustomRequirement? initialRequirement;
  final String lockedStudentId;
  final String? lockedStudentName;
  final String? lockedClassName;

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
  final _unitPrice = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _dueDate;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRequirement;
    _studentId = initial?.studentId.isNotEmpty == true
        ? initial!.studentId
        : widget.lockedStudentId.isNotEmpty
        ? widget.lockedStudentId
        : null;
    _name.text = initial?.name ?? '';
    _quantity.text = '${initial?.quantity ?? 1}';
    _unit.text = initial?.unit ?? 'piece';
    _unitPrice.text = initial == null || initial.estimatedUnitPrice == 0
        ? ''
        : '${initial.estimatedUnitPrice}';
    _notes.text = initial?.notes ?? '';
    _dueDate = initial?.dueDate ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _unitPrice.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialRequirement == null
            ? 'Add student-specific requirement'
            : 'Edit student-specific requirement',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.lockedStudentId.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lockedStudentName ?? 'Selected student',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (widget.lockedClassName?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.lockedClassName!,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _studentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Student *',
                      hintText: 'Select a student',
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                    items: widget.candidates
                        .map(
                          (student) => DropdownMenuItem(
                            value: student.studentId,
                            child: Text(
                              '${student.studentName} · ${student.className}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: widget.initialRequirement == null
                        ? (value) => setState(() => _studentId = value)
                        : null,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Select a student'
                        : null,
                  ),
                const SizedBox(height: 16),
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
                        validator: (value) => int.tryParse(value ?? '') == null
                            ? 'Required'
                            : null,
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
                TextFormField(
                  controller: _unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Suggested unit price (optional)',
                    prefixText: 'GH₵ ',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    final amount = double.tryParse(value!.trim());
                    return amount == null || amount < 0
                        ? 'Enter a valid amount'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: 'Due date *',
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
              _StudentRequirementFormResult(
                studentId: _studentId!,
                requirement: StudentCustomRequirement(
                  id:
                      widget.initialRequirement?.id ??
                      'custom-${DateTime.now().microsecondsSinceEpoch}',
                  name: _name.text.trim(),
                  quantity: int.parse(_quantity.text),
                  unit: _unit.text.trim(),
                  dueDate: _dueDate,
                  notes: _notes.text.trim(),
                  studentId: _studentId!,
                  studentName:
                      widget.initialRequirement?.studentName ??
                      widget.lockedStudentName ??
                      widget.candidates
                          .where((item) => item.studentId == _studentId)
                          .map((item) => item.studentName)
                          .firstOrNull ??
                      '',
                  className:
                      widget.initialRequirement?.className ??
                      widget.lockedClassName ??
                      widget.candidates
                          .where((item) => item.studentId == _studentId)
                          .map((item) => item.className)
                          .firstOrNull ??
                      '',
                  receivedQuantity:
                      widget.initialRequirement?.receivedQuantity ?? 0,
                  estimatedUnitPrice:
                      double.tryParse(_unitPrice.text.trim()) ?? 0,
                  status:
                      widget.initialRequirement?.status ??
                      StudentSpecificRequirementStatus.draft,
                  creatorOwned: widget.initialRequirement?.creatorOwned ?? true,
                  requesterName: widget.initialRequirement?.requesterName ?? '',
                  requesterNote: widget.initialRequirement?.requesterNote ?? '',
                  rejectionReason:
                      widget.initialRequirement?.rejectionReason ?? '',
                ),
              ),
            );
          },
          child: Text(
            widget.initialRequirement == null
                ? 'Save as Draft'
                : 'Save changes',
          ),
        ),
      ],
    );
  }
}

class _StudentRequirementSubmissionDialog extends StatefulWidget {
  const _StudentRequirementSubmissionDialog({
    required this.requirement,
    required this.approvers,
  });

  final StudentCustomRequirement requirement;
  final List<FeeApprover> approvers;

  @override
  State<_StudentRequirementSubmissionDialog> createState() =>
      _StudentRequirementSubmissionDialogState();
}

class _StudentRequirementSubmissionDialogState
    extends State<_StudentRequirementSubmissionDialog> {
  int? _approverId;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.approval_outlined,
        color: AppColors.green,
        size: 32,
      ),
      title: const Text('Submit for approval'),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.requirement.quantity} ${widget.requirement.unit} of ${widget.requirement.name} for ${widget.requirement.studentName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              value: _approverId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Approver *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              items: widget.approvers
                  .map(
                    (approver) => DropdownMenuItem(
                      value: approver.id,
                      child: Text('${approver.name} · ${approver.role}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _approverId = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Note for approver (optional)',
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
        FilledButton.icon(
          onPressed: _approverId == null
              ? null
              : () => Navigator.pop(
                  context,
                  _RequirementSubmission(_approverId!, _note.text.trim()),
                ),
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit'),
        ),
      ],
    );
  }
}

class _StudentRequirementReviewDialog extends StatelessWidget {
  const _StudentRequirementReviewDialog({required this.requirement});
  final StudentCustomRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final canDecide =
        requirement.canApprove &&
        requirement.status == StudentSpecificRequirementStatus.pendingApproval;
    return AlertDialog(
      title: Text(canDecide ? 'Review requirement' : 'Requirement details'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requirement.studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    requirement.className,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              requirement.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ReviewFact(
                    label: 'QUANTITY REQUIRED',
                    value: '${requirement.quantity} ${requirement.unit}',
                    prominent: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ReviewFact(
                    label: 'DUE DATE',
                    value: _date(requirement.dueDate),
                  ),
                ),
              ],
            ),
            if (requirement.estimatedUnitPrice > 0) ...[
              const SizedBox(height: 14),
              _ReviewFact(
                label: 'SUGGESTED PRICE',
                value:
                    '${_money(requirement.estimatedUnitPrice)} per ${_singularUnit(requirement.unit)}',
              ),
            ],
            if (requirement.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReviewFact(label: 'INSTRUCTIONS', value: requirement.notes),
            ],
            if (requirement.requesterNote.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReviewFact(
                label: 'REQUESTER NOTE',
                value: requirement.requesterNote,
              ),
            ],
            if (requirement.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReviewFact(
                label: 'CHANGES REQUESTED',
                value: requirement.rejectionReason,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canDecide) ...[
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'reject'),
            child: const Text('Request changes'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'approve'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
          ),
        ],
      ],
    );
  }
}

class _StudentRequirementReceivedDialog extends StatefulWidget {
  const _StudentRequirementReceivedDialog({required this.requirement});
  final StudentCustomRequirement requirement;

  @override
  State<_StudentRequirementReceivedDialog> createState() =>
      _StudentRequirementReceivedDialogState();
}

class _StudentRequirementReceivedDialogState
    extends State<_StudentRequirementReceivedDialog> {
  late final TextEditingController _quantity;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: '${widget.requirement.receivedQuantity}',
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record delivered quantity'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.requirement.studentName} · ${widget.requirement.name}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.requirement.quantity} ${widget.requirement.unit} required in total',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity delivered to date *',
                errorText: _error,
                suffixText: widget.requirement.unit,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
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
            final value = int.tryParse(_quantity.text.trim());
            if (value == null ||
                value < 0 ||
                value > widget.requirement.quantity) {
              setState(
                () => _error =
                    'Enter a quantity from 0 to ${widget.requirement.quantity}',
              );
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('Save delivery'),
        ),
      ],
    );
  }
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({
    required this.label,
    required this.value,
    this.prominent = false,
  });
  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: prominent ? AppColors.green : AppColors.text,
            fontSize: prominent ? 18 : 14,
            fontWeight: prominent ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PublishRequirementsPanel extends StatelessWidget {
  const _PublishRequirementsPanel({required this.group});

  final ClassRequirementGroup group;

  @override
  Widget build(BuildContext context) {
    final reviewItems = _publicationReviewItems(group);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 720
        ? screenWidth
        : (screenWidth * .40).clamp(540.0, 680.0).toDouble();
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 20,
        child: SafeArea(
          left: false,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Publish approved items',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${group.className} · ${reviewItems.length} items',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ITEMS TO PUBLISH',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...reviewItems.map(_itemCard),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 15, 22, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('confirm-publish-requirements'),
                          onPressed: () => Navigator.pop(
                            context,
                            const RequirementNotificationPlan(
                              useDefaultPreference: true,
                              methods: {},
                              message:
                                  'Your child’s class requirements have been updated.',
                            ),
                          ),
                          icon: const Icon(Icons.publish_rounded),
                          label: const Text('Publish items'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(_RequirementPublicationItem reviewItem) {
    final item = reviewItem.item;
    final previous = reviewItem.previous;
    final label = switch (reviewItem.kind) {
      _RequirementPublicationKind.newItem => 'NEW',
      _RequirementPublicationKind.modified => 'MODIFIED',
      _RequirementPublicationKind.same => 'SAME',
      _RequirementPublicationKind.removed => 'REMOVED',
    };
    final color = switch (reviewItem.kind) {
      _RequirementPublicationKind.newItem => AppColors.blue,
      _RequirementPublicationKind.modified => AppColors.amber,
      _RequirementPublicationKind.same => AppColors.green,
      _RequirementPublicationKind.removed => AppColors.red,
    };
    return Container(
      key: Key('publish-item-${item.identityKey}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: .32)),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: .045),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _SmallPill(label: label, color: color),
            ],
          ),
          const SizedBox(height: 7),
          if (previous != null &&
              reviewItem.kind == _RequirementPublicationKind.modified)
            Text(
              '${previous.quantity} ${previous.unit}  →  ${item.quantity} ${item.unit}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          else
            Text(
              '${item.quantity} ${item.unit}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if (previous != null &&
              reviewItem.kind == _RequirementPublicationKind.modified &&
              previous.estimatedUnitPrice != item.estimatedUnitPrice)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${_money(previous.estimatedUnitPrice)} → ${_money(item.estimatedUnitPrice)} per ${_singularUnit(item.unit)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
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
  var progress = 0.0;
  var total = 0;
  for (final student in students) {
    if (student.items.isNotEmpty) {
      for (final item in student.items) {
        total++;
        final status = item.status.toUpperCase();
        if (status == 'WAIVED' ||
            status == 'CASH_EQUIVALENT' ||
            item.requiredQuantity <= 0) {
          progress += 1;
        } else {
          progress += (item.receivedQuantity / item.requiredQuantity).clamp(
            0.0,
            1.0,
          );
        }
      }
    } else {
      for (final item in group.items) {
        total++;
        final target = _targetQuantity(student, item);
        if (target <= 0) {
          progress += 1;
        } else {
          progress += ((student.receivedQuantities[item.id] ?? 0) / target)
              .clamp(0.0, 1.0);
        }
      }
    }
    for (final item in student.customRequirements.where(
      (item) => item.status == StudentSpecificRequirementStatus.active,
    )) {
      total++;
      progress += item.quantity <= 0
          ? 1
          : (item.receivedQuantity / item.quantity).clamp(0.0, 1.0);
    }
  }
  return total == 0 ? 0 : progress / total;
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
    RequirementAdjustmentType.fullWaiver ||
    RequirementAdjustmentType.cashEquivalent => 0,
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
    RequirementAdjustmentType.cashEquivalent => 'Cash equivalent received',
  };
}

String _studentRequirementStatusLabel(
  StudentSpecificRequirementStatus status,
) => switch (status) {
  StudentSpecificRequirementStatus.draft => 'Draft',
  StudentSpecificRequirementStatus.pendingApproval => 'Pending approval',
  StudentSpecificRequirementStatus.changesRequested => 'Changes requested',
  StudentSpecificRequirementStatus.active => 'Active',
  StudentSpecificRequirementStatus.inactive => 'Inactive',
};

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

String _publishedItemAuditText(ClassRequirementItem item) {
  final at = item.lifecycleAt;
  if (at == null || item.lifecycleAction.trim().isEmpty) return '';
  final verb = item.lifecycleAction.toUpperCase() == 'UPDATED'
      ? 'Updated'
      : 'Added';
  final date = _date(at);
  return item.lifecycleBy.trim().isEmpty
      ? '$verb $date'
      : '$verb $date by ${item.lifecycleBy.trim()}';
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
