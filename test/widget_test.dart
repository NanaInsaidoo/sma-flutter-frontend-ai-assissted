import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/app.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';

void main() {
  testWidgets('shows the login screen first', (tester) async {
    await tester.pumpWidget(const SchoolManagementApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  test('only super platform roles can manage account managers', () {
    expect(PlatformRole.accountManager.canManageAccountManagers, isFalse);
    expect(PlatformRole.superAccountManager.canManageAccountManagers, isTrue);
    expect(PlatformRole.superAdmin.canManageAccountManagers, isTrue);
  });
}
