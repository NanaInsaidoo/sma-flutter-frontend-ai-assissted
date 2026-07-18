import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/fee_adjustment_workflow_models.dart';

class FeeAdjustmentsContent extends StatefulWidget {
  const FeeAdjustmentsContent({super.key});

  @override
  State<FeeAdjustmentsContent> createState() => _FeeAdjustmentsContentState();
}

class _FeeAdjustmentsContentState extends State<FeeAdjustmentsContent> {
  final _searchController = TextEditingController();
  late List<WorkflowFeeAdjustment> _adjustments;
  FeeAdjustmentWorkflowStatus? _statusFilter;
  FeeAdjustmentWorkflowType? _typeFilter;
  String _classFilter = 'All classes';

  @override
  void initState() {
    super.initState();
    _adjustments = [..._mockAdjustments];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkflowFeeAdjustment> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _adjustments
        .where((item) {
          final matchesSearch =
              query.isEmpty ||
              item.studentName.toLowerCase().contains(query) ||
              item.customStudentId.toLowerCase().contains(query) ||
              item.feeItem.toLowerCase().contains(query) ||
              item.id.toLowerCase().contains(query);
          return matchesSearch &&
              (_statusFilter == null || item.status == _statusFilter) &&
              (_typeFilter == null || item.type == _typeFilter) &&
              (_classFilter == 'All classes' || item.className == _classFilter);
        })
        .toList(growable: false);
  }

  int _count(FeeAdjustmentWorkflowStatus status) =>
      _adjustments.where((item) => item.status == status).length;

