import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/presentation/facility_checklist_template_pdf.dart';

void main() {
  test('builds a printable facility checklist template', () async {
    final bytes = await buildFacilityChecklistTemplatePdf(
      schoolLabel: 'SMA-DEMO-001',
      termName: 'First Term',
      sections: const [
        FacilityChecklistTemplateSection(
          name: 'Classrooms',
          items: ['Roof has no leaks', 'Doors and windows work correctly'],
        ),
      ],
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(
      facilityChecklistTemplateFileName('First Term'),
      'facility-inspection-checklist-first-term.pdf',
    );
  });
}
