import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';

void main() {
  test('optional registration details do not create attention reasons', () {
    final school = _school(
      status: SchoolStatus.approved,
      progress: 1,
      subscriptionStatus: 'GES registration missing',
    );

    expect(school.needsAttentionReasons, isEmpty);
  });

  test('incomplete onboarding remains a required attention reason', () {
    final school = _school(status: SchoolStatus.inProgress, progress: .5);

    expect(
      school.needsAttentionReasons,
      contains('School has not moved to the next onboarding step after 5 days'),
    );
  });
}

ManagedSchool _school({
  required SchoolStatus status,
  required double progress,
  String subscriptionStatus = '',
}) {
  return ManagedSchool(
    name: 'SMA Demonstration Academy',
    code: 'SMA-DEMO-001',
    region: 'Greater Accra',
    district: 'Accra Metropolitan',
    town: 'Accra',
    students: 12,
    staff: 7,
    status: status,
    progress: progress,
    accountManager: 'Demo Manager',
    subscriptionPlan: 'UAT',
    subscriptionStatus: subscriptionStatus,
    renewalDate: '',
    lastActive: '',
    approvedDate: '',
    administratorName: 'Demo Administrator',
    administratorPhone: '0200000000',
    administratorEmail: 'admin@example.com',
  );
}
