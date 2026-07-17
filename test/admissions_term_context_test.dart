import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';

void main() {
  test('normalizes backend academic term date arrays for API filtering', () {
    final term = AdmissionTermContext.fromJson({
      'id': 3,
      'academicYear': {'name': '2025-2026'},
      'termType': {'name': 'Second Term'},
      'startDate': [2026, 7, 6],
      'endDate': [2026, 7, 31],
    });

    expect(term.startDate, '2026-07-06');
    expect(term.endDate, '2026-07-31');
  });

  test('maps full student details used by the household dashboard', () {
    final student = AdmissionStudent.fromJson({
      'customStudentId': 'STU-ABC-1234',
      'householdId': 16,
      'firstName': 'Ama',
      'middleName': 'Efua',
      'lastName': 'Mensah',
      'status': 'PENDING_APPROVAL',
      'gender': {'id': 2, 'name': 'Female'},
      'dateOfBirth': [2018, 3, 12],
      'gradeName': 'Basic 2',
    });

    expect(student.displayName, 'Ama Efua Mensah');
    expect(student.gender, 'Female');
    expect(student.dateOfBirth, '2018-03-12');
    expect(student.gradeLevel, 'Basic 2');
  });

  test('maps the compact class field returned by student filters', () {
    final student = AdmissionStudent.fromJson({
      'customStudentId': 'STU-ABC-1234',
      'householdId': 16,
      'firstName': 'Ama',
      'lastName': 'Mensah',
      'status': 'PENDING_APPROVAL',
      'class_': 'Basic 2',
    });

    expect(student.gradeLevel, 'Basic 2');
  });
}
