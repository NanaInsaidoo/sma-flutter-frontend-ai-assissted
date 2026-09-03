import '../../fees/domain/fee_models.dart';

enum HouseholdFeeState { unavailable, notAssessed, due, settled, credit }

bool householdHasAssessedFees(FeeStudentAccount account) {
  return account.assessments.isNotEmpty ||
      account.totalFees != 0 ||
      account.totalExpected > 0;
}

HouseholdFeeState householdFeeState(FeeStudentAccount? account) {
  if (account == null) return HouseholdFeeState.unavailable;
  if (account.balance > 0) return HouseholdFeeState.due;
  if (account.balance < 0) return HouseholdFeeState.credit;
  if (!householdHasAssessedFees(account)) return HouseholdFeeState.notAssessed;
  return HouseholdFeeState.settled;
}

double householdOutstandingTotal(Iterable<FeeStudentAccount> accounts) {
  return accounts.fold<double>(
    0,
    (total, account) => total + (account.balance > 0 ? account.balance : 0),
  );
}

DateTime? householdNextDueDate(Iterable<FeeStudentAccount> accounts) {
  final dates =
      accounts
          .where((account) => account.balance > 0)
          .expand((account) => account.assessments)
          .where((assessment) {
            final status = assessment.status.trim().toUpperCase();
            return assessment.dueDate != null &&
                !status.contains('PAID') &&
                !status.contains('WAIVED') &&
                !status.contains('CANCELLED');
          })
          .map((assessment) => assessment.dueDate!)
          .toList()
        ..sort();
  return dates.isEmpty ? null : dates.first;
}

bool householdPaymentCountsAsReceived(FeeStudentPayment payment) {
  final status = payment.status.trim().toUpperCase();
  return payment.netAmount > 0 &&
      !status.contains('REJECTED') &&
      !status.contains('CANCELLED') &&
      !status.contains('REVERSED') &&
      !status.contains('PENDING');
}
