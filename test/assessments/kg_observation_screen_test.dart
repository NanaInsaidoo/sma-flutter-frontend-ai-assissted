import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/assessments/data/assessment_api_client.dart';
import 'package:school_management_app/src/assessments/presentation/kg_observation_screen.dart';

class FakeKgApi extends AssessmentApiClient {
  FakeKgApi({
    this.locked = false,
    this.closed = false,
    this.fail = false,
    this.early = false,
  }) : super(accessToken: 'test');
  final bool locked;
  final bool closed;
  final bool fail;
  final bool early;
  String? lastReason;
  List<Map<String, dynamic>> saved = [];
  Map<String, dynamic> row = {
    'studentId': 'STU-1',
    'studentName': 'Ama Test',
    'rating': null,
    'observation': '',
  };
  @override
  Future<AssessmentFormSetup> getFormSetup(String school) async =>
      AssessmentFormSetup(
        streams: const [
          AssessmentStreamOption(
            id: 5,
            gradeLevelId: 1,
            gradeName: 'KG1',
            streamName: 'A',
            studentCount: 1,
          ),
        ],
        gradeLevels: const [
          AssessmentGradeLevelOption(
            id: 1,
            name: 'KG1',
            status: 'ACTIVE',
            displayOrder: 1,
          ),
        ],
        subjects: const [
          AssessmentSubjectOption(
            id: 7,
            gradeLevelId: 1,
            name: 'Mathematics',
            availableStreamIds: {5},
          ),
        ],
        academicYearId: 2,
        academicYearName: '2026-2027',
        termId: 9,
        termName: 'First Term',
        termSequence: 1,
        termClosed: closed,
        teachingStartDate: early ? DateTime(2099, 1, 1) : null,
      );
  @override
  Future<Map<String, dynamic>> getHandbookReference() async => {
    'kgRatings': [
      {
        'code': 'G',
        'label': 'Gold',
        'description': 'Independent and flexible application',
      },
      {
        'code': 'S',
        'label': 'Silver',
        'description': 'Sufficient independent application',
      },
      {
        'code': 'B',
        'label': 'Bronze',
        'description': 'Needs guidance or ongoing help',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> getKgObservations({
    required String schoolId,
    required int streamId,
    required int subjectId,
    required int term,
    required int academicYearId,
  }) async => [
    {...row, 'reportGenerated': locked},
  ];
  @override
  Future<void> saveKgObservations({
    required String schoolId,
    required int streamId,
    required int subjectId,
    required int term,
    required int academicYearId,
    required List<Map<String, dynamic>> entries,
    String? vacationOverrideReason,
  }) async {
    lastReason = vacationOverrideReason;
    expect(schoolId, 'SCH');
    expect(streamId, 5);
    expect(subjectId, 7);
    expect(term, 1);
    expect(academicYearId, 2);
    if (fail) {
      throw const AssessmentApiException(
        'The term was closed while you were editing.',
      );
    }
    saved = entries;
    row = {...row, ...entries.single};
  }
}

void main() {
  Future<void> start(WidgetTester tester, FakeKgApi api) async {
    tester.view.physicalSize = const Size(1100, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: KgObservationScreen(api: api, schoolId: 'SCH'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('kg-rating-STU-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kg-note-STU-1')),
      'Counts objects independently',
    );
    await tester.pump();
  }

  testWidgets('teacher selects a qualitative rating and saves an observation', (
    tester,
  ) async {
    final api = FakeKgApi();
    await start(tester, api);
    await edit(tester);
    await tester.ensureVisible(find.text('Save observations'));
    await tester.tap(find.text('Save observations'));
    await tester.pumpAndSettle();
    expect(api.saved.single, {
      'studentId': 'STU-1',
      'rating': 'G',
      'observation': 'Counts objects independently',
    });
    expect(find.text('KG observations saved.'), findsOneWidget);
    expect(find.text('HP'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('kg-note-STU-1')))
          .controller!
          .text,
      'Counts objects independently',
    );
  });
  testWidgets('generated reports lock ratings and observation text', (
    tester,
  ) async {
    await start(tester, FakeKgApi(locked: true));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('kg-rating-STU-1')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('kg-note-STU-1')))
          .readOnly,
      isTrue,
    );
  });
  testWidgets('closed terms are read only', (tester) async {
    await start(tester, FakeKgApi(closed: true));
    expect(
      find.text('This term is closed. Observations are read only.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('kg-rating-STU-1')),
          )
          .onChanged,
      isNull,
    );
  });
  testWidgets('failed save preserves edits and shows the server explanation', (
    tester,
  ) async {
    await start(tester, FakeKgApi(fail: true));
    await edit(tester);
    await tester.ensureVisible(find.text('Save observations'));
    await tester.tap(find.text('Save observations'));
    await tester.pumpAndSettle();
    expect(
      find.text('The term was closed while you were editing.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('kg-note-STU-1')))
          .controller!
          .text,
      'Counts objects independently',
    );
  });
  testWidgets('early observations require a reason and send it to the server', (
    tester,
  ) async {
    final api = FakeKgApi(early: true);
    await start(tester, api);
    await edit(tester);
    await tester.ensureVisible(find.text('Save observations'));
    await tester.tap(find.text('Save observations'));
    await tester.pumpAndSettle();
    expect(api.saved, isEmpty);
    expect(
      find.text(
        'Enter a reason of at least 5 characters for recording before teaching begins.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for early recording'),
      'A recorded development observation',
    );
    await tester.ensureVisible(find.text('Save observations'));
    await tester.tap(find.text('Save observations'));
    await tester.pumpAndSettle();
    expect(api.lastReason, 'A recorded development observation');
    expect(api.saved, hasLength(1));
  });
}
