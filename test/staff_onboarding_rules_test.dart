import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';

void main() {
  test('employment reference can be omitted', () {
    expect(
      isOptionalStaffReferenceValid(
        name: '',
        jobTitle: '',
        organization: '',
        phone: '',
        email: '',
        relationship: '',
        durationKnown: '',
      ),
      isTrue,
    );
  });

  test('a started employment reference must be completed', () {
    expect(
      isOptionalStaffReferenceValid(
        name: 'Ama Mensah',
        jobTitle: '',
        organization: '',
        phone: '',
        email: '',
        relationship: '',
        durationKnown: '',
      ),
      isFalse,
    );
  });

  test('a complete employment reference is accepted', () {
    expect(
      isOptionalStaffReferenceValid(
        name: 'Ama Mensah',
        jobTitle: 'Head teacher',
        organization: 'Example School',
        phone: '+233241234567',
        email: 'ama@example.com',
        relationship: 'Former supervisor',
        durationKnown: '3 years',
      ),
      isTrue,
    );
  });
}
