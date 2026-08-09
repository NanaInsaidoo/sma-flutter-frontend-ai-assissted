import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/assessments/presentation/report_dashboard_rules.dart';

void main() {
  group('report dashboard status', () {
    test('uses only the three official lifecycle statuses', () {
      expect(normalizeReportStatus('GENERATED'), 'Generated');
      expect(normalizeReportStatus('published'), 'Published');
      expect(normalizeReportStatus('NOT_GENERATED'), 'Not Generated');
      expect(normalizeReportStatus('UPDATE_REQUIRED'), 'Update required');
      expect(
        normalizeReportStatus('PUBLISHED_UPDATE_REQUIRED'),
        'Published · update required',
      );
      expect(
        normalizeReportStatus('Published · update required'),
        'Published · update required',
      );
      expect(normalizeReportStatus('DRAFT'), 'Not Generated');
      expect(normalizeReportStatus(null), 'Not Generated');
    });

    test('allows distribution only after publication', () {
      expect(canDistributeReport('PUBLISHED'), isTrue);
      expect(canDistributeReport('Published'), isTrue);
      expect(canDistributeReport('GENERATED'), isFalse);
      expect(canDistributeReport('NOT_GENERATED'), isFalse);
      expect(canDistributeReport(null), isFalse);
      expect(canDistributeReport('PUBLISHED_UPDATE_REQUIRED'), isFalse);
    });

    test('stale published reports retain their published history', () {
      expect(reportHasPublishedVersion('PUBLISHED'), isTrue);
      expect(reportHasPublishedVersion('PUBLISHED_UPDATE_REQUIRED'), isTrue);
      expect(reportHasPublishedVersion('Published · update required'), isTrue);
      expect(reportHasPublishedVersion('GENERATED'), isFalse);
      expect(reportHasPublishedVersion('UPDATE_REQUIRED'), isFalse);
    });

    test('recognizes generated and stale report versions', () {
      expect(reportHasGeneratedVersion('GENERATED'), isTrue);
      expect(reportHasGeneratedVersion('UPDATE_REQUIRED'), isTrue);
      expect(reportHasGeneratedVersion('PUBLISHED_UPDATE_REQUIRED'), isTrue);
      expect(reportHasGeneratedVersion('NOT_GENERATED'), isFalse);
      expect(reportNeedsUpdate('UPDATE_REQUIRED'), isTrue);
      expect(reportNeedsUpdate('PUBLISHED_UPDATE_REQUIRED'), isTrue);
      expect(reportNeedsUpdate('PUBLISHED'), isFalse);
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
