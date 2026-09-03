import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/leave_api_client.dart';
import 'leave_date_format.dart';
import 'leave_calendar.dart';
import '../../theme/app_theme.dart';
import '../../platform/presentation/document_opener_stub.dart'
    if (dart.library.html) '../../platform/presentation/document_opener_web.dart';

String leaveLabel(Object? value) => switch (value) {
  'DRAFT' => 'Draft',
  'APPROVED' => 'Approved',
  'REJECTED' => 'Rejected',
  'CANCELLED' => 'Cancelled',
  'PENDING_APPROVAL' => 'Pending approval',
  'NEEDS_REVISION' => 'Needs revision',
  'ON_LEAVE' => 'On leave today',
  'CHANGE_PENDING_APPROVAL' => 'Change pending approval',
  'EARLY_RETURN' => 'Early return',
  'VOID' => 'Approval revoked',
  'CANCEL' => 'Cancellation',
  'WITHDRAWN' => 'Withdrawn',
  'REQUEST_CHANGES' => 'Changes requested',
  'WITHDRAW' => 'Withdrawn',
  'REVOKE' => 'Approval revoked',
  _ => (value ?? '').toString().toLowerCase().replaceAll('_', ' '),
};
const leaveStatuses = [
  'PENDING_APPROVAL',
  'APPROVED',
  'REJECTED',
  'DRAFT',
  'NEEDS_REVISION',
  'CANCELLED',
  'ON_LEAVE',
  'CHANGE_PENDING_APPROVAL',
];

const _leaveTableFields = [
  'id',
  'staffName',
  'typeName',
  'startDate',
  'endDate',
  'days',
  'status',
  'createdAt',
];

