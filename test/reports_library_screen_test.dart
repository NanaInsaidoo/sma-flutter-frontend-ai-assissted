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
    _report('OWNER', 'Owner / board summary'),
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
      'Finance closure report',
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
  Widget buildScreen() {
    reports = _FakeReports();
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ReportsLibraryScreen(
          schoolName: 'SMA Demonstration Academy',
          schoolId: 'SMA-001',
          academicYear: '2026-2027',
          currentTerm: 'Second Term',
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
    expect(find.text('Owner / board summary'), findsWidgets);
    expect(find.text('End-of-term facility inspection'), findsWidgets);
    expect(find.text('Final · Locked'), findsWidgets);
    expect(find.text('Live'), findsWidgets);
  });

  testWidgets('previews real finance metrics and collection pace', (
    tester,
  ) async {
    size(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View').at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View').at(3));
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
    await tester.tap(find.text('PDF').first);
    await tester.pumpAndSettle();
    expect(reports.downloads, contains('SMA-001:1:HEADMASTER'));
  });
}
