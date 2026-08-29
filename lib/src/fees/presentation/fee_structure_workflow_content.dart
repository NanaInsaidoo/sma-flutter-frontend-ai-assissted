import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';

class FeeStructureWorkflowContent extends StatefulWidget {
  const FeeStructureWorkflowContent({
    super.key,
    required this.api,
    required this.customSchoolId,
    required this.termId,
    required this.termName,
    required this.currentUserId,
    required this.money,
    required this.onChanged,
    this.catalogueOnly = false,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final int termId;
  final String termName;
  final int currentUserId;
  final String Function(double amount) money;
  final Future<void> Function() onChanged;
  final bool catalogueOnly;

  @override
  State<FeeStructureWorkflowContent> createState() =>
      _FeeStructureWorkflowContentState();
}

class _FeeStructureWorkflowContentState
    extends State<FeeStructureWorkflowContent> {
  List<FeeStreamOption> _streams = const [];
  List<FeeClassStructure> _structures = const [];
  List<FeeMasterItem> _masterItems = const [];
  List<FeeApprover> _approvers = const [];
  FeeWorkflowSummary? _summary;
  bool _showRemovedMasterItems = false;
  bool _loading = true;
  bool _acting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeeStructureWorkflowContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.termId != widget.termId ||
        oldWidget.customSchoolId != widget.customSchoolId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.catalogueOnly && widget.termId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.catalogueOnly) {
        final items = await widget.api.getFeeMasterItems(widget.customSchoolId);
        if (!mounted) return;
        setState(() => _masterItems = items);
        return;
      }
      final results = await Future.wait([
        widget.api.getFeeStreams(widget.customSchoolId),
        widget.api.getFeeStructuresForTerm(
          customSchoolId: widget.customSchoolId,
          termId: widget.termId,
        ),
        widget.api.getFeeMasterItems(widget.customSchoolId),
        widget.api.getFeeApprovers(widget.customSchoolId),
        widget.api.getFeeWorkflowSummary(
          customSchoolId: widget.customSchoolId,
          academicTermId: widget.termId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _streams = (results[0] as List<FeeStreamOption>)
            .where((stream) => stream.active)
            .toList();
        _structures = results[1] as List<FeeClassStructure>;
        _masterItems = results[2] as List<FeeMasterItem>;
        _approvers = results[3] as List<FeeApprover>;
        _summary = results[4] as FeeWorkflowSummary;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.red),
              const SizedBox(width: 12),
              Expanded(child: Text('Could not load fee setup. $_error')),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.catalogueOnly) ...[
          _catalogueHeader(),
          const SizedBox(height: 18),
          _masterTable(_masterItems),
        ] else ...[
          _header(),
          const SizedBox(height: 16),
          if (_summary != null) _summaryBanner(_summary!),
          const SizedBox(height: 16),
          _streamTable(_streams),
        ],
      ],
    );
  }

  Widget _catalogueHeader() {
    final removedCount = _masterItems
        .where(
          (item) =>
              !item.active &&
              item.status.toUpperCase() == 'APPROVED' &&
              !item.hasPendingChange,
        )
        .length;
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.outlined(
          tooltip: 'Refresh fee catalogue',
          onPressed: _acting ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (removedCount > 0)
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _showRemovedMasterItems = !_showRemovedMasterItems,
            ),
            icon: Icon(
              _showRemovedMasterItems
                  ? Icons.visibility_off_outlined
                  : Icons.inventory_2_outlined,
            ),
            label: Text(
              _showRemovedMasterItems
                  ? 'Hide removed'
                  : 'Show removed ($removedCount)',
            ),
          ),
        FilledButton.icon(
          onPressed: () => _openMasterEditor(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add fee item'),
        ),
      ],
    );
    const heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fee Catalogue',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 5),
        Text(
          'Manage the fee items used across the school. System items are protected; amounts are set per stream.',
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: heading),
            const SizedBox(width: 24),
            actions,
          ],
        );
      },
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Structure',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.termName} · Prepare, approve and publish fees for every stream.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Refresh fee workflow',
        onPressed: _acting ? null : _load,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _summaryBanner(FeeWorkflowSummary summary) {
    final incomplete = summary.streamsWithoutActiveFees > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: incomplete ? const Color(0xFFFFF7E8) : AppColors.greenSoft,
        border: Border.all(
          color: incomplete ? AppColors.amber : AppColors.green,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            incomplete ? Icons.warning_amber_rounded : Icons.check_circle,
            color: incomplete ? AppColors.amber : AppColors.green,
          ),
          Text(
            incomplete
                ? 'Fees are not active for ${summary.streamsWithoutActiveFees} of ${summary.activeStreams} streams.'
                : 'Fees are active for every stream.',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (summary.approvedNotPublished > 0)
            Text(
              '${summary.approvedNotPublished} approved, awaiting publication',
            ),
        ],
      ),
    );
  }

  Widget _streamTable(List<FeeStreamOption> streams) {
    if (streams.isEmpty) {
      return const _EmptyWorkflow(message: 'No active streams are configured.');
    }
    final groups = <String, List<FeeStreamOption>>{};
    for (final stream in streams) {
      groups.putIfAbsent(stream.gradeName, () => []).add(stream);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _streamTableHeader(compact),
              ...groups.entries.expand((entry) {
                return [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF5F7F6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (stream) => _streamRow(stream, compact: compact),
                  ),
                ];
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _streamTableHeader(bool compact) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        const Expanded(flex: 3, child: _ColumnLabel('STREAM')),
        if (!compact) ...[
          const SizedBox(width: 100, child: _ColumnLabel('STUDENTS')),
          const SizedBox(width: 120, child: _ColumnLabel('FEE ITEMS')),
        ],
        const SizedBox(width: 135, child: _ColumnLabel('TOTAL / TERM')),
        SizedBox(
          width: compact ? 135 : 180,
          child: const _ColumnLabel('STATUS'),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );

  Widget _streamRow(FeeStreamOption stream, {required bool compact}) {
    final structure = _structureFor(stream.id);
    final structureStatus = structure?.status.toUpperCase();
    final opensInEditMode =
        structure == null ||
        (structure.creatorOwned &&
            (structureStatus == 'DRAFT' || structureStatus == 'REJECTED'));
    return InkWell(
      onTap: () => opensInEditMode
          ? _openStructureEditor(stream, structure)
          : _openStructureDetails(stream, structure),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stream.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              SizedBox(
                width: 100,
                child: Text(
                  '${stream.studentCount}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  structure == null
                      ? '—'
                      : '${structure.feeItems.where((item) => item.status != 'INACTIVE').length}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ],
            SizedBox(
              width: 135,
              child: Text(
                structure == null ? '—' : widget.money(structure.totalPerTerm),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(
              width: compact ? 135 : 180,
              child: structure == null
                  ? const _StatusChip(status: 'NOT_CONFIGURED')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _StatusChip(status: structure.status),
                        if (structure.hasPublishedVersion &&
                            structure.status.toUpperCase() != 'PUBLISHED')
                          Tooltip(
                            message: structure.revisionReason.isEmpty
                                ? 'The currently published fees remain active until this revision is published.'
                                : structure.revisionReason,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Modified',
                                style: TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 32,
              child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  FeeClassStructure? _structureFor(int streamId) {
    for (final structure in _structures) {
      if (structure.streamId == streamId) return structure;
    }
    return null;
  }

  Widget _masterTable(List<FeeMasterItem> items) {
    final removedItems = items
        .where(
          (item) =>
              !item.active &&
              item.status.toUpperCase() == 'APPROVED' &&
              !item.hasPendingChange,
        )
        .toList();
    final visibleItems = _showRemovedMasterItems
        ? items
        : items.where((item) => !removedItems.contains(item)).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                for (var index = 0; index < visibleItems.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  _compactMasterRow(visibleItems[index]),
                ],
              ],
            );
          }
          return Column(
            children: [
              const _CatalogueTableHeader(),
              for (var index = 0; index < visibleItems.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _masterRow(visibleItems[index]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _masterRow(FeeMasterItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _masterChangeCell(
              item.code,
              item.editableCode,
              item.hasPendingChange,
              bold: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: _masterItemDetails(item)),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _masterChangeCell(
              item.category,
              item.editableCategory,
              item.hasPendingChange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _catalogueItemType(item)),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: _masterActionMenu(item)),
        ],
      ),
    );
  }

  Widget _compactMasterRow(FeeMasterItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _masterChangeCell(
                        item.code,
                        item.editableCode,
                        item.hasPendingChange,
                        bold: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _catalogueItemType(item),
                  ],
                ),
                const SizedBox(height: 7),
                _masterItemDetails(item),
                const SizedBox(height: 7),
                Text(
                  item.editableCategory,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _masterActionMenu(item),
        ],
      ),
    );
  }

  Widget _masterItemDetails(FeeMasterItem item) {
    final description = item.editableDescription.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _masterChangeCell(
          item.itemName,
          item.editableName,
          item.hasPendingChange,
          bold: true,
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }

  Widget _catalogueItemType(FeeMasterItem item) {
    final label = item.systemDefined
        ? 'System'
        : item.active
        ? 'Custom'
        : 'Inactive';
    final color = item.systemDefined
        ? AppColors.blue
        : item.active
        ? AppColors.green
        : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _masterActionMenu(FeeMasterItem item) {
    if (item.systemDefined) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Fee item actions',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
      onSelected: (action) {
        if (action == 'edit') {
          _openMasterEditor(item);
        } else if (action == 'toggle') {
          _openMasterEditor(item, desiredActive: !item.active);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.active
                  ? Icons.remove_circle_outline_rounded
                  : Icons.restore_rounded,
              color: item.active ? AppColors.red : AppColors.green,
            ),
            title: Text(item.active ? 'Deactivate' : 'Restore'),
          ),
        ),
      ],
    );
  }

  Widget _masterChangeCell(
    String current,
    String proposed,
    bool pending, {
    bool bold = false,
  }) {
    final changed =
        pending && proposed.trim().isNotEmpty && proposed != current;
    if (!changed) {
      return Text(
        current,
        overflow: TextOverflow.ellipsis,
        style: bold ? const TextStyle(fontWeight: FontWeight.w800) : null,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          proposed,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        Text(
          'Current: $current',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _openStructureEditor(
    FeeStreamOption stream,
    FeeClassStructure? structure,
  ) async {
    final saved = await _showRightDrawer<bool>(
      barrierLabel: 'Close class fee editor',
      builder: (_) => _StreamFeeEditor(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        termId: widget.termId,
        stream: stream,
        structure: structure,
        masterItems: _masterItems
            .where((item) => item.hasApprovedVersion && item.active)
            .toList(),
        approvers: _approvers,
        money: widget.money,
      ),
    );
    if (saved == true) await _refreshAfterAction();
  }

  Future<void> _openStructureDetails(
    FeeStreamOption stream,
    FeeClassStructure? structure,
  ) async {
    var currentStructure = structure;
    var editing = false;
    final saved = await _showRightDrawer<bool>(
      barrierLabel: 'Close stream fee details',
      builder: (panelContext) => StatefulBuilder(
        builder: (context, setPanelState) {
          if (editing) {
            return _StreamFeeEditor(
              api: widget.api,
              customSchoolId: widget.customSchoolId,
              termId: widget.termId,
              stream: stream,
              structure: currentStructure,
              masterItems: _masterItems
                  .where((item) => item.hasApprovedVersion && item.active)
                  .toList(),
              approvers: _approvers,
              money: widget.money,
            );
          }
          return _structureDetailsPanel(
            panelContext,
            stream,
            currentStructure,
            onWithdraw: currentStructure == null
                ? null
                : () async {
                    final draft = await _withdrawApprovalRequest(
                      currentStructure!,
                    );
                    if (draft == null || !panelContext.mounted) return;
                    setPanelState(() {
                      currentStructure = draft;
                      editing = true;
                    });
                  },
          );
        },
      ),
    );
    if (saved == true) await _refreshAfterAction();
  }

  Future<T?> _showRightDrawer<T>({
    required String barrierLabel,
    required WidgetBuilder builder,
  }) => showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    barrierLabel: barrierLabel,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );

  Widget _structureDetailsPanel(
    BuildContext panelContext,
    FeeStreamOption stream,
    FeeClassStructure? structure, {
    VoidCallback? onWithdraw,
  }) {
    final screenWidth = MediaQuery.sizeOf(panelContext).width;
    final panelWidth = screenWidth < 680
        ? screenWidth
        : (screenWidth * .36).clamp(480.0, 580.0).toDouble();
    final feeItems =
        structure?.feeItems
            .where((item) => item.status.toUpperCase() != 'INACTIVE')
            .toList() ??
        const <FeeStructureItem>[];
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stream Fees',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Review the structure and choose an action',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(panelContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CLASS & STREAM',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${stream.gradeName} · ${stream.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _StatusChip(
                                    status:
                                        structure?.status ?? 'NOT_CONFIGURED',
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${stream.studentCount} student${stream.studentCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'ACTIONS',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _structurePanelActions(
                            panelContext,
                            stream,
                            structure,
                            onWithdraw: onWithdraw,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'FEE ITEMS',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),
                            Text(
                              '${feeItems.length}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (feeItems.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No fees have been configured for this stream.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        else
                          ...feeItems.map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.feeName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (item.category.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 3,
                                            ),
                                            child: Text(
                                              item.category,
                                              style: const TextStyle(
                                                color: AppColors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        if (item.description.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 3,
                                            ),
                                            child: Text(
                                              item.description,
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.money(item.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (structure?.revisionReason.isNotEmpty == true) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'REVISION REASON',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(structure!.revisionReason),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total per term',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        structure == null
                            ? widget.money(0)
                            : widget.money(structure.totalPerTerm),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
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

  List<Widget> _structurePanelActions(
    BuildContext panelContext,
    FeeStreamOption stream,
    FeeClassStructure? structure, {
    VoidCallback? onWithdraw,
  }) {
    if (structure == null) {
      return [
        FilledButton.icon(
          onPressed: () => _leavePanel(
            panelContext,
            () => _openStructureEditor(stream, null),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Set up fees'),
        ),
      ];
    }
    final status = structure.status.toUpperCase();
    if (status == 'DRAFT' || status == 'REJECTED') {
      if (!structure.creatorOwned) {
        return const [
          Text(
            'Only the creator can edit this draft.',
            style: TextStyle(color: AppColors.muted),
          ),
        ];
      }
      return [
        FilledButton.icon(
          onPressed: () => _leavePanel(
            panelContext,
            () => _openStructureEditor(stream, structure),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _leavePanel(panelContext, () => _submitStructure(structure)),
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _leavePanel(panelContext, () => _copyItems(structure)),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy'),
        ),
        TextButton.icon(
          onPressed: () =>
              _leavePanel(panelContext, () => _deleteStructure(structure)),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
        ),
      ];
    }
    if (status == 'PENDING_APPROVAL') {
      if (structure.creatorOwned) {
        return [
          OutlinedButton.icon(
            onPressed: _acting ? null : onWithdraw,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Withdraw approval request'),
          ),
        ];
      }
      return [
        Text(
          'Pending review by ${structure.assignedApproverName}. Decisions are managed from Approvals.',
          style: const TextStyle(color: AppColors.muted),
        ),
      ];
    }
    if (status == 'APPROVED') {
      return [
        FilledButton.icon(
          onPressed: () =>
              _leavePanel(panelContext, () => _publishStructure(structure)),
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publish'),
        ),
      ];
    }
    return [
      FilledButton.icon(
        onPressed: () => _leavePanel(
          panelContext,
          () => _openStructureEditor(stream, structure),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Revise'),
      ),
      OutlinedButton.icon(
        onPressed: () => _leavePanel(panelContext, () => _copyItems(structure)),
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy'),
      ),
    ];
  }

  Future<void> _leavePanel(
    BuildContext panelContext,
    Future<void> Function() action,
  ) async {
    Navigator.pop(panelContext);
    await Future<void>.delayed(Duration.zero);
    if (mounted) await action();
  }

  Future<void> _openMasterEditor(
    FeeMasterItem? item, {
    bool? desiredActive,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeeMasterEditor(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        item: item,
        desiredActive: desiredActive,
      ),
    );
    if (saved == true) await _refreshAfterAction();
  }

  Future<int?> _chooseApprover() async {
    if (_approvers.isEmpty) {
      _notice(
        'Add another active Administrator or Headmaster before submitting.',
      );
      return null;
    }
    var selectedId = 0;
    return showDialog<int>(
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
                const Text(
                  'Choose the Administrator or Headmaster who should review this fee structure.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  key: const Key('fee-structure-approver-dialog-dropdown'),
                  value: selectedId > 0 ? selectedId : null,
                  decoration: const InputDecoration(
                    labelText: 'Approver',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  isExpanded: true,
                  items: _approvers
                      .map(
                        (approver) => DropdownMenuItem(
                          value: approver.id,
                          child: Text('${approver.name} · ${approver.role}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedId = value ?? 0),
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
              key: const Key('fee-structure-confirm-approver'),
              onPressed: selectedId <= 0
                  ? null
                  : () => Navigator.pop(dialogContext, selectedId),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitStructure(FeeClassStructure item) async {
    final approver = await _chooseApprover();
    if (approver == null) return;
    await _run(
      () => widget.api.submitFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: item.structureId,
        approverId: approver,
      ),
      'Fee structure submitted for approval.',
    );
  }

  Future<FeeClassStructure?> _withdrawApprovalRequest(
    FeeClassStructure item,
  ) async {
    if (_acting) return null;
    setState(() => _acting = true);
    try {
      final draft = await widget.api.withdrawFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: item.structureId,
      );
      if (!mounted) return null;
      _notice(
        'Approval request withdrawn. The fee structure is now a draft.',
        success: true,
      );
      await _refreshAfterAction();
      return draft;
    } catch (error) {
      if (mounted) _notice('$error');
      return null;
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _publishStructure(FeeClassStructure item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish approved fees?'),
        content: const Text(
          'Parents will see these fees and student accounts will be assessed. Published fees are locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.api.publishFeeStructure(
          customSchoolId: widget.customSchoolId,
          structureId: item.structureId,
        ),
        'Fees published and activated.',
      );
    }
  }

  Future<void> _deleteStructure(FeeClassStructure item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fee draft?'),
        content: const Text('This removes only the unpublished draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.api.deleteFeeStructure(
          customSchoolId: widget.customSchoolId,
          structureId: item.structureId,
        ),
        'Draft deleted.',
      );
    }
  }

  Future<void> _copyItems(FeeClassStructure structure) async {
    final result = await showDialog<_CopySelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CopyFeeItemsDialog(
        source: structure,
        streams: _streams
            .where((stream) => stream.id != structure.streamId)
            .toList(),
      ),
    );
    if (result == null) return;
    final preview = await widget.api.copyFeeStructureItems(
      customSchoolId: widget.customSchoolId,
      structureId: structure.structureId,
      itemIds: result.itemIds,
      targetStreamIds: result.streamIds,
      overwrite: false,
      preview: true,
      reason: result.reason,
    );
    if (!mounted) return;
    var overwrite = false;
    if (preview.requiresConfirmation) {
      final first = preview.conflicts
          .take(3)
          .map(
            (conflict) =>
                '${conflict.gradeName} · ${conflict.streamName} (${conflict.status})',
          )
          .join('\n');
      final more = preview.conflicts.length > 3
          ? '\n+ ${preview.conflicts.length - 3} more'
          : '';
      overwrite =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Existing fee items will be overwritten'),
              content: Text(
                '$first$more\n\nPending submissions will return to Draft. Approved drafts will lose approval. Published fees will receive a new revision draft.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ) ==
          true;
      if (!overwrite) return;
    }
    await _run(
      () => widget.api.copyFeeStructureItems(
        customSchoolId: widget.customSchoolId,
        structureId: structure.structureId,
        itemIds: result.itemIds,
        targetStreamIds: result.streamIds,
        overwrite: overwrite,
        preview: false,
        reason: result.reason,
      ),
      'Selected fee items copied.',
    );
  }

  Future<void> _run(Future<Object?> Function() action, String success) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      _notice(success, success: true);
      await _refreshAfterAction();
    } catch (error) {
      if (mounted) _notice('$error');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _refreshAfterAction() async {
    await _load();
    await widget.onChanged();
  }

  void _notice(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.green : AppColors.red,
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: .45,
    ),
  );
}

class _CatalogueTableHeader extends StatelessWidget {
  const _CatalogueTableHeader();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF5F7F6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: const Row(
      children: [
        Expanded(flex: 2, child: _ColumnLabel('CODE')),
        SizedBox(width: 16),
        Expanded(flex: 5, child: _ColumnLabel('FEE ITEM')),
        SizedBox(width: 16),
        Expanded(flex: 3, child: _ColumnLabel('CATEGORY')),
        SizedBox(width: 16),
        Expanded(flex: 2, child: _ColumnLabel('TYPE')),
        SizedBox(width: 48),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (label, color) = switch (normalized) {
      'PUBLISHED' => ('Active', AppColors.green),
      'APPROVED' => ('Approved', const Color(0xFF4776E6)),
      'PENDING_APPROVAL' => ('Pending approval', AppColors.amber),
      'DRAFT' => ('Draft', AppColors.muted),
      'SYSTEM' => ('System item', AppColors.blue),
      'ACTIVE' => ('Custom item', AppColors.green),
      'REMOVED' => ('Removed', AppColors.red),
      'NOT_CONFIGURED' => ('Fees not active', AppColors.red),
      _ => (status.replaceAll('_', ' '), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
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

class _EmptyWorkflow extends StatelessWidget {
  const _EmptyWorkflow({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.muted)),
      ),
    ),
  );
}

class _StreamFeeEditor extends StatefulWidget {
  const _StreamFeeEditor({
    required this.api,
    required this.customSchoolId,
    required this.termId,
    required this.stream,
    required this.structure,
    required this.masterItems,
    required this.approvers,
    required this.money,
  });
  final FeeApiClient api;
  final String customSchoolId;
  final int termId;
  final FeeStreamOption stream;
  final FeeClassStructure? structure;
  final List<FeeMasterItem> masterItems;
  final List<FeeApprover> approvers;
  final String Function(double amount) money;

  @override
  State<_StreamFeeEditor> createState() => _StreamFeeEditorState();
}

class _StreamFeeEditorState extends State<_StreamFeeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _revisionReason = TextEditingController();
  late final List<_FeeRowDraft> _rows;
  bool _saving = false;
  bool _submitting = false;

  bool get _revision => widget.structure?.status.toUpperCase() == 'PUBLISHED';
  double get _total => _rows.fold(
    0,
    (sum, row) => sum + (double.tryParse(row.amount.text) ?? 0),
  );

  @override
  void initState() {
    super.initState();
    final existing = widget.structure?.feeItems ?? const <FeeStructureItem>[];
    _rows = existing
        .where((item) => item.status.toUpperCase() != 'INACTIVE')
        .map(
          (item) => _FeeRowDraft(
            itemId: item.feeId,
            masterId: item.feeMasterItemId,
            amount: TextEditingController(text: item.amount.toStringAsFixed(2)),
            dueDate: item.dueDate,
          ),
        )
        .toList();
    if (_rows.isEmpty && widget.masterItems.isNotEmpty) {
      _rows.add(
        _FeeRowDraft(
          itemId: 0,
          masterId: widget.masterItems.first.id,
          amount: TextEditingController(text: '0.00'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _revisionReason.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 680
        ? screenWidth
        : (screenWidth * .36).clamp(480.0, 580.0).toDouble();
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
                _drawerHeader(),
                const Divider(height: 1),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _classSummary(),
                          if (widget.structure?.rejectionReason
                                  .trim()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: .10),
                                border: Border.all(
                                  color: AppColors.amber.withValues(alpha: .45),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CHANGES REQUESTED',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    widget.structure!.rejectionReason.trim(),
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (widget.approvers.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No eligible approver is available. You can save a draft, but another active Administrator or Headmaster is required before submission.',
                                style: TextStyle(color: AppColors.text),
                              ),
                            ),
                          if (_revision) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _revisionReason,
                              decoration: const InputDecoration(
                                labelText: 'Reason for this revision',
                                helperText:
                                    'The published fees stay active until this revision is approved and published.',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter the reason for this revision'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Text(
                                'FEE ITEMS',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _rows.length > 1 ? 'drag to reorder' : '',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: _rows.length,
                            onReorder: _reorderRows,
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              return KeyedSubtree(
                                key: ObjectKey(row),
                                child: _feeRow(index, row),
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: _availableMasterItems.isEmpty
                                ? null
                                : _addRow,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add fee item'),
                          ),
                          if (_availableMasterItems.isEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'All available fee items have been added.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _drawerFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<FeeMasterItem> get _availableMasterItems => widget.masterItems
      .where((master) => !_rows.any((row) => row.masterId == master.id))
      .toList();

  Widget _drawerHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.structure == null ? 'Add Class Fees' : 'Edit Class Fees',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _revision
                    ? 'Create a controlled revision of this fee structure'
                    : 'Update this stream fee structure',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _classSummary() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CLASS & STREAM',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.stream.gradeName} · ${widget.stream.name}',
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        _StatusChip(status: widget.structure?.status ?? 'DRAFT'),
      ],
    ),
  );

  Widget _drawerFooter() => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total per term',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              widget.money(_total),
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => _save(submit: false),
                child: Text(
                  _saving && !_submitting ? 'Saving…' : 'Save as draft',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(submit: true),
                icon: _saving && _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _saving && _submitting
                      ? 'Submitting…'
                      : 'Submit for approval',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _feeRow(int index, _FeeRowDraft row) {
    final available = widget.masterItems
        .where(
          (master) =>
              master.id == row.masterId ||
              !_rows.any(
                (other) => other != row && other.masterId == master.id,
              ),
        )
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_indicator_rounded, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: row.masterId > 0 ? row.masterId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fee item'),
              items: available
                  .map(
                    (master) => DropdownMenuItem(
                      value: master.id,
                      child: Text(
                        '${master.code} · ${master.itemName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => row.masterId = value ?? 0),
              validator: (value) =>
                  value == null || value <= 0 ? 'Select a fee item' : null,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 138,
            child: TextFormField(
              controller: row.amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'GH₵ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount < 0
                    ? 'Enter a valid amount'
                    : null;
              },
            ),
          ),
          IconButton(
            onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
            tooltip: 'Remove fee item',
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }

  void _addRow() {
    final available = _availableMasterItems;
    if (available.isEmpty) return;
    setState(
      () => _rows.add(
        _FeeRowDraft(
          itemId: 0,
          masterId: available.first.id,
          amount: TextEditingController(text: '0.00'),
        ),
      ),
    );
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index).dispose());
  }

  void _reorderRows(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
    });
  }

  Future<void> _save({required bool submit}) async {
    setState(() => _submitting = submit);
    if (!_formKey.currentState!.validate() || _rows.isEmpty) {
      setState(() => _submitting = false);
      return;
    }
    _ApprovalSubmission? submission;
    if (submit) {
      submission = await _chooseApproverForSubmission();
      if (submission == null) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }
    setState(() => _saving = true);
    var draftSaved = false;
    try {
      final saved = await widget.api.saveFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: widget.structure?.structureId ?? 0,
        gradeLevelId: widget.stream.gradeLevelId,
        streamId: widget.stream.id,
        termId: widget.termId,
        revisionReason: _revisionReason.text,
        feeItems: _rows.map((row) {
          final master = widget.masterItems.firstWhere(
            (item) => item.id == row.masterId,
          );
          return FeeStructureItem(
            feeId: row.itemId,
            feeMasterItemId: master.id,
            masterCode: master.code,
            categoryId: 0,
            category: master.category,
            feeName: master.itemName,
            amount: double.tryParse(row.amount.text) ?? 0,
            description: master.description,
            status: 'ACTIVE',
            dueDate: row.dueDate,
            mandatory: true,
            instructions: '',
          );
        }).toList(),
      );
      draftSaved = true;
      if (submit) {
        await widget.api.submitFeeStructure(
          customSchoolId: widget.customSchoolId,
          structureId: saved.structureId,
          approverId: submission!.approverId,
          note: submission.note,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draftSaved && submit
                ? 'The draft was saved, but submission failed: $error'
                : '$error',
          ),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<_ApprovalSubmission?> _chooseApproverForSubmission() async {
    if (widget.approvers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add another active Administrator or Headmaster before submitting.',
          ),
          backgroundColor: AppColors.amber,
        ),
      );
      return null;
    }
    var selectedId =
        widget.approvers.any(
          (item) => item.id == widget.structure?.assignedApproverId,
        )
        ? widget.structure!.assignedApproverId
        : 0;
    final note = TextEditingController();
    final result = await showDialog<_ApprovalSubmission>(
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
                  'Choose who should review the fees for ${widget.stream.gradeName} · ${widget.stream.name}.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  key: const Key('fee-editor-approver-dialog-dropdown'),
                  value: selectedId > 0 ? selectedId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Approver',
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
                  onChanged: (value) =>
                      setDialogState(() => selectedId = value ?? 0),
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
              key: const Key('fee-editor-confirm-approver'),
              onPressed: selectedId <= 0
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      _ApprovalSubmission(selectedId, note.text.trim()),
                    ),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    return result;
  }
}

class _ApprovalSubmission {
  const _ApprovalSubmission(this.approverId, this.note);
  final int approverId;
  final String note;
}

class _FeeRowDraft {
  _FeeRowDraft({
    required this.itemId,
    required this.masterId,
    required this.amount,
    this.dueDate,
  });
  final int itemId;
  int masterId;
  final TextEditingController amount;
  final DateTime? dueDate;
  void dispose() => amount.dispose();
}

class _FeeMasterEditor extends StatefulWidget {
  const _FeeMasterEditor({
    required this.api,
    required this.customSchoolId,
    required this.item,
    this.desiredActive,
  });
  final FeeApiClient api;
  final String customSchoolId;
  final FeeMasterItem? item;
  final bool? desiredActive;
  @override
  State<_FeeMasterEditor> createState() => _FeeMasterEditorState();
}

class _FeeMasterEditorState extends State<_FeeMasterEditor> {
  static const _otherCategory = '__OTHER__';
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _reason;
  List<FeeCategory> _categories = const [];
  String _selectedCategory = '';
  bool _loadingCategories = true;
  bool _categoryLoadFailed = false;
  bool _active = true;
  bool _saving = false;

  bool get _removing => widget.desiredActive == false;
  bool get _restoring => widget.desiredActive == true;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _code = TextEditingController(text: item?.editableCode ?? '');
    _name = TextEditingController(text: item?.editableName ?? '');
    _category = TextEditingController(text: item?.editableCategory ?? '');
    _description = TextEditingController(text: item?.editableDescription ?? '');
    _reason = TextEditingController(
      text: widget.desiredActive == null ? item?.changeReason ?? '' : '',
    );
    _active = widget.desiredActive ?? item?.draftActive ?? true;
    _loadCategories();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _removing
          ? 'Deactivate custom fee item'
          : _restoring
          ? 'Restore fee catalogue item'
          : widget.item == null
          ? 'Add fee catalogue item'
          : 'Edit fee catalogue item',
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_removing || _restoring) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_removing ? AppColors.red : AppColors.green)
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _removing
                        ? 'This item will no longer be available for new fee structures. Existing fees, payments, receipts and reports will remain unchanged.'
                        : 'This custom item will become available for new fee structures again.',
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      enabled: !_removing && !_restoring,
                      decoration: const InputDecoration(labelText: 'Code'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _name,
                      enabled: !_removing && !_restoring,
                      decoration: const InputDecoration(labelText: 'Fee item'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory.isEmpty ? null : _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  suffixIcon: _loadingCategories
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: [
                  ..._categories.map(
                    (category) => DropdownMenuItem(
                      value: category.name,
                      child: Text(category.name),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _otherCategory,
                    child: Text('Other'),
                  ),
                ],
                onChanged: _loadingCategories || _removing || _restoring
                    ? null
                    : (value) {
                        final wasOther = _selectedCategory == _otherCategory;
                        setState(() {
                          _selectedCategory = value ?? '';
                          if (_selectedCategory == _otherCategory) {
                            if (!wasOther) _category.clear();
                          } else {
                            _category.text = _selectedCategory;
                          }
                        });
                      },
                validator: (value) =>
                    value == null || value.isEmpty ? 'Select a category' : null,
              ),
              if (_categoryLoadFailed) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'The category list could not be loaded. You can use Other or retry.',
                        style: TextStyle(color: AppColors.amber, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadCategories,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
              if (_selectedCategory == _otherCategory) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  enabled: !_removing && !_restoring,
                  decoration: const InputDecoration(
                    labelText: 'Specify category',
                  ),
                  validator: _required,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                enabled: !_removing && !_restoring,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              if (widget.item?.hasApprovedVersion == true) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  decoration: InputDecoration(
                    labelText: _removing
                        ? 'Reason for deactivation'
                        : _restoring
                        ? 'Reason for restoration'
                        : 'Reason for this wording or status change',
                  ),
                  validator: _removing || _restoring ? _required : null,
                ),
              ],
              if (!_removing && !_restoring) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for new fee structures'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          _saving
              ? 'Saving…'
              : _removing
              ? 'Deactivate item'
              : _restoring
              ? 'Restore item'
              : widget.item == null
              ? 'Add item'
              : 'Save changes',
        ),
      ),
    ],
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _loadingCategories = true;
        _categoryLoadFailed = false;
      });
    }
    try {
      final categories = await widget.api.getFeeCategories();
      categories.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
      if (!mounted) return;
      final existing = _category.text.trim();
      FeeCategory? matching;
      for (final category in categories) {
        if (category.name.toLowerCase() == existing.toLowerCase()) {
          matching = category;
          break;
        }
      }
      setState(() {
        _categories = categories;
        _selectedCategory =
            matching?.name ?? (existing.isNotEmpty ? _otherCategory : '');
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const [];
        _selectedCategory = _category.text.trim().isEmpty ? '' : _otherCategory;
        _loadingCategories = false;
        _categoryLoadFailed = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.saveFeeMasterItem(
        customSchoolId: widget.customSchoolId,
        itemId: widget.item?.id ?? 0,
        code: _code.text,
        itemName: _name.text,
        category: _category.text,
        description: _description.text,
        active: _active,
        changeReason: _reason.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
      );
    }
  }
}

class _CopySelection {
  const _CopySelection({
    required this.itemIds,
    required this.streamIds,
    required this.reason,
  });
  final List<int> itemIds;
  final List<int> streamIds;
  final String reason;
}

class _CopyFeeItemsDialog extends StatefulWidget {
  const _CopyFeeItemsDialog({required this.source, required this.streams});
  final FeeClassStructure source;
  final List<FeeStreamOption> streams;
  @override
  State<_CopyFeeItemsDialog> createState() => _CopyFeeItemsDialogState();
}

class _CopyFeeItemsDialogState extends State<_CopyFeeItemsDialog> {
  final Set<int> _items = {};
  final Set<int> _streams = {};
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Copy fee items to other streams'),
    content: SizedBox(
      width: 680,
      height: 520,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FEE ITEMS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.muted,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: widget.source.feeItems
                        .map(
                          (item) => CheckboxListTile(
                            value: _items.contains(item.feeId),
                            title: Text(item.feeName),
                            subtitle: Text(item.masterCode),
                            onChanged: (value) => setState(
                              () => value == true
                                  ? _items.add(item.feeId)
                                  : _items.remove(item.feeId),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TARGET STREAMS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.muted,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: widget.streams
                        .map(
                          (stream) => CheckboxListTile(
                            value: _streams.contains(stream.id),
                            title: Text('${stream.gradeName} · ${stream.name}'),
                            onChanged: (value) => setState(
                              () => value == true
                                  ? _streams.add(stream.id)
                                  : _streams.remove(stream.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason (used for published revisions)',
                  ),
                ),
              ],
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
        onPressed: _items.isEmpty || _streams.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _CopySelection(
                  itemIds: _items.toList(),
                  streamIds: _streams.toList(),
                  reason: _reason.text.trim(),
                ),
              ),
        child: const Text('Review copy'),
      ),
    ],
  );
}
