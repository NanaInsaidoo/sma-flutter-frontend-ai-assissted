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
  });
  final String schoolId;
  final BursarTermClosureRepository repository;
  final int? actorUserId;
  final bool management;
  final VoidCallback? onOpenFees, onOpenExpenses;
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance term closure',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Reconcile the term’s finances and submit them for headmaster approval.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _status(x.status),
            ],
          ),
          const SizedBox(height: 20),
          _snapshot(x),
          const SizedBox(height: 18),
          if (widget.management) _management(x) else _form(x),
        ],
      );
    },
  );
  Widget _snapshot(BursarTermClosure x) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System-generated finance snapshot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          x.snapshotLocked
              ? 'Locked when the bursar submitted this closure${x.submittedAt == null ? '.' : ' on ${_dateTime(x.submittedAt!)}.'}'
              : 'Live figures — the values update as transactions change.',
          style: TextStyle(
            color: x.snapshotLocked ? AppColors.green : AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric('Expected fees', x.expectedFees),
            _metric('Collected', x.collectedFees, color: AppColors.green),
            _metric('Waived', x.waivedFees),
            _metric('Adjustments', x.approvedAdjustments),
            _metric(
              'Outstanding',
              x.outstandingFees,
              color: x.outstandingFees > 0 ? AppColors.red : AppColors.green,
            ),
          ],
        ),
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
                'The final petty-cash cycle is closed and balanced.',
                petty,
                (v) => petty = v,
                locked,
                widget.onOpenExpenses,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: saving ? null : () => save(false),
                child: const Text('Save draft'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: saving || hasPending ? null : () => save(true),
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
        if (consolidated.isEmpty)
          const Text('No items have been recommended.')
        else
          ...List.generate(consolidated.length, (index) {
            final item = consolidated[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${item['name'] ?? 'Item'} · ${item['category'] ?? 'Uncategorised'}',
              ),
              subtitle: Text(
                '${item['description'] ?? ''}\nQty ${item['quantity'] ?? 1} · ${_gh(double.tryParse('${item['unitPrice']}') ?? 0)} each · ${item['reason'] ?? ''}',
              ),
              isThreeLine: true,
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

  Widget _management(BursarTermClosure x) => Column(
    children: [
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Headmaster approval',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              x.status == 'NOT_STARTED'
                  ? 'The bursar has not started the closure.'
                  : x.status == 'DRAFT'
                  ? 'The bursar is still preparing the closure.'
                  : x.status == 'SUBMITTED'
                  ? 'The finance closure is ready for your review.'
                  : 'The finance closure is approved.',
            ),
            const SizedBox(height: 14),
            if (x.status == 'SUBMITTED')
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: saving ? null : approve,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve finance closure'),
                  ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : returnToBursar,
                    icon: const Icon(Icons.undo),
                    label: const Text('Return to bursar'),
                  ),
                ],
              ),
            if (x.status == 'APPROVED')
              TextButton.icon(
                onPressed: saving ? null : reopen,
                icon: const Icon(Icons.lock_open),
                label: const Text('Reopen approved closure'),
              ),
            if (x.reviewReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Latest review note: ${x.reviewReason}'),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      _reviewDetails(x),
    ],
  );
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
    if (reason == null) return;
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
    if (reason != null) {
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

  Future<String?> _reason(String title, String action) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason (required)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = c.text.trim();
              if (value.length >= 5) Navigator.pop(x, value);
            },
            child: Text(action),
          ),
        ],
      ),
    );
    c.dispose();
    return reason;
  }

  Widget _reviewDetails(BursarTermClosure x) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submitted details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Reconciled: ${_gh(x.reconciliationTotal)}  •  Difference: ${_gh(x.difference)}',
        ),
        if (x.discrepancyExplanation.isNotEmpty)
          Text('Explanation: ${x.discrepancyExplanation}'),
        const SizedBox(height: 10),
        Text(
          'Unresolved matters: ${x.unresolvedItems.isEmpty ? 'Not stated' : x.unresolvedItems}',
        ),
        const SizedBox(height: 10),
        Text(
          '${x.consolidatedRecommendations.length} next-term item recommendation${x.consolidatedRecommendations.length == 1 ? '' : 's'} consolidated.',
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
  Widget _metric(String l, double v, {Color color = AppColors.text}) =>
      Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 5),
            Text(
              _gh(v),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
  Widget _card(Widget c) => Container(
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
