import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../assessments/presentation/report_pdf_download.dart';
import 'attendance_report_spreadsheet_download.dart';

Future<bool> exportAttendanceReportPdf({
  required String fileName,
  required String schoolName,
  required String title,
  required String subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  Map<String, String> summary = const {},
}) async {
  final document = pw.Document();
  final generated = DateTime.now();
  final generatedText =
      '${generated.day.toString().padLeft(2, '0')}/${generated.month.toString().padLeft(2, '0')}/${generated.year} '
      '${generated.hour.toString().padLeft(2, '0')}:${generated.minute.toString().padLeft(2, '0')}';
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 30),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.teal700, width: 1.4),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 28,
              height: 28,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Text(
                'S',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(
                schoolName.trim().isEmpty ? 'School attendance' : schoolName,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
            ),
            pw.Text(
              'Generated $generatedText',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        if (summary.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Row(
            children: summary.entries
                .map(
                  (entry) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 8),
                      padding: const pw.EdgeInsets.all(9),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        border: pw.Border.all(color: PdfColors.teal100),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.key.toUpperCase(),
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            entry.value,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 8,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 6,
          ),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
        ),
      ],
    ),
  );
  return downloadReportPdf(fileName, await document.save());
}

Future<bool> exportAttendanceReportSpreadsheet({
  required String fileName,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final lines = <String>[
    headers.map(_csvCell).join(','),
    ...rows.map((row) => row.map(_csvCell).join(',')),
  ];
  return downloadAttendanceSpreadsheet(fileName, lines.join('\r\n'));
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
