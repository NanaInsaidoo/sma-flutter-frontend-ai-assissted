import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

void main() {
  test('current academic term parses the academic context contract', () {
    final term = CurrentAcademicTerm.fromJson({
      'customSchoolId': 'SCH-001',
      'academicYear': {'id': 10, 'name': '2026/2027'},
      'academicTerm': {
        'id': 44,
        'name': 'Second Term',
        'sequence': 2,
        'startDate': '2026-05-04',
        'endDate': '2026-08-07',
        'closed': false,
      },
    });

    expect(term.id, 44);
    expect(term.name, 'Second Term · 2026/2027');
  });
}
