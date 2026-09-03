const _months = [
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

DateTime? _parse(Object? value) {
  if (value is DateTime) return value;
  if (value is List && value.length >= 3 && value.every((v) => v is int)) {
    int part(int i) => i < value.length ? value[i] as int : 0;
    return DateTime(part(0), part(1), part(2), part(3), part(4), part(5));
  }
  return DateTime.tryParse(value?.toString() ?? '');
}

/// Calendar leave dates are displayed without applying timezone conversions.
String formatLeaveDate(Object? value) {
  final date = _parse(value);
  if (date == null) return 'Not recorded';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String formatLeaveDateRange(Object? start, Object? end) =>
    '${formatLeaveDate(start)} – ${formatLeaveDate(end)}';

String formatLeaveDateTime(Object? value) {
  final date = _parse(value);
  if (date == null) return 'Not recorded';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatLeaveDate(date)} · $hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// Approval summaries contain an ISO date range alongside the leave type.
String formatLeaveSummaryDates(String text) => text.replaceAllMapped(
  RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),
  (match) => formatLeaveDate(match.group(0)),
);
