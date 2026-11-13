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
    this.onOpenTermDates,
    this.onEditCurrentTermDates,
    this.onSetUpNextTerm,
    this.onBeginNextTerm,
    this.onOpenFees,
    this.onOpenFacilities,
    this.onConfirmNoFinanceActivity,
    this.embedded = false,
    this.workstreamActions = const {},
  });
  final String schoolId;
  final HeadmasterTermClosureRepository repository;
  final int? actorUserId;
  final VoidCallback? onTermTransitioned;
  final Future<bool> Function()? onOpenTermDates;
  final Future<bool> Function(int termId)? onEditCurrentTermDates;
  final Future<bool> Function(int termId)? onSetUpNextTerm;
  final Future<Map<String, dynamic>> Function(int closedTermId, int nextTermId)?
  onBeginNextTerm;
  final ValueChanged<int>? onOpenFees;
  final VoidCallback? onOpenFacilities;
  final Future<HeadmasterTermClosure> Function(int termId)?
  onConfirmNoFinanceActivity;
  final bool embedded;
  final Map<String, VoidCallback> workstreamActions;
  @override
  State<HeadmasterTermClosureScreen> createState() => _State();
}

class _State extends State<HeadmasterTermClosureScreen> {
  static const _tableHeaderStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: .4,
  );
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
    if (saving) return;
    setState(() => saving = true);
    try {
      final refreshed = await widget.repository.get(widget.schoolId);
      if (!mounted) return;
      final previousWarningControllers = warningControllers.values.toList();
      warningControllers.clear();
      setState(() {
        data = null;
        future = Future.value(refreshed);
        saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in previousWarningControllers) {
          controller.dispose();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      notice('$e');
    }
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
      final content = _dashboard(x);
      if (widget.embedded) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: content,
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
        children: [content],
      );
    },
  );

  bool _setupPending(HeadmasterTermClosure closure) =>
      closure.termClosed && closure.transition['status'] == 'PENDING_SETUP';

  Widget _dashboard(HeadmasterTermClosure x) {
    if (_setupPending(x)) return _pendingSetup(x);
    final blockers = x.items
        .where((item) => item.severity == 'BLOCKER' && !item.ready)
        .toList();
    final pendingWarnings = x.items
        .where((item) => item.warning && !_isReviewedWarning(item))
        .length;
    final scheduled = blockers.where(_isScheduleItem).length;
    final actionableBlockers = blockers.length - scheduled;
    final scheduledOnly =
        !x.termClosed &&
        scheduled > 0 &&
        actionableBlockers == 0 &&
        pendingWarnings == 0;
    final transitionChecks = x.items.where(_isTransitionCheck).toList();
    final otherChecks = x.items
        .where((item) => !_isTransitionCheck(item))
        .toList();
    final showTransition =
        transitionChecks.isNotEmpty || x.transitionPreview.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(x, scheduledOnly),
        const SizedBox(height: 20),
        _summary(x, scheduledOnly),
        const SizedBox(height: 24),
        if (showTransition) ...[
          _transition(x, transitionChecks),
          const SizedBox(height: 24),
        ],
        _sectionHeading(
          showTransition ? 'Other closure actions' : 'All closure actions',
          'Open an action to review or complete it.',
        ),
        const SizedBox(height: 12),
        _actionRegister(otherChecks),
        const SizedBox(height: 24),
        _sectionHeading(
          'Final closure',
          'Review the checklist and save the closing record for this term.',
        ),
        const SizedBox(height: 12),
        _closurePanel(
          x,
          actionableBlockers,
          pendingWarnings,
          scheduledOnly: scheduledOnly,
        ),
      ],
    );
  }

  Widget _header(HeadmasterTermClosure x, bool scheduledOnly) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Term Closure Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'See every closure action, its status and where to complete the work.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      );
      final controls = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _badge(
            _statusLabel(x, scheduledOnly),
            _statusColor(x, scheduledOnly),
          ),
          IconButton.outlined(
            tooltip: 'Recheck readiness',
            onPressed: saving ? null : _reloadCurrentTerm,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
      if (constraints.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 14), controls],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          controls,
        ],
      );
    },
  );

  String _statusLabel(HeadmasterTermClosure x, bool scheduledOnly) =>
      x.termClosed
      ? 'CLOSED'
      : x.readyToClose
      ? 'READY TO CLOSE'
      : scheduledOnly
      ? 'CLOSURE SCHEDULED'
      : 'ACTION REQUIRED';

  Color _statusColor(HeadmasterTermClosure x, bool scheduledOnly) {
    if (x.termClosed || x.readyToClose) return AppColors.green;
    if (scheduledOnly) return AppColors.blue;
    final hasBlockers = x.items.any(
      (item) =>
          item.severity == 'BLOCKER' && !item.ready && !_isScheduleItem(item),
    );
    return hasBlockers ? AppColors.red : AppColors.amber;
  }

  Widget _summary(HeadmasterTermClosure x, bool scheduledOnly) {
    final ready = x.items
        .where((item) => item.ready || _isReviewedWarning(item))
        .length;
    final total = x.items.length;
    final blockers = x.items
        .where(
          (item) =>
              item.severity == 'BLOCKER' &&
              !item.ready &&
              !_isScheduleItem(item),
        )
        .length;
    final warnings = x.items
        .where((item) => item.warning && !_isReviewedWarning(item))
        .length;
    final reviewedWarnings = x.items.where(_isReviewedWarning).length;
    final scheduled = x.items
        .where((item) => !item.ready && _isScheduleItem(item))
        .length;
    final progress = total == 0 ? 0.0 : ready / total;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  x.termClosed
                      ? 'This term is closed'
                      : x.readyToClose
                      ? 'Everything is ready'
                      : '$ready of $total actions complete',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _statusColor(x, scheduledOnly),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: _statusColor(x, scheduledOnly),
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip(
                Icons.list_alt_rounded,
                '$total all actions',
                AppColors.blue,
              ),
              _summaryChip(
                Icons.check_circle_outline,
                '$ready cleared',
                AppColors.green,
              ),
              if (blockers > 0)
                _summaryChip(
                  Icons.error_outline,
                  '$blockers need attention',
                  AppColors.red,
                ),
              if (reviewedWarnings > 0)
                _summaryChip(
                  Icons.fact_check_outlined,
                  '$reviewedWarnings reviewed',
                  AppColors.green,
                ),
              if (warnings > 0)
                _summaryChip(
                  Icons.warning_amber_rounded,
                  '$warnings need review',
                  AppColors.amber,
                ),
              if (scheduled > 0)
                _summaryChip(
                  Icons.schedule_rounded,
                  '$scheduled scheduled',
                  AppColors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _sectionHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
    ],
  );

  Widget _actionRegister(List<TermClosureItem> items) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 820;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (!compact) _actionTableHeader(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No closure actions are available for this term.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              for (var i = 0; i < items.length; i++)
                _actionRow(
                  items[i],
                  compact: compact,
                  showDivider: i < items.length - 1,
                ),
          ],
        ),
      );
    },
  );

  Widget _actionTableHeader() => Container(
    color: AppColors.background,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    child: const Row(
      children: [
        SizedBox(width: 34),
        Expanded(flex: 5, child: Text('ACTION', style: _tableHeaderStyle)),
        Expanded(flex: 2, child: Text('AREA', style: _tableHeaderStyle)),
        SizedBox(width: 148, child: Text('STATUS', style: _tableHeaderStyle)),
        SizedBox(width: 215),
      ],
    ),
  );

  Widget _actionRow(
    TermClosureItem item, {
    required bool compact,
    required bool showDivider,
  }) {
    final status = _actionStatus(item);
    final color = _actionStatusColor(status);
    final isFacilities = item.key == 'FACILITIES';
    final VoidCallback? openWorkstream = isFacilities
        ? widget.onOpenFacilities ?? _openFacilitiesDialog
        : widget.workstreamActions[item.key];
    final VoidCallback? reviewWarning = item.warning
        ? () => _openWarning(item)
        : null;
    final action = reviewWarning ?? (isFacilities ? null : openWorkstream);
    final title = _actionTitle(item.label, openWorkstream ?? reviewWarning);
    final showFinanceOptions =
        item.key == 'FINANCE' &&
        !item.ready &&
        item.canConfirmNoFinanceActivity &&
        data?.termClosed == false &&
        widget.onConfirmNoFinanceActivity != null;
    final buttons = [
      if (isFacilities)
        OutlinedButton.icon(
          onPressed: openWorkstream,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Open inspection'),
        ),
      if (action != null)
        TextButton.icon(
          onPressed: action,
          icon: Icon(
            item.ready
                ? Icons.visibility_outlined
                : Icons.arrow_forward_rounded,
            size: 18,
          ),
          label: Text(_actionLabel(item)),
        ),
      if (showFinanceOptions)
        PopupMenuButton<String>(
          enabled: !saving,
          tooltip: 'Finance options',
          icon: const Icon(Icons.more_horiz),
          onSelected: (_) => _confirmNoFinanceActivity(),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'confirm',
              child: Text('Confirm no finance activity'),
            ),
          ],
        ),
    ];
    final decoration = showDivider
        ? const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          )
        : null;
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _actionStatusIcon(status),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: title),
                const SizedBox(width: 8),
                _badge(status, color),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                item.detail,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      _actionArea(item),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ...buttons,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: decoration,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(_actionStatusIcon(status), color: color, size: 22),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _actionArea(item),
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 148, child: Align(child: _badge(status, color))),
          SizedBox(
            width: 215,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: buttons,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTitle(String label, VoidCallback? onPressed) {
    if (onPressed == null) {
      return Text(label, style: const TextStyle(fontWeight: FontWeight.w800));
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  String _actionStatus(TermClosureItem item) {
    if (item.noFinanceActivity) return 'Not applicable';
    if (item.ready) return 'Complete';
    if (_isScheduleItem(item)) return 'Scheduled';
    if (_isReviewedWarning(item)) return 'Reviewed';
    if (item.warning) return 'Needs review';
    final value = '${item.status} ${item.detail}'.toLowerCase();
    if (value.contains('not_started') || value.contains('not started')) {
      return 'Not started';
    }
    if (value.contains('in_progress') ||
        value.contains('in progress') ||
        value.contains('draft')) {
      return 'In progress';
    }
    return 'Needs attention';
  }

  bool _isScheduleItem(TermClosureItem item) {
    final key = item.key.toUpperCase();
    final label = item.label.toLowerCase();
    return key.contains('CLOSING_DATE') || label.contains('closing date');
  }

  bool _isTransitionCheck(TermClosureItem item) =>
      _isScheduleItem(item) || item.key == 'NEXT_TERM';

  bool _isReviewedWarning(TermClosureItem item) =>
      item.warning && (acknowledgements[item.key]?.trim().length ?? 0) >= 5;

  Color _actionStatusColor(String status) => switch (status) {
    'Complete' || 'Reviewed' => AppColors.green,
    'Not applicable' => AppColors.muted,
    'Scheduled' || 'In progress' => AppColors.blue,
    'Needs review' => AppColors.amber,
    'Not started' => AppColors.muted,
    _ => AppColors.red,
  };

  IconData _actionStatusIcon(String status) => switch (status) {
    'Complete' => Icons.check_circle_rounded,
    'Not applicable' => Icons.remove_circle_outline_rounded,
    'Reviewed' => Icons.fact_check_rounded,
    'Scheduled' => Icons.schedule_rounded,
    'In progress' => Icons.pending_rounded,
    'Needs review' => Icons.warning_amber_rounded,
    'Not started' => Icons.radio_button_unchecked_rounded,
    _ => Icons.error_rounded,
  };

  String _actionArea(TermClosureItem item) {
    final key = item.key.toUpperCase();
    if (key.contains('TEACHER') ||
        key.contains('REPORT') ||
        key.contains('EVALUATION')) {
      return 'Academic';
    }
    if (key.contains('ATTENDANCE')) return 'Attendance';
    if (key.contains('FINANCE')) return 'Finance';
    if (key.contains('STAFF')) return 'Staff';
    if (key.contains('INCIDENT')) return 'Student welfare';
    if (key.contains('FACILIT')) return 'Operations';
    if (key.contains('DATE') || item.label.toLowerCase().contains('date')) {
      return 'Schedule';
    }
    return 'Term closure';
  }

  String _actionLabel(TermClosureItem item) {
    final key = item.key.toUpperCase();
    if (item.warning) return 'Review warning';
    if (item.ready) return 'View';
    if (key.contains('TEACHER')) return 'Review teachers';
    if (key.contains('FINANCE')) {
      return _actionStatus(item) == 'Not started'
          ? 'Start closure'
          : 'Continue closure';
    }
    if (key.contains('STAFF_REVIEWS')) return 'Review staff';
    if (key.contains('EVALUATION')) return 'Approve evaluations';
    if (key.contains('REPORT_CORRECTION')) return 'Review corrections';
    if (key.contains('REPORT')) return 'Review reports';
    if (key.contains('ATTENDANCE')) return 'Review attendance';
    if (key.contains('INCIDENT')) return 'Review incidents';
    return 'Go to area';
  }

  Future<void> _confirmNoFinanceActivity() async {
    final confirm = widget.onConfirmNoFinanceActivity;
    final termId = data?.termId;
    if (saving || confirm == null || termId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm no finance activity'),
        content: const SizedBox(
          width: 416,
          child: Text(
            'Confirm this term had no fee charges, payments, expenses or '
            'petty-cash setup. The app will check the term’s records before '
            'marking Finance and petty cash as not applicable.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || saving) return;
    await run(() => confirm(termId), 'No finance activity confirmed.');
  }

  Future<void> _openWarning(TermClosureItem item) async {
    final controller = warningControllers.putIfAbsent(
      item.key,
      () => TextEditingController(text: acknowledgements[item.key] ?? ''),
    );
    final locked = data?.termClosed == true;
    final areaAction = widget.workstreamActions[item.key];
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item.label),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.detail,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  enabled: !locked,
                  autofocus: !locked,
                  maxLines: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Reason for accepting this warning',
                    helperText: 'Required if the warning remains at closure.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(locked ? 'Close' : 'Cancel'),
            ),
            if (areaAction != null)
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'area'),
                child: const Text('Open work area'),
              ),
            if (!locked)
              FilledButton(
                onPressed: controller.text.trim().length < 5
                    ? null
                    : () => Navigator.pop(context, 'save'),
                child: const Text('Save acknowledgement'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'area') {
      areaAction?.call();
    } else if (result == 'save') {
      acknowledgements[item.key] = controller.text.trim();
      await saveDraft();
    }
  }

  Future<void> _openFacilitiesDialog() async {
    var inspectionValue = inspection;
    final conditionController = TextEditingController(text: condition.text);
    final damagesController = TextEditingController(text: damages.text);
    final actionsController = TextEditingController(text: actions.text);
    final locked = data?.termClosed == true;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Facilities inspection'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record the final condition of the school facilities.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: inspectionValue,
                    onChanged: locked
                        ? null
                        : (value) =>
                              setDialogState(() => inspectionValue = value),
                    title: const Text(
                      'Inspection completed',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (inspectionValue) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: conditionController,
                      enabled: !locked,
                      decoration: const InputDecoration(
                        labelText: 'Overall condition',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: damagesController,
                      enabled: !locked,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Damage or loss found',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: actionsController,
                      enabled: !locked,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Required repairs or actions',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(locked ? 'Close' : 'Cancel'),
            ),
            if (!locked)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save inspection'),
              ),
          ],
        ),
      ),
    );
    if (shouldSave == true && mounted) {
      setState(() {
        inspection = inspectionValue;
        condition.text = conditionController.text;
        damages.text = damagesController.text;
        actions.text = actionsController.text;
      });
      await saveDraft();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      conditionController.dispose();
      damagesController.dispose();
      actionsController.dispose();
    });
  }

  Future<void> _openTermDates() async {
    final changed = await widget.onOpenTermDates?.call() ?? false;
    if (!changed || !mounted) return;
    notice('Next term dates updated.');
    await _reloadCurrentTerm();
  }

  Future<void> _editCurrentTermDates(int termId) async {
    final edit = widget.onEditCurrentTermDates;
    if (edit == null || saving) return;
    setState(() => saving = true);
    bool changed;
    try {
      changed = await edit(termId);
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted || !changed) return;
    await _reloadCurrentTerm();
    if (mounted) notice('Current term dates updated.');
  }

  Widget _closurePanel(
    HeadmasterTermClosure x,
    int blockerCount,
    int warningCount, {
    required bool scheduledOnly,
  }) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: x.readyToClose ? AppColors.greenSoft : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                x.termClosed
                    ? Icons.lock_rounded
                    : x.readyToClose
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                color: x.termClosed || x.readyToClose
                    ? AppColors.green
                    : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _closureMessage(x, blockerCount, warningCount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : openReport,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Management report'),
            ),
            FilledButton.icon(
              onPressed: saving || x.termClosed
                  ? null
                  : x.readyToClose
                  ? closeTerm
                  : scheduledOnly
                  ? () => _showScheduledClosure(x)
                  : null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Close term'),
            ),
          ],
        ),
      ],
    ),
  );

  String _termLabel(
    HeadmasterTermClosure closure,
    String key,
    String fallback,
  ) => closure.transitionPreview[key]?.toString() ?? fallback;

  Widget _pendingSetup(HeadmasterTermClosure closure) {
    final preview = closure.transitionPreview;
    final currentName = _termLabel(
      closure,
      'currentTermName',
      'The previous term',
    );
    final nextName = _termLabel(closure, 'nextTermName', 'next term');
    final datesReady = preview['available'] == true;
    final nextId = int.tryParse('${preview['nextTermId']}');
    final ready = preview['ready'] == true && nextId != null;
    final missingFees =
        (preview['missingPublishedFeeStructures'] as num? ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(closure, false),
        const SizedBox(height: 20),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Next term setup pending',
                '$currentName is closed. Review the setup before beginning $nextName.',
              ),
              const SizedBox(height: 16),
              if (datesReady) ...[
                Text(
                  '$nextName · ${preview['academicYear'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _transitionValue(
                      'Teaching starts',
                      _transitionDate(preview['teachingStartDate']),
                    ),
                    _transitionValue(
                      'Teaching ends',
                      _transitionDate(preview['teachingEndDate']),
                    ),
                    _transitionValue(
                      'Earliest closing date',
                      _transitionDate(preview['closingDate']),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${preview['promotionsResolvable'] ?? 0} of ${preview['students'] ?? 0} student progression decisions ready.',
                ),
                const SizedBox(height: 6),
              ],
              Text(
                preview['detail']?.toString() ??
                    'Confirm the academic period and dates.',
                style: TextStyle(
                  color: ready ? AppColors.green : AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: saving ? null : openReport,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Management report'),
                  ),
                  if (widget.onSetUpNextTerm != null)
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => _setUpNextTerm(closure.termId),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Resume setup'),
                    ),
                  if (datesReady &&
                      nextId != null &&
                      missingFees &&
                      !ready &&
                      widget.onOpenFees != null)
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => widget.onOpenFees!(nextId),
                      child: const Text('Open fee setup'),
                    ),
                  if (widget.onBeginNextTerm != null)
                    FilledButton(
                      onPressed: saving || !ready
                          ? null
                          : () => _beginNextTerm(closure.termId, nextId),
                      child: Text('Begin $nextName'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setUpNextTerm(int closedTermId) async {
    final setup = widget.onSetUpNextTerm;
    if (saving || setup == null) return;
    setState(() => saving = true);
    bool saved;
    try {
      saved = await setup(closedTermId);
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (saved && mounted) await _reloadCurrentTerm();
  }

  Future<void> _beginNextTerm(int closedTermId, int nextTermId) async {
    final begin = widget.onBeginNextTerm;
    if (saving || begin == null) return;
    setState(() => saving = true);
    Map<String, dynamic> result;
    try {
      result = await begin(closedTermId, nextTermId);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        notice(error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (!mounted) return;
    await _showTransitionComplete(result);
    if (!mounted) return;
    setState(() => saving = false);
    await _reloadCurrentTerm();
    if (mounted) widget.onTermTransitioned?.call();
  }

  Future<void> _showClosureComplete(HeadmasterTermClosure closure) async {
    final currentName = _termLabel(closure, 'currentTermName', 'This term');
    final nextName = _termLabel(closure, 'nextTermName', 'next term');
    final beginSetup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$currentName is complete'),
        content: SizedBox(
          width: 390,
          child: Text(
            'The closing record is saved. Set up $nextName when you’re ready.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          if (widget.onSetUpNextTerm != null)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Begin $nextName'),
            ),
        ],
      ),
    );
    if (mounted && beginSetup == true) await _setUpNextTerm(closure.termId);
  }

  String _closureMessage(
    HeadmasterTermClosure closure,
    int blockerCount,
    int warningCount,
  ) {
    if (closure.termClosed) {
      return 'The closing snapshot is locked and available in the management report.';
    }
    if (closure.readyToClose) {
      return 'All checks have passed. The term can now be closed.';
    }

    final scheduledMessage = _scheduledClosureMessage(closure);
    final String pendingMessage;
    if (blockerCount > 0) {
      pendingMessage =
          '$blockerCount required ${blockerCount == 1 ? 'action remains' : 'actions remain'}. Complete the work and review any warnings before closing.';
    } else if (warningCount > 0) {
      pendingMessage =
          '$warningCount ${warningCount == 1 ? 'warning requires' : 'warnings require'} a saved acknowledgement before closing.';
    } else {
      return scheduledMessage ?? 'Recheck readiness before closing the term.';
    }
    return scheduledMessage == null
        ? pendingMessage
        : '$pendingMessage\n$scheduledMessage';
  }

  String? _scheduledClosureMessage(HeadmasterTermClosure closure) {
    final scheduledCheck = closure.items
        .where((item) => !item.ready && _isScheduleItem(item))
        .firstOrNull;
    final closingDate = _parseDate(
      closure.transitionPreview['currentTermClosingDate'],
    );
    return scheduledCheck == null
        ? null
        : closingDate == null
        ? scheduledCheck.detail
        : 'You can close this term on or after ${_transitionDate(closingDate, fullMonth: true)}.';
  }

  Future<void> _showScheduledClosure(HeadmasterTermClosure closure) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Term closure is scheduled'),
        content: SizedBox(
          width: 400,
          child: Text(
            _scheduledClosureMessage(closure) ??
                'Recheck readiness to see the earliest closing date.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _transition(
    HeadmasterTermClosure closure,
    List<TermClosureItem> checks,
  ) {
    final preview = closure.transitionPreview;
    final closingDate = preview['currentTermClosingDate'];
    final hasClosingCheck = checks.any(_isScheduleItem);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'Term transition',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (widget.onOpenTermDates != null && !closure.termClosed)
                  OutlinedButton.icon(
                    onPressed: saving ? null : _openTermDates,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Manage next term dates'),
                  ),
              ],
            ),
          ),
          for (final check in checks) ...[
            const SizedBox(height: 12),
            _transitionCheck(closure, check, closingDate),
          ],
          if (!hasClosingCheck && closingDate != null) ...[
            const SizedBox(height: 12),
            _transitionValue(
              'Earliest closing date',
              _transitionDate(closingDate, showToday: true, fullMonth: true),
            ),
          ],
          if (preview['available'] == true) ...[
            const SizedBox(height: 16),
            Text(
              '${preview['nextTermName'] ?? 'Next term'} dates',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _transitionValue(
                  'Teaching starts',
                  _transitionDate(preview['teachingStartDate']),
                ),
                _transitionValue(
                  'Teaching ends',
                  _transitionDate(preview['teachingEndDate']),
                ),
                _transitionValue(
                  'Next term closes',
                  _transitionDate(preview['closingDate']),
                ),
              ],
            ),
          ] else if (checks.every(_isScheduleItem)) ...[
            const SizedBox(height: 12),
            Text(
              '${preview['detail'] ?? 'Next-term details are not available yet.'}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _transitionCheck(
    HeadmasterTermClosure closure,
    TermClosureItem check,
    Object? closingDate,
  ) {
    final isClosingDate = _isScheduleItem(check);
    final status = _actionStatus(check);
    final detail = isClosingDate && closingDate != null
        ? _transitionDate(closingDate, showToday: true, fullMonth: true)
        : check.detail;
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isClosingDate ? 'Earliest closing date' : 'Next term readiness',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: AppColors.muted)),
      ],
    );
    final controls = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _badge(status, _actionStatusColor(status)),
        if (isClosingDate &&
            !closure.termClosed &&
            widget.onEditCurrentTermDates != null)
          OutlinedButton.icon(
            onPressed: saving
                ? null
                : () => _editCurrentTermDates(closure.termId),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Edit current term dates'),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [description, const SizedBox(height: 8), controls],
              )
            : Row(
                children: [
                  Expanded(child: description),
                  const SizedBox(width: 10),
                  controls,
                ],
              ),
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

  String _transitionDate(
    dynamic value, {
    bool showToday = false,
    bool fullMonth = false,
  }) {
    final parsed = _parseDate(value);
    if (parsed == null) return _displayDate(value);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[parsed.month - 1];
    final date =
        '${parsed.day} ${fullMonth ? month : month.substring(0, 3)} ${parsed.year}';
    final today = DateTime.now();
    final isToday =
        parsed.year == today.year &&
        parsed.month == today.month &&
        parsed.day == today.day;
    return showToday && isToday ? '$date · Today' : date;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is List && value.length >= 3) {
      final year = int.tryParse('${value[0]}');
      final month = int.tryParse('${value[1]}');
      final day = int.tryParse('${value[2]}');
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse('${value ?? ''}');
  }

  HeadmasterTermClosureInput input({String? confirmation}) =>
      HeadmasterTermClosureInput(
        actorUserId: widget.actorUserId,
        termId: data?.termId,
        acknowledgements: acknowledgements,
        facilities: {
          ...?data?.facilities,
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
        title: const Text('Close this term?'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This saves the closing record. You can set up and begin the next term afterward.',
                ),
                const SizedBox(height: 14),
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: c,
            builder: (context, value, child) => FilledButton(
              onPressed: value.text.trim() == 'CLOSE TERM'
                  ? () => Navigator.pop(x, true)
                  : null,
              child: child,
            ),
            child: const Text('Close term'),
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
        'The term is closed.',
      );
      final closed = data;
      if (!mounted || closed == null || !closed.termClosed) return;
      if (_setupPending(closed)) {
        await _showClosureComplete(closed);
      } else if (closed.transition.isNotEmpty) {
        await _showTransitionComplete(closed.transition);
        if (!mounted) return;
        await _reloadCurrentTerm();
        if (mounted) widget.onTermTransitioned?.call();
      }
    }
  }

  Future<void> _showTransitionComplete(
    Map<String, dynamic> t,
  ) => showDialog<void>(
    context: context,
    builder: (context) {
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
            if (t['nextTermFeesDeferred'] != true ||
                (t['nextTermFeeLinesAssigned'] as num? ?? 0) > 0)
              Text(
                '${t['nextTermFeeLinesAssigned'] ?? 0} next-term fee lines assigned',
              ),
            if (t['nextTermFeesDeferred'] == true)
              const Text(
                'You can set up any missing fees during the new term.',
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
            child: const Text('Continue to dashboard'),
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
        notice(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void notice(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