/// All entry points load the current request and use the same permission-aware reviewer UI.
Future<bool?> showLeaveRequestDetails({
  required BuildContext context,
  required LeaveApiClient api,
  required int requestId,
  LeaveJson? contextData,
  VoidCallback? onChanged,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _LeaveDetail(
    api: api,
    id: requestId,
    contextData: contextData,
    onChanged: onChanged,
  ),
);
String _date(DateTime date) => date.toIso8601String().split('T').first;
List<LeaveJson> _maps(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({
    super.key,
    required this.api,
    this.staffUserId,
    this.embedded = false,
    this.myLeave = false,
    this.onChanged,
  });
  final LeaveApiClient api;
  final int? staffUserId;
  final bool embedded;
  final bool myLeave;
  final VoidCallback? onChanged;
  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  LeaveJson? _context, _result;
  List<LeaveJson> _balances = [];
  String? _error, _status;
  int? _staff;
  int _page = 0, _year = DateTime.now().year, _loadId = 0;
  bool _loading = true;
  int _sortColumn = 7;
  bool _sortAscending = false;
  DateTimeRange? _range;
  bool _calendarView = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool get _reviewer => !widget.myLeave && _context?['canReview'] == true;
  int get _me => _context!['currentUserId'] as int;
  @override
  void initState() {
    super.initState();
    _staff = widget.staffUserId;
    _load();
  }

  @override
  void didUpdateWidget(covariant LeaveManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staffUserId != widget.staffUserId ||
        oldWidget.myLeave != widget.myLeave ||
        oldWidget.api.schoolId != widget.api.schoolId ||
        oldWidget.api.accessToken != widget.api.accessToken) {
      _context = null;
      _result = null;
      _balances = [];
      _staff = widget.staffUserId;
      _page = 0;
      _status = null;
      _range = null;
      _load();
    }
  }

  Future<void> _load() async {
    final load = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await widget.api.context();
      if (!mounted || load != _loadId) return;
      if (!widget.myLeave && !widget.embedded && ctx['canReview'] != true) {
        setState(() {
          _context = ctx;
          _result = null;
          _balances = [];
          _loading = false;
        });
        return;
      }
      final staffId = widget.myLeave ? ctx['currentUserId'] as int : _staff;
      final data = _calendarView
          ? await widget.api.calendar(
              month: _calendarMonth,
              staffId: staffId,
              status: _status,
            )
          : await widget.api.list(
              staffId: staffId,
              status: _status,
              from: _range == null ? null : _date(_range!.start),
              to: _range == null ? null : _date(_range!.end),
              page: _page,
              sortBy: _leaveTableFields[_sortColumn],
              direction: _sortAscending ? 'asc' : 'desc',
            );
      final balances = await widget.api.balances(
        staffId ?? ctx['currentUserId'] as int,
        _year,
      );
      if (!mounted || load != _loadId) return;
      setState(() {
        _context = ctx;
        _result = data;
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      if (mounted && load == _loadId) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _changed() {
    widget.onChanged?.call();
    _load();
  }

  Future<void> _form([LeaveJson? request]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeaveForm(
        api: widget.api,
        contextData: _context!,
        request: request,
        staffId: widget.myLeave ? _me : _staff,
        lockStaff: widget.myLeave,
      ),
    );
    if (changed == true && mounted) _changed();
  }

  Future<void> _detail(LeaveJson row) async {
    await showLeaveRequestDetails(
      context: context,
      api: widget.api,
      requestId: row['id'] as int,
      contextData: _context,
      onChanged: _changed,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_context != null &&
        !widget.myLeave &&
        !widget.embedded &&
        _context!['canReview'] != true) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Leave Management is available to authorised leave approvers. Open My Leave to view your own requests.',
          ),
        ),
      );
    }
    if (_loading && _result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 24,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.myLeave
                      ? 'My Leave'
                      : widget.embedded
                      ? 'Leave history'
                      : 'Leave Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _reviewer
                      ? 'Review requests and plan staff availability.'
                      : 'Your leave requests, decisions and balances.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            if (_context != null)
              FilledButton.icon(
                onPressed: _loading ? null : () => _form(),
                icon: const Icon(Icons.add),
                label: const Text('Request leave'),
              ),
            IconButton(
              tooltip: 'Refresh leave',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) _errorPanel(_error!, _load),
        if (_result != null && _context != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final status in leaveStatuses)
                SizedBox(
                  key: ValueKey('leave-status-$status'),
                  width: 210,
                  child: Card(
                    child: InkWell(
                      onTap: _loading
                          ? null
                          : () {
                              setState(() {
                                _status = status;
                                _page = 0;
                              });
                              _load();
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status == 'PENDING_APPROVAL'
                                  ? 'Pending requests'
                                  : status == 'ON_LEAVE'
                                  ? 'On leave today'
                                  : status == 'APPROVED'
                                  ? 'Approved leave'
                                  : status == 'REJECTED'
                                  ? 'Rejected requests'
                                  : leaveLabel(status),
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_result!['counts'] as Map)[status] ?? 0}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.myLeave
                  ? 'Your requests across all dates. On leave is as of today (UTC).'
                  : 'Counts cover all dates for the selected staff. On leave is as of today (UTC).',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        key: const ValueKey('leave-view-switch'),
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('List'),
                            icon: Icon(Icons.table_rows_outlined),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Calendar'),
                            icon: Icon(Icons.calendar_month_outlined),
                          ),
                        ],
                        selected: {_calendarView},
                        onSelectionChanged: _loading
                            ? null
                            : (selection) {
                                setState(() {
                                  _calendarView = selection.single;
                                  _page = 0;
                                });
                                _load();
                              },
                      ),
                      if (_reviewer && widget.staffUserId == null)
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<int>(
                            value: _staff ?? -1,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Staff member',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: -1,
                                child: Text('All staff'),
                              ),
                              for (final staff in _maps(_context!['staff']))
                                DropdownMenuItem(
                                  value: staff['id'] as int,
                                  child: Text(
                                    staff['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _loading
                                ? null
                                : (v) {
                                    setState(() {
                                      _staff = v == -1 ? null : v;
                                      _page = 0;
                                    });
                                    _load();
                                  },
                          ),
                        ),
                      SizedBox(
                        width: 215,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey(_status),
                          value: _status ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All statuses'),
                            ),
                            for (final s in [
                              'DRAFT',
                              'PENDING_APPROVAL',
                              'APPROVED',
                              'REJECTED',
                              'CANCELLED',
                              'NEEDS_REVISION',
                              'ON_LEAVE',
                              'CHANGE_PENDING_APPROVAL',
                            ])
                              DropdownMenuItem(
                                value: s,
                                child: Text(leaveLabel(s)),
                              ),
                          ],
                          onChanged: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    _status = v == '' ? null : v;
                                    _page = 0;
                                  });
                                  _load();
                                },
                        ),
                      ),
                      if (!_calendarView)
                        OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                  final value = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2200, 12, 31),
                                    initialDateRange: _range,
                                  );
                                  if (value != null && mounted) {
                                    setState(() {
                                      _range = value;
                                      _page = 0;
                                    });
                                    _load();
                                  }
                                },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _range == null
                                ? 'Filter leave dates'
                                : formatLeaveDateRange(
                                    _range!.start,
                                    _range!.end,
                                  ),
                          ),
                        ),
                      if (!_calendarView && _range != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _range = null;
                              _page = 0;
                            });
                            _load();
                          },
                          child: const Text('Clear dates'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.myLeave ? 'My requests' : 'Leave requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_calendarView)
                    LeaveCalendar(
                      month: _calendarMonth,
                      rows: _loading || _error != null
                          ? []
                          : _maps(_result!['items']),
                      loading: _loading,
                      hasError: _error != null,
                      statusLabel: leaveLabel,
                      onMonthChanged: (month) {
                        setState(() => _calendarMonth = month);
                        _load();
                      },
                      onOpen: _detail,
                    )
                  else ...[
                    const Text(
                      'Select a column to sort. Open a row to view the request.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _LeaveRequestsTable(
                      rows: _maps(_result!['items']),
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onSort: _loading
                          ? null
                          : (column, ascending) {
                              setState(() {
                                _sortColumn = column;
                                _sortAscending = ascending;
                                _page = 0;
                              });
                              _load();
                            },
                      onOpen: _detail,
                    ),
                    if (_maps(_result!['items']).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No leave requests found. New requests will appear here.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text('${_result!['total']} requests')),
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _loading || _page == 0
                              ? null
                              : () {
                                  setState(() => _page--);
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page ${_page + 1}'),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed:
                              _loading ||
                                  (_page + 1) * 25 >= (_result!['total'] as int)
                              ? null
                              : () {
                                  setState(() => _page++);
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ExpansionTile(
              title: Text(
                '${_staff == null ? 'My leave balances' : 'Leave balances'} · $_year',
              ),
              subtitle: const Text(
                'Taken, scheduled and pending days are tracked separately.',
              ),
              childrenPadding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous allowance year',
                      onPressed: _year <= 2000
                          ? null
                          : () {
                              setState(() => _year--);
                              _load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('$_year'),
                    IconButton(
                      tooltip: 'Next allowance year',
                      onPressed: _year >= 2200
                          ? null
                          : () {
                              setState(() => _year++);
                              _load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const Spacer(),
                    if (_reviewer && (_staff ?? _me) != _me)
                      OutlinedButton(
                        onPressed: () => _allowance(),
                        child: const Text('Set allowance'),
                      ),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Inclusive calendar days, including weekends. No automatic carry-over.',
                  ),
                ),
                const SizedBox(height: 10),
                for (final b in _balances)
                  ListTile(
                    dense: true,
                    title: Text('${b['typeName']}'),
                    subtitle: Text(
                      'Taken: ${b['takenDays'] ?? 0} · Scheduled: ${b['scheduledDays'] ?? b['approvedDays'] ?? 0} · Pending: ${b['pendingDays']}',
                    ),
                    trailing: Text(
                      b['allowance'] == null
                          ? 'Not configured'
                          : '${b['available']} / ${b['allowance']} available',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
    return widget.embedded
        ? content
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: content,
          );
  }

  Future<void> _allowance() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AllowanceDialog(
        api: widget.api,
        staffId: _staff!,
        year: _year,
        types: _maps(_context!['types']),
      ),
    );
    if (changed == true && mounted) _changed();
  }
}

class _LeaveRequestsTable extends StatefulWidget {
  const _LeaveRequestsTable({
    required this.rows,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onOpen,
  });
  final List<LeaveJson> rows;
  final int sortColumn;
  final bool sortAscending;
  final DataColumnSortCallback? onSort;
  final ValueChanged<LeaveJson> onOpen;

  @override
  State<_LeaveRequestsTable> createState() => _LeaveRequestsTableState();
}

class _LeaveRequestsTableState extends State<_LeaveRequestsTable> {
  final _scroll = ScrollController();
  static const _headers = [
    'Reference',
    'Staff member',
    'Leave type',
    'Start date',
    'End date',
    'Days',
    'Status',
    'Requested',
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _status(LeaveJson row) {
    final status = row['changeStatus'] == 'PENDING_APPROVAL'
        ? 'CHANGE_PENDING_APPROVAL'
        : row['status'];
    final color = switch (status) {
      'APPROVED' => AppColors.green,
      'REJECTED' => AppColors.red,
      'PENDING_APPROVAL' => const Color(0xFF9A6700),
      'CHANGE_PENDING_APPROVAL' => const Color(0xFF9A6700),
      'NEEDS_REVISION' => const Color(0xFF6554C0),
      _ => AppColors.muted,
    };
    return Tooltip(
      message: row['canReview'] == true
          ? 'Awaiting your review'
          : leaveLabel(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          leaveLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (constraints.maxWidth < 1100) ...[
            const Text(
              'Scroll horizontally to see all columns.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                key: const ValueKey('leave-table-scroll'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    key: const ValueKey('leave-requests-table'),
                    showCheckboxColumn: false,
                    sortColumnIndex: widget.sortColumn,
                    sortAscending: widget.sortAscending,
                    headingRowHeight: 48,
                    dataRowMinHeight: 68,
                    dataRowMaxHeight: 68,
                    horizontalMargin: 16,
                    columnSpacing: 28,
                    headingRowColor: const WidgetStatePropertyAll(
                      Color(0xFFF3F7F6),
                    ),
                    headingTextStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: .4,
                    ),
                    dividerThickness: .6,
                    columns: [
                      for (var i = 0; i < _headers.length; i++)
                        DataColumn(
                          numeric: i == 5,
                          tooltip: 'Sort by ${_headers[i].toLowerCase()}',
                          onSort: widget.onSort,
                          label: Row(
                            key: ValueKey('leave-sort-${_leaveTableFields[i]}'),
                            children: [
                              Text(_headers[i].toUpperCase()),
                              if (widget.sortColumn != i) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.unfold_more,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                    rows: [
                      for (var i = 0; i < widget.rows.length; i++)
                        DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.hovered)
                                ? AppColors.greenSoft
                                : i.isOdd
                                ? const Color(0xFFFAFCFC)
                                : Colors.white,
                          ),
                          onSelectChanged: (_) => widget.onOpen(widget.rows[i]),
                          cells: [
                            DataCell(
                              Text(
                                '#${widget.rows[i]['id']}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 185,
                                child: Text(
                                  '${widget.rows[i]['staffName']}',
                                  key: ValueKey(
                                    'leave-request-${widget.rows[i]['id']}',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text('${widget.rows[i]['typeName']}')),
                            DataCell(
                              Text(
                                formatLeaveDate(widget.rows[i]['startDate']),
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: widget.rows[i]['actualEndDate'] == null
                                    ? 'Approved end date'
                                    : 'Actual end date · originally ${formatLeaveDate(widget.rows[i]['endDate'])}',
                                child: Text(
                                  formatLeaveDate(
                                    widget.rows[i]['actualEndDate'] ??
                                        widget.rows[i]['endDate'],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: 'Inclusive calendar days',
                                child: Text('${widget.rows[i]['days']}'),
                              ),
                            ),
                            DataCell(_status(widget.rows[i])),
                            DataCell(
                              Tooltip(
                                message: formatLeaveDateTime(
                                  widget.rows[i]['createdAt'],
                                ),
                                child: Text(
                                  formatLeaveDate(widget.rows[i]['createdAt']),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _errorPanel(String message, VoidCallback retry) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    children: [
      const Icon(Icons.error_outline, color: AppColors.red),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  ),
);

class _LeaveForm extends StatefulWidget {
  const _LeaveForm({
    required this.api,
    required this.contextData,
    this.request,
    this.staffId,
    this.lockStaff = false,
  });
  final LeaveApiClient api;
  final LeaveJson contextData;
  final LeaveJson? request;
  final int? staffId;
  final bool lockStaff;
  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _notes;
  late int _staff;
  String? _type;
  DateTime? _start, _end;
  LeaveJson? _saved;
  PlatformFile? _file;
  bool _busy = false, _changed = false, _removeAttachment = false;
  late final bool _resubmitting;
  String? _error;
  @override
  void initState() {
    super.initState();
    _saved = widget.request;
    _resubmitting = const {
      'PENDING_APPROVAL',
      'APPROVED',
    }.contains(_saved?['status']);
    _staff =
        (_saved?['staffUserId'] ??
                widget.staffId ??
                widget.contextData['currentUserId'])
            as int;
    _type = _saved?['typeCode'];
    _start = DateTime.tryParse('${_saved?['startDate']}');
    _end = DateTime.tryParse('${_saved?['endDate']}');
    final savedNotes = '${_saved?['notes'] ?? ''}'.trim();
    _notes = TextEditingController(
      text: savedNotes.isNotEmpty ? savedNotes : '${_saved?['reason'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _start ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200, 12, 31),
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          _start = date;
          if (_end != null && _end!.isBefore(date)) _end = date;
        } else {
          _end = date;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.bytes == null || file.size == 0 || file.size > 5 * 1024 * 1024) {
        throw LeaveApiException(
          'Choose a non-empty document or image up to 5 MB.',
        );
      }
      setState(() {
        _file = file;
        _removeAttachment = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save(bool submit) async {
    if (!_key.currentState!.validate()) return;
    if (_start == null ||
        _end == null ||
        _end!.isBefore(_start!) ||
        _end!.difference(_start!).inDays >= 366) {
      setState(
        () => _error = 'Select a valid date range of up to 366 calendar days.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _saved = await widget.api.save({
        'staffUserId': _staff,
        'typeCode': _type,
        'startDate': _date(_start!),
        'endDate': _date(_end!),
        'reason': '',
        'notes': _notes.text,
        'version': _saved?['version'],
      }, id: _saved?['id']);
      _changed = true;
      if (_file != null) {
        _saved = await widget.api.attach(_saved!, _file!.name, _file!.bytes!);
        _file = null;
      } else if (_removeAttachment) {
        _saved = await widget.api.removeAttachment(_saved!);
        _removeAttachment = false;
      }
      if (submit) _saved = await widget.api.action(_saved!, 'SUBMIT', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit
                ? 'Leave request submitted for approval.'
                : 'Leave draft saved.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              '${_saved != null ? 'Your saved draft is retained. ' : ''}$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        _saved == null
            ? 'Request leave'
            : _resubmitting
            ? 'Change leave'
            : 'Edit leave request',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dates count as inclusive calendar days, including weekends. Another authorised leave approver reviews the request.',
                ),
                const SizedBox(height: 18),
                if (widget.lockStaff)
                  TextFormField(
                    key: const ValueKey('leave-request-locked-staff'),
                    initialValue:
                        _maps(widget.contextData['staff'])
                            .where((s) => s['id'] == _staff)
                            .map((s) => '${s['name']}')
                            .firstOrNull ??
                        'Your staff account',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Requesting leave for',
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: _staff,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                    ),
                    items: _maps(widget.contextData['staff'])
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as int,
                            child: Text(s['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: _busy || _saved != null
                        ? null
                        : (v) => setState(() => _staff = v!),
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Leave type'),
                  items: _maps(widget.contextData['types'])
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['code'] as String,
                          child: Text(t['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => _type = v),
                  validator: (v) => v == null ? 'Select a leave type' : null,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _start == null
                            ? 'Start date'
                            : formatLeaveDate(_start!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickDate(false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        _end == null ? 'End date' : formatLeaveDate(_end!),
                      ),
                    ),
                  ],
                ),
                if (_start != null && _end != null && !_end!.isBefore(_start!))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_end!.difference(_start!).inDays + 1} calendar days',
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('leave-notes'),
                  controller: _notes,
                  enabled: !_busy,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Enter notes',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add supporting document'),
                    ),
                    if (_file != null ||
                        (!_removeAttachment &&
                            _saved?['attachmentName'] != null))
                      Text(_file?.name ?? _saved!['attachmentName']),
                    if (_file != null ||
                        (!_removeAttachment &&
                            _saved?['attachmentName'] != null))
                      IconButton(
                        tooltip: 'Remove attachment',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _file = null;
                                _removeAttachment = true;
                              }),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const Text(
                  'Optional · PDF, Word or images · up to 5 MB',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _changed),
          child: const Text('Close'),
        ),
        if (!_resubmitting)
          OutlinedButton(
            onPressed: _busy ? null : () => _save(false),
            child: const Text('Save draft'),
          ),
        FilledButton(
          onPressed: _busy ? null : () => _save(true),
          child: Text(
            _resubmitting ? 'Submit changes for approval' : 'Submit request',
          ),
        ),
      ],
    ),
  );
}

class _LeaveDetail extends StatefulWidget {
  const _LeaveDetail({
    required this.api,
    required this.id,
    this.contextData,
    this.onChanged,
  });
  final LeaveApiClient api;
  final int id;
  final LeaveJson? contextData;
  final VoidCallback? onChanged;
  @override
  State<_LeaveDetail> createState() => _LeaveDetailState();
}

class _LeaveDetailState extends State<_LeaveDetail> {
  LeaveJson? _request;
  LeaveJson? _context;
  String? _error;
  bool _busy = false, _changed = false, _actionsLocked = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.detail(widget.id);
      final ctx = widget.contextData ?? _context ?? await widget.api.context();
      if (mounted) {
        setState(() {
          _request = r;
          _context = ctx;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _request = null;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action, [String comment = '']) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final actingOnChange = _request?['changeStatus'] == 'PENDING_APPROVAL';
      final r = await widget.api.action(_request!, action, comment);
      if (!mounted) return;
      setState(() {
        _request = r;
        _changed = true;
        _actionsLocked = true;
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actingOnChange
                ? 'Leave change: ${leaveLabel(r['changeStatus'])}.'
                : action == 'CANCEL' && r['changeStatus'] == 'PENDING_APPROVAL'
                ? 'Leave cancellation sent for approval.'
                : 'Leave request: ${leaveLabel(r['status'])}.',
          ),
        ),
      );
    } on LeaveApiException catch (e) {
      if (e.statusCode == 409 && mounted) {
        await _load();
        widget.onChanged?.call();
        if (mounted) {
          setState(
            () => _error =
                '${e.message} ${_request == null ? 'Unable to reload the request. Use Refresh to try again.' : 'The latest request has been loaded; review it before continuing.'}',
          );
        }
      } else if (mounted) {
        setState(() {
          _error = e.toString();
          if (e.statusCode == 403 || e.statusCode == 404) _request = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askReasonAndAct({
    required String action,
    required String title,
    required String label,
  }) async {
    var enteredReason = '';
    String? validation;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: TextField(
              key: ValueKey('leave-${action.toLowerCase()}-reason'),
              autofocus: true,
              maxLines: 3,
              maxLength: 2000,
              onChanged: (value) => enteredReason = value,
              decoration: InputDecoration(
                labelText: label,
                errorText: validation,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                final value = enteredReason.trim();
                if (value.isEmpty) {
                  setLocal(() => validation = 'Enter a reason');
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (reason != null && mounted) await _action(action, reason);
  }

  Future<void> _edit() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeaveForm(
        api: widget.api,
        contextData: _context!,
        request: _request,
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _changed = true;
        _actionsLocked = true;
      });
      widget.onChanged?.call();
      _load();
    }
  }

  Future<void> _requestLeaveChange(String type) async {
    final updated = await showDialog<LeaveJson>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _LeaveChangeDialog(api: widget.api, request: _request!, type: type),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _request = updated;
      _changed = true;
      _actionsLocked = true;
    });
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave change sent for approval.')),
    );
  }

  Future<void> _attachment() async {
    setState(() => _busy = true);
    try {
      prepareDocumentWindow();
      await openDocumentUrl(await widget.api.attachmentUrl(widget.id));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    final pending = r?['status'] == 'PENDING_APPROVAL';
    final changePending = r?['changeStatus'] == 'PENDING_APPROVAL';
    final canWithdraw =
        (pending || changePending) &&
        r?['canWithdraw'] == true &&
        (!pending || r?['requesterId'] == _context?['currentUserId']);
    final canRevoke = r?['canRevoke'] == true;
    final storedNotes = '${r?['notes'] ?? ''}'.trim();
    final notesText = storedNotes.isNotEmpty
        ? storedNotes
        : '${r?['reason'] ?? ''}';
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('Leave request #${widget.id}')),
            IconButton(
              tooltip: 'Refresh request',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) _errorPanel(_error!, _load),
                if (r != null) ...[
                  Text(
                    '${r['staffName']} · ${r['typeName']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Chip(label: Text(leaveLabel(r['status']))),
                  const SizedBox(height: 8),
                  Text(
                    '${formatLeaveDateRange(r['startDate'], r['endDate'])} · ${r['requestedDays'] ?? r['days']} calendar days',
                  ),
                  if (r['actualEndDate'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Actual leave: ${formatLeaveDateRange(r['startDate'], r['actualEndDate'])} · ${r['days']} days taken',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Originally approved through ${formatLeaveDate(r['endDate'])}.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  if (changePending) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: .08),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: .35),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leaveLabel(r['changeType'])} pending approval',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (r['proposedActualEndDate'] != null)
                            Text(
                              'Proposed last leave day: ${formatLeaveDate(r['proposedActualEndDate'])}',
                            ),
                          if ('${r['changeReason'] ?? ''}'.isNotEmpty)
                            Text('Reason: ${r['changeReason']}'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(notesText),
                  if (r['attachmentName'] != null)
                    TextButton.icon(
                      onPressed: _busy ? null : _attachment,
                      icon: const Icon(Icons.attach_file),
                      label: Text('View ${r['attachmentName']}'),
                    ),
                  if ('${r['reviewComment'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Reviewer comment: ${r['reviewComment']}'),
                    ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Activity history'),
                    subtitle: const Text(
                      'Who acted, when, and the saved request details',
                    ),
                    children: _maps(r['events'])
                        .map(
                          (e) => ExpansionTile(
                            title: Text(
                              '${leaveLabel(e['action'])} · ${e['actorName']}',
                            ),
                            subtitle: Text(
                              formatLeaveDateTime(e['occurredAt']),
                            ),
                            children: [
                              if ('${e['comment'] ?? ''}'.isNotEmpty)
                                ListTile(title: Text('${e['comment']}')),
                              Builder(
                                builder: (_) {
                                  LeaveJson snapshot = {};
                                  try {
                                    snapshot = Map<String, dynamic>.from(
                                      jsonDecode(e['snapshot'] ?? '{}'),
                                    );
                                  } catch (_) {}
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final item in snapshot.entries)
                                          if (item.value != null &&
                                              '${item.value}'.isNotEmpty)
                                            Text(
                                              '${leaveLabel(item.key)}: ${const {'startDate', 'endDate'}.contains(item.key) ? formatLeaveDate(item.value) : item.value}',
                                            ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, _changed),
            child: const Text('Close'),
          ),
          if (!_actionsLocked && canWithdraw)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _askReasonAndAct(
                      action: 'WITHDRAW',
                      title: changePending
                          ? 'Withdraw leave change?'
                          : 'Withdraw leave request?',
                      label: 'Withdrawal reason',
                    ),
              child: Text(
                changePending ? 'Withdraw leave change' : 'Withdraw request',
              ),
            ),
          if (!_actionsLocked && canRevoke)
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _askReasonAndAct(
                      action: 'REVOKE',
                      title: 'Revoke leave approval?',
                      label: 'Reason for revoking approval',
                    ),
              child: const Text('Revoke approval'),
            ),
          if (!_actionsLocked &&
              r?['canRequestEarlyReturn'] == true &&
              r?['canEdit'] != true)
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _requestLeaveChange('EARLY_RETURN'),
              child: const Text('Request early return'),
            ),
          if (!_actionsLocked && r?['canEdit'] == true)
            FilledButton(
              onPressed: _busy ? null : _edit,
              child: Text(
                const {'PENDING_APPROVAL', 'APPROVED'}.contains(r?['status'])
                    ? 'Change leave'
                    : 'Edit request',
              ),
            ),
          if (!_actionsLocked && r?['canReview'] == true) ...[
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _askReasonAndAct(
                      action: 'REJECT',
                      title: changePending
                          ? 'Reject leave change?'
                          : 'Reject leave request?',
                      label: 'Rejection reason',
                    ),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _action('APPROVE'),
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaveChangeDialog extends StatefulWidget {
  const _LeaveChangeDialog({
    required this.api,
    required this.request,
    required this.type,
  });

  final LeaveApiClient api;
  final LeaveJson request;
  final String type;

  @override
  State<_LeaveChangeDialog> createState() => _LeaveChangeDialogState();
}

class _LeaveChangeDialogState extends State<_LeaveChangeDialog> {
  final _reason = TextEditingController();
  DateTime? _actualEndDate;
  bool _busy = false;
  String? _error;

  DateTime get _start => DateTime.parse('${widget.request['startDate']}');

  DateTime get _latestEnd {
    final approvedEnd = DateTime.parse(
      '${widget.request['actualEndDate'] ?? widget.request['endDate']}',
    ).subtract(const Duration(days: 1));
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    return approvedEnd.isBefore(localToday) ? approvedEnd : localToday;
  }

  @override
  void initState() {
    super.initState();
    _actualEndDate = _latestEnd;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: _start,
      lastDate: _latestEnd,
      initialDate: _actualEndDate ?? _latestEnd,
    );
    if (selected != null) setState(() => _actualEndDate = selected);
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty || _actualEndDate == null) {
      setState(
        () => _error = 'Select the actual last leave day and enter a reason.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.api.requestChange(
        widget.request,
        type: widget.type,
        actualEndDate: _actualEndDate,
        reason: _reason.text,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request early return'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record the employee’s actual last day on leave. Another administrator or head teacher must approve the change.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('leave-actual-end-date'),
            onPressed: _busy ? null : _chooseDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _actualEndDate == null
                  ? 'Select actual last leave day'
                  : 'Actual last day: ${formatLeaveDate(_actualEndDate)}',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('leave-change-reason'),
            controller: _reason,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('submit-leave-change'),
        onPressed: _busy ? null : _submit,
        child: const Text('Send for approval'),
      ),
    ],
  );
}

class _AllowanceDialog extends StatefulWidget {
  const _AllowanceDialog({
    required this.api,
    required this.staffId,
    required this.year,
    required this.types,
  });
  final LeaveApiClient api;
  final int staffId, year;
  final List<LeaveJson> types;
  @override
  State<_AllowanceDialog> createState() => _AllowanceDialogState();
}

class _AllowanceDialogState extends State<_AllowanceDialog> {
  final _days = TextEditingController(), _reason = TextEditingController();
  String? _type, _error;
  bool _busy = false;
  @override
  void dispose() {
    _days.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final days = int.tryParse(_days.text);
    if (_type == null ||
        days == null ||
        days < 0 ||
        days > 366 ||
        _reason.text.trim().isEmpty) {
      setState(() => _error = 'Select a type, enter 0–366 days and a reason.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.setAllowance(widget.staffId, {
        'typeCode': _type,
        'year': widget.year,
        'days': days,
        'reason': _reason.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Set allowance · ${widget.year}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Use the school’s agreed allowance in calendar days. Changes are audited. Approved and pending days cannot be removed.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: widget.types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['code'] as String,
                        child: Text(t['name']),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => _type = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _days,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Annual allowance (calendar days)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Reason for setting this allowance',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save allowance'),
        ),
      ],
    ),
  );
}
