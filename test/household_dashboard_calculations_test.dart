import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/admissions/domain/household_dashboard_calculations.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

void main() {
  test('empty zero-balance account is not assessed, never settled', () {
    final account = _account(balance: 0);
    expect(householdHasAssessedFees(account), isFalse);
    expect(householdFeeState(account), HouseholdFeeState.notAssessed);
  });

  test('missing account remains unavailable rather than zero', () {
    expect(householdFeeState(null), HouseholdFeeState.unavailable);
  });

  test('assessed zero balance is settled, including a waived fee', () {
    final account = _account(
      balance: 0,
      assessments: [_assessment('WAIVED', DateTime(2026, 9, 1))],
    );
    expect(householdHasAssessedFees(account), isTrue);
    expect(householdFeeState(account), HouseholdFeeState.settled);
  });

  test('charges can be present even without assessment details', () {
    final account = _account(balance: 0, totalFees: 100, totalExpected: 100);
    expect(householdHasAssessedFees(account), isTrue);
    expect(householdFeeState(account), HouseholdFeeState.settled);
  });

  test('debit and credit balances are distinguished', () {
    expect(householdFeeState(_account(balance: 100)), HouseholdFeeState.due);
    expect(householdFeeState(_account(balance: -40)), HouseholdFeeState.credit);
  });

  test('a mixed household retains its unassessed child and actual debt', () {
    final accounts = [
      _account(balance: 735, totalFees: 785, totalExpected: 785),
      _account(balance: 0),
    ];
    expect(
      accounts.where((account) => !householdHasAssessedFees(account)).length,
      1,
    );
    expect(householdOutstandingTotal(accounts), 735);
  });

  test('household total ignores student credit balances', () {
    final accounts = [
      _account(balance: 285),
      _account(balance: -40),
      _account(balance: 15),
    ];

    expect(householdOutstandingTotal(accounts), 300);
  });

  test('next due date excludes settled assessment states', () {
    final accounts = [
      _account(
        balance: 285,
        assessments: [
          _assessment('PAID', DateTime(2026, 9, 1)),
          _assessment('WAIVED', DateTime(2026, 9, 2)),
          _assessment('OUTSTANDING', DateTime(2026, 9, 15)),
          _assessment('OUTSTANDING', DateTime(2026, 10, 1)),
        ],
      ),
    ];

    expect(householdNextDueDate(accounts), DateTime(2026, 9, 15));
  });

  test('received payments exclude pending and reversed money', () {
    expect(
      householdPaymentCountsAsReceived(_payment('COMPLETED', 120)),
      isTrue,
    );
    expect(householdPaymentCountsAsReceived(_payment('PENDING', 120)), isFalse);
    expect(
      householdPaymentCountsAsReceived(_payment('REVERSED', 120)),
      isFalse,
    );
    expect(householdPaymentCountsAsReceived(_payment('COMPLETED', 0)), isFalse);
  });
}

FeeStudentAccount _account({
  required double balance,
  double totalFees = 0,
  double totalExpected = 0,
  List<FeeAssessmentLine> assessments = const [],
}) {
  return FeeStudentAccount(
    termId: 1,
    termName: 'First Term',
    academicYear: '2026-2027',
    customStudentId: 'STU-1',
    studentName: 'Student One',
    className: 'Basic 1',
    totalFees: totalFees,
    totalAdjustments: 0,
    totalExpected: totalExpected,
    totalPaid: 0,
    balance: balance,
    paymentStatus: '',
    assessments: assessments,
    adjustments: const [],
    payments: const [],
  );
}

FeeAssessmentLine _assessment(String status, DateTime dueDate) {
  return FeeAssessmentLine(
    assessmentId: 1,
    itemKey: 'ITEM',
    feeName: 'Tuition',
    categoryName: 'Tuition',
    description: '',
    amount: 100,
    dueDate: dueDate,
    status: status,
  );
}

FeeStudentPayment _payment(String status, double netAmount) {
  return FeeStudentPayment(
    id: 1,
    amount: netAmount,
    refundedAmount: 0,
    netAmount: netAmount,
    paymentDate: DateTime(2026, 8, 30),
    paymentMethod: 'Cash',
    referenceNumber: 'RCPT-1',
    receivedBy: 'Administrator',
    termId: 1,
    status: status,
    statusReason: '',
    chequeNumber: '',
    chequeBank: '',
    chequeDate: null,
    overpaymentAmount: 0,
    overpaymentReason: '',
  );
}
