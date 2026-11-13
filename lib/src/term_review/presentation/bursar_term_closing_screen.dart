import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/bursar_term_closure_models.dart';

class BursarTermClosingScreen extends StatefulWidget {
  const BursarTermClosingScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.actorUserId,
    this.management = false,
    this.onOpenFees,
    this.onOpenExpenses,
    this.embedded = false,
    this.onChanged,
  });
  final String schoolId;
  final BursarTermClosureRepository repository;
  final int? actorUserId;
  final bool management;
  final VoidCallback? onOpenFees, onOpenExpenses;
  final bool embedded;
  final VoidCallback? onChanged;
  @override
  State<BursarTermClosingScreen> createState() => _State();
}

class _State extends State<BursarTermClosingScreen> {
  late Future<BursarTermClosure> future;
  BursarTermClosure? data;
  List<Map<String, dynamic>> consolidated = [];
  bool saving = false,
      fees = false,
      payments = false,
      petty = false,
      recommendations = false;
  final cash = TextEditingController(),
      bank = TextEditingController(),
      mobile = TextEditingController(),
      discrepancy = TextEditingController(),
      unresolved = TextEditingController();
  @override
  void initState() {
    super.initState();
    future = widget.repository.get(widget.schoolId);
  }

  @override
  void dispose() {
    for (final c in [cash, bank, mobile, discrepancy, unresolved]) {
      c.dispose();
    }
    super.dispose();
  }

