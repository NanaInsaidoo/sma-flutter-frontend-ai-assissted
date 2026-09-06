import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/approval_api_client.dart';
import '../domain/approval_models.dart';
import '../../leave/data/leave_api_client.dart';
import '../../leave/presentation/leave_management_screen.dart';
import '../../leave/presentation/leave_date_format.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.onOpenSource,
    this.onInboxChanged,
    this.leaveApi,
  });

  final String schoolId;
  final ApprovalApiClient repository;
  final ValueChanged<ApprovalItem>? onOpenSource;
  final ValueChanged<ApprovalInbox>? onInboxChanged;
  final LeaveApiClient? leaveApi;

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
                        'PENDING_ACCEPTANCE',
                        'CHANGES_REQUESTED',
                        'NEEDS_REVISION',
                        'APPROVED',
                        'ACCEPTED',
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
    if (item.type == 'STAFF_LEAVE') {
      await showLeaveRequestDetails(
        context: context,
        requestId: item.entityId,
        api:
            widget.leaveApi ??
            LeaveApiClient(
              schoolId: widget.schoolId,
              accessToken: widget.repository.accessToken,
              onRefreshAccessToken: widget.repository.onRefreshAccessToken,
            ),
        onChanged: () {
          if (mounted) _refresh();
        },
      );
      if (mounted) _refresh();
      return;
    }
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
      itemsStillInIssuerCustody:
          item.type == 'SHOP_STOCK_HANDOVER' && action == 'CANCEL',
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
              'Review requests available to you and follow the requests you submitted.',
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
        caption: 'Waiting for your action',
        onTap: () => onChanged(true),
      ),
      _SummaryCard(
        selected: !myApprovals,
        icon: Icons.outbox_outlined,
        title: 'My requests',
        count: inbox.pendingMyRequests,
        caption: 'Still awaiting completion',
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
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
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
                    item.type == 'STAFF_LEAVE'
                        ? formatLeaveSummaryDates(item.subtitle)
                        : item.subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (constraints.maxWidth < 400) ...[
                    const SizedBox(height: 8),
                    _StatusPill(status: item.status),
                  ],
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
            if (constraints.maxWidth >= 400) _StatusPill(status: item.status),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
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
  Future<void> _run(
    String action, {
    bool reasonRequired = false,
    String? reasonPrompt,
  }) async {
    if (_busy) return;
    var reason = '';
    if (action == 'APPROVE' && widget.item.type == 'SHOP_RECONCILIATION') {
      final sellerAcknowledgement = widget.item.status == 'AWAITING_SELLER_ACK';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            sellerAcknowledgement
                ? 'Acknowledge this count?'
                : 'Confirm differences and close reconciliation?',
          ),
          content: Text(
            sellerAcknowledgement
                ? 'Confirm that you have reviewed the stock and money counted for you. If there are differences, an independent administrator will resolve them.'
                : 'This will update the recorded balances using the confirmed differences and permanently close this reconciliation. Continue only after checking the count. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(
                sellerAcknowledgement
                    ? 'Acknowledge as correct'
                    : 'Confirm and continue',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (action == 'ACCEPT' && widget.item.type == 'SHOP_STOCK_HANDOVER') {
      final entries = _primarySection(widget.item)?.entries;
      final entry = entries == null || entries.isEmpty ? null : entries.first;
      final quantity = entry == null ? null : _fieldValue(entry, 'Quantity');
      final stockDescription = entry == null
          ? 'this stock'
          : quantity == null || quantity.isEmpty
          ? entry.title
          : '$quantity of ${entry.title}';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm stock received?'),
          content: Text(
            'Confirm only after you have physically received and counted $stockDescription. You will become responsible for it after confirmation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              key: const ValueKey('approval-confirm-stock-received'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, confirm receipt'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (action == 'CANCEL' && widget.item.type == 'SHOP_STOCK_HANDOVER') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _CancelStockIssueConfirmation(
          recipientName: widget.item.approverName,
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (reasonRequired) {
      final value = await showDialog<String>(
        context: context,
        builder: (context) =>
            _DecisionReasonDialog(action: reasonPrompt ?? action),
      );
      if (value == null || !mounted) return;
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
                    Expanded(
                      child: Text(
                        item.type == 'STUDENT_ITEM_EXEMPTION'
                            ? 'Item exemption'
                            : item.type == 'STUDENT_RECORD_CHANGE'
                            ? 'Student record change'
                            : item.type == 'SHOP_STOCK_HANDOVER'
                            ? 'Stock handover'
                            : item.type == 'SHOP_RECONCILIATION'
                            ? 'Reconciliation review'
                            : 'Approval details',
                        style: const TextStyle(
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
                      if (item.type == 'STUDENT_ITEM_EXEMPTION')
                        _ItemExemptionRequest(item: item)
                      else if (item.type == 'STUDENT_RECORD_CHANGE')
                        _StudentRecordChangeRequest(item: item)
                      else if (item.type == 'SHOP_STOCK_HANDOVER')
                        _StockHandoverRequest(
                          item: item,
                          onOpenSource: widget.onOpenSource,
                        )
                      else if (item.type == 'SHOP_RECONCILIATION')
                        _ShopReconciliationRequest(item: item)
                      else ...[
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
                      ],
                      if (widget.onOpenSource != null &&
                          item.type != 'SHOP_STOCK_HANDOVER') ...[
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
                                      item.type == 'SHOP_STOCK_HANDOVER'
                                      ? _run('CANCEL')
                                      : _run('WITHDRAW', reasonRequired: true),
                                  child: Text(
                                    item.type == 'SHOP_STOCK_HANDOVER'
                                        ? 'Cancel issuance'
                                        : 'Withdraw approval request',
                                  ),
                                ),
                              ),
                            if (item.canReject)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _run(
                                    'REJECT',
                                    reasonRequired: true,
                                    reasonPrompt:
                                        item.type == 'SHOP_STOCK_HANDOVER'
                                        ? 'STOCK_PROBLEM'
                                        : item.type == 'SHOP_RECONCILIATION'
                                        ? item.status == 'AWAITING_SELLER_ACK'
                                              ? 'DISPUTE_COUNT'
                                              : 'RECOUNT'
                                        : null,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: Text(
                                    item.type == 'SHOP_STOCK_HANDOVER'
                                        ? 'Report problem'
                                        : item.type == 'SHOP_RECONCILIATION'
                                        ? item.status == 'AWAITING_SELLER_ACK'
                                              ? 'Report a problem'
                                              : 'Send for recount'
                                        : 'Reject',
                                  ),
                                ),
                              ),
                            if ((item.canWithdraw || item.canReject) &&
                                item.canApprove)
                              const SizedBox(width: 10),
                            if (item.canApprove)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _run(
                                    item.type == 'SHOP_STOCK_HANDOVER'
                                        ? 'ACCEPT'
                                        : 'APPROVE',
                                    reasonRequired:
                                        item.type == 'SHOP_RECONCILIATION' &&
                                        item.status != 'AWAITING_SELLER_ACK',
                                    reasonPrompt: 'RESOLUTION',
                                  ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: Text(
                                    item.type == 'SHOP_STOCK_HANDOVER'
                                        ? 'Confirm receipt'
                                        : item.type == 'SHOP_RECONCILIATION'
                                        ? item.status == 'AWAITING_SELLER_ACK'
                                              ? 'Acknowledge as correct'
                                              : 'Resolve differences'
                                        : 'Approve',
                                  ),
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

class _CancelStockIssueConfirmation extends StatefulWidget {
  const _CancelStockIssueConfirmation({required this.recipientName});

  final String recipientName;

  @override
  State<_CancelStockIssueConfirmation> createState() =>
      _CancelStockIssueConfirmationState();
}

class _CancelStockIssueConfirmationState
    extends State<_CancelStockIssueConfirmation> {
  bool _affirmed = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cancel stock issuance?'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cancelling will return the full quantity to the central store.',
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            key: const ValueKey('stock-cancellation-custody-affirmation'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _affirmed,
            onChanged: (value) => setState(() => _affirmed = value == true),
            title: Text(
              'I confirm the items are still in my custody and were not handed to ${widget.recipientName}.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep issuance'),
      ),
      FilledButton(
        key: const ValueKey('confirm-stock-issuance-cancellation'),
        onPressed: _affirmed ? () => Navigator.pop(context, true) : null,
        style: FilledButton.styleFrom(backgroundColor: AppColors.red),
        child: const Text('Cancel issuance'),
      ),
    ],
  );
}

class _DecisionReasonDialog extends StatefulWidget {
  const _DecisionReasonDialog({required this.action});
  final String action;

  @override
  State<_DecisionReasonDialog> createState() => _DecisionReasonDialogState();
}

class _DecisionReasonDialogState extends State<_DecisionReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(switch (widget.action) {
      'REJECT' => 'Reject request',
      'STOCK_PROBLEM' => 'Report a stock problem',
      'DISPUTE_COUNT' => 'Dispute this count',
      'RECOUNT' => 'Reject and recount',
      'RESOLUTION' => 'Record the resolution',
      _ => 'Withdraw approval request',
    }),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: 'Decision reason *',
          hintText: switch (widget.action) {
            'REJECT' => 'Explain why you are rejecting this request.',
            'STOCK_PROBLEM' =>
              'Explain what is wrong, such as the item or quantity.',
            'DISPUTE_COUNT' =>
              'Explain which stock or money count you disagree with.',
            'RECOUNT' => 'Explain why a fresh count is required.',
            'RESOLUTION' =>
              'Explain how the differences were checked and resolved.',
            _ => 'Explain why you are withdrawing this request.',
          },
          helperText: '5–1000 characters. Saved in the audit trail.',
          helperMaxLines: 2,
          errorMaxLines: 2,
        ),
        validator: (value) {
          final length = (value ?? '').trim().length;
          return length < 5 || length > 1000
              ? 'Enter a decision reason (5–1000 characters).'
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: Text(switch (widget.action) {
          'STOCK_PROBLEM' => 'Report problem',
          'DISPUTE_COUNT' => 'Submit dispute',
          'RESOLUTION' => 'Resolve and close',
          _ => 'Continue',
        }),
      ),
    ],
  );
}

class _ApprovalPanelResult {
  const _ApprovalPanelResult({this.reload = false, this.conflictMessage});
  final bool reload;
  final String? conflictMessage;
}

class _ShopReconciliationRequest extends StatelessWidget {
  const _ShopReconciliationRequest({required this.item});

  final ApprovalItem item;

  double _number(String? value) =>
      double.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;

  String _difference(String? value, {bool money = false}) {
    final amount = _number(value);
    if (amount == 0) return 'Matches';
    final formatted = money
        ? 'GHS ${amount.abs().toStringAsFixed(2)}'
        : '${amount.abs().toInt()}';
    return '$formatted ${amount < 0 ? 'short' : 'extra'}';
  }

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _line(ApprovalDetailEntry entry) {
    final difference = _fieldValue(entry, 'Difference');
    final explanation = _fieldValue(entry, 'Explanation');
    final money =
        entry.title == 'Cash held' || entry.title == 'Mobile Money records';
    final changed = _number(difference) != 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (entry.subtitle.isNotEmpty)
                      Text(
                        entry.subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (changed ? AppColors.red : AppColors.green).withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _difference(difference, money: money),
                  style: TextStyle(
                    color: changed ? AppColors.red : AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 5,
            children: [
              Text('Expected: ${_fieldValue(entry, 'Expected') ?? '—'}'),
              Text(
                'Counted: ${_fieldValue(entry, 'Counted') ?? _fieldValue(entry, 'Verified') ?? '—'}',
              ),
            ],
          ),
          if (changed) ...[
            const SizedBox(height: 6),
            Text(
              'Explanation: ${explanation == null || explanation == 'null' || explanation.trim().isEmpty ? 'Not provided' : explanation}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _primarySection(item)?.entries ?? const [];
    final cash = entries
        .where((entry) => entry.title == 'Cash held')
        .firstOrNull;
    final momo = entries
        .where((entry) => entry.title == 'Mobile Money records')
        .firstOrNull;
    final stock = entries
        .where(
          (entry) =>
              entry.title != 'Cash held' &&
              entry.title != 'Mobile Money records',
        )
        .toList();
    final stockDifferences = stock
        .where((entry) => _number(_fieldValue(entry, 'Difference')) != 0)
        .toList();
    final cashDifference = _number(
      cash == null ? null : _fieldValue(cash, 'Difference'),
    );
    final momoDifference = _number(
      momo == null ? null : _fieldValue(momo, 'Difference'),
    );
    final seller = item.title.replaceFirst(
      RegExp(r'^Independent count\s*·\s*'),
      '',
    );
    final acknowledging = item.status == 'AWAITING_SELLER_ACK';
    final attention = <ApprovalDetailEntry>[
      ...stockDifferences,
      if (cash != null && cashDifference != 0) cash,
      if (momo != null && momoDifference != 0) momo,
    ];

    return Column(
      key: const ValueKey('shop-reconciliation-approval-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusPill(status: item.status),
        const SizedBox(height: 14),
        Text(
          seller,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(item.subtitle, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: acknowledging
                ? AppColors.green.withValues(alpha: 0.07)
                : AppColors.amber.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                acknowledging
                    ? 'Your confirmation is required'
                    : 'Your independent decision is required',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                acknowledging
                    ? 'Review the count below. Acknowledge only if the figures are correct; report a problem if anything is wrong.'
                    : 'Review every difference and explanation. Resolve only after an independent check, or send it for a recount.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StockHandoverField(label: 'Seller being reconciled', value: seller),
        _StockHandoverField(label: 'Counted by', value: item.requesterName),
        _StockHandoverField(
          label: acknowledging ? 'Acknowledged by' : 'Independent approver',
          value: item.approverName,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric(
              'Stock checked',
              '${stock.length} item lines',
              Icons.inventory_2_outlined,
              AppColors.green,
            ),
            _metric(
              'Stock differences',
              stockDifferences.isEmpty
                  ? 'None'
                  : '${stockDifferences.length} need attention',
              Icons.warning_amber_rounded,
              stockDifferences.isEmpty ? AppColors.green : AppColors.red,
            ),
            _metric(
              'Cash difference',
              _difference(
                cash == null ? null : _fieldValue(cash, 'Difference'),
                money: true,
              ),
              Icons.payments_outlined,
              cashDifference == 0 ? AppColors.green : AppColors.red,
            ),
            _metric(
              'Mobile Money difference',
              _difference(
                momo == null ? null : _fieldValue(momo, 'Difference'),
                money: true,
              ),
              Icons.phone_android_outlined,
              momoDifference == 0 ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Differences requiring attention',
          icon: attention.isEmpty
              ? Icons.check_circle_outline
              : Icons.warning_amber_rounded,
          child: attention.isEmpty
              ? const Text('All stock and money records match the count.')
              : Column(children: [for (final entry in attention) _line(entry)]),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ExpansionTile(
            key: const ValueKey('shop-reconciliation-full-count'),
            initiallyExpanded: stock.length <= 5,
            title: const Text(
              'Review all stock count lines',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${stock.length} item lines'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [for (final entry in stock) _line(entry)],
          ),
        ),
      ],
    );
  }
}

class _StockHandoverRequest extends StatelessWidget {
  const _StockHandoverRequest({required this.item, this.onOpenSource});

  final ApprovalItem item;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final section = _primarySection(item);
    final entry = section == null || section.entries.isEmpty
        ? null
        : section.entries.first;
    String value(String label, [String fallback = 'Not specified']) {
      final result = entry == null ? null : _fieldValue(entry, label);
      return result == null || result.trim().isEmpty ? fallback : result;
    }

    final itemName =
        (entry?.title.isNotEmpty == true
                ? entry!.title
                : item.title.replaceFirst(
                    RegExp(r'^Stock handover\s*·\s*'),
                    '',
                  ))
            .replaceAll(' · ', ', ');
    final status = switch (item.status) {
      'PENDING_ACCEPTANCE' =>
        'Pending — waiting on ${item.approverName.isEmpty ? 'recipient' : item.approverName} to confirm',
      'ACCEPTED' => 'Receipt confirmed',
      'REJECTED' => 'Problem reported',
      'CANCELLED' => 'Issuance cancelled',
      _ => _statusText(item.status),
    };
    final statusColor = switch (item.status) {
      'PENDING_ACCEPTANCE' => AppColors.amber,
      'ACCEPTED' => AppColors.green,
      'REJECTED' || 'CANCELLED' => AppColors.red,
      _ => AppColors.muted,
    };

    return Container(
      key: const ValueKey('stock-handover-compact-details'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            itemName,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested ${_dateText(item.submittedAt ?? item.createdAt).replaceFirst(' · ', ', ')}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          _StockHandoverField(
            label: 'Quantity',
            value: value('Quantity'),
            emphasized: true,
          ),
          _StockHandoverField(
            label: 'From',
            value: value('Issued by', item.requesterName),
          ),
          _StockHandoverField(
            label: 'To',
            value: value('Issued to', item.approverName),
          ),
          _StockHandoverField(label: 'Location', value: value('Location')),
          if (onOpenSource != null) ...[
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('stock-handover-open-source'),
              onPressed: onOpenSource,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Open source page →'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockHandoverField extends StatelessWidget {
  const _StockHandoverField({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasized ? AppColors.green : AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
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
                    _requestSummaryTitle(item),
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
      title: item.type == 'SHOP_STOCK_HANDOVER'
          ? 'Issue note'
          : revised
          ? 'Reason for revision'
          : 'Requester note',
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

class _StudentRecordChangeRequest extends StatelessWidget {
  const _StudentRecordChangeRequest({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final reason = item.requesterNote.trim();
    final entries = item.detailSections.expand((section) => section.entries);
    return Container(
      key: const Key('student-record-change-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(status: item.status),
          const SizedBox(height: 12),
          Text(
            item.title.replaceFirst(RegExp(r'^Record change\s*·\s*'), ''),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const Text('No changed fields were recorded for this request.')
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? 'Requested change' : entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RecordChangeValue(
                            label: 'Before',
                            value:
                                _fieldValue(entry, 'Before') ?? 'Not recorded',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 19, 8, 0),
                          child: Icon(Icons.arrow_forward_rounded, size: 16),
                        ),
                        Expanded(
                          child: _RecordChangeValue(
                            label: 'Proposed',
                            value:
                                _fieldValue(entry, 'Proposed') ??
                                'Not recorded',
                            proposed: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          const Text(
            'Reason',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(reason.isEmpty ? 'Not provided' : reason),
          if (item.pending) ...[
            const SizedBox(height: 12),
            const Text(
              'Changes take effect only after approval.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('student-record-change-more-details'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'More details',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              children: [
                for (final detail in <String, String>{
                  'Student ID': item.subtitle,
                  'Requested by': item.requesterName,
                  'Approver': item.approverName,
                  'Submitted': _dateText(item.submittedAt ?? item.createdAt),
                  if (item.decidedAt != null)
                    'Decided': _dateText(item.decidedAt),
                  if (!item.pending &&
                      item.reason.isNotEmpty &&
                      item.reason != reason)
                    'Decision note': item.reason,
                }.entries)
                  if (detail.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              detail.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordChangeValue extends StatelessWidget {
  const _RecordChangeValue({
    required this.label,
    required this.value,
    this.proposed = false,
  });
  final String label;
  final String value;
  final bool proposed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: proposed ? AppColors.green : AppColors.navy,
          fontWeight: proposed ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ],
  );
}

class _ItemExemptionRequest extends StatelessWidget {
  const _ItemExemptionRequest({required this.item});
  final ApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final entries =
        _primarySection(item)?.entries ?? const <ApprovalDetailEntry>[];
    final entry = entries.isEmpty ? null : entries.first;
    String field(String label) =>
        entry == null ? '' : (_fieldValue(entry, label) ?? '').trim();
    final student = field('Student');
    final itemName = field('Item');
    final reason = item.requesterNote.trim().isNotEmpty
        ? item.requesterNote.trim()
        : field('Reason').isNotEmpty
        ? field('Reason')
        : item.reason;
    final quantities = [
      if (field('Current requirement').isNotEmpty)
        '${field('Current requirement')} required',
      if (field('Already received').isNotEmpty)
        '${field('Already received')} received',
    ].join(' · ');
    final metadata = <String, String>{
      'Student ID': field('Student ID'),
      'Academic period': field('Academic period').isEmpty
          ? item.academicPeriod
          : field('Academic period'),
      'Requested by': item.requesterName,
      'Approver': item.approverName,
      'Created': _dateText(item.createdAt),
      'Submitted': _dateText(item.submittedAt ?? item.createdAt),
      'Last updated': _dateText(item.updatedAt),
      'Scope': field('Requested change'),
      if (item.decidedAt != null) 'Decided': _dateText(item.decidedAt),
      if (!item.pending && item.reason.isNotEmpty && item.reason != reason)
        'Decision note': item.reason,
    };
    return Container(
      key: const Key('item-exemption-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(status: item.status),
          const SizedBox(height: 14),
          Text(
            [
              student.isEmpty ? item.title : student,
              field('Class'),
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            itemName.isEmpty
                ? (item.subtitle.isEmpty ? 'Item not specified' : item.subtitle)
                : itemName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          if (quantities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(quantities, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 18),
          const Text(
            'Reason',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(reason.isEmpty ? 'Not provided' : reason),
          const SizedBox(height: 14),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('item-exemption-more-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4),
              title: const Text(
                'More details',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              children: [
                for (final detail in metadata.entries)
                  if (detail.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              detail.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              detail.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
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
    if (item.type == 'SHOP_INVENTORY_ADJUSTMENT') {
      return _InventoryAdjustmentDecisionRow(entry: entry);
    }
    if (item.type == 'SHOP_RECONCILIATION') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(entry.subtitle, style: const TextStyle(color: AppColors.muted)),
          for (final field in entry.fields)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${field.label}: ${field.value}'),
            ),
        ],
      );
    }
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
      'SHOP_STOCK_HANDOVER' => _fieldValue(entry, 'Quantity'),
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
      'SHOP_STOCK_HANDOVER' => [
        _labelledField(entry, 'Issued by', 'From'),
        _labelledField(entry, 'Issued to', 'To'),
        _labelledField(entry, 'Location', 'Location'),
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

class _InventoryAdjustmentDecisionRow extends StatelessWidget {
  const _InventoryAdjustmentDecisionRow({required this.entry});
  final ApprovalDetailEntry entry;

  @override
  Widget build(BuildContext context) {
    final current =
        _fieldValue(entry, 'Current unassigned quantity') ?? 'Not recorded';
    final proposed =
        _fieldValue(entry, 'Proposed unassigned quantity') ?? 'Not recorded';
    final rawChange = (_fieldValue(entry, 'Quantity change') ?? '').trim();
    final reduction = rawChange.startsWith('-');
    final increase = rawChange.startsWith('+');
    final changedAmount = rawChange.replaceFirst(RegExp(r'^[+-]'), '').trim();
    final action = reduction
        ? 'Remove $changedAmount from available inventory'
        : increase
        ? 'Add $changedAmount to available inventory'
        : 'Correct available inventory to $proposed';
    final actionColor = reduction ? AppColors.red : AppColors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: actionColor.withValues(alpha: .24)),
          ),
          child: Row(
            children: [
              Icon(
                reduction
                    ? Icons.remove_circle_outline
                    : increase
                    ? Icons.add_circle_outline
                    : Icons.inventory_outlined,
                color: actionColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action,
                  style: TextStyle(
                    color: actionColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InventoryApprovalQuantity(
                label: 'Current stock',
                value: current,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward_rounded, color: AppColors.muted),
            ),
            Expanded(
              child: _InventoryApprovalQuantity(
                label: 'After approval',
                value: proposed,
                emphasized: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'The available central-store quantity changes only if this request is approved.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _InventoryApprovalQuantity extends StatelessWidget {
  const _InventoryApprovalQuantity({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: emphasized ? AppColors.green : AppColors.navy,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
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
        'Requester, assigned person and important dates',
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
    'STUDENT_ITEM_EXEMPTION' => 'Student item exemption',
    'FEE_ADJUSTMENT' => 'Adjustment request',
    'PAYMENT_REVERSAL' => 'Payment reversal request',
    'STUDENT_TRANSFER' => 'Transfer request',
    'SHOP_INVENTORY_ADJUSTMENT' => 'Inventory change',
    'SHOP_STOCK_HANDOVER' => 'Stock handover',
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
  'SHOP_RECONCILIATION' => 'Counts and adjustments',
  'FEE_STRUCTURE' => 'Fees in this request',
  'CLASS_REQUIREMENT' => 'Items in this request',
  'STUDENT_REQUIREMENT' => 'Student-specific item in this request',
  'STUDENT_ITEM_EXEMPTION' => 'Item being exempted',
  'FEE_ADJUSTMENT' => 'Requested fee adjustment',
  'PAYMENT_REVERSAL' => 'Requested payment reversal',
  'STUDENT_TRANSFER' => 'Requested grade change',
  'SHOP_INVENTORY_ADJUSTMENT' => 'Requested inventory change',
  'SHOP_STOCK_HANDOVER' => 'Stock awaiting confirmation',
  _ => 'Request summary',
};

String _requestSummaryTitle(ApprovalItem item) {
  if (item.type != 'SHOP_INVENTORY_ADJUSTMENT') return item.title;
  final entries = _primarySection(item)?.entries;
  if (entries == null || entries.isEmpty) return item.title;
  final entry = entries.first;
  final change = (_fieldValue(entry, 'Quantity change') ?? '').trim();
  final type = entry.subtitle.toLowerCase();
  final action = type.contains('reduction') || change.startsWith('-')
      ? 'Remove stock'
      : type.contains('increase') || change.startsWith('+')
      ? 'Add stock'
      : 'Correct stock count';
  return '$action · ${entry.title}';
}

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
          label: item.type == 'SHOP_STOCK_HANDOVER'
              ? 'Issued by'
              : 'Requested by',
          value: item.requesterName.isEmpty
              ? 'Not available'
              : item.requesterName,
        ),
        _PanelField(
          label: item.type == 'SHOP_STOCK_HANDOVER'
              ? 'Recipient'
              : 'Assigned approver',
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
      'PENDING_APPROVAL' || 'PENDING_ACCEPTANCE' => const Color(0xFFD88A00),
      'CHANGES_REQUESTED' => const Color(0xFFD88A00),
      'APPROVED' || 'PUBLISHED' || 'ACCEPTED' => AppColors.green,
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
