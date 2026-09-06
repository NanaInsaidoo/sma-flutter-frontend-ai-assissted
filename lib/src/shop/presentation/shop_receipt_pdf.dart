import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef ReceiptJson = Map<String, dynamic>;

bool shopReceiptAwaitingCollection(ReceiptJson receipt) =>
    {'PENDING_COLLECTION', 'PENDING_PICKUP'}.contains(receipt['status']);

String shopReceiptStatusLabel(ReceiptJson receipt) =>
    switch (receipt['status']) {
      'PENDING_COLLECTION' || 'PENDING_PICKUP' => 'Paid · Awaiting collection',
      'COLLECTED' => 'Paid · Collected',
      'CANCELLATION_PENDING' => 'Cancellation pending',
      'CANCELLED' => 'Cancelled',
      'REFUND_PENDING' => 'Refund pending',
      'REFUNDED' => 'Refunded',
      'PARTIALLY_REFUNDED' => 'Partially refunded',
      _ => 'Paid',
    };

Future<Uint8List> buildShopReceiptPdf({
  required ReceiptJson receipt,
  required String schoolName,
}) async {
  final sale = _map(receipt['sale']);
  final lines = _maps(sale['lines']);
  final reference = '${receipt['reference'] ?? 'SHOP-RECEIPT'}';
  final token = '${receipt['pickupToken'] ?? ''}'.trim();
  final pendingCollection =
      token.isNotEmpty && shopReceiptAwaitingCollection(receipt);
  final document = pw.Document(
    title: reference,
    author: schoolName,
    subject: 'School shop receipt',
  );
  final navy = PdfColor.fromHex('#172131');
  final teal = PdfColor.fromHex('#00796B');
  final muted = PdfColor.fromHex('#6B7789');
  final border = PdfColor.fromHex('#DEE5E3');
  final soft = PdfColor.fromHex('#E8F6F3');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _pdfText(schoolName),
                    style: pw.TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'SCHOOL SHOP RECEIPT',
                    style: pw.TextStyle(
                      color: teal,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: soft,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                _pdfText(shopReceiptStatusLabel(receipt)).toUpperCase(),
                style: pw.TextStyle(
                  color: teal,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Container(height: 1, color: border),
        pw.SizedBox(height: 14),
        _detailRow('Receipt number', reference, navy, muted),
        _detailRow('Date', _dateText(receipt['issuedAt']), navy, muted),
        _detailRow(
          'Buyer',
          '${sale['buyerName'] ?? sale['studentName'] ?? 'Not specified'}',
          navy,
          muted,
        ),
        _detailRow('Payment', _paymentText(sale), navy, muted),
        _detailRow(
          'Received by',
          '${receipt['cashierName'] ?? sale['processedByName'] ?? 'School shop'}',
          navy,
          muted,
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder(
            top: pw.BorderSide(color: border),
            bottom: pw.BorderSide(color: border),
            horizontalInside: pw.BorderSide(color: border),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.7),
            3: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: soft),
              children: [
                _cell('ITEM', bold: true, color: muted),
                _cell('QTY', bold: true, color: muted, right: true),
                _cell('UNIT PRICE', bold: true, color: muted, right: true),
                _cell('TOTAL', bold: true, color: muted, right: true),
              ],
            ),
            for (final line in lines)
              pw.TableRow(
                children: [
                  _cell('${line['itemName'] ?? 'Item'}', color: navy),
                  _cell('${line['quantity'] ?? 0}', color: navy, right: true),
                  _cell(_money(line['unitPrice']), color: navy, right: true),
                  _cell(_money(line['lineTotal']), color: navy, right: true),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'TOTAL PAID',
              style: pw.TextStyle(color: muted, fontSize: 9),
            ),
            pw.SizedBox(width: 16),
            pw.Text(
              _money(sale['totalAmount']),
              style: pw.TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        if (pendingCollection) ...[
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: soft,
              border: pw.Border.all(color: teal, width: .7),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'COLLECTION TOKEN',
                  style: pw.TextStyle(
                    color: teal,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  token,
                  style: pw.TextStyle(
                    color: navy,
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  _pdfText(
                    'Present this receipt and token to ${receipt['custodianName'] ?? 'the store'} to collect the items.',
                  ),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 22),
        pw.Text(
          'Thank you. Keep this receipt for collection, returns, and enquiries.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: muted, fontSize: 9),
        ),
      ],
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(reference, style: pw.TextStyle(color: muted, fontSize: 8)),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: muted, fontSize: 8),
            ),
          ],
        ),
      ),
    ),
  );
  return document.save();
}

pw.Widget _detailRow(
  String label,
  String value,
  PdfColor valueColor,
  PdfColor labelColor,
) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 4),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 95,
        child: pw.Text(
          label,
          style: pw.TextStyle(color: labelColor, fontSize: 9),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          _pdfText(value),
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            color: valueColor,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _cell(
  String value, {
  required PdfColor color,
  bool bold = false,
  bool right = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 8),
  child: pw.Text(
    _pdfText(value),
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      color: color,
      fontSize: 8.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

ReceiptJson _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<ReceiptJson> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];

String _money(dynamic value) {
  final amount = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return 'GHS ${amount.toStringAsFixed(2)}';
}

String _paymentText(ReceiptJson sale) {
  final method = '${sale['paymentMethod'] ?? 'CASH'}'.toUpperCase();
  final reference = '${sale['momoReference'] ?? ''}'.trim();
  if (method == 'MOMO') {
    return reference.isEmpty ? 'Mobile Money' : 'Mobile Money - $reference';
  }
  return method == 'CASH' ? 'Cash' : method.replaceAll('_', ' ');
}

String _pdfText(String value) => value
    .replaceAll('·', '-')
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('₵', 'GHS');

String _dateText(dynamic value) {
  DateTime? date;
  if (value is String) date = DateTime.tryParse(value);
  if (value is List && value.length >= 3) {
    date = DateTime(
      (value[0] as num).toInt(),
      (value[1] as num).toInt(),
      (value[2] as num).toInt(),
      value.length > 3 ? (value[3] as num).toInt() : 0,
      value.length > 4 ? (value[4] as num).toInt() : 0,
    );
  }
  date ??= DateTime.now();
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
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}, $hour:$minute $period';
}
