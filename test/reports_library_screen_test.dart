import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/reports/domain/management_report_models.dart';
import 'package:school_management_app/src/reports/presentation/reports_library_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

class _FakeReports implements ManagementReportRepository {
  final downloads = <String>[];
  @override
  Future<List<int>> downloadPdf(
    String schoolId,
    int termId,
    String type,
  ) async {
    downloads.add('$schoolId:$termId:$type');
    return [37, 80, 68, 70];
  }

  @override
  Future<List<ManagementReport>> list(String schoolId) async => [
    _report('HEADMASTER', 'Headmaster management report'),
    _report('OWNER', 'Full school term management report'),
    _report(
      'FACILITY',
      'End-of-term facility inspection',
      metrics: const {
        'status': 'Completed',
        'areasRecorded': 53,
        'attentionItems': 3,
      },
    ),
    _report(
      'FINANCE',
      'Comprehensive term financial report',
      category: 'FINANCE',
      metrics: const {
        'billed': 12000.0,
        'collected': 9600.0,
        'collectionRate': '80%',
      },
      sections: const [
        ManagementReportSection(
          title: 'Collection pace',
          headers: ['Period', 'Collected', 'Share of billed', 'Cumulative'],
          rows: [
            ['Days 1–20', 4800.0, '40%', '40%'],
            ['Days 21–40', 2400.0, '20%', '60%'],
          ],
        ),
      ],
    ),
    _report(
      'STUDENT_ATTENDANCE',
      'Student attendance report',
      category: 'OPERATIONS',
    ),
    _report(
      'STUDENT_REPORTS',
      'Student report-card summary',
      category: 'ACADEMIC',
    ),
    _report(
      'ACADEMIC_PERFORMANCE',
      'Academic performance report',
      category: 'ACADEMIC',
    ),
    _report('ADMISSIONS', 'Admissions term report', category: 'OPERATIONS'),
    _report(
      'STAFF_ATTENDANCE',
      'Staff attendance report',
      category: 'OPERATIONS',
    ),
    _report('INCIDENTS', 'Incident report', category: 'OPERATIONS'),
    _report(
      'STAFF_PERFORMANCE',
      'Staff performance review report',
      category: 'OPERATIONS',
    ),
    _report(
      'CONFIDENTIAL_NEW',
      'Unclassified confidential report',
      category: 'OPERATIONS',
    ),
    ManagementReport(
      id: '2:READINESS',
      termId: 2,
      type: 'READINESS',
      title: 'Second Term readiness',
      description: 'Live term dates and readiness.',
      category: 'TERM',
      status: 'LIVE',
      academicYear: '2026-2027',
      term: 'Second Term',
      metrics: const {'operationalStart': '2026-12-12'},
      sections: const [],
      notes: const [],
    ),
  ];
  static ManagementReport _report(
    String type,
    String title, {
    String category = 'TERM',
    Map<String, Object?> metrics = const {'status': 'Complete'},
    List<ManagementReportSection> sections = const [],
  }) => ManagementReport(
    id: '1:$type',
    termId: 1,
    type: type,
    title: title,
    description: 'Concise report from recorded school data.',
    category: category,
    status: 'FINAL_LOCKED',
    academicYear: '2026-2027',
    term: 'First Term',
    closedAt: DateTime(2026, 10, 11),
    metrics: metrics,
    sections: sections,
    notes: const ['No material exception was identified.'],
  );
}

