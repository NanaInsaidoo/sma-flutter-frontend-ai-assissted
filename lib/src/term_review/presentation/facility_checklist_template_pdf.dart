import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FacilityChecklistTemplateSection {
  const FacilityChecklistTemplateSection({
    required this.name,
    required this.items,
  });

  final String name;
  final List<String> items;
}

Future<Uint8List> buildFacilityChecklistTemplatePdf({
  required String schoolLabel,
  required String termName,
  required List<FacilityChecklistTemplateSection> sections,
}) async {
  final document = pw.Document(
    title: 'End-of-Term Facility Inspection Checklist',
    author: schoolLabel,
  );
  final navy = PdfColor.fromHex('#172131');
  final teal = PdfColor.fromHex('#2F9487');
  final tealSoft = PdfColor.fromHex('#E6F4F1');
  final muted = PdfColor.fromHex('#6B7789');
  final border = PdfColor.fromHex('#D6DFDD');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox.shrink()
          : pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 7),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: border)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FACILITY INSPECTION CHECKLIST',
                    style: pw.TextStyle(
                      color: teal,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _safe(termName),
                    style: pw.TextStyle(color: muted, fontSize: 8),
                  ),
                ],
              ),
            ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Use this paper checklist during the inspection, then enter the final results in SMA.',
            style: pw.TextStyle(color: muted, fontSize: 6.5),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: muted, fontSize: 6.5),
          ),
        ],
      ),
      build: (_) => [
        pw.Row(
          children: [
            pw.Container(
              width: 38,
              height: 38,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: teal,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'SMA',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 11),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'End-of-Term Facility Inspection',
                    style: pw.TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'PRINTABLE CHECKLIST TEMPLATE',
                    style: pw.TextStyle(
                      color: teal,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: tealSoft,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Row(
            children: [
              _field('School', schoolLabel, navy, muted),
              _field('Term', termName, navy, muted),
              _field('Inspection date', '________________', navy, muted),
              _field('Inspector', '________________', navy, muted),
            ],
          ),
        ),
        pw.SizedBox(height: 9),
        pw.Text(
          'Mark one condition for every applicable item. Record a finding, responsible person and due date for every Poor rating. Attach photo evidence in the digital inspection where helpful.',
          style: pw.TextStyle(color: muted, fontSize: 8, lineSpacing: 2),
        ),
        for (final section in sections) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            _safe(section.name),
            style: pw.TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: .5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4.7),
              1: pw.FlexColumnWidth(.65),
              2: pw.FlexColumnWidth(.65),
              3: pw.FlexColumnWidth(.65),
              4: pw.FlexColumnWidth(.65),
              5: pw.FlexColumnWidth(2.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tealSoft),
                children: [
                  _cell('Inspection item', bold: true, color: teal),
                  _cell('Good', bold: true, color: teal, center: true),
                  _cell('Fair', bold: true, color: teal, center: true),
                  _cell('Poor', bold: true, color: teal, center: true),
                  _cell('N/A', bold: true, color: teal, center: true),
                  _cell('Finding / action', bold: true, color: teal),
                ],
              ),
              ...section.items.map(
                (item) => pw.TableRow(
                  children: [
                    _cell(_safe(item)),
                    _cell('[ ]', center: true),
                    _cell('[ ]', center: true),
                    _cell('[ ]', center: true),
                    _cell('[ ]', center: true),
                    _cell(''),
                  ],
                ),
              ),
            ],
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Text(
          'Management follow-up',
          style: pw.TextStyle(
            color: navy,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Finding',
            'Priority',
            'Assigned to',
            'Due date',
            'Completed',
          ],
          data: List.generate(6, (_) => ['', '', '', '', '[ ]']),
          border: pw.TableBorder.all(color: border, width: .5),
          headerDecoration: pw.BoxDecoration(color: tealSoft),
          headerStyle: pw.TextStyle(
            color: teal,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(color: navy, fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(6),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Sign-off',
          style: pw.TextStyle(
            color: navy,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _signature('Headteacher', navy, muted),
            pw.SizedBox(width: 12),
            _signature('Assistant head', navy, muted),
            pw.SizedBox(width: 12),
            _signature('SMC / PTA chair', navy, muted),
          ],
        ),
      ],
    ),
  );

  return document.save();
}

String facilityChecklistTemplateFileName(String termName) {
  final clean = termName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'facility-inspection-checklist-$clean.pdf';
}

pw.Widget _field(String label, String value, PdfColor navy, PdfColor muted) =>
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: muted,
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _safe(value),
            style: pw.TextStyle(
              color: navy,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );

pw.Widget _cell(
  String value, {
  bool bold = false,
  PdfColor? color,
  bool center = false,
}) => pw.Container(
  alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
  child: pw.Text(
    value,
    style: pw.TextStyle(
      color: color ?? PdfColors.grey900,
      fontSize: 6.3,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

pw.Widget _signature(String label, PdfColor navy, PdfColor muted) =>
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 18),
          pw.Container(height: .5, color: navy),
          pw.SizedBox(height: 4),
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 7)),
          pw.Text(
            'Name / signature / date',
            style: pw.TextStyle(color: muted, fontSize: 6),
          ),
        ],
      ),
    );

String _safe(String value) => value
    .replaceAll('\u2019', "'")
    .replaceAll('\u2013', '-')
    .replaceAll('\u2014', '-')
    .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
    .trim();
