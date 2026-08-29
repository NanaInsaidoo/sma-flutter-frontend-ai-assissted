import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/app.dart';
import 'package:school_management_app/src/auth/data/auth_api_client.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';

void main() {
  testWidgets('shows the login screen first', (tester) async {
    await tester.pumpWidget(const SchoolManagementApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('drag selection recovers after a form field had focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SchoolManagementApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('Built for Ghanaian private schools.'),
        matching: find.byType(RichText),
      ),
    );
    final start = paragraph.localToGlobal(const Offset(4, 4));
    final end = paragraph.localToGlobal(
      Offset(paragraph.size.width - 4, paragraph.size.height - 4),
    );
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(paragraph.selections, isNotEmpty);
    expect(paragraph.selections.single.isCollapsed, isFalse);
  });

  test('only super platform roles can manage account managers', () {
    expect(PlatformRole.accountManager.canManageAccountManagers, isFalse);
    expect(PlatformRole.superAccountManager.canManageAccountManagers, isTrue);
    expect(PlatformRole.superAdmin.canManageAccountManagers, isTrue);
  });

  test(
    'active account manager does not require approval after password change',
    () {
      final active = _accountManagerSession(accountStatus: 'ACTIVE');
      final invited = _accountManagerSession(accountStatus: 'INVITED');

      expect(active.requiresApprovalAfterInitialPasswordChange, isFalse);
      expect(invited.requiresApprovalAfterInitialPasswordChange, isTrue);
    },
  );
}

AuthSession _accountManagerSession({required String accountStatus}) {
  return AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    firstName: 'Thomas',
    lastName: 'Doe',
    userName: 'ACC94205',
    mustChangePassword: true,
    requiresDateOfBirth: false,
    isAccountManager: true,
    role: 'ACCOUNT_MANAGER',
    accountStatus: accountStatus,
    userStatus: 'ACTIVE',
    customSchoolId: '',
    schoolName: '',
    userId: 22,
  );
}
