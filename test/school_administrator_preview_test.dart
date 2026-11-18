import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';
import 'package:school_management_app/src/platform/presentation/school_administrator_preview_screen.dart';

import 'support/fake_platform_repository.dart';

void main() {
  testWidgets('preview waits for a real school and can change or exit it', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    final openedSchools = <String>[];
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolAdministratorPreviewScreen(
          repository: repository,
          onExit: () => exits++,
          schoolBuilder: (school) {
            openedSchools.add(school.code);
            return Text('Workspace for ${school.code}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(openedSchools, isEmpty);
    expect(repository.status, 'APPROVED');

    await tester.tap(find.text('Demo School'));
    await tester.pumpAndSettle();
    expect(find.text('Workspace for SCH-DEMO'), findsOneWidget);
    expect(openedSchools, ['SCH-DEMO']);

    await tester.tap(find.text('Change school'));
    await tester.pumpAndSettle();
    expect(find.text('Select a school'), findsOneWidget);
    expect(find.text('Workspace for SCH-DEMO'), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repository.searchTerm, 'missing');
    expect(find.text('No approved schools found.'), findsOneWidget);

    await tester.tap(find.text('Back to platform'));
    expect(exits, 1);
  });
}

class _PreviewRepository extends FakePlatformRepository {
  String? status;
  String? searchTerm;

  @override
  Future<ManagedSchoolPage> getSchools({
    String? searchTerm,
    String? region,
    String? district,
    String? status,
    String? accountManagerId,
    int page = 0,
    int size = 10,
  }) async {
    this.status = status;
    this.searchTerm = searchTerm;
    final schools = searchTerm == 'missing' ? <ManagedSchool>[] : [_school];
    return ManagedSchoolPage(
      schools: schools,
      totalElements: schools.length,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
    );
  }
}

const _school = ManagedSchool(
  name: 'Demo School',
  code: 'SCH-DEMO',
  region: '',
  town: '',
  students: 0,
  staff: 0,
  status: SchoolStatus.approved,
  progress: 1,
  accountManager: '',
  subscriptionPlan: '',
  subscriptionStatus: '',
  renewalDate: '',
  lastActive: '',
  approvedDate: '',
  administratorName: '',
  administratorPhone: '',
  administratorEmail: '',
);