  Future<void> _openAdjustment(WorkflowFeeAdjustment adjustment) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close adjustment review',
      barrierColor: Colors.black.withValues(alpha: .44),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: _AdjustmentReviewPanel(
          adjustment: adjustment,
          onAction: (action) {
            Navigator.of(context).pop();
            _handleAction(adjustment, action);
          },
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Future<void> _handleAction(
    WorkflowFeeAdjustment adjustment,
    _ReviewAction action,
  ) async {
    if (action == _ReviewAction.delete) {
      final confirmed = await _confirm(
        title: 'Delete draft adjustment?',
        message: 'This removes the unsubmitted adjustment permanently.',
        actionLabel: 'Delete',
      );
      if (!confirmed || !mounted) return;
      setState(
        () => _adjustments.removeWhere((item) => item.id == adjustment.id),
      );
      _notify('Draft adjustment deleted.');
      return;
    }

    if (action == _ReviewAction.duplicate) {
      final copy = adjustment.copyWith(
        id: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
        status: FeeAdjustmentWorkflowStatus.draft,
        createdOn: DateTime.now(),
        createdBy: 'Current administrator',
        clearReview: true,
      );
      setState(() => _adjustments.insert(0, copy));
      _notify('A draft copy was created for revision.');
      return;
    }

    final note = switch (action) {
      _ReviewAction.requestChanges => await _requestNote(
        title: 'Request changes',
        label: 'Explain what must be corrected',
        actionLabel: 'Request changes',
      ),
      _ReviewAction.reject => await _requestNote(
        title: 'Reject adjustment',
        label: 'Reason for rejection',
        actionLabel: 'Reject',
      ),
      _ReviewAction.reverse => await _requestNote(
        title: 'Reverse adjustment',
        label: 'Reason for reversal',
        actionLabel: 'Reverse',
      ),
      _ => '',
    };
    if (note == null || !mounted) return;

    final status = switch (action) {
      _ReviewAction.approve => FeeAdjustmentWorkflowStatus.approved,
      _ReviewAction.requestChanges =>
        FeeAdjustmentWorkflowStatus.changesRequested,
      _ReviewAction.reject => FeeAdjustmentWorkflowStatus.rejected,
      _ReviewAction.reverse => FeeAdjustmentWorkflowStatus.reversed,
      _ => adjustment.status,
    };
    final updated = adjustment.copyWith(
      status: status,
      reviewedOn: DateTime.now(),
      reviewedBy: 'Current administrator',
      reviewNote: note,
    );
    setState(() {
      final index = _adjustments.indexWhere((item) => item.id == adjustment.id);
      if (index >= 0) _adjustments[index] = updated;
      if (action == _ReviewAction.reverse) {
        _adjustments.insert(
          0,
          adjustment.copyWith(
            id: 'REV-${DateTime.now().millisecondsSinceEpoch}',
            type: adjustment.type == FeeAdjustmentWorkflowType.discount
                ? FeeAdjustmentWorkflowType.surcharge
                : FeeAdjustmentWorkflowType.discount,
            reason: 'Reversal of ${adjustment.id}: $note',
            status: FeeAdjustmentWorkflowStatus.complete,
            createdOn: DateTime.now(),
            createdBy: 'Current administrator',
            clearReview: true,
          ),
        );
      }
    });
    _notify(switch (action) {
      _ReviewAction.approve => 'Adjustment approved.',
      _ReviewAction.requestChanges => 'Changes requested from the creator.',
      _ReviewAction.reject => 'Adjustment rejected.',
      _ReviewAction.reverse => 'Adjustment reversed.',
      _ => 'Adjustment updated.',
    });
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _requestNote({
    required String title,
    required String label,
    required String actionLabel,
  }) async {
    final key = GlobalKey<FormState>();
    var note = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: key,
          child: TextFormField(
            key: const Key('adjustment-review-note'),
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(labelText: label),
            onChanged: (value) => note = value,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter a reason' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(context, note.trim());
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = <String>{
      'All classes',
      ..._adjustments.map((item) => item.className),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Adjustments',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Review discounts, surcharges, corrections, and reversals.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const _MockDataBadge(),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 36) / 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AdjustmentMetric(
                  width: width,
                  label: 'Pending approval',
                  value: _count(FeeAdjustmentWorkflowStatus.pending),
                  color: AppColors.amber,
                ),
                _AdjustmentMetric(
                  width: width,
                  label: 'Changes requested',
                  value: _count(FeeAdjustmentWorkflowStatus.changesRequested),
                  color: AppColors.purple,
                ),
                _AdjustmentMetric(
                  width: width,
                  label: 'Approved',
                  value: _count(FeeAdjustmentWorkflowStatus.approved),
                  color: AppColors.green,
                ),
                _AdjustmentMetric(
                  width: width,
                  label: 'Reversed',
                  value: _count(FeeAdjustmentWorkflowStatus.reversed),
                  color: AppColors.red,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    key: const Key('adjustments-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText:
                          'Search student, ID, fee item, or adjustment ID',
                    ),
                  ),
                ),
                SizedBox(
                  width: 205,
                  child: DropdownButtonFormField<FeeAdjustmentWorkflowStatus?>(
                    value: _statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    hint: const Text('All statuses'),
                    items: [
                      ...FeeAdjustmentWorkflowStatus.values.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(value)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<FeeAdjustmentWorkflowType?>(
                    value: _typeFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    hint: const Text('All types'),
                    items: const [
                      DropdownMenuItem(
                        value: FeeAdjustmentWorkflowType.discount,
                        child: Text('Discount'),
                      ),
                      DropdownMenuItem(
                        value: FeeAdjustmentWorkflowType.surcharge,
                        child: Text('Surcharge'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _typeFilter = value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _classFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: classes
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _classFilter = value!),
                  ),
                ),
                if (_searchController.text.trim().isNotEmpty ||
                    _statusFilter != null ||
                    _typeFilter != null ||
                    _classFilter != 'All classes')
                  TextButton.icon(
                    key: const Key('clear-adjustment-filters'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _statusFilter = null;
                        _typeFilter = null;
                        _classFilter = 'All classes';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: _filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No adjustments match these filters.'),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 1080),
                    child: DataTable(
                      horizontalMargin: 18,
                      columnSpacing: 24,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 76,
                      headingRowColor: const WidgetStatePropertyAll(
                        AppColors.background,
                      ),
                      columns: const [
                        DataColumn(label: Text('STUDENT')),
                        DataColumn(label: Text('APPLIES TO')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('AMOUNT'), numeric: true),
                        DataColumn(label: Text('REQUESTED BY')),
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('')),
                      ],
                      rows: _filtered.map((item) {
                        return DataRow(
                          onSelectChanged: (_) => _openAdjustment(item),
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 190,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.studentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${item.customStudentId} · ${item.className}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(item.feeItem)),
                            DataCell(Text(_typeLabel(item.type))),
                            DataCell(
                              Text(
                                _adjustmentMoney(item),
                                style: TextStyle(
                                  color:
                                      item.type ==
                                          FeeAdjustmentWorkflowType.discount
                                      ? AppColors.green
                                      : AppColors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            DataCell(Text(item.createdBy)),
                            DataCell(Text(_date(item.createdOn))),
                            DataCell(_StatusPill(status: item.status)),
                            DataCell(
                              OutlinedButton(
                                key: Key('review-adjustment-${item.id}'),
                                onPressed: () => _openAdjustment(item),
                                child: const Text('Review'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

enum _ReviewAction {
  approve,
  requestChanges,
  reject,
  reverse,
  delete,
  duplicate,
}

class _AdjustmentReviewPanel extends StatelessWidget {
  const _AdjustmentReviewPanel({
    required this.adjustment,
    required this.onAction,
  });

  final WorkflowFeeAdjustment adjustment;
  final ValueChanged<_ReviewAction> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = switch (adjustment.status) {
      FeeAdjustmentWorkflowStatus.pending => const [
        _ReviewAction.approve,
        _ReviewAction.requestChanges,
        _ReviewAction.reject,
      ],
      FeeAdjustmentWorkflowStatus.approved => const [_ReviewAction.reverse],
      FeeAdjustmentWorkflowStatus.draft => const [_ReviewAction.delete],
      FeeAdjustmentWorkflowStatus.rejected => const [_ReviewAction.duplicate],
      _ => const <_ReviewAction>[],
    };
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: 500,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Adjustment review',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              adjustment.studentName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _StatusPill(status: adjustment.status),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${adjustment.customStudentId} · ${adjustment.className}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      _ReviewInfo(label: 'Adjustment ID', value: adjustment.id),
                      _ReviewInfo(
                        label: 'Applies to',
                        value: adjustment.feeItem,
                      ),
                      _ReviewInfo(
                        label: 'Type',
                        value: _typeLabel(adjustment.type),
                      ),
                      _ReviewInfo(
                        label: 'Amount',
                        value: _adjustmentMoney(adjustment),
                      ),
                      _ReviewInfo(label: 'Reason', value: adjustment.reason),
                      _ReviewInfo(
                        label: 'Requested',
                        value:
                            '${adjustment.createdBy} · ${_date(adjustment.createdOn)}',
                      ),
                      if (adjustment.reviewedBy != null)
                        _ReviewInfo(
                          label: 'Reviewed',
                          value:
                              '${adjustment.reviewedBy} · ${_date(adjustment.reviewedOn!)}',
                        ),
                      if (adjustment.reviewNote?.trim().isNotEmpty == true)
                        _ReviewInfo(
                          label: 'Review note',
                          value: adjustment.reviewNote!,
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Approved adjustments affect the student fee balance. Pending and rejected records remain visible for audit.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions
                        .map(
                          (action) => action == _ReviewAction.approve
                              ? FilledButton.icon(
                                  key: const Key('approve-adjustment'),
                                  onPressed: () => onAction(action),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Approve'),
                                )
                              : OutlinedButton(
                                  key: Key('adjustment-action-${action.name}'),
                                  onPressed: () => onAction(action),
                                  child: Text(_actionLabel(action)),
                                ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewInfo extends StatelessWidget {
  const _ReviewInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AdjustmentMetric extends StatelessWidget {
  const _AdjustmentMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final FeeAdjustmentWorkflowStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MockDataBadge extends StatelessWidget {
  const _MockDataBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Prototype data',
        style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _money(double amount) => 'GH₵ ${amount.abs().toStringAsFixed(0)}';

String _adjustmentMoney(WorkflowFeeAdjustment item) =>
    item.type == FeeAdjustmentWorkflowType.discount
    ? '(${_money(item.amount)})'
    : _money(item.amount);

String _typeLabel(FeeAdjustmentWorkflowType type) =>
    type == FeeAdjustmentWorkflowType.discount ? 'Discount' : 'Surcharge';

String _statusLabel(FeeAdjustmentWorkflowStatus status) => switch (status) {
  FeeAdjustmentWorkflowStatus.draft => 'Draft',
  FeeAdjustmentWorkflowStatus.pending => 'Pending approval',
  FeeAdjustmentWorkflowStatus.changesRequested => 'Changes requested',
  FeeAdjustmentWorkflowStatus.approved => 'Approved',
  FeeAdjustmentWorkflowStatus.rejected => 'Rejected',
  FeeAdjustmentWorkflowStatus.complete => 'Complete',
  FeeAdjustmentWorkflowStatus.reversed => 'Reversed',
  FeeAdjustmentWorkflowStatus.cancelled => 'Cancelled',
};

Color _statusColor(FeeAdjustmentWorkflowStatus status) => switch (status) {
  FeeAdjustmentWorkflowStatus.draft => AppColors.muted,
  FeeAdjustmentWorkflowStatus.pending => AppColors.amber,
  FeeAdjustmentWorkflowStatus.changesRequested => AppColors.purple,
  FeeAdjustmentWorkflowStatus.approved => AppColors.green,
  FeeAdjustmentWorkflowStatus.rejected => AppColors.red,
  FeeAdjustmentWorkflowStatus.complete => AppColors.blue,
  FeeAdjustmentWorkflowStatus.reversed => AppColors.red,
  FeeAdjustmentWorkflowStatus.cancelled => AppColors.muted,
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

String _actionLabel(_ReviewAction action) => switch (action) {
  _ReviewAction.approve => 'Approve',
  _ReviewAction.requestChanges => 'Request changes',
  _ReviewAction.reject => 'Reject',
  _ReviewAction.reverse => 'Reverse',
  _ReviewAction.delete => 'Delete',
  _ReviewAction.duplicate => 'Duplicate and revise',
};

final _mockAdjustments = <WorkflowFeeAdjustment>[
  WorkflowFeeAdjustment(
    id: 'ADJ-2026-0042',
    customStudentId: 'STU-FA1BC0-9043',
    studentName: 'Kwame Yaw Asante',
    className: 'JHS 1A',
    feeItem: 'Tuition fee',
    type: FeeAdjustmentWorkflowType.discount,
    amount: 50,
    reason: 'Sibling discount for two enrolled children.',
    status: FeeAdjustmentWorkflowStatus.pending,
    createdOn: DateTime(2026, 7, 16),
    createdBy: 'Ama Owusu',
  ),
  WorkflowFeeAdjustment(
    id: 'ADJ-2026-0041',
    customStudentId: 'STU-FA1BC0-3391',
    studentName: 'Abena Asante',
    className: 'Basic 4B',
    feeItem: 'Overall fee account',
    type: FeeAdjustmentWorkflowType.discount,
    amount: 80,
    reason: 'Approved staff-child concession.',
    status: FeeAdjustmentWorkflowStatus.approved,
    createdOn: DateTime(2026, 7, 14),
    createdBy: 'Eric Amozini',
    reviewedOn: DateTime(2026, 7, 15),
    reviewedBy: 'Ama Owusu',
  ),
  WorkflowFeeAdjustment(
    id: 'ADJ-2026-0039',
    customStudentId: 'STU-FA1BC0-7702',
    studentName: 'Akosua Owusu',
    className: 'JHS 2A',
    feeItem: 'ICT / Computer',
    type: FeeAdjustmentWorkflowType.discount,
    amount: 25,
    reason: 'Supporting document must be attached.',
    status: FeeAdjustmentWorkflowStatus.changesRequested,
    createdOn: DateTime(2026, 7, 12),
    createdBy: 'Kofi Mensah',
    reviewedOn: DateTime(2026, 7, 13),
    reviewedBy: 'Ama Owusu',
    reviewNote: 'Attach the signed bursary approval letter.',
  ),
  WorkflowFeeAdjustment(
    id: 'ADJ-2026-0036',
    customStudentId: 'STU-FA1BC0-5512',
    studentName: 'Yaw Boateng',
    className: 'Basic 6A',
    feeItem: 'Tuition fee',
    type: FeeAdjustmentWorkflowType.surcharge,
    amount: 20,
    reason: 'Late payment charge entered after the grace period.',
    status: FeeAdjustmentWorkflowStatus.rejected,
    createdOn: DateTime(2026, 7, 9),
    createdBy: 'Kofi Mensah',
    reviewedOn: DateTime(2026, 7, 10),
    reviewedBy: 'Ama Owusu',
    reviewNote: 'The approved grace period had not ended.',
  ),
  WorkflowFeeAdjustment(
    id: 'ADJ-2026-0032',
    customStudentId: 'STU-FA1BC0-1184',
    studentName: 'Esi Addo',
    className: 'KG 2',
    feeItem: 'PTA levy',
    type: FeeAdjustmentWorkflowType.discount,
    amount: 30,
    reason: 'Draft hardship-support adjustment.',
    status: FeeAdjustmentWorkflowStatus.draft,
    createdOn: DateTime(2026, 7, 7),
    createdBy: 'Ama Owusu',
  ),
];
