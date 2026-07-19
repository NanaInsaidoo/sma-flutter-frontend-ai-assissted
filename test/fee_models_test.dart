import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

void main() {
  test('school grade keeps separate setup and curriculum identifiers', () {
    final grade = FeeGradeLevel.fromJson({
      'id': 26,
      'gradeLevelId': 4,
      'gradeName': 'Basic 2',
    });

    expect(grade.id, 26);
    expect(grade.curriculumGradeLevelId, 4);
    expect(grade.name, 'Basic 2');
  });

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

  test('fee structure parses the versioned backend contract', () {
    final structure = FeeClassStructure.fromJson({
      'structureId': 91,
      'gradeLevelId': 12,
      'levelCode': 'B6',
      'fullName': 'Basic 6',
      'studentCount': 42,
      'version': 3,
      'status': 'DRAFT',
      'totalPerTerm': 450,
      'publishedAt': null,
      'feeItems': [
        {
          'itemId': 501,
          'feeName': 'Tuition fee',
          'category': 'TUITION',
          'amount': 450,
          'active': true,
        },
        {
          'itemId': 502,
          'feeName': 'ICT levy',
          'category': 'LEVY',
          'amount': 50,
          'active': false,
        },
      ],
    });

    expect(structure.structureId, 91);
    expect(structure.version, 3);
    expect(structure.status, 'DRAFT');
    expect(structure.feeItems.first.feeId, 501);
    expect(structure.feeItems.first.status, 'ACTIVE');
    expect(structure.feeItems.last.feeId, 502);
    expect(structure.feeItems.last.status, 'INACTIVE');
  });

  test('student waiver parses its term, scope, and selected fee items', () {
    final waiver = FeeWaiverAssignment.fromJson({
      'id': 71,
      'academicTermId': 44,
      'customStudentId': 'STU-044',
      'studentName': 'Ama Mensah',
      'className': 'Basic 6',
      'waiverTypeId': 9,
      'waiverType': 'Partial bursary',
      'valueType': 'percentage',
      'value': 50,
      'scope': 'selected_fee_items',
      'eligibleAmount': 500,
      'waivedAmount': 250,
      'reason': 'Approved bursary',
      'status': 'active',
      'assessments': [
        {'assessmentId': 90, 'feeName': 'Tuition Fee', 'amount': 500},
      ],
      'createdAt': '2026-07-18T10:15:00',
    });

    expect(waiver.academicTermId, 44);
    expect(waiver.customStudentId, 'STU-044');
    expect(waiver.scope, 'SELECTED_FEE_ITEMS');
    expect(waiver.valueType, 'PERCENTAGE');
    expect(waiver.waivedAmount, 250);
    expect(waiver.assessments.single.assessmentId, 90);
  });
}
