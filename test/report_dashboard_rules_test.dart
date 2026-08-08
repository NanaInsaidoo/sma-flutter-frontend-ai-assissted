import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/assessments/presentation/report_dashboard_rules.dart';

void main() {
  group('report dashboard status', () {
    test('uses only the three official lifecycle statuses', () {
      expect(normalizeReportStatus('GENERATED'), 'Generated');
      expect(normalizeReportStatus('published'), 'Published');
      expect(normalizeReportStatus('NOT_GENERATED'), 'Not Generated');
      expect(normalizeReportStatus('DRAFT'), 'Not Generated');
      expect(normalizeReportStatus(null), 'Not Generated');
    });
  });

  group('report readiness summary', () {
    test('shows ready when no requirements are pending', () {
      expect(summarizeReportReadiness(const []), 'Ready');
    });

    test('shows the only pending requirement', () {
      expect(
        summarizeReportReadiness(const ['Teacher remark pending']),
        'Teacher remark pending',
      );
    });

    test('shows the first requirement and number of additional blockers', () {
      expect(
        summarizeReportReadiness(const [
          'Grades incomplete',
          'Evaluation pending',
          'Progression decision pending',
        ]),
        'Grades incomplete · +2 more',
      );
    });
  });
}
