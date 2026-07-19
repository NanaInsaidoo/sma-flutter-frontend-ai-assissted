import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';

class FeeAdjustmentsContent extends StatefulWidget {
  const FeeAdjustmentsContent({
    super.key,
    required this.api,
    required this.customSchoolId,
    required this.termId,
    this.onChanged,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final int termId;
  final Future<void> Function()? onChanged;

  @override
  State<FeeAdjustmentsContent> createState() => _FeeAdjustmentsContentState();
}

class _FeeAdjustmentsContentState extends State<FeeAdjustmentsContent> {
  final _searchController = TextEditingController();
  FeeAdjustmentsPage? _page;
  Object? _error;
  bool _loading = true;
  int _pageIndex = 0;
  static const _pageSize = 20;
  String? _statusFilter;
  _AdjustmentKind? _typeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeeAdjustmentsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customSchoolId != widget.customSchoolId ||
        oldWidget.termId != widget.termId) {
      _pageIndex = 0;
      _page = null;
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FeeAdjustment> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return (_page?.content ?? const <FeeAdjustment>[])
        .where((item) {
          final kind = _kind(item);
          final matchesSearch =
              query.isEmpty ||
              item.studentName.toLowerCase().contains(query) ||
              item.customStudentId.toLowerCase().contains(query) ||
              item.feeName.toLowerCase().contains(query) ||
              '${item.id}'.contains(query);
          return matchesSearch &&
              (_statusFilter == null ||
                  item.status.trim().toUpperCase() == _statusFilter) &&
              (_typeFilter == null || kind == _typeFilter);
        })
        .toList(growable: false);
  }

  Future<void> _load() async {
    if (widget.termId <= 0 || widget.customSchoolId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The current academic term is unavailable.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.getFeeAdjustmentsPage(
        customSchoolId: widget.customSchoolId,
        termId: widget.termId,
        page: _pageIndex,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _pageIndex = page.page;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _count(String status) => (_page?.content ?? const <FeeAdjustment>[])
      .where((item) => item.status.trim().toUpperCase() == status)
      .length;

  Future<void> _openAdjustment(FeeAdjustment adjustment) async {
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
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
  }

  Future<void> _handleAction(
    FeeAdjustment adjustment,
    _ReviewAction action,
  ) async {
    if (action == _ReviewAction.delete) {
      final confirmed = await _confirm(
        title: 'Delete draft adjustment?',
        message: 'This permanently removes the unsubmitted adjustment.',
        actionLabel: 'Delete',
      );
      if (!confirmed) return;
      await _mutate(
        () => widget.api.deleteFeeAdjustment(
          customSchoolId: widget.customSchoolId,
          adjustmentId: adjustment.id,
        ),
        'Draft adjustment deleted.',
      );
      return;
    }

    final nextStatus = switch (action) {
      _ReviewAction.submit => 'PENDING',
      _ReviewAction.approve => 'APPROVED',
      _ReviewAction.reject => 'REJECTED',
      _ReviewAction.complete => 'COMPLETE',
      _ReviewAction.cancel => 'CANCELLED',
      _ReviewAction.delete => adjustment.status,
    };
    if (action == _ReviewAction.reject || action == _ReviewAction.cancel) {
      final confirmed = await _confirm(
        title: action == _ReviewAction.reject
            ? 'Reject adjustment?'
            : 'Cancel adjustment?',
        message: action == _ReviewAction.reject
            ? 'The adjustment will not affect the student fee balance.'
            : 'The adjustment will remain visible as a cancelled audit record.',
        actionLabel: action == _ReviewAction.reject ? 'Reject' : 'Cancel',
      );
      if (!confirmed) return;
    }
    await _mutate(
      () => widget.api.updateFeeAdjustment(
        customSchoolId: widget.customSchoolId,
        adjustmentId: adjustment.id,
        status: nextStatus,
      ),
      switch (action) {
        _ReviewAction.submit => 'Adjustment submitted for approval.',
        _ReviewAction.approve => 'Adjustment approved.',
        _ReviewAction.reject => 'Adjustment rejected.',
        _ReviewAction.complete => 'Adjustment marked complete.',
        _ReviewAction.cancel => 'Adjustment cancelled.',
        _ReviewAction.delete => 'Adjustment deleted.',
      },
    );
  }

  Future<void> _mutate(
    Future<Object?> Function() action,
    String message,
  ) async {
    setState(() => _loading = true);
    try {
      await action();
      await _load();
      await widget.onChanged?.call();
      _notify(message);
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
        );
      }
    }
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
                child: const Text('Keep adjustment'),
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.green),
    );
  }

