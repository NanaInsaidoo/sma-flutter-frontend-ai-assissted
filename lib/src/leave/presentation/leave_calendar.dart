import 'package:flutter/material.dart';
import '../data/leave_api_client.dart';
import '../../theme/app_theme.dart';
import 'leave_date_format.dart';

const _monthNames = [
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
String leaveMonthTitle(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';
String _dayKey(DateTime day) => day.toIso8601String().split('T').first;

List<DateTime> leaveCalendarDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final count = DateTime(month.year, month.month + 1, 0).day;
  final leading = first.weekday - 1;
  final cells = ((leading + count) / 7).ceil() * 7;
  return List.generate(
    cells,
    (index) => DateTime(month.year, month.month, index - leading + 1),
  );
}

List<LeaveJson> leavesOnDay(List<LeaveJson> rows, DateTime day) => rows.where((
  row,
) {
  final start = DateTime.tryParse('${row['startDate']}');
  final end = DateTime.tryParse('${row['actualEndDate'] ?? row['endDate']}');
  return start != null &&
      end != null &&
      !day.isBefore(start) &&
      !day.isAfter(end);
}).toList();

Color _statusColor(Object? status) => switch (status) {
  'APPROVED' => AppColors.green,
  'PENDING_APPROVAL' => const Color(0xFF9A6700),
  'REJECTED' => AppColors.red,
  'NEEDS_REVISION' => const Color(0xFF6554C0),
  _ => AppColors.muted,
};

class LeaveCalendar extends StatefulWidget {
  const LeaveCalendar({
    super.key,
    required this.month,
    required this.rows,
    required this.onMonthChanged,
    required this.onOpen,
    required this.statusLabel,
    this.loading = false,
    this.hasError = false,
  });
  final DateTime month;
  final List<LeaveJson> rows;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<LeaveJson> onOpen;
  final String Function(Object?) statusLabel;
  final bool loading, hasError;
  @override
  State<LeaveCalendar> createState() => _LeaveCalendarState();
}

class _LeaveCalendarState extends State<LeaveCalendar> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openDay(DateTime date, List<LeaveJson> rows) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave on ${formatLeaveDate(date)}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  ListTile(
                    key: ValueKey('calendar-day-request-${row['id']}'),
                    title: Text('${row['staffName']} · ${row['typeName']}'),
                    subtitle: Text(
                      '${formatLeaveDateRange(row['startDate'], row['actualEndDate'] ?? row['endDate'])}\n${widget.statusLabel(row['status'])}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      widget.onOpen(row);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _day(DateTime date, double width) {
    final inMonth =
        date.month == widget.month.month && date.year == widget.month.year;
    final rows = inMonth && !widget.loading && !widget.hasError
        ? leavesOnDay(widget.rows, date)
        : <LeaveJson>[];
    final now = DateTime.now();
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return Container(
      key: ValueKey('leave-calendar-day-${_dayKey(date)}'),
      width: width,
      height: 166,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: inMonth ? Colors.white : const Color(0xFFF5F7F7),
        border: Border.all(
          color: today ? AppColors.green : const Color(0xFFE3E9E8),
          width: today ? 1.5 : .5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: today ? AppColors.greenSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: today
                    ? AppColors.green
                    : inMonth
                    ? AppColors.navyDark
                    : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final row in rows.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message:
                    '${row['staffName']} · ${row['typeName']}\n${formatLeaveDateRange(row['startDate'], row['actualEndDate'] ?? row['endDate'])}\n${widget.statusLabel(row['status'])}',
                child: Material(
                  color: _statusColor(row['status']).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    key: ValueKey(
                      'leave-calendar-event-${_dayKey(date)}-${row['id']}',
                    ),
                    borderRadius: BorderRadius.circular(5),
                    onTap: () => widget.onOpen(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            color: _statusColor(row['status']),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${row['staffName']} · ${row['typeName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(row['status']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (rows.length > 3)
            InkWell(
              key: ValueKey('leave-calendar-more-${_dayKey(date)}'),
              onTap: () => _openDay(date, rows),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '+${rows.length - 3} more',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed:
                widget.loading ||
                    widget.month.year <= 2000 && widget.month.month == 1
                ? null
                : () => widget.onMonthChanged(
                    DateTime(widget.month.year, widget.month.month - 1),
                  ),
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            onPressed: widget.loading
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.month,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2200, 12, 31),
                      helpText: 'Choose a date in the month to view',
                    );
                    if (picked != null && mounted) {
                      widget.onMonthChanged(
                        DateTime(picked.year, picked.month),
                      );
                    }
                  },
            child: Text(
              leaveMonthTitle(widget.month),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed:
                widget.loading ||
                    widget.month.year >= 2200 && widget.month.month == 12
                ? null
                : () => widget.onMonthChanged(
                    DateTime(widget.month.year, widget.month.month + 1),
                  ),
            icon: const Icon(Icons.chevron_right),
          ),
          OutlinedButton(
            onPressed: widget.loading
                ? null
                : () {
                    final now = DateTime.now();
                    widget.onMonthChanged(DateTime(now.year, now.month));
                  },
            child: const Text('This month'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final status in [
            'PENDING_APPROVAL',
            'APPROVED',
            'REJECTED',
            'DRAFT',
            'NEEDS_REVISION',
            'CANCELLED',
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: _statusColor(status), size: 8),
                const SizedBox(width: 4),
                Text(
                  widget.statusLabel(status),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Requests appear on every day of their date range. Only approved leave is a confirmed absence.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      if (widget.loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Loading all leave requests for this month…'),
        ),
      if (!widget.loading && !widget.hasError)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            widget.rows.isEmpty
                ? 'No leave requests for this month and these filters.'
                : '${widget.rows.length} leave requests in ${leaveMonthTitle(widget.month)}',
          ),
        ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 980
              ? 980.0
              : constraints.maxWidth;
          final days = leaveCalendarDays(widget.month);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth < 980)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Scroll horizontally to see the full week.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('leave-calendar-scroll'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final label in [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ])
                              Container(
                                width: width / 7,
                                color: const Color(0xFFF3F7F6),
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (var week = 0; week < days.length ~/ 7; week++)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var day = 0; day < 7; day++)
                                _day(days[week * 7 + day], width / 7),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