  void hydrate(BursarTermClosure x) {
    if (data != null) return;
    data = x;
    consolidated = x.consolidatedRecommendations
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    fees = x.feesReviewed;
    payments = x.paymentsReconciled;
    petty = x.pettyCashClosed;
    recommendations = x.recommendationsReviewed;
    cash.text = _plain(x.cashTotal);
    bank.text = _plain(x.bankTotal);
    mobile.text = _plain(x.mobileMoneyTotal);
    discrepancy.text = x.discrepancyExplanation;
    unresolved.text = x.unresolvedItems;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BursarTermClosure>(
    future: future,
    builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(
          child: Text('Unable to load finance closure: ${s.error}'),
        );
      }
      hydrate(s.requireData);
      final x = data!;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(x),
          const SizedBox(height: 20),
          if (x.noFinanceActivity) ...[
            _approvalStatus(x),
            if (x.teacherRecommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _teacherRecommendations(x),
            ],
          ] else if (widget.management)
            _management(x)
          else ...[
            _snapshot(x),
            const SizedBox(height: 18),
            _form(x),
          ],
        ],
      );
      if (widget.embedded) return content;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: content,
            ),
          ),
        ],
      );
    },
  );

  Widget _heading(BursarTermClosure closure) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.start,
    spacing: 16,
    runSpacing: 10,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finance term closure',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            closure.noFinanceActivity
                ? 'Finance closure is not required for this term.'
                : widget.management
                ? 'Review the bursar’s reconciliation and sign off for term closure.'
                : 'Reconcile the term’s finances and submit them for headmaster approval.',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
      if (!widget.management && !closure.noFinanceActivity)
        _status(closure.status),
    ],
  );

  Widget _snapshot(BursarTermClosure x) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fee snapshot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          x.snapshotLocked
              ? 'Figures at submission${x.submittedAt == null ? '.' : ' on ${_dateTime(x.submittedAt!)}.'}'
              : 'Live totals for this term.',
          style: TextStyle(
            color: x.snapshotLocked ? AppColors.green : AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _metrics([
          _metric('Expected fees', x.expectedFees),
          _metric('Collected', x.collectedFees, color: const Color(0xFF17685C)),
          _metric('Waived', x.waivedFees),
          _metric('Adjustments', x.approvedAdjustments),
          _metric(
            'Outstanding',
            x.outstandingFees,
            color: x.outstandingFees > 0
                ? const Color(0xFF9B382E)
                : AppColors.text,
          ),
        ]),
        if (x.pendingAdjustmentCount > 0) ...[
          const SizedBox(height: 14),
          Text(
            '${x.pendingAdjustmentCount} fee adjustment${x.pendingAdjustmentCount == 1 ? ' is' : 's are'} still pending.',
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (x.pendingReversalCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${x.pendingReversalCount} payment reversal${x.pendingReversalCount == 1 ? ' is' : 's are'} still pending approval.',
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if ((x.pendingAdjustmentCount > 0 || x.pendingReversalCount > 0) &&
            widget.onOpenFees != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onOpenFees,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Resolve pending finance actions'),
          ),
        ],
      ],
    ),
  );
  Widget _form(BursarTermClosure x) {
    final locked = x.locked;
    final hasPending =
        x.pendingAdjustmentCount > 0 || x.pendingReversalCount > 0;
    return Column(
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Closure checklist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              _check(
                'I reviewed expected fees, collections, balances, waivers and adjustments.',
                fees,
                (v) => fees = v,
                locked,
                widget.onOpenFees,
              ),
              _check(
                'Payment records are reconciled against cash, bank and mobile money.',
                payments,
                (v) => payments = v,
                locked,
                null,
              ),
              _check(
                'I verified the final petty-cash reconciliation.',
                petty,
                (v) => petty = v,
                locked || x.pettyCashBlocker != null,
                widget.onOpenExpenses,
              ),
              if (x.pettyCashBlocker case final reason?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    reason,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              _check(
                'Teacher recommendations were reviewed and consolidated.',
                recommendations,
                (v) => recommendations = v,
                locked,
                null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _recommendations(locked, x.teacherRecommendations.length),
        const SizedBox(height: 18),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment reconciliation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _money('Cash', cash, locked),
                  _money('Bank', bank, locked),
                  _money('Mobile money', mobile, locked),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final total = _num(cash) + _num(bank) + _num(mobile),
                      diff = total - x.collectedFees;
                  return Text(
                    'Entered total: ${_gh(total)}  •  Difference from recorded collections: ${_gh(diff)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: diff.abs() > .009
                          ? AppColors.red
                          : AppColors.green,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discrepancy,
                enabled: !locked,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      'Discrepancy explanation (required when totals differ)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unresolved financial items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unresolved,
                enabled: !locked,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Record unresolved balances, missing documents, disputed payments or write “None”.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!locked && hasPending) ...[
          _blockingNotice(
            'Submission is blocked until every pending fee adjustment and payment reversal is resolved.',
          ),
          const SizedBox(height: 14),
        ],
        if (!locked)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: saving ? null : () => save(false),
                child: const Text('Save draft'),
              ),
              FilledButton(
                onPressed: saving || hasPending || x.pettyCashBlocker != null
                    ? null
                    : () => save(true),
                child: const Text('Submit for approval'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _recommendations(bool locked, int teacherCount) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next-term item consolidation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$teacherCount teacher recommendation${teacherCount == 1 ? '' : 's'} received. The bursar may change or remove items before approval.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (!locked)
              FilledButton.tonalIcon(
                onPressed: () => _editItem(null),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (data!.teacherRecommendations.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Teacher submissions',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!locked)
                TextButton.icon(
                  onPressed: _copyTeacherRecommendations,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy all to consolidated list'),
                ),
            ],
          ),
          ...data!.teacherRecommendations.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(
                '${item['name'] ?? 'Item'} · ${item['category'] ?? 'Uncategorised'}',
              ),
              subtitle: _recommendationDetails(item),
              trailing: locked
                  ? null
                  : IconButton(
                      tooltip: 'Add to consolidated list',
                      onPressed: () => _copyTeacherRecommendation(item),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Bursar consolidated list',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        if (consolidated.isEmpty)
          const Text('No consolidated items yet.')
        else
          ...List.generate(consolidated.length, (index) {
            final item = consolidated[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${item['name'] ?? 'Item'} · ${item['category'] ?? 'Uncategorised'}',
              ),
              subtitle: _recommendationDetails(item),
              trailing: locked
                  ? null
                  : Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _editItem(index),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => consolidated.removeAt(index)),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
            );
          }),
      ],
    ),
  );

  Widget _recommendationDetails(Map<String, dynamic> item) {
    final description = '${item['description'] ?? ''}'.trim();
    final reason = '${item['reason'] ?? ''}'.trim();
    final unitPrice = _gh(double.tryParse('${item['unitPrice']}') ?? 0);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(description),
            const SizedBox(height: 7),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _recommendationFact('Quantity', '${item['quantity'] ?? 1}'),
              _recommendationFact('Unit price', unitPrice),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Reason: $reason',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recommendationFact(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  void _copyTeacherRecommendations() {
    setState(() {
      for (final item in data!.teacherRecommendations) {
        _addConsolidatedCopy(item);
      }
      recommendations = true;
    });
  }

  void _copyTeacherRecommendation(Map<String, dynamic> item) {
    setState(() {
      _addConsolidatedCopy(item);
      recommendations = true;
    });
  }

  void _addConsolidatedCopy(Map<String, dynamic> source) {
    final copy = Map<String, dynamic>.from(source);
    final duplicate = consolidated.any(
      (item) =>
          '${item['name']}'.trim().toLowerCase() ==
              '${copy['name']}'.trim().toLowerCase() &&
          '${item['category']}'.trim().toLowerCase() ==
              '${copy['category']}'.trim().toLowerCase() &&
          '${item['description']}'.trim().toLowerCase() ==
              '${copy['description']}'.trim().toLowerCase(),
    );
    if (!duplicate) consolidated.add(copy);
  }

  Future<void> _editItem(int? index) async {
    final old = index == null ? <String, dynamic>{} : consolidated[index];
    final name = TextEditingController(text: '${old['name'] ?? ''}');
    final category = TextEditingController(text: '${old['category'] ?? ''}');
    final description = TextEditingController(
      text: '${old['description'] ?? ''}',
    );
    final quantity = TextEditingController(text: '${old['quantity'] ?? 1}');
    final price = TextEditingController(text: '${old['unitPrice'] ?? ''}');
    final reason = TextEditingController(text: '${old['reason'] ?? ''}');
    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Add consolidated item' : 'Edit item'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Item name'),
                ),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated unit price',
                  ),
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Reason needed'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(),
              'category': category.text.trim(),
              'description': description.text.trim(),
              'quantity': int.tryParse(quantity.text) ?? 1,
              'unitPrice': double.tryParse(price.text) ?? 0,
              'reason': reason.text.trim(),
            }),
            child: const Text('Save item'),
          ),
        ],
      ),
    );
    for (final controller in [
      name,
      category,
      description,
      quantity,
      price,
      reason,
    ]) {
      controller.dispose();
    }
    if (item != null && mounted) {
      setState(() {
        if (index == null) {
          consolidated.add(item);
        } else {
          consolidated[index] = item;
        }
      });
    }
  }

  Widget _management(BursarTermClosure closure) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _approvalStatus(closure),
      const SizedBox(height: 16),
      _snapshot(closure),
      if (closure.locked) ...[
        const SizedBox(height: 16),
        _submittedDetails(closure),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (closure.status == 'SUBMITTED') ...[
              OutlinedButton.icon(
                onPressed: saving ? null : returnToBursar,
                icon: const Icon(Icons.undo),
                label: const Text('Return to bursar'),
              ),
              FilledButton.icon(
                onPressed: saving || closure.pettyCashBlocker != null
                    ? null
                    : approve,
                icon: const Icon(Icons.check),
                label: const Text('Approve finance closure'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: saving ? null : reopen,
                icon: const Icon(Icons.lock_open),
                label: const Text('Reopen approved closure'),
              ),
          ],
        ),
      ],
    ],
  );

  Widget _teacherRecommendations(BursarTermClosure closure) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teacher recommendations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        for (final item in closure.teacherRecommendations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lightbulb_outline),
            title: Text('${item['name'] ?? 'Item'}'),
            subtitle: _recommendationDetails(item),
          ),
      ],
    ),
  );

  Widget _approvalStatus(BursarTermClosure closure) {
    final (title, detail, icon, color, background) = switch (closure.status) {
      'NO_FINANCE_ACTIVITY' => (
        'Not applicable',
        'No finance activity was confirmed for this term.',
        Icons.remove_circle_outline,
        AppColors.muted,
        AppColors.background,
      ),
      'SUBMITTED' => (
        'Ready for your review',
        'Review the submitted figures and unresolved items before approving.',
        Icons.fact_check_outlined,
        const Color(0xFF174A91),
        const Color(0xFFEDF3FF),
      ),
      'APPROVED' => (
        'Finance closure approved',
        'Finance is signed off on the term closure checklist.',
        Icons.verified_outlined,
        const Color(0xFF17685C),
        AppColors.greenSoft,
      ),
      'DRAFT' => (
        'Bursar preparing the closure',
        'Approval becomes available when the bursar submits the reconciliation.',
        Icons.edit_note_outlined,
        const Color(0xFF854B0A),
        const Color(0xFFFFF3DC),
      ),
      _ => (
        'Waiting for the bursar',
        'The bursar needs to reconcile the term’s payments and petty cash and submit the closure.',
        Icons.schedule_outlined,
        const Color(0xFF475467),
        AppColors.background,
      ),
    };
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(color: Color(0xFF475467)),
                    ),
                    if (closure.approvedAt case final approvedAt?) ...[
                      const SizedBox(height: 4),
                      Text('Approved on ${_dateTime(approvedAt)}'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (closure.reviewReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Latest review note',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(closure.reviewReason),
          ],
          if (closure.pettyCashBlocker case final blocker?) ...[
            const SizedBox(height: 14),
            _blockingNotice(blocker),
          ],
        ],
      ),
    );
  }

  Future<void> save(bool submit) async {
    final total = _num(cash) + _num(bank) + _num(mobile),
        diff = total - (data?.collectedFees ?? 0);
    if (submit && diff.abs() > .009 && discrepancy.text.trim().isEmpty) {
      notice('Explain the reconciliation difference before submitting.');
      return;
    }
    if (submit && unresolved.text.trim().isEmpty) {
      notice('State unresolved items or enter “None”.');
      return;
    }
    final i = BursarTermClosureInput(
      actorUserId: widget.actorUserId,
      feesReviewed: fees,
      paymentsReconciled: payments,
      pettyCashClosed: petty,
      recommendationsReviewed: recommendations,
      cashTotal: _num(cash),
      bankTotal: _num(bank),
      mobileMoneyTotal: _num(mobile),
      discrepancyExplanation: discrepancy.text.trim(),
      unresolvedItems: unresolved.text.trim(),
      consolidatedRecommendations: consolidated,
    );
    await run(
      () => submit
          ? widget.repository.submit(widget.schoolId, i)
          : widget.repository.saveDraft(widget.schoolId, i),
      submit ? 'Finance closure submitted.' : 'Draft saved.',
    );
  }

  Future<void> approve() => run(
    () => widget.repository.approve(
      widget.schoolId,
      actorUserId: widget.actorUserId,
    ),
    'Finance closure approved.',
  );
  Future<void> returnToBursar() async {
    final reason = await _reason('Return finance closure', 'Return to bursar');
    if (!mounted || reason == null) return;
    await run(
      () => widget.repository.returnToBursar(
        widget.schoolId,
        actorUserId: widget.actorUserId,
        reason: reason,
      ),
      'Finance closure returned to the bursar.',
    );
  }

  Future<void> reopen() async {
    final reason = await _reason('Reopen approved closure', 'Reopen');
    if (mounted && reason != null) {
      await run(
        () => widget.repository.reopen(
          widget.schoolId,
          actorUserId: widget.actorUserId,
          reason: reason,
        ),
        'Finance closure reopened.',
      );
    }
  }

  Future<String?> _reason(String title, String action) {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => setDialogState(() => reason = value.trim()),
            decoration: const InputDecoration(labelText: 'Reason (required)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: reason.length >= 5
                  ? () => Navigator.pop(context, reason)
                  : null,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submittedDetails(BursarTermClosure closure) {
    final hasDifference = closure.difference.abs() > .009;
    final reconciliation = _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment reconciliation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _amountRow('Cash', closure.cashTotal),
          _amountRow('Bank', closure.bankTotal),
          _amountRow('Mobile money', closure.mobileMoneyTotal),
          const Divider(height: 16, color: AppColors.border),
          _amountRow(
            'Reconciled total',
            closure.reconciliationTotal,
            emphasized: true,
          ),
          _amountRow(
            'Difference from recorded collections',
            closure.difference,
            emphasized: true,
            color: hasDifference ? const Color(0xFF9B382E) : AppColors.text,
          ),
          if (closure.discrepancyExplanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Discrepancy explanation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(closure.discrepancyExplanation),
          ],
        ],
      ),
    );
    final followUp = _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unresolved financial items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            closure.unresolvedItems.isEmpty
                ? 'None recorded.'
                : closure.unresolvedItems,
          ),
          const Divider(height: 32, color: AppColors.border),
          const Text(
            'Next-term recommendations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (closure.consolidatedRecommendations.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No next-term items submitted.'),
          ],
          for (final item in closure.consolidatedRecommendations)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _recommendationDetails(item),
                ],
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 780
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: reconciliation),
                const SizedBox(width: 16),
                Expanded(child: followUp),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [reconciliation, const SizedBox(height: 16), followUp],
            ),
    );
  }

  Widget _amountRow(
    String label,
    double amount, {
    bool emphasized = false,
    Color color = AppColors.text,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            _gh(amount),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _blockingNotice(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
    ),
  );

  Future<void> run(
    Future<BursarTermClosure> Function() action,
    String message,
  ) async {
    setState(() => saving = true);
    try {
      final x = await action();
      if (!mounted) return;
      setState(() {
        data = x;
        saving = false;
      });
      notice(message);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        notice('$e');
      }
    }
  }

  void notice(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  Widget _check(
    String t,
    bool v,
    void Function(bool) set,
    bool locked,
    VoidCallback? open,
  ) => Row(
    children: [
      Expanded(
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: v,
          onChanged: locked ? null : (x) => setState(() => set(x ?? false)),
          title: Text(t),
        ),
      ),
      if (open != null)
        TextButton(onPressed: open, child: const Text('Review')),
    ],
  );
  Widget _money(String l, TextEditingController c, bool locked) => SizedBox(
    width: 220,
    child: TextField(
      controller: c,
      enabled: !locked,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: l, prefixText: 'GH₵ '),
    ),
  );
  Widget _metrics(List<Widget> metrics) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 730
          ? 5
          : width >= 460
          ? 3
          : width >= 210
          ? 2
          : 1;
      const gap = 10.0;
      final tileWidth = (width - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metric in metrics)
            SizedBox(width: tileWidth, child: metric),
        ],
      );
    },
  );

  Widget _metric(String label, double value, {Color color = AppColors.text}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF475467))),
            const SizedBox(height: 5),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _gh(value),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(Widget c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: c,
  );
  Widget _status(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      s.replaceAll('_', ' '),
      style: const TextStyle(
        color: AppColors.green,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;
  String _plain(double v) => v == 0 ? '' : v.toStringAsFixed(2);
  String _gh(double v) => 'GH₵ ${v.toStringAsFixed(2)}';
  String _dateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} at ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