  Future<void> _changePage(int page) async {
    if (_loading || page < 0 || page >= (_page?.totalPages ?? 0)) return;
    setState(() => _pageIndex = page);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final start = page == null || page.totalElements == 0
        ? 0
        : page.page * page.size + 1;
    final end = page == null
        ? 0
        : (page.page * page.size + page.content.length).clamp(
            0,
            page.totalElements,
          );
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
                    'Review term discounts and surcharges before they affect student balances.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh adjustments',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loading && page == null)
          const _AdjustmentLoading()
        else if (_error != null && page == null)
          _AdjustmentError(error: _error!, onRetry: _load)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AdjustmentMetric(
                    width: cardWidth,
                    label: 'Pending on this page',
                    value: _count('PENDING'),
                    color: AppColors.amber,
                  ),
                  _AdjustmentMetric(
                    width: cardWidth,
                    label: 'Approved on this page',
                    value: _count('APPROVED'),
                    color: AppColors.green,
                  ),
                  _AdjustmentMetric(
                    width: cardWidth,
                    label: 'Complete on this page',
                    value: _count('COMPLETE'),
                    color: AppColors.blue,
                  ),
                  _AdjustmentMetric(
                    width: cardWidth,
                    label: 'Rejected or cancelled',
                    value: _count('REJECTED') + _count('CANCELLED'),
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 400,
                    child: TextField(
                      key: const Key('adjustments-search'),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText:
                            'Search the current page by student, fee, or ID',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 205,
                    child: DropdownButtonFormField<String?>(
                      value: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      hint: const Text('All statuses'),
                      items: _statusOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_statusLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _statusFilter = value),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<_AdjustmentKind?>(
                      value: _typeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type'),
                      hint: const Text('All types'),
                      items: const [
                        DropdownMenuItem(
                          value: _AdjustmentKind.discount,
                          child: Text('Discount'),
                        ),
                        DropdownMenuItem(
                          value: _AdjustmentKind.surcharge,
                          child: Text('Surcharge'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _typeFilter = value),
                    ),
                  ),
                  if (_searchController.text.trim().isNotEmpty ||
                      _statusFilter != null ||
                      _typeFilter != null)
                    TextButton.icon(
                      key: const Key('clear-adjustment-filters'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _statusFilter = null;
                          _typeFilter = null;
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
            child: Stack(
              children: [
                if ((page?.content.isEmpty ?? true))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 72, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 36,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No fee adjustments for this term',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Adjustments created from a student fee account will appear here.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No adjustments on this page match the filters.',
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1060),
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
                          DataColumn(label: Text('CREATED BY')),
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('')),
                        ],
                        rows: _filtered.map((item) {
                          final type = _kind(item);
                          return DataRow(
                            onSelectChanged: (_) => _openAdjustment(item),
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 205,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _provided(item.studentName, 'Student'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        _provided(
                                          item.customStudentId,
                                          'ID unavailable',
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _provided(
                                    item.feeName,
                                    'Fee item unavailable',
                                  ),
                                ),
                              ),
                              DataCell(Text(_kindLabel(type))),
                              DataCell(
                                Text(
                                  _adjustmentMoney(item),
                                  style: TextStyle(
                                    color: type == _AdjustmentKind.discount
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(Text(_createdBy(item))),
                              DataCell(Text(_date(item.createdDate))),
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
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          if (page != null && page.totalElements > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing $start-$end of ${page.totalElements} adjustments',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: page.page > 0 && !_loading
                      ? () => _changePage(page.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Page ${page.page + 1} of ${page.totalPages}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: page.page + 1 < page.totalPages && !_loading
                      ? () => _changePage(page.page + 1)
                      : null,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

enum _AdjustmentKind { discount, surcharge }

enum _ReviewAction { submit, approve, reject, complete, cancel, delete }

class _AdjustmentReviewPanel extends StatelessWidget {
  const _AdjustmentReviewPanel({
    required this.adjustment,
    required this.onAction,
  });

  final FeeAdjustment adjustment;
  final ValueChanged<_ReviewAction> onAction;

  @override
  Widget build(BuildContext context) {
    final status = adjustment.status.trim().toUpperCase();
    final actions = switch (status) {
      'DRAFT' => const [_ReviewAction.submit, _ReviewAction.delete],
      'PENDING' => const [_ReviewAction.approve, _ReviewAction.reject],
      'APPROVED' => const [_ReviewAction.complete, _ReviewAction.cancel],
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
                              _provided(adjustment.studentName, 'Student'),
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
                        _provided(
                          adjustment.customStudentId,
                          'Student ID unavailable',
                        ),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      _ReviewInfo(
                        label: 'Adjustment ID',
                        value: '${adjustment.id}',
                      ),
                      _ReviewInfo(
                        label: 'Applies to',
                        value: _provided(
                          adjustment.feeName,
                          'Fee item unavailable',
                        ),
                      ),
                      _ReviewInfo(
                        label: 'Type',
                        value: _kindLabel(_kind(adjustment)),
                      ),
                      _ReviewInfo(
                        label: 'Amount',
                        value: _adjustmentMoney(adjustment),
                      ),
                      _ReviewInfo(
                        label: 'Reason',
                        value: _provided(
                          adjustment.description,
                          'No description provided',
                        ),
                      ),
                      _ReviewInfo(
                        label: 'Created',
                        value:
                            '${_createdBy(adjustment)} · ${_date(adjustment.createdDate)}',
                      ),
                      if (adjustment.updatedDate != null)
                        _ReviewInfo(
                          label: 'Last updated',
                          value:
                              '${_updatedBy(adjustment)} · ${_date(adjustment.updatedDate)}',
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Approved and completed adjustments affect the student fee account. Rejected and cancelled records remain visible for audit.',
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
                    children: actions.map((action) {
                      final primary =
                          action == _ReviewAction.approve ||
                          action == _ReviewAction.submit ||
                          action == _ReviewAction.complete;
                      return primary
                          ? FilledButton.icon(
                              key: Key('adjustment-action-${action.name}'),
                              onPressed: () => onAction(action),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(_actionLabel(action)),
                            )
                          : OutlinedButton(
                              key: Key('adjustment-action-${action.name}'),
                              onPressed: () => onAction(action),
                              child: Text(_actionLabel(action)),
                            );
                    }).toList(),
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

  final String status;

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

class _AdjustmentLoading extends StatelessWidget {
  const _AdjustmentLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (index) => Container(
          height: index == 0 ? 108 : 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentError extends StatelessWidget {
  const _AdjustmentError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 38, color: AppColors.red),
            const SizedBox(height: 12),
            const Text(
              'Unable to load fee adjustments',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

const _statusOptions = [
  'DRAFT',
  'PENDING',
  'APPROVED',
  'REJECTED',
  'COMPLETE',
  'CANCELLED',
];

_AdjustmentKind _kind(FeeAdjustment item) {
  final type = item.adjustmentType.trim().toLowerCase();
  if (type.contains('discount')) return _AdjustmentKind.discount;
  if (type.contains('surcharge')) return _AdjustmentKind.surcharge;
  return item.amount < 0 ? _AdjustmentKind.discount : _AdjustmentKind.surcharge;
}

String _kindLabel(_AdjustmentKind type) =>
    type == _AdjustmentKind.discount ? 'Discount' : 'Surcharge';

String _money(double amount) {
  final absolute = amount.abs();
  final value = absolute % 1 == 0
      ? absolute.toStringAsFixed(0)
      : absolute.toStringAsFixed(2);
  return 'GH₵ $value';
}

String _adjustmentMoney(FeeAdjustment item) =>
    _kind(item) == _AdjustmentKind.discount
    ? '(${_money(item.amount)})'
    : _money(item.amount);

String _statusLabel(String status) {
  final normalized = status.trim().toUpperCase();
  return switch (normalized) {
    'DRAFT' => 'Draft',
    'PENDING' => 'Pending approval',
    'APPROVED' => 'Approved',
    'REJECTED' => 'Rejected',
    'COMPLETE' => 'Complete',
    'CANCELLED' => 'Cancelled',
    _ => normalized.isEmpty ? 'Not provided' : normalized.replaceAll('_', ' '),
  };
}

Color _statusColor(String status) => switch (status.trim().toUpperCase()) {
  'DRAFT' => AppColors.muted,
  'PENDING' => AppColors.amber,
  'APPROVED' => AppColors.green,
  'REJECTED' => AppColors.red,
  'COMPLETE' => AppColors.blue,
  'CANCELLED' => AppColors.muted,
  _ => AppColors.muted,
};

String _date(DateTime? date) {
  if (date == null) return 'Date unavailable';
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

String _createdBy(FeeAdjustment item) {
  final type = item.createdByType.trim().replaceAll('_', ' ');
  if (type.isEmpty) return 'Creator unavailable';
  return item.createdById > 0 ? '$type #${item.createdById}' : type;
}

String _updatedBy(FeeAdjustment item) {
  final type = item.updatedByType.trim().replaceAll('_', ' ');
  if (type.isEmpty) return 'Updater unavailable';
  return item.updatedById > 0 ? '$type #${item.updatedById}' : type;
}

String _provided(String value, String otherwise) =>
    value.trim().isEmpty ? otherwise : value.trim();

String _actionLabel(_ReviewAction action) => switch (action) {
  _ReviewAction.submit => 'Submit for approval',
  _ReviewAction.approve => 'Approve',
  _ReviewAction.reject => 'Reject',
  _ReviewAction.complete => 'Mark complete',
  _ReviewAction.cancel => 'Cancel adjustment',
  _ReviewAction.delete => 'Delete draft',
};