void main() {
  late _FakeReports reports;
  Widget buildScreen({String role = 'OWNER'}) {
    reports = _FakeReports();
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ReportsLibraryScreen(
          schoolName: 'SMA Demonstration Academy',
          schoolId: 'SMA-001',
          academicYear: '2026-2027',
          currentTerm: 'Second Term',
          viewerRole: role,
          repository: reports,
        ),
      ),
    );
  }

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows live and locked reports loaded from the repository', (
    tester,
  ) async {
    size(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reports-library-screen')),
      findsOneWidget,
    );
    expect(find.text('Headmaster management report'), findsWidgets);
    expect(find.text('Full school term management report'), findsWidgets);
    expect(find.text('End-of-term facility inspection'), findsWidgets);
    expect(find.text('Owner / Proprietor report access'), findsOneWidget);
    expect(find.text('Final · Locked'), findsWidgets);
    expect(find.text('Live'), findsWidgets);
  });

  testWidgets('previews real finance metrics and collection pace', (
    tester,
  ) async {
    size(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final view = find.byKey(const ValueKey('report-view-1-FINANCE'));
    await tester.ensureVisible(view);
    await tester.pumpAndSettle();
    await tester.tap(view);
    await tester.pumpAndSettle();
    expect(find.text('Collection pace'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Days 1–20'), findsOneWidget);
    expect(
      find.text(
        'Final snapshot — these figures were locked when the term closed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('requests the selected backend report PDF', (tester) async {
    size(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('featured-report-download-1-HEADMASTER')),
    );
    await tester.pumpAndSettle();
    expect(reports.downloads, contains('SMA-001:1:HEADMASTER'));
  });

  final roleCases =
      <
        ({String role, String label, List<String> visible, List<String> hidden})
      >[
        (
          role: 'OWNER',
          label: 'Owner / Proprietor',
          visible: [
            'Full school term management report',
            'Headmaster management report',
            'Comprehensive term financial report',
            'Unclassified confidential report',
          ],
          hidden: [],
        ),
        (
          role: 'HEADMASTER',
          label: 'Headmaster',
          visible: [
            'Headmaster management report',
            'Comprehensive term financial report',
            'Incident report',
          ],
          hidden: ['Full school term management report'],
        ),
        (
          role: 'HEAD_TEACHER',
          label: 'Head teacher',
          visible: [
            'Headmaster management report',
            'Comprehensive term financial report',
            'Academic performance report',
          ],
          hidden: [
            'Full school term management report',
            'Unclassified confidential report',
          ],
        ),
        (
          role: 'ASSISTANT_HEAD_TEACHER',
          label: 'Assistant head teacher',
          visible: [
            'Academic performance report',
            'Student attendance report',
            'End-of-term facility inspection',
          ],
          hidden: [
            'Full school term management report',
            'Headmaster management report',
            'Comprehensive term financial report',
          ],
        ),
        (
          role: 'ADMINISTRATOR',
          label: 'Administrator',
          visible: [
            'Comprehensive term financial report',
            'Admissions term report',
            'Staff performance review report',
          ],
          hidden: [
            'Full school term management report',
            'Headmaster management report',
            'Unclassified confidential report',
          ],
        ),
        (
          role: 'BURSAR',
          label: 'Bursar',
          visible: [
            'Comprehensive term financial report',
            'Second Term readiness',
          ],
          hidden: [
            'Full school term management report',
            'Headmaster management report',
            'Academic performance report',
            'End-of-term facility inspection',
          ],
        ),
        (
          role: 'SECRETARY',
          label: 'Secretary',
          visible: [
            'Admissions term report',
            'Student attendance report',
            'End-of-term facility inspection',
          ],
          hidden: [
            'Full school term management report',
            'Comprehensive term financial report',
            'Incident report',
          ],
        ),
        (
          role: 'CLASS_TEACHER',
          label: 'Teacher',
          visible: ['Student attendance report', 'Student report-card summary'],
          hidden: [
            'Full school term management report',
            'Comprehensive term financial report',
            'Academic performance report',
            'Staff attendance report',
          ],
        ),
        (
          role: 'SUBJECT_TEACHER',
          label: 'Teacher',
          visible: ['Student attendance report', 'Student report-card summary'],
          hidden: [
            'Full school term management report',
            'Comprehensive term financial report',
          ],
        ),
      ];

  for (final roleCase in roleCases) {
    testWidgets('${roleCase.role} sees only assigned reports', (tester) async {
      size(tester);
      await tester.pumpWidget(buildScreen(role: roleCase.role));
      await tester.pumpAndSettle();

      expect(find.text('${roleCase.label} report access'), findsOneWidget);
      for (final title in roleCase.visible) {
        expect(
          find.text(title),
          findsWidgets,
          reason: '$title should be visible',
        );
      }
      for (final title in roleCase.hidden) {
        expect(
          find.text(title),
          findsNothing,
          reason: '$title should be hidden',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restricted role downloads only an assigned report', (
    tester,
  ) async {
    size(tester);
    await tester.pumpWidget(buildScreen(role: 'BURSAR'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-download-1-OWNER')), findsNothing);
    final financeDownload = find.byKey(
      const ValueKey('report-download-1-FINANCE'),
    );
    await tester.ensureVisible(financeDownload);
    await tester.tap(financeDownload);
    await tester.pumpAndSettle();
    expect(reports.downloads, ['SMA-001:1:FINANCE']);
  });
}
