export 'shop_accounting_csv_export_stub.dart'
    if (dart.library.html) 'shop_accounting_csv_export_web.dart';

const _accountingMonths = [
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

/// Converts backend Java date arrays and ISO date strings into a readable
/// spreadsheet value instead of exporting their raw JSON representation.
String formatShopAccountingCsvDate(Object? value) {
  if (value == null) return '';

  DateTime? date;
  var includesTime = false;
  if (value is List && value.length >= 3) {
    int part(int index) => index < value.length && value[index] is num
        ? (value[index] as num).toInt()
        : 0;
    date = DateTime(
      part(0),
      part(1),
      part(2),
      part(3),
      part(4),
      part(5),
      part(6) ~/ 1000000,
    );
    includesTime = value.length > 3;
  } else {
    final raw = value.toString().trim();
    date = DateTime.tryParse(raw);
    includesTime = raw.contains('T') || RegExp(r'\d{2}:\d{2}').hasMatch(raw);
  }
  if (date == null) return value.toString();

  final dateText =
      '${date.day.toString().padLeft(2, '0')} '
      '${_accountingMonths[date.month - 1]} ${date.year}';
  if (!includesTime) return dateText;

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$dateText ${hour.toString()}:${date.minute.toString().padLeft(2, '0')} $period';
}
