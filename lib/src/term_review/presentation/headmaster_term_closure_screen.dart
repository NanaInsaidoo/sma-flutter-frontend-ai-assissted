import 'package:flutter/material.dart';
import '../../platform/presentation/document_opener.dart';
import '../../theme/app_theme.dart';
import '../domain/headmaster_term_closure_models.dart';

class HeadmasterTermClosureScreen extends StatefulWidget {
  const HeadmasterTermClosureScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.actorUserId,
    this.onTermTransitioned,
  });
  final String schoolId;
  final HeadmasterTermClosureRepository repository;
  final int? actorUserId;
  final VoidCallback? onTermTransitioned;
  @override
  State<HeadmasterTermClosureScreen> createState() => _State();
}

class _State extends State<HeadmasterTermClosureScreen> {
  late Future<HeadmasterTermClosure> future;
  HeadmasterTermClosure? data;
  Map<String, String> acknowledgements = {};
  final Map<String, TextEditingController> warningControllers = {};
  bool inspection = false, saving = false;
  final condition = TextEditingController(),
      damages = TextEditingController(),
      actions = TextEditingController();
  @override
  void initState() {
    super.initState();
    future = widget.repository.get(widget.schoolId);
  }

  @override
  void dispose() {
    condition.dispose();
    damages.dispose();
    actions.dispose();
    for (final controller in warningControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void hydrate(HeadmasterTermClosure x) {
    if (data != null) return;
    data = x;
    acknowledgements = Map.of(x.acknowledgements);
    for (final item in x.items.where((item) => item.warning)) {
      warningControllers[item.key] = TextEditingController(
        text: acknowledgements[item.key] ?? '',
      );
    }
    inspection = x.facilities['inspectionCompleted'] == true;
    condition.text = '${x.facilities['overallCondition'] ?? ''}';
    damages.text = '${x.facilities['damageDetails'] ?? ''}';
    actions.text = '${x.facilities['requiredActions'] ?? ''}';
  }

  Future<void> _reloadCurrentTerm() async {
    final refreshed = await widget.repository.get(widget.schoolId);
    if (!mounted) return;
    final previousWarningControllers = warningControllers.values.toList();
    warningControllers.clear();
    setState(() {
      data = null;
      future = Future.value(refreshed);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in previousWarningControllers) {
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HeadmasterTermClosure>(
    future: future,
    builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(child: Text('Unable to load term readiness: ${s.error}'));
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
                      'Term readiness and closure',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Resolve blockers, acknowledge warnings and preserve the final term snapshot.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _badge(
                x.termClosed
                    ? 'CLOSED'
                    : x.readyToClose
                    ? 'READY TO CLOSE'
                    : 'ACTION REQUIRED',
                x.termClosed || x.readyToClose
                    ? AppColors.green
                    : AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _summary(x),
          const SizedBox(height: 18),
          ...x.items.map(_item),
          const SizedBox(height: 18),
          _transition(x),
          const SizedBox(height: 18),
          _facilities(x.termClosed),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save closure draft'),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : openReport,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate management report'),
              ),
              FilledButton.icon(
                onPressed: saving || x.termClosed || !x.readyToClose
                    ? null
                    : closeTerm,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Close term and begin next term'),
              ),
            ],
          ),
        ],
      );
    },
  );
  Widget _transition(HeadmasterTermClosure x) {
    final p = x.transitionPreview;
    if (p.isEmpty) return const SizedBox.shrink();
    final available = p['available'] == true;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next operational term',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            available
                ? '${p['nextTermName'] ?? 'Next term'} will begin operationally when this term closes.'
                : '${p['detail'] ?? 'Configure the next term before closing.'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (available) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _transitionValue(
                  'Operational start',
                  _displayDate(p['operationalStartDate']),
                ),
                _transitionValue(
                  'Teaching begins',
                  _displayDate(p['teachingStartDate']),
                ),
                _transitionValue('Students', '${p['students'] ?? 0}'),
                _transitionValue(
                  'Balances forward',
                  'GH₵${p['balancesToCarryForward'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Vacation admissions, fees and payments will use the next term. Academic records created before teaching begins will require a warning acknowledgement and reason.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _transitionValue(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
  Widget _summary(HeadmasterTermClosure x) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Closure overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Ready',
              x.items.where((e) => e.ready).length,
              AppColors.green,
            ),
            _metric(
              'Blockers',
              x.items.where((e) => e.severity == 'BLOCKER' && !e.ready).length,
              AppColors.red,
            ),
            _metric(
              'Warnings',
              x.items.where((e) => e.warning).length,
              AppColors.amber,
            ),
            _metric(
              'Students',
              int.tryParse('${x.summary['students']}') ?? 0,
              AppColors.blue,
            ),
          ],
        ),
      ],
    ),
  );
  Widget _item(TermClosureItem item) {
    final color = item.ready
        ? AppColors.green
        : item.severity == 'BLOCKER'
        ? AppColors.red
        : AppColors.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.ready
                      ? Icons.check_circle_outline
                      : item.severity == 'BLOCKER'
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _badge(item.status.replaceAll('_', ' '), color),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.detail, style: const TextStyle(color: AppColors.muted)),
            if (item.warning) ...[
              const SizedBox(height: 10),
              TextField(
                enabled: data?.termClosed != true,
                controller: warningControllers[item.key],
                onChanged: (v) => acknowledgements[item.key] = v,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for accepting this warning before closure',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _facilities(bool locked) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Facilities inspection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const Text(
          'This may be completed after students are dismissed. If left incomplete, acknowledge the warning above.',
          style: TextStyle(color: AppColors.muted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: inspection,
          onChanged: locked ? null : (v) => setState(() => inspection = v),
          title: const Text('Inspection completed'),
        ),
        if (inspection) ...[
          TextField(
            controller: condition,
            enabled: !locked,
            decoration: const InputDecoration(labelText: 'Overall condition'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: damages,
            enabled: !locked,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Damage or loss found',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: actions,
            enabled: !locked,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Required repairs or actions',
            ),
          ),
        ],
      ],
    ),
  );
  HeadmasterTermClosureInput input({String? confirmation}) =>
      HeadmasterTermClosureInput(
        actorUserId: widget.actorUserId,
        acknowledgements: acknowledgements,
        facilities: {
          'inspectionCompleted': inspection,
          'overallCondition': condition.text.trim(),
          'damageDetails': damages.text.trim(),
          'requiredActions': actions.text.trim(),
        },
        confirmation: confirmation,
      );
  Future<void> saveDraft() => run(
    () => widget.repository.saveDraft(widget.schoolId, input()),
    'Closure draft saved.',
  );
  Future<void> closeTerm() async {
    final c = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('Close this term and begin the next term?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This preserves the immutable closing snapshot, applies approved promotions, carries outstanding balances forward, assigns published next-term fees and makes ${data?.transitionPreview['nextTermName'] ?? 'the next term'} operational for vacation admissions and payments.',
            ),
            const SizedBox(height: 8),
            Text(
              'Teaching begins ${_displayDate(data?.transitionPreview['teachingStartDate'])}. Academic activity before then remains available with a warning and mandatory reason.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Type CLOSE TERM to continue.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Confirmation'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, c.text.trim() == 'CLOSE TERM'),
            child: const Text('Close term and begin next term'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    if (confirmed == true) {
      await run(
        () => widget.repository.close(
          widget.schoolId,
          input(confirmation: 'CLOSE TERM'),
        ),
        'The term is closed and the next term is operational.',
      );
      if (mounted && data?.transition.isNotEmpty == true) {
        await _showTransitionComplete();
        await _reloadCurrentTerm();
        widget.onTermTransitioned?.call();
      }
    }
  }

  Future<void> _showTransitionComplete() => showDialog<void>(
    context: context,
    builder: (context) {
      final t = data!.transition;
      return AlertDialog(
        title: const Text('Term transition completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t['nextTermName'] ?? 'The next term'} is now the operational term.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '${t['studentsTransitioned'] ?? 0} student placements applied',
            ),
            Text('GH₵${t['balanceAmount'] ?? 0} carried forward'),
            Text(
              '${t['nextTermFeeLinesAssigned'] ?? 0} next-term fee lines assigned',
            ),
            const SizedBox(height: 10),
            const Text(
              'Vacation admissions, fees and payments are available. Academic activity before teaching starts will show a warning and require a reason.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );

  Future<void> openReport() async {
    prepareDocumentWindow();
    try {
      final bytes = await widget.repository.downloadReport(widget.schoolId);
      await openDocumentBytes(
        bytes,
        'application/pdf',
        'term-management-report.pdf',
      );
    } catch (e) {
      notice('$e');
    }
  }

  Future<void> run(
    Future<HeadmasterTermClosure> Function() action,
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
  Widget _metric(String l, int v, Color c) => Container(
    width: 170,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: const TextStyle(color: AppColors.muted)),
        Text(
          '$v',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c),
        ),
      ],
    ),
  );
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );

  String _displayDate(dynamic value) {
    if (value == null) return '—';
    if (value is List && value.length >= 3) {
      final year = int.tryParse('${value[0]}');
      final month = int.tryParse('${value[1]}');
      final day = int.tryParse('${value[2]}');
      if (year != null && month != null && day != null) {
        return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }
    final text = '$value';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}
