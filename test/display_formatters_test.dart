import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/common/display_formatters.dart';

void main() {
  test('role codes are shown as readable names', () {
    expect(displayRoleName('CLASS_TEACHER'), 'Teacher');
    expect(displayRoleName('SUBJECT_TEACHER'), 'Teacher');
    expect(displayRoleName('HEAD_TEACHER'), 'Head teacher');
    expect(displayRoleName('ASSISTANT_HEAD_TEACHER'), 'Assistant head teacher');
    expect(displayRoleName('OFFICE_ADMINISTRATOR'), 'Office administrator');
    expect(displayRoleName(''), 'Staff');
  });
}
