import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/auth/data/auth_api_client.dart';

void main() {
  test('auth session retains primary and additional roles', () {
    final session = AuthSession.fromJson({
      'accessToken': '',
      'role': 'SUBJECT_TEACHER',
      'roles': ['SUBJECT_TEACHER', 'BURSAR'],
      'userId': 17,
    });

    expect(session.role, 'SUBJECT_TEACHER');
    expect(session.hasRole('SUBJECT_TEACHER'), isTrue);
    expect(session.hasRole('BURSAR'), isTrue);
    expect(session.effectiveRoles, ['SUBJECT_TEACHER', 'BURSAR']);
  });
}
