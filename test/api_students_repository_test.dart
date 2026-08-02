import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/students/data/api_students_repository.dart';
import 'package:school_management_app/src/students/domain/student_models.dart';

void main() {
  test(
    'reloads pending adjustments separately from the balance account',
    () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/v1/current-term/SCH-001')) {
          return _json({
            'id': 44,
            'academicYear': {'name': '2026-2027'},
            'termType': {'name': 'Second Term'},
            'startDate': '2026-07-01',
            'endDate': '2026-07-19',
          });
        }
        if (path.endsWith('/api/students/schools/SCH-001/students/STU-001')) {
          return _json({
            'customStudentId': 'STU-001',
            'firstName': 'Kofi',
            'lastName': 'Moley',
            'status': 'ACTIVE',
            'gradeName': 'KG1',
            'genderName': 'Male',
            'dateOfBirth': '2020-01-02',
          });
        }
        if (path.endsWith('/fee-account')) {
          return _json({
            'termId': 44,
            'customStudentId': 'STU-001',
            'totalFees': 1000,
            'totalAdjustments': 0,
            'totalExpected': 1000,
            'totalPaid': 0,
            'balance': 1000,
            'assessments': [
              {'assessmentId': 501, 'feeName': 'Tuition Fee', 'amount': 1000},
            ],
            'adjustments': [],
            'payments': [],
          });
        }
        if (path.endsWith('/api/schools/SCH-001/fee-adjustments')) {
          return _json([
            {
              'id': 71,
              'customStudentId': 'STU-001',
              'studentName': 'Kofi Moley',
              'studentId': 1,
              'termId': 44,
              'termName': 'Second Term',
              'feeId': 501,
              'feeName': 'Tuition Fee',
              'adjustmentTypeId': 1,
              'adjustmentType': 'Discount',
              'amount': -25,
              'description': 'Pending support',
              'status': 'PENDING_APPROVAL',
              'createdByType': 'ADMINISTRATOR',
              'createdById': 9,
              'createdDate': '2026-07-10T09:00:00',
              'assignedApproverId': 12,
              'assignedApproverName': 'Efua Nyarko',
            },
          ]);
        }
        if (path.contains('/attendance/student/')) {
          return _json({'attendanceRate': 0, 'recentAttendanceRecords': []});
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final repository = ApiStudentsRepository(
        customSchoolId: 'SCH-001',
        accessToken: 'token',
        client: client,
      );

      final student = await repository.getStudent('STU-001');

      expect(student.feeAdjustments, hasLength(1));
      expect(student.feeAdjustments.single.id, '71');
      expect(
        student.feeAdjustments.single.status,
        StudentFeeAdjustmentStatus.pending,
      );
    },
  );
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);
