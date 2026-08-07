import 'dart:async';

import 'package:flutter/material.dart';

import '../../assessments/presentation/report_pdf_download_stub.dart'
    if (dart.library.html) '../../assessments/presentation/report_pdf_download_web.dart';
import '../../theme/app_theme.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';

class PaymentReversalsContent extends StatefulWidget {
  const PaymentReversalsContent({
    super.key,
    required this.api,
    required this.customSchoolId,
    required this.currentTermId,
    required this.currentUserId,
    required this.onChanged,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final int currentTermId;
  final int currentUserId;
  final Future<void> Function() onChanged;

  @override
  State<PaymentReversalsContent> createState() =>
      _PaymentReversalsContentState();
}

class _PaymentReversalsContentState extends State<PaymentReversalsContent> {
  List<PaymentReversal> _rows = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = 'ALL';
  String _term = 'CURRENT';
  String _requester = 'ALL';
  String _approver = 'ALL';
  int _page = 0;
  int _sortColumn = 5;
  bool _ascending = false;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.getSchoolPaymentReversals(
        customSchoolId: widget.customSchoolId,
      );
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
          _page = 0;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  List<PaymentReversal> get _filtered {
    final query = _query.trim().toLowerCase();
    final values = _rows.where((row) {
      if (_status != 'ALL' && row.status != _status) return false;
      if (_term == 'CURRENT' && row.termId != widget.currentTermId) {
        return false;
      }
      if (_requester != 'ALL' && row.requesterName != _requester) return false;
      if (_approver != 'ALL' && row.approverName != _approver) return false;
      if (query.isEmpty) return true;
      return row.studentName.toLowerCase().contains(query) ||
          row.customStudentId.toLowerCase().contains(query) ||
          row.paymentReference.toLowerCase().contains(query) ||
          row.reversalReference.toLowerCase().contains(query);
    }).toList();
    int compare(PaymentReversal a, PaymentReversal b) => switch (_sortColumn) {
      0 => a.studentName.compareTo(b.studentName),
      1 => a.paymentReference.compareTo(b.paymentReference),
      2 => a.amount.compareTo(b.amount),
      3 => a.status.compareTo(b.status),
      4 => a.approverName.compareTo(b.approverName),
      _ => (a.createdAt ?? DateTime(1970)).compareTo(
        b.createdAt ?? DateTime(1970),
      ),
    };
    values.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return values;
  }

  Future<void> _open(PaymentReversal reversal) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReversalQueueDialog(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        currentUserId: widget.currentUserId,
        reversal: reversal,
      ),
    );
    if (changed == true) {
      await _load();
      await widget.onChanged();
    }
  }

