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
            'payments': [
              {
                'paymentId': 81,
                'amount': 250,
                'refundedAmount': 250,
                'netAmount': 0,
                'paymentDate': [2026, 7, 11, 10, 30],
                'paymentMethod': 'Cash',
                'referenceNumber': 'RCPT-0081',
                'receivedBy': 'Kofi Nketia',
                'status': 'REVERSED',
                'statusReason': 'Reversed under REV-0081',
              },
            ],
          });
        }
        if (path.endsWith('/api/payments/schools/SCH-001/reversals')) {
          return _json([
            {
              'id': 91,
              'paymentId': 81,
              'paymentReference': 'RCPT-0081',
              'customStudentId': 'STU-001',
              'studentName': 'Kofi Moley',
              'termId': 44,
              'amount': 250,
              'status': 'APPROVED',
              'reason': 'Payment entered for the wrong student',
              'requesterName': 'Kofi Nketia',
              'approverName': 'Efua Nyarko',
              'decidedByName': 'Efua Nyarko',
              'reversalReference': 'REV-0081',
              'createdAt': [2026, 7, 12, 9, 0],
              'decidedAt': [2026, 7, 12, 9, 30],
            },
          ]);
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
      expect(student.payments, hasLength(1));
      expect(student.payments.single.recordedAmount, 250);
      expect(student.payments.single.amount, 0);
      expect(student.payments.single.refundedAmount, 250);
      expect(student.payments.single.isReversed, isTrue);
      expect(student.paymentReversals, hasLength(1));
      expect(student.paymentReversals.single.reversalReference, 'REV-0081');
      expect(
        student.paymentReversals.single.reason,
        'Payment entered for the wrong student',
      );
    },
  );

  test('shows approved class items while they await publication', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/v1/current-term/SCH-001')) {
        return _json({
          'id': 44,
          'academicYear': {'name': '2026-2027'},
          'termType': {'name': 'First Term'},
          'startDate': '2026-08-25',
          'endDate': '2026-12-11',
        });
      }
      if (path.endsWith('/api/students/schools/SCH-001/students/STU-001')) {
        return _json({
          'customStudentId': 'STU-001',
          'firstName': 'Kojo',
          'lastName': 'Boateng',
          'status': 'ACTIVE',
          'gradeLevel': {'id': 7, 'name': 'Creche'},
          'genderName': 'Male',
          'dateOfBirth': '2020-01-02',
        });
      }
      if (path.endsWith('/api/schools/SCH-001/class-requirements')) {
        return _json([
          {
            'requirementId': 90,
            'className': 'Creche',
            'gradeLevelId': 7,
            'status': 'APPROVED',
            'items': [
              {
                'itemId': 901,
                'name': 'Exercise books',
                'category': 'Learning materials',
                'quantity': 10,
                'unit': 'pieces',
                'estimatedUnitPrice': 30,
                'dueDate': '2026-09-10',
              },
            ],
          },
        ]);
      }
      if (path.contains('/attendance/student/')) {
        return _json({'attendanceRate': 0, 'recentAttendanceRecords': []});
      }
      return http.Response('{}', 404);
    });
    final repository = ApiStudentsRepository(
      customSchoolId: 'SCH-001',
      accessToken: 'token',
      client: client,
    );

    final student = await repository.getStudent('STU-001');

    expect(student.requirements, hasLength(1));
    expect(student.requirements.single.name, 'Exercise books');
    expect(
      student.requirements.single.status,
      StudentRequirementStatus.awaitingPublication,
    );
    expect(student.requirementsAwaitingPublication, 1);
    expect(student.requirementsOutstanding, 0);
  });

  test(
    'loads item receipt history and combines selected receipt PDFs',
    () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.endsWith('/requirement-collections')) {
          return _json([
            {
              'receiptId': 12,
              'receiptNumber': 'ITEM-0012',
              'studentId': 'STU-001',
              'studentName': 'Kojo Boateng',
              'className': 'Creche',
              'academicTerm': 'First Term 2026-2027',
              'collectedAt': '2026-08-29T10:30:00',
              'collectedBy': 'Kofi Nketia',
              'items': [
                {
                  'requirementId': 91,
                  'itemName': 'Exercise books',
                  'unit': 'books',
                  'quantityReceived': 2,
                  'totalReceived': 4,
                  'requiredQuantity': 10,
                },
              ],
            },
          ]);
        }
        if (request.url.path.endsWith(
          '/requirement-collections/receipts.pdf',
        )) {
          return http.Response.bytes(const [37, 80, 68, 70], 200);
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final repository = ApiStudentsRepository(
        customSchoolId: 'SCH-001',
        accessToken: 'token',
        client: client,
      );

      final history = await repository.getStudentItemReceipts(
        studentId: 'STU-001',
      );
      final pdf = await repository.downloadStudentItemReceipts(
        studentId: 'STU-001',
        receiptIds: const [12, 9],
      );

      expect(history.single.number, 'ITEM-0012');
      expect(history.single.totalQuantityCollected, 2);
      expect(pdf, const [37, 80, 68, 70]);
      expect(requests.last.queryParameters['receiptIds'], '12,9');
    },
  );
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);
