import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/fees/presentation/fee_adjustments_content.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  Future<void> pumpAdjustments(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: FeeAdjustmentsContent(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the centralized review queue and filters records', (
    tester,
  ) async {
    await pumpAdjustments(tester);

    expect(find.text('Fee Adjustments'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsOneWidget);
    expect(find.text('Abena Asante'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('adjustments-search')),
      'Abena',
    );
    await tester.pump();

    expect(find.text('Abena Asante'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsNothing);
    expect(find.byKey(const Key('clear-adjustment-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-adjustment-filters')));
    await tester.pump();
    expect(find.text('Kwame Yaw Asante'), findsOneWidget);
  });

  testWidgets('approves a pending adjustment from the review drawer', (
    tester,
  ) async {
    await pumpAdjustments(tester);

    await tester.tap(find.text('Kwame Yaw Asante'));
    await tester.pumpAndSettle();
    expect(find.text('Adjustment review'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-adjustment')));
    await tester.pumpAndSettle();

    expect(find.text('Adjustment approved.'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('requires a note before requesting changes', (tester) async {
    await pumpAdjustments(tester);

    await tester.tap(find.text('Kwame Yaw Asante'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adjustment-action-requestChanges')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Request changes'));
    await tester.pump();
    expect(find.text('Enter a reason'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('adjustment-review-note')),
      'Attach the signed approval letter.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Request changes'));
    await tester.pumpAndSettle();

    expect(find.text('Changes requested from the creator.'), findsOneWidget);
    expect(find.text('Changes requested'), findsWidgets);
  });
}
