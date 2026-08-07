import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/fees/presentation/household_split_payment_screen.dart';

void main() {
  testWidgets('prevents allocating above a child fee-item balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseholdSplitPaymentScreen(
          householdName: 'Ama Household',
          studentNames: ['Adwoa', 'Kofi'],
        ),
      ),
    );

    final tuition = find.byKey(
      const Key('household-allocation-STU-056C1F-4591-101'),
    );
    await tester.enterText(tuition, '901');
    await tester.pump();

    expect(find.text('Maximum 900.00'), findsOneWidget);
    final review = tester.widget<FilledButton>(
      find.byKey(const Key('review-household-transactions')),
    );
    expect(review.onPressed, isNull);
  });

  testWidgets('splits one amount into separate student receipts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseholdSplitPaymentScreen(
          householdName: 'Ama NurseryFlow Household',
          studentNames: ['Adwoa PdfGate', 'Kofi Test NurseryFlow'],
        ),
      ),
    );

    expect(find.text('GH₵ 1000.00'), findsAtLeastNWidgets(2));
    expect(find.text('Review transactions'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('review-household-transactions')),
    );
    await tester.tap(find.byKey(const Key('review-household-transactions')));
    await tester.pumpAndSettle();

    expect(find.text('2 independent payment transactions'), findsOneWidget);
    expect(find.text('Post 2 payments'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('post-household-payments')),
    );
    await tester.tap(find.byKey(const Key('post-household-payments')));
    await tester.pumpAndSettle();

    expect(find.text('2 payments recorded'), findsOneWidget);
    expect(find.textContaining('RCP-2027-'), findsNWidgets(2));
    expect(find.textContaining('TXN-2027-'), findsNWidgets(2));
  });
}