  int _count(String status) =>
      _rows.where((row) => row.status == status).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 90),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          children: [
            Text('Could not load reversals: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final filtered = _filtered;
    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final pageRows = filtered.skip(start).take(_pageSize).toList();
    final requesters =
        _rows
            .map((row) => row.requesterName)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final approvers =
        _rows
            .map((row) => row.approverName)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Reversals',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review, approve and audit payment corrections.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(
              label: 'Draft',
              count: _count('DRAFT'),
              color: AppColors.muted,
              onTap: () => setState(() {
                _status = 'DRAFT';
                _page = 0;
              }),
            ),
            _Metric(
              label: 'Pending approval',
              count: _count('PENDING_APPROVAL'),
              color: AppColors.amber,
              onTap: () => setState(() {
                _status = 'PENDING_APPROVAL';
                _page = 0;
              }),
            ),
            _Metric(
              label: 'Approved',
              count: _count('APPROVED'),
              color: AppColors.green,
              onTap: () => setState(() {
                _status = 'APPROVED';
                _page = 0;
              }),
            ),
            _Metric(
              label: 'Rejected',
              count: _count('REJECTED'),
              color: AppColors.red,
              onTap: () => setState(() {
                _status = 'REJECTED';
                _page = 0;
              }),
            ),
            _Metric(
              label: 'Cancelled',
              count: _count('CANCELLED'),
              color: AppColors.muted,
              onTap: () => setState(() {
                _status = 'CANCELLED';
                _page = 0;
              }),
            ),
          ],
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
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Student, receipt or reversal reference',
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _page = 0;
                    }),
                  ),
                ),
                _Filter(
                  value: _status,
                  label: 'Status',
                  values: const {
                    'ALL': 'All statuses',
                    'DRAFT': 'Draft',
                    'PENDING_APPROVAL': 'Pending approval',
                    'APPROVED': 'Approved',
                    'REJECTED': 'Rejected',
                    'CANCELLED': 'Cancelled',
                  },
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 0;
                  }),
                ),
                _Filter(
                  value: _term,
                  label: 'Term',
                  values: const {'CURRENT': 'Current term', 'ALL': 'All terms'},
                  onChanged: (value) => setState(() {
                    _term = value;
                    _page = 0;
                  }),
                ),
                _NameFilter(
                  value: _requester,
                  label: 'Requester',
                  names: requesters,
                  onChanged: (value) => setState(() {
                    _requester = value;
                    _page = 0;
                  }),
                ),
                _NameFilter(
                  value: _approver,
                  label: 'Approver',
                  names: approvers,
                  onChanged: (value) => setState(() {
                    _approver = value;
                    _page = 0;
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (pageRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Text(
                    'No reversal requests match these filters.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: _sortColumn,
                    sortAscending: _ascending,
                    columns:
                        [
                              'Student',
                              'Original receipt',
                              'Amount',
                              'Status',
                              'Approver',
                              'Requested',
                            ].indexed
                            .map(
                              (entry) => DataColumn(
                                label: Text(entry.$2),
                                onSort: (column, ascending) => setState(() {
                                  _sortColumn = column;
                                  _ascending = ascending;
                                }),
                              ),
                            )
                            .toList(),
                    rows: pageRows
                        .map(
                          (row) => DataRow(
                            onSelectChanged: (_) => _open(row),
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.studentName.isEmpty
                                          ? row.customStudentId
                                          : row.studentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      row.customStudentId,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(row.paymentReference)),
                              DataCell(
                                Text('GH₵${row.amount.toStringAsFixed(2)}'),
                              ),
                              DataCell(_StatusPill(status: row.status)),
                              DataCell(
                                Text(
                                  row.approverName.isEmpty
                                      ? 'Not assigned'
                                      : row.approverName,
                                ),
                              ),
                              DataCell(Text(_date(row.createdAt))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} request${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('Page ${_page + 1} of $pageCount'),
                    IconButton(
                      onPressed: _page + 1 >= pageCount
                          ? null
                          : () => setState(() => _page++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReversalQueueDialog extends StatefulWidget {
  const _ReversalQueueDialog({
    required this.api,
    required this.customSchoolId,
    required this.currentUserId,
    required this.reversal,
  });
  final FeeApiClient api;
  final String customSchoolId;
  final int currentUserId;
  final PaymentReversal reversal;
  @override
  State<_ReversalQueueDialog> createState() => _ReversalQueueDialogState();
}

class _ReversalQueueDialogState extends State<_ReversalQueueDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  int? _approverId;
  late Future<List<FeeAdjustmentApprover>> _approvers;
  @override
  void initState() {
    super.initState();
    _approverId = widget.reversal.approverId == 0
        ? null
        : widget.reversal.approverId;
    _approvers = widget.api.getFeeAdjustmentApprovers(widget.customSchoolId);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _requester =>
      widget.reversal.requestedBy == '${widget.currentUserId}';
  bool get _approver => widget.reversal.approverId == widget.currentUserId;

  Future<void> _action(String action) async {
    if (const {'REJECT', 'CANCEL', 'REASSIGN'}.contains(action) &&
        _reason.text.trim().length < 5) {
      setState(() => _error = 'Enter a reason of at least 5 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.performPaymentReversalAction(
        customSchoolId: widget.customSchoolId,
        reversalId: widget.reversal.id,
        action: action,
        reason: _reason.text.trim().isEmpty ? 'Approved' : _reason.text,
        approverId: _approverId,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _receipt() async {
    await _download(
      widget.api.downloadPaymentReceipts(
        customSchoolId: widget.customSchoolId,
        paymentIds: [widget.reversal.paymentId],
      ),
      '${widget.reversal.paymentReference}.pdf',
    );
  }

  Future<void> _confirmation() async {
    await _download(
      widget.api.downloadPaymentReversalConfirmation(
        customSchoolId: widget.customSchoolId,
        reversalId: widget.reversal.id,
      ),
      '${widget.reversal.reversalReference}.pdf',
    );
  }

  Future<void> _download(Future<List<int>> future, String name) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await downloadReportPdf(name, await future);
      if (!ok) {
        throw const FeeApiException('The document could not be downloaded.');
      }
      if (mounted) {
        setState(() => _busy = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reversal;
    return AlertDialog(
      title: const Text('Payment reversal'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(status: r.status),
                  const Spacer(),
                  Text(
                    'GH₵${r.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Line(
                'Student',
                r.studentName.isEmpty ? r.customStudentId : r.studentName,
              ),
              _Line('Original receipt', r.paymentReference),
              _Line(
                'Requested by',
                r.requesterName.isEmpty ? r.requestedBy : r.requesterName,
              ),
              _Line(
                'Assigned approver',
                r.approverName.isEmpty ? 'Not assigned' : r.approverName,
              ),
              _Line('Reason', r.reason),
              if (r.reversalReference.isNotEmpty)
                _Line('Reversal reference', r.reversalReference),
              if (r.isActive) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<FeeAdjustmentApprover>>(
                  future: _approvers,
                  builder: (context, snapshot) {
                    final rows =
                        (snapshot.data ?? const <FeeAdjustmentApprover>[])
                            .where((item) => item.id != widget.currentUserId)
                            .toList();
                    return DropdownButtonFormField<int>(
                      value: rows.any((item) => item.id == _approverId)
                          ? _approverId
                          : null,
                      decoration: const InputDecoration(labelText: 'Approver'),
                      items: rows
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.name} · ${item.role}'),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || !_requester
                          ? null
                          : (value) => setState(() => _approverId = value),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Action reason',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _receipt,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Original receipt'),
        ),
        if (r.status == 'APPROVED')
          FilledButton.icon(
            onPressed: _busy ? null : _confirmation,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Confirmation'),
          ),
        if (r.status == 'DRAFT' && _requester)
          FilledButton(
            onPressed: _busy || _approverId == null
                ? null
                : () => _action('SUBMIT'),
            child: const Text('Submit'),
          ),
        if (r.status == 'PENDING_APPROVAL' && _requester) ...[
          OutlinedButton(
            onPressed: _busy ? null : () => _action('CANCEL'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: _busy || _approverId == null
                ? null
                : () => _action('REASSIGN'),
            child: const Text('Change approver'),
          ),
        ],
        if (r.status == 'PENDING_APPROVAL' && _approver) ...[
          OutlinedButton(
            onPressed: _busy ? null : () => _action('REJECT'),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _action('APPROVE'),
            child: const Text('Approve'),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.value,
    required this.label,
    required this.values,
    required this.onChanged,
  });
  final String value, label;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: values.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class _NameFilter extends StatelessWidget {
  const _NameFilter({
    required this.value,
    required this.label,
    required this.names,
    required this.onChanged,
  });
  final String value, label;
  final List<String> names;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => _Filter(
    value: value,
    label: label,
    values: {
      'ALL': 'All ${label.toLowerCase()}s',
      for (final name in names) name: name,
    },
    onChanged: onChanged,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'APPROVED' => AppColors.green,
      'PENDING_APPROVAL' => AppColors.amber,
      'REJECTED' => AppColors.red,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

String _date(DateTime? value) => value == null
    ? 'Not recorded'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
