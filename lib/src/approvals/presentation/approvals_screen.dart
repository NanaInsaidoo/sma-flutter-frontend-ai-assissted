import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/approval_api_client.dart';
import '../domain/approval_models.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.onOpenSource,
    this.onInboxChanged,
  });

  final String schoolId;
  final ApprovalApiClient repository;
  final ValueChanged<ApprovalItem>? onOpenSource;
  final ValueChanged<ApprovalInbox>? onInboxChanged;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<ApprovalInbox> _future;
  bool _myApprovals = true;
  String _category = 'All';
  String _status = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ApprovalInbox> _load() async {
    final value = await widget.repository.getInbox(widget.schoolId);
    widget.onInboxChanged?.call(value);
    return value;
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApprovalInbox>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }
        final inbox = snapshot.data!;
        final source = _myApprovals ? inbox.myApprovals : inbox.myRequests;
        final categories = {'All', ...source.map((item) => item.category)};
        final items = source.where((item) {
          final categoryMatches =
              _category == 'All' || item.category == _category;
          final statusMatches = _status == 'All' || item.status == _status;
          final q = _query.toLowerCase();
          final queryMatches =
              q.isEmpty ||
              item.title.toLowerCase().contains(q) ||
              item.subtitle.toLowerCase().contains(q) ||
              item.requesterName.toLowerCase().contains(q);
          return categoryMatches && statusMatches && queryMatches;
        }).toList();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(constraints.maxWidth < 700 ? 16 : 28),
              children: [
                _Header(onRefresh: _refresh),
                const SizedBox(height: 20),
                _Summary(
                  inbox: inbox,
                  myApprovals: _myApprovals,
                  onChanged: (value) => setState(() {
                    _myApprovals = value;
                    _category = 'All';
                    _status = 'All';
                  }),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 700
                          ? constraints.maxWidth
                          : 300,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search approvals',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ),
                    _Filter(
                      label: 'Category',
                      value: categories.contains(_category) ? _category : 'All',
                      values: categories.toList(),
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    _Filter(
                      label: 'Status',
                      value: _status,
                      values: const [
                        'All',
                        'PENDING_APPROVAL',
                        'CHANGES_REQUESTED',
                        'APPROVED',
                        'DRAFT',
                        'REJECTED',
                        'CANCELLED',
                        'PUBLISHED',
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  _EmptyState(myApprovals: _myApprovals)
                else
                  _ApprovalList(
                    items: items,
                    onOpen: (item) => _openItem(context, item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openItem(BuildContext context, ApprovalItem item) async {
    final result = await showModalBottomSheet<_ApprovalPanelResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.centerRight,
        child: _ApprovalPanel(
          item: item,
          onOpenSource: widget.onOpenSource == null
              ? null
              : () {
                  Navigator.pop(context, const _ApprovalPanelResult());
                  widget.onOpenSource!.call(item);
                },
          onAction: (action, reason) => _act(item, action, reason),
        ),
      ),
    );
    if (!mounted || !context.mounted) return;
    if (result?.reload == true) _refresh();
    if (result?.conflictMessage != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request updated'),
          content: Text(
            '${result!.conflictMessage}\n\nThe approvals list has been refreshed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _act(ApprovalItem item, String action, String reason) async {
    final inbox = await widget.repository.performAction(
      schoolId: widget.schoolId,
      item: item,
      action: action,
      reason: reason,
    );
    widget.onInboxChanged?.call(inbox);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approvals',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Review requests assigned to you and follow the requests you submitted.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        onPressed: onRefresh,
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.inbox,
    required this.myApprovals,
    required this.onChanged,
  });
  final ApprovalInbox inbox;
  final bool myApprovals;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _SummaryCard(
        selected: myApprovals,
        icon: Icons.approval_outlined,
        title: 'My approvals',
        count: inbox.pendingMyApproval,
        caption: 'Waiting for your decision',
        onTap: () => onChanged(true),
      ),
      _SummaryCard(
        selected: !myApprovals,
        icon: Icons.outbox_outlined,
        title: 'My requests',
        count: inbox.pendingMyRequests,
        caption: 'Still awaiting approval',
        onTap: () => onChanged(false),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.caption,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final int count;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Material(
      color: selected ? AppColors.green.withValues(alpha: .08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AppColors.green : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected
                    ? AppColors.green
                    : const Color(0xFFE9F2F0),
                foregroundColor: selected ? Colors.white : AppColors.green,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: selected ? AppColors.green : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item == 'All' && label == 'Category'
                    ? 'All categories'
                    : _statusText(item),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items, required this.onOpen});
  final List<ApprovalItem> items;
  final ValueChanged<ApprovalItem> onOpen;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _ApprovalRow(item: items[i], onTap: () => onOpen(items[i])),
          if (i != items.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({required this.item, required this.onTap});
  final ApprovalItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _categoryColor(item.category).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _categoryIcon(item.category),
              color: _categoryColor(item.category),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 820) ...[
            Expanded(
              child: Text(
                item.requesterName.isEmpty ? '—' : item.requesterName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                _dateText(item.submittedAt ?? item.updatedAt),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
          _StatusPill(status: item.status),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _ApprovalPanel extends StatefulWidget {
  const _ApprovalPanel({
    required this.item,
    required this.onAction,
    this.onOpenSource,
  });
  final ApprovalItem item;
  final Future<void> Function(String action, String reason) onAction;
  final VoidCallback? onOpenSource;
  @override
  State<_ApprovalPanel> createState() => _ApprovalPanelState();
}

class _ApprovalPanelState extends State<_ApprovalPanel> {
  bool _busy = false;
  Future<void> _run(String action, {bool reasonRequired = false}) async {
    var reason = '';
    if (reasonRequired) {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'REJECT' ? 'Reject request' : 'Withdraw approval request',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Explain why this request is being returned.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length >= 5) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (value == null) return;
      reason = value;
    }
    setState(() => _busy = true);
    try {
      await widget.onAction(action, reason);
      if (mounted) {
        Navigator.pop(context, const _ApprovalPanelResult(reload: true));
      }
    } on ApprovalApiException catch (error) {
      if (!mounted) return;
      if (error.isConflict) {
        Navigator.pop(
          context,
          _ApprovalPanelResult(reload: true, conflictMessage: error.message),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width < 680
              ? MediaQuery.sizeOf(context).width
              : 620,
          height: MediaQuery.sizeOf(context).height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Approval details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RequestSummary(item: item),
                      if (item.requesterNote.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _RequesterNote(item: item),
                      ],
                      const SizedBox(height: 16),
                      _DecisionDetails(item: item),
                      if (item.detailSections.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _AdditionalRequestDetails(item: item),
                      ],
                      if (item.detailSections.isEmpty) ...[
                        const SizedBox(height: 16),
                        _RequestPeopleAndDates(item: item),
                        const SizedBox(height: 16),
                        _LegacyRequestDetails(item: item),
                      ],
                      if (widget.onOpenSource != null) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: widget.onOpenSource,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open source page'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (item.canApprove || item.canReject || item.canWithdraw)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            if (item.canWithdraw)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _run('WITHDRAW', reasonRequired: true),
                                  child: const Text(
                                    'Withdraw approval request',
                                  ),
                                ),
                              ),
                            if (item.canReject)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _run('REJECT', reasonRequired: true),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                            if ((item.canWithdraw || item.canReject) &&
                                item.canApprove)
                              const SizedBox(width: 10),
                            if (item.canApprove)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _run('APPROVE'),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Approve'),
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

class _ApprovalPanelResult {
  const _ApprovalPanelResult({this.reload = false, this.conflictMessage});
  final bool reload;
  final String? conflictMessage;
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _categoryColor(item.category).withValues(alpha: .07),
      border: Border.all(
        color: _categoryColor(item.category).withValues(alpha: .2),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _categoryColor(item.category).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: _categoryColor(item.category),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusPill(status: item.status),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _InlineMeta(
                        icon: Icons.person_outline_rounded,
                        text: item.requesterName.isEmpty
                            ? 'Requester unavailable'
                            : item.requesterName,
                      ),
                      _InlineMeta(
                        icon: Icons.schedule_rounded,
                        text: _dateText(item.submittedAt ?? item.createdAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _RequesterNote extends StatelessWidget {
  const _RequesterNote({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final revised =
        (item.type == 'FEE_STRUCTURE' ||
            item.type == 'CLASS_REQUIREMENT' ||
            item.type == 'STUDENT_REQUIREMENT') &&
        (item.version ?? 1) > 1;
    return _PanelCard(
      title: revised ? 'Reason for revision' : 'Requester note',
      icon: Icons.notes_rounded,
      child: Text(
        item.requesterNote,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _DecisionDetails extends StatelessWidget {
  const _DecisionDetails({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final section = _primarySection(item);
    if (section == null || section.entries.isEmpty) {
      return _LegacyRequestDetails(item: item);
    }
    return _PanelCard(
      title: _decisionSectionTitle(item.type),
      icon: _categoryIcon(item.category),
      child: Column(
        children: [
          for (var index = 0; index < section.entries.length; index++) ...[
            _DecisionRow(item: item, entry: section.entries[index]),
            if (index != section.entries.length - 1) const Divider(height: 25),
          ],
          if (item.type == 'FEE_STRUCTURE' && item.amount != null) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total per term',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Text(
                  'GH₵ ${item.amount!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.item, required this.entry});
  final ApprovalItem item;
  final ApprovalDetailEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = switch (item.type) {
      'FEE_ADJUSTMENT' ||
      'PAYMENT_REVERSAL' ||
      'STUDENT_TRANSFER' => _fieldValue(entry, 'Student') ?? entry.title,
      'STUDENT_REQUIREMENT' => _fieldValue(entry, 'Item') ?? entry.title,
      _ => entry.title,
    };
    final trailing = switch (item.type) {
      'CLASS_REQUIREMENT' ||
      'STUDENT_REQUIREMENT' => _fieldValue(entry, 'Quantity'),
      'FEE_ADJUSTMENT' => _fieldValue(entry, 'Amount'),
      'PAYMENT_REVERSAL' => _fieldValue(entry, 'Amount to reverse'),
      'STUDENT_TRANSFER' => _fieldValue(entry, 'Effective date'),
      _ => _fieldValue(entry, 'Amount'),
    };
    final subtitleParts = switch (item.type) {
      'CLASS_REQUIREMENT' => [
        _fieldValue(entry, 'Due date'),
        _labelledField(entry, 'Estimated unit price', 'Est. price'),
        _labelledField(entry, 'Estimated total', 'Est. total'),
      ],
      'STUDENT_REQUIREMENT' => [
        _fieldValue(entry, 'Student'),
        _fieldValue(entry, 'Class'),
        _fieldValue(entry, 'Due date'),
        _labelledField(entry, 'Estimated unit price', 'Est. price'),
        _labelledField(entry, 'Estimated total', 'Est. total'),
      ],
      'FEE_ADJUSTMENT' => [
        _fieldValue(entry, 'Fee item'),
        _fieldValue(entry, 'Adjustment type'),
      ],
      'PAYMENT_REVERSAL' => [
        _fieldValue(entry, 'Payment reference'),
        _fieldValue(entry, 'Reason for reversal'),
      ],
      'STUDENT_TRANSFER' => [
        _transferRoute(entry),
        _fieldValue(entry, 'Reason'),
      ],
      'FEE_STRUCTURE' => const <String?>[],
      _ => [entry.subtitle],
    };
    final subtitle = subtitleParts
        .whereType<String>()
        .where((value) => value.isNotEmpty && value != trailing)
        .join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? item.title : title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null && trailing.isNotEmpty) ...[
          const SizedBox(width: 16),
          Text(
            trailing,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize:
                  item.type == 'CLASS_REQUIREMENT' ||
                      item.type == 'STUDENT_REQUIREMENT'
                  ? 19
                  : 15,
              fontWeight: FontWeight.w900,
              color: AppColors.green,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdditionalRequestDetails extends StatelessWidget {
  const _AdditionalRequestDetails({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: const Icon(Icons.info_outline_rounded, color: AppColors.green),
      title: const Text(
        'View additional details',
        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
      ),
      subtitle: const Text(
        'Requester, assigned approver and request dates',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      children: [_RequestPeopleAndDates(item: item)],
    ),
  );
}

ApprovalDetailSection? _primarySection(ApprovalItem item) {
  final expected = switch (item.type) {
    'FEE_STRUCTURE' => 'Fee items',
    'CLASS_REQUIREMENT' => 'Required items',
    'STUDENT_REQUIREMENT' => 'Student-specific item',
    'FEE_ADJUSTMENT' => 'Adjustment request',
    'PAYMENT_REVERSAL' => 'Payment reversal request',
    'STUDENT_TRANSFER' => 'Transfer request',
    _ => '',
  };
  for (final section in item.detailSections) {
    if (section.title == expected) return section;
  }
  return item.detailSections.isEmpty ? null : item.detailSections.first;
}

String? _fieldValue(ApprovalDetailEntry entry, String label) {
  for (final field in entry.fields) {
    if (field.label.toLowerCase() == label.toLowerCase()) return field.value;
  }
  return null;
}

String? _labelledField(
  ApprovalDetailEntry entry,
  String fieldLabel,
  String displayLabel,
) {
  final value = _fieldValue(entry, fieldLabel);
  return value == null || value.isEmpty ? null : '$displayLabel $value';
}

String? _transferRoute(ApprovalDetailEntry entry) {
  final from = _fieldValue(entry, 'From');
  final to = _fieldValue(entry, 'To');
  if (from == null || to == null) return from ?? to;
  return '$from → $to';
}

String _decisionSectionTitle(String type) => switch (type) {
  'FEE_STRUCTURE' => 'Fees in this request',
  'CLASS_REQUIREMENT' => 'Items in this request',
  'STUDENT_REQUIREMENT' => 'Student-specific item in this request',
  'FEE_ADJUSTMENT' => 'Requested fee adjustment',
  'PAYMENT_REVERSAL' => 'Requested payment reversal',
  'STUDENT_TRANSFER' => 'Requested grade change',
  _ => 'Request summary',
};

class _RequestPeopleAndDates extends StatelessWidget {
  const _RequestPeopleAndDates({required this.item});
  final ApprovalItem item;
  @override
  Widget build(BuildContext context) => _PanelCard(
    title: 'Request information',
    icon: Icons.assignment_ind_outlined,
    child: Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        _PanelField(
          label: 'Requested by',
          value: item.requesterName.isEmpty
              ? 'Not available'
              : item.requesterName,
        ),
        _PanelField(
          label: 'Assigned approver',
          value: item.approverName.isEmpty ? 'Not assigned' : item.approverName,
        ),
        _PanelField(label: 'Created', value: _dateText(item.createdAt)),
        _PanelField(label: 'Submitted', value: _dateText(item.submittedAt)),
        _PanelField(label: 'Last updated', value: _dateText(item.updatedAt)),
      ],
    ),
  );
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        child,
      ],
    ),
  );
}

class _PanelField extends StatelessWidget {
  const _PanelField({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 245,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 16 : 13,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
            color: emphasized ? AppColors.green : AppColors.navy,
          ),
        ),
      ],
    ),
  );
}

class _LegacyRequestDetails extends StatelessWidget {
  const _LegacyRequestDetails({required this.item});
  final ApprovalItem item;
  @override
  Widget build(BuildContext context) => _PanelCard(
    title: 'Request details',
    icon: Icons.description_outlined,
    child: Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _PanelField(label: 'Category', value: item.category),
        if (item.amount != null)
          _PanelField(
            label: 'Amount',
            value: 'GH₵ ${item.amount!.toStringAsFixed(2)}',
            emphasized: true,
          ),
        if (item.reason.isNotEmpty)
          _PanelField(label: 'Reason', value: item.reason),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PENDING_APPROVAL' => const Color(0xFFD88A00),
      'CHANGES_REQUESTED' => const Color(0xFFD88A00),
      'APPROVED' || 'PUBLISHED' => AppColors.green,
      'REJECTED' || 'CANCELLED' => Colors.red,
      _ => AppColors.blue,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _statusText(status),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.myApprovals});
  final bool myApprovals;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.task_alt_rounded, size: 44, color: AppColors.green),
        const SizedBox(height: 14),
        Text(
          myApprovals
              ? 'Nothing is waiting for you'
              : 'No requests match this view',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          myApprovals
              ? 'New requests assigned to you will appear here.'
              : 'Requests you create will appear here for tracking.',
          style: const TextStyle(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String _statusText(String value) => switch (value) {
  'PENDING_APPROVAL' => 'Pending approval',
  'All' => 'All statuses',
  _ =>
    value
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' '),
};

String _dateText(DateTime? value) {
  if (value == null) return 'Not available';
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} · $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}

IconData _categoryIcon(String category) => switch (category) {
  'Items & supplies' => Icons.inventory_2_outlined,
  'Payment reversals' => Icons.undo_rounded,
  'Fee adjustments' => Icons.tune_rounded,
  _ => Icons.account_balance_wallet_outlined,
};

Color _categoryColor(String category) => switch (category) {
  'Items & supplies' => const Color(0xFF6657D9),
  'Payment reversals' => const Color(0xFFD45B53),
  'Fee adjustments' => const Color(0xFF3577D4),
  _ => AppColors.green,
};
