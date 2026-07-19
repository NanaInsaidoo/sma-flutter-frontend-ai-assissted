import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/class_requirements_repository.dart';
import '../domain/class_requirement_models.dart';

class PriorTermRequirementsScreen extends StatefulWidget {
  const PriorTermRequirementsScreen({
    super.key,
    required this.repository,
    required this.onBack,
  });

  final ClassRequirementsRepository repository;
  final VoidCallback onBack;

  @override
  State<PriorTermRequirementsScreen> createState() =>
      _PriorTermRequirementsScreenState();
}

class _PriorTermRequirementsScreenState
    extends State<PriorTermRequirementsScreen> {
  bool _byStudent = true;
  bool _showResolved = false;
  String _query = '';
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final records = widget.repository.priorTermRequirements;
    if (_selectedStudentId != null) {
      final studentRecords = records
          .where((item) => item.studentId == _selectedStudentId)
          .toList();
      if (studentRecords.isNotEmpty) {
        return _PriorTermStudentDetail(
          records: studentRecords,
          onBack: () => setState(() => _selectedStudentId = null),
          onResolve: _resolve,
        );
      }
    }

    final pending = records
        .where((item) => item.status == PriorTermRequirementStatus.pending)
        .toList();
    final resolved = records.length - pending.length;
    final affectedStudents = pending
        .map((item) => item.studentId)
        .toSet()
        .length;
    final outstandingUnits = pending.fold<int>(
      0,
      (sum, item) => sum + item.remainingQuantity,
    );
    final estimatedValue = pending.fold<double>(
      0,
      (sum, item) => sum + item.estimatedOutstandingValue,
    );
    final visible = records.where((item) {
      if (!_showResolved && item.status != PriorTermRequirementStatus.pending) {
        return false;
      }
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return item.studentName.toLowerCase().contains(query) ||
          item.itemName.toLowerCase().contains(query) ||
          item.originClassName.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to items & supplies'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Prior-term outstanding requirements',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Resolve physical obligations from completed terms without mixing them into the current-term checklist.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720
                ? 1
                : constraints.maxWidth < 1050
                ? 2
                : 4;
            final width =
                (constraints.maxWidth - (16 * (columns - 1))) / columns;
            final data = [
              _PriorSummaryData(
                'Affected students',
                '$affectedStudents',
                'With unresolved items',
                Icons.groups_outlined,
                AppColors.amber,
              ),
              _PriorSummaryData(
                'Outstanding items',
                '${pending.length}',
                '$outstandingUnits physical units',
                Icons.inventory_2_outlined,
                AppColors.red,
              ),
              _PriorSummaryData(
                'Estimated value',
                _money(estimatedValue),
                'Guidance for cash conversion',
                Icons.payments_outlined,
                AppColors.green,
              ),
              _PriorSummaryData(
                'Resolved',
                '$resolved',
                'Retained in resolution history',
                Icons.task_alt_rounded,
                AppColors.blue,
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: data
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: _PriorSummaryCard(data: item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final search = TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Search student, item, or class',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    );
                    final controls = Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ViewChoice(
                          selected: _byStudent,
                          icon: Icons.person_outline_rounded,
                          label: 'By student',
                          onTap: () => setState(() => _byStudent = true),
                        ),
                        _ViewChoice(
                          selected: !_byStudent,
                          icon: Icons.inventory_2_outlined,
                          label: 'By item',
                          onTap: () => setState(() => _byStudent = false),
                        ),
                        FilterChip(
                          selected: _showResolved,
                          onSelected: (value) =>
                              setState(() => _showResolved = value),
                          label: const Text('Show resolved'),
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 780) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 12),
                          controls,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 16),
                        controls,
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              if (visible.isEmpty)
                const _EmptyPriorTermState()
              else if (_byStudent)
                _PriorStudentsTable(
                  records: visible,
                  onOpenStudent: (studentId) =>
                      setState(() => _selectedStudentId = studentId),
                )
              else
                _PriorItemsTable(records: visible),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _resolve(PriorTermRequirement requirement) async {
    final result = await showDialog<_ResolutionResult>(
      context: context,
      builder: (context) => _ResolutionDialog(requirement: requirement),
    );
    if (result == null) return;

    if (result.action == _ResolutionAction.recordReceived) {
      try {
        await widget.repository.recordPriorTermReceived(
          requirementId: requirement.id,
          quantity: result.quantity!,
          notes: result.notes,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
        return;
      }
    } else {
      final status = switch (result.action) {
        _ResolutionAction.carryForward || _ResolutionAction.adjustAndCarry =>
          PriorTermRequirementStatus.carriedForward,
        _ResolutionAction.convertToCash =>
          PriorTermRequirementStatus.convertedToCash,
        _ResolutionAction.waive => PriorTermRequirementStatus.waived,
        _ResolutionAction.writeOff => PriorTermRequirementStatus.writtenOff,
        _ResolutionAction.recordReceived => PriorTermRequirementStatus.pending,
      };
      try {
        await widget.repository.resolvePriorTermRequirement(
          requirementId: requirement.id,
          status: status,
          carriedQuantity: result.quantity,
          convertedCashAmount: result.cashAmount,
          carriedDueDate: result.dueDate,
          notes: result.notes,
          notifyGuardian: result.notifyGuardian,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${requirement.itemName} updated successfully.')),
    );
  }
}

class _PriorTermStudentDetail extends StatelessWidget {
  const _PriorTermStudentDetail({
    required this.records,
    required this.onBack,
    required this.onResolve,
  });

  final List<PriorTermRequirement> records;
  final VoidCallback onBack;
  final ValueChanged<PriorTermRequirement> onResolve;

  @override
  Widget build(BuildContext context) {
    final first = records.first;
    final pending = records
        .where((item) => item.status == PriorTermRequirementStatus.pending)
        .toList();
    final value = pending.fold<double>(
      0,
      (sum, item) => sum + item.estimatedOutstandingValue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to outstanding requirements'),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.green,
                  child: Text(
                    _initials(first.studentName),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.studentName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${first.originClassName} · ${first.originTerm}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _MetricPill(label: '${pending.length} pending'),
                const SizedBox(width: 10),
                _MetricPill(label: '${_money(value)} estimate'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Requirement resolution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Resolve each obligation independently. Completed actions remain visible for audit history.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1120,
              child: Column(
                children: [
                  const _PriorDetailHeader(),
                  ...records.map(
                    (item) => _PriorDetailRow(
                      item: item,
                      onResolve:
                          item.status == PriorTermRequirementStatus.pending
                          ? () => onResolve(item)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorStudentsTable extends StatelessWidget {
  const _PriorStudentsTable({
    required this.records,
    required this.onOpenStudent,
  });

  final List<PriorTermRequirement> records;
  final ValueChanged<String> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PriorTermRequirement>>{};
    for (final item in records) {
      groups.putIfAbsent(item.studentId, () => []).add(item);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1040,
        child: Column(
          children: [
            const _SimpleHeader(
              labels: [
                'STUDENT',
                'ORIGINAL CLASS',
                'PENDING ITEMS',
                'REMAINING UNITS',
                'ESTIMATED VALUE',
                'ACTION',
              ],
              flexes: [28, 17, 14, 17, 15, 13],
            ),
            ...groups.entries.map((entry) {
              final items = entry.value;
              final first = items.first;
              final pending = items
                  .where(
                    (item) => item.status == PriorTermRequirementStatus.pending,
                  )
                  .toList();
              final units = pending.fold<int>(
                0,
                (sum, item) => sum + item.remainingQuantity,
              );
              final value = pending.fold<double>(
                0,
                (sum, item) => sum + item.estimatedOutstandingValue,
              );
              return _SimpleRow(
                cells: [
                  _StudentCell(name: first.studentName, id: first.studentId),
                  Text(first.originClassName),
                  Text('${pending.length}'),
                  Text('$units'),
                  Text(_money(value)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () => onOpenStudent(entry.key),
                      child: const Text('Review'),
                    ),
                  ),
                ],
                flexes: const [28, 17, 14, 17, 15, 13],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PriorItemsTable extends StatelessWidget {
  const _PriorItemsTable({required this.records});

  final List<PriorTermRequirement> records;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PriorTermRequirement>>{};
    for (final item in records) {
      groups.putIfAbsent(item.itemName, () => []).add(item);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1040,
        child: Column(
          children: [
            const _SimpleHeader(
              labels: [
                'ITEM',
                'CATEGORY',
                'ORIGIN',
                'STUDENTS',
                'REMAINING',
                'ESTIMATED VALUE',
              ],
              flexes: [24, 18, 19, 13, 13, 16],
            ),
            ...groups.values.map((items) {
              final first = items.first;
              final pending = items
                  .where(
                    (item) => item.status == PriorTermRequirementStatus.pending,
                  )
                  .toList();
              final units = pending.fold<int>(
                0,
                (sum, item) => sum + item.remainingQuantity,
              );
              final value = pending.fold<double>(
                0,
                (sum, item) => sum + item.estimatedOutstandingValue,
              );
              return _SimpleRow(
                cells: [
                  Text(
                    first.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(first.category),
                  Text('${first.originClassName} · ${first.originTerm}'),
                  Text(
                    '${pending.map((item) => item.studentId).toSet().length}',
                  ),
                  Text('$units ${first.unit}'),
                  Text(_money(value)),
                ],
                flexes: const [24, 18, 19, 13, 13, 16],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PriorDetailHeader extends StatelessWidget {
  const _PriorDetailHeader();

  @override
  Widget build(BuildContext context) {
    return const _SimpleHeader(
      labels: [
        'ITEM',
        'ORIGIN',
        'REQUIRED',
        'RECEIVED',
        'OUTSTANDING',
        'ESTIMATED VALUE',
        'STATUS',
        'ACTION',
      ],
      flexes: [23, 19, 12, 12, 14, 16, 17, 13],
    );
  }
}

class _PriorDetailRow extends StatelessWidget {
  const _PriorDetailRow({required this.item, required this.onResolve});

  final PriorTermRequirement item;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final pending = item.status == PriorTermRequirementStatus.pending;
    return _SimpleRow(
      cells: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              item.category,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        Text('${item.originClassName}\n${item.originTerm}'),
        Text('${item.originalQuantity} ${item.unit}'),
        Text('${item.receivedQuantity} ${item.unit}'),
        Text('${item.remainingQuantity} ${item.unit}'),
        Text(_money(item.estimatedOutstandingValue)),
        _StatusPill(status: item.status),
        pending
            ? Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: onResolve,
                  child: const Text('Resolve'),
                ),
              )
            : Tooltip(
                message: item.resolutionNotes.isEmpty
                    ? 'Resolution recorded'
                    : item.resolutionNotes,
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.muted,
                ),
              ),
      ],
      flexes: const [23, 19, 12, 12, 14, 16, 17, 13],
    );
  }
}

enum _ResolutionAction {
  recordReceived,
  carryForward,
  convertToCash,
  adjustAndCarry,
  waive,
  writeOff,
}

class _ResolutionResult {
  const _ResolutionResult({
    required this.action,
    required this.notes,
    required this.notifyGuardian,
    this.quantity,
    this.cashAmount,
    this.dueDate,
  });

  final _ResolutionAction action;
  final String notes;
  final bool notifyGuardian;
  final int? quantity;
  final double? cashAmount;
  final DateTime? dueDate;
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog({required this.requirement});

  final PriorTermRequirement requirement;

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _cashAmount;
  final _notes = TextEditingController();
  _ResolutionAction _action = _ResolutionAction.recordReceived;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _notifyGuardian = true;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: '${widget.requirement.remainingQuantity}',
    );
    _cashAmount = TextEditingController(
      text: widget.requirement.estimatedOutstandingValue.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cashAmount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsQuantity =
        _action == _ResolutionAction.recordReceived ||
        _action == _ResolutionAction.carryForward ||
        _action == _ResolutionAction.adjustAndCarry;
    final needsDueDate =
        _action == _ResolutionAction.carryForward ||
        _action == _ResolutionAction.adjustAndCarry;
    final needsCash = _action == _ResolutionAction.convertToCash;
    final notify = _action != _ResolutionAction.recordReceived;

    return AlertDialog(
      title: const Text('Resolve prior-term requirement'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.requirement.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.requirement.studentName} · ${widget.requirement.remainingQuantity} ${widget.requirement.unit} outstanding',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _money(widget.requirement.estimatedOutstandingValue),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<_ResolutionAction>(
                  value: _action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: _ResolutionAction.values
                      .map(
                        (action) => DropdownMenuItem(
                          value: action,
                          child: Text(_actionLabel(action)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _action = value);
                  },
                ),
                const SizedBox(height: 14),
                if (needsQuantity)
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _action == _ResolutionAction.recordReceived
                          ? 'Quantity received'
                          : 'Quantity to carry forward',
                      suffixText: widget.requirement.unit,
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');
                      if (quantity == null || quantity < 1) {
                        return 'Enter a valid quantity';
                      }
                      if (quantity > widget.requirement.remainingQuantity) {
                        return 'Cannot exceed ${widget.requirement.remainingQuantity}';
                      }
                      return null;
                    },
                  ),
                if (needsDueDate) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (value != null) setState(() => _dueDate = value);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'New due date',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_date(_dueDate)),
                    ),
                  ),
                ],
                if (needsCash) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cashAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cash charge for current term',
                      prefixText: 'GH₵ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This closes the physical obligation. The live backend will create a linked current-term fee charge.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Resolution note *',
                    hintText: 'Explain the decision for the audit record',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a resolution note'
                      : null,
                ),
                if (notify) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notifyGuardian,
                    onChanged: (value) =>
                        setState(() => _notifyGuardian = value),
                    title: const Text('Notify guardian'),
                    subtitle: const Text(
                      'Use the household’s default notification preference.',
                    ),
                  ),
                ],
                if (_action == _ResolutionAction.waive ||
                    _action == _ResolutionAction.writeOff) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _action == _ResolutionAction.waive
                          ? 'Waive: the school formally excuses this student from the obligation.'
                          : 'Write off: the school closes an uncollectible obligation without treating it as an exemption.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
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
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm resolution'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final needsQuantity =
        _action == _ResolutionAction.recordReceived ||
        _action == _ResolutionAction.carryForward ||
        _action == _ResolutionAction.adjustAndCarry;
    Navigator.pop(
      context,
      _ResolutionResult(
        action: _action,
        notes: _notes.text.trim(),
        notifyGuardian: _action == _ResolutionAction.recordReceived
            ? false
            : _notifyGuardian,
        quantity: needsQuantity ? int.parse(_quantity.text) : null,
        cashAmount: _action == _ResolutionAction.convertToCash
            ? double.parse(_cashAmount.text)
            : null,
        dueDate:
            _action == _ResolutionAction.carryForward ||
                _action == _ResolutionAction.adjustAndCarry
            ? _dueDate
            : null,
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({required this.labels, required this.flexes});

  final List<String> labels;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => Expanded(
            flex: flexes[index],
            child: Text(
              labels[index],
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.cells, required this.flexes});

  final List<Widget> cells;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(
          cells.length,
          (index) => Expanded(flex: flexes[index], child: cells[index]),
        ),
      ),
    );
  }
}

class _StudentCell extends StatelessWidget {
  const _StudentCell({required this.name, required this.id});

  final String name;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.greenSoft,
          foregroundColor: AppColors.green,
          child: Text(
            _initials(name),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                id.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PriorTermRequirementStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PriorTermRequirementStatus.pending => AppColors.amber,
      PriorTermRequirementStatus.fulfilled => AppColors.green,
      PriorTermRequirementStatus.carriedForward => AppColors.blue,
      PriorTermRequirementStatus.convertedToCash => AppColors.purple,
      PriorTermRequirementStatus.waived => AppColors.green,
      PriorTermRequirementStatus.writtenOff => AppColors.red,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
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
      ),
    );
  }
}

class _ViewChoice extends StatelessWidget {
  const _ViewChoice({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.greenSoft : Colors.white,
        side: BorderSide(color: selected ? AppColors.green : AppColors.border),
      ),
      icon: Icon(selected ? Icons.check_rounded : icon, size: 18),
      label: Text(label),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyPriorTermState extends StatelessWidget {
  const _EmptyPriorTermState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, color: AppColors.green, size: 38),
          SizedBox(height: 12),
          Text(
            'No matching outstanding requirements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'Try another search or include resolved items.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PriorSummaryData {
  const _PriorSummaryData(
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

class _PriorSummaryCard extends StatelessWidget {
  const _PriorSummaryCard({required this.data});

  final _PriorSummaryData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
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
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(data.icon, color: data.color, size: 20),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              data.value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(data.caption, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

String _actionLabel(_ResolutionAction action) {
  return switch (action) {
    _ResolutionAction.recordReceived => 'Record item received',
    _ResolutionAction.carryForward => 'Carry forward as physical item',
    _ResolutionAction.convertToCash => 'Convert to current-term cash charge',
    _ResolutionAction.adjustAndCarry => 'Adjust quantity and carry forward',
    _ResolutionAction.waive => 'Waive requirement',
    _ResolutionAction.writeOff => 'Write off requirement',
  };
}

String _statusLabel(PriorTermRequirementStatus status) {
  return switch (status) {
    PriorTermRequirementStatus.pending => 'Pending',
    PriorTermRequirementStatus.fulfilled => 'Received',
    PriorTermRequirementStatus.carriedForward => 'Carried forward',
    PriorTermRequirementStatus.convertedToCash => 'Converted to cash',
    PriorTermRequirementStatus.waived => 'Waived',
    PriorTermRequirementStatus.writtenOff => 'Written off',
  };
}

String _money(double amount) {
  final value = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return 'GH₵ $value';
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

String _initials(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
