import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/reports/domain/report_access_policy.dart';

void main() {
  group('ReportAccessPolicy', () {
    test('normalises supported legacy role names', () {
      expect(ReportAccessPolicy.normalizeRole('admin'), 'ADMINISTRATOR');
      expect(
        ReportAccessPolicy.normalizeRole('office-administrator'),
        'ADMINISTRATOR',
      );
      expect(ReportAccessPolicy.normalizeRole('proprietor'), 'OWNER');
      expect(ReportAccessPolicy.normalizeRole('school_owner'), 'OWNER');
    });

    test('recognises every assignable school role', () {
      for (final role in const [
        'OWNER',
        'ADMINISTRATOR',
        'HEADMASTER',
        'HEAD_TEACHER',
        'ASSISTANT_HEAD_TEACHER',
        'CLASS_TEACHER',
        'SUBJECT_TEACHER',
        'BURSAR',
        'SECRETARY',
      ]) {
        expect(
          ReportAccessPolicy.canOpenLibrary(role),
          isTrue,
          reason: '$role should have a role-specific report library',
        );
      }
    });

    test('owner receives every report including unknown future reports', () {
      for (final type in const [
        'OWNER',
        'HEADMASTER',
        'FINANCE',
        'ACADEMIC_PERFORMANCE',
        'CONFIDENTIAL_NEW',
      ]) {
        expect(
          ReportAccessPolicy.canViewReport(
            role: 'OWNER',
            type: type,
            category: 'OPERATIONS',
          ),
          isTrue,
        );
      }
    });

    test('senior leadership receives the full school report', () {
      for (final role in const [
        'HEADMASTER',
        'HEAD_TEACHER',
        'ADMINISTRATOR',
      ]) {
        expect(
          ReportAccessPolicy.canViewReport(
            role: role,
            type: 'OWNER',
            category: 'TERM',
          ),
          isTrue,
          reason: '$role should receive the full school report',
        );
      }
    });

    test('headmaster receives all classified reports', () {
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'HEADMASTER',
          type: 'BOARD_CONFIDENTIAL',
          category: 'TERM',
        ),
        isFalse,
      );
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'HEADMASTER',
          type: 'FINANCE',
          category: 'FINANCE',
        ),
        isTrue,
      );
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'HEADMASTER',
          type: 'CONFIDENTIAL_NEW',
          category: 'OPERATIONS',
        ),
        isTrue,
      );
    });

    test('restricted roles deny unknown report types by default', () {
      for (final role in const [
        'ADMINISTRATOR',
        'HEAD_TEACHER',
        'ASSISTANT_HEAD_TEACHER',
        'BURSAR',
        'SECRETARY',
        'CLASS_TEACHER',
      ]) {
        expect(
          ReportAccessPolicy.canViewReport(
            role: role,
            type: 'CONFIDENTIAL_NEW',
            category: 'OPERATIONS',
          ),
          isFalse,
          reason: '$role must not inherit a new report automatically',
        );
      }
    });

    test('bursar is limited to term and finance reports', () {
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'BURSAR',
          type: 'PETTY_CASH_ANALYSIS',
          category: 'FINANCE',
        ),
        isTrue,
      );
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'BURSAR',
          type: 'READINESS',
          category: 'TERM',
        ),
        isTrue,
      );
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'BURSAR',
          type: 'STUDENT_ATTENDANCE',
          category: 'OPERATIONS',
        ),
        isFalse,
      );
    });

    test('secretary is limited to administrative operational reports', () {
      for (final type in const [
        'ADMISSIONS',
        'STUDENT_ATTENDANCE',
        'FACILITY_INSPECTION',
        'READINESS',
      ]) {
        expect(
          ReportAccessPolicy.canViewReport(
            role: 'SECRETARY',
            type: type,
            category: 'OPERATIONS',
          ),
          isTrue,
          reason: '$type should be available to the secretary',
        );
      }
      expect(
        ReportAccessPolicy.canViewReport(
          role: 'SECRETARY',
          type: 'FINANCE',
          category: 'FINANCE',
        ),
        isFalse,
      );
    });

    test('teacher receives only assignment-oriented report types', () {
      for (final role in const [
        'TEACHER',
        'CLASS_TEACHER',
        'SUBJECT_TEACHER',
      ]) {
        expect(
          ReportAccessPolicy.canViewReport(
            role: role,
            type: 'STUDENT_REPORTS',
            category: 'ACADEMIC',
          ),
          isTrue,
        );
        expect(
          ReportAccessPolicy.canViewReport(
            role: role,
            type: 'STUDENT_ATTENDANCE',
            category: 'OPERATIONS',
          ),
          isTrue,
        );
        expect(
          ReportAccessPolicy.canViewReport(
            role: role,
            type: 'ACADEMIC_PERFORMANCE',
            category: 'ACADEMIC',
          ),
          isFalse,
        );
      }
    });
  });
}
