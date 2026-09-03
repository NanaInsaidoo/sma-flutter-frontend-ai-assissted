import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';
import 'package:school_management_app/src/admissions/domain/admission_medical_vitals.dart';

void main() {
  test('new admission does not assume a blood group', () {
    final vitals = AdmissionMedicalVitals.fromJson(null);
    expect(vitals.bloodGroupId, isNull);
    expect(vitals.bloodGroupName, isEmpty);
    expect(vitals.toUpdateJson().containsKey('bloodGroupId'), isFalse);
  });

  test('reopening a medical record retains its group and measurements', () {
    final vitals = AdmissionMedicalVitals.fromJson({
      'bloodGroupId': 7,
      'bloodGroup': {'id': 7, 'name': 'O+'},
      'heightCm': 120.5,
      'weightKg': 23,
    });
    expect(vitals.bloodGroupId, 7);
    expect(vitals.bloodGroupName, 'O+');
    expect(vitals.toUpdateJson(), {
      'bloodGroupId': 7,
      'heightCm': 120.5,
      'weightKg': 23,
    });
  });

  test('supports blood group ID nested inside the saved lookup', () {
    final vitals = AdmissionMedicalVitals.fromJson({
      'bloodGroup': {'id': 5, 'name': 'AB+'},
    });
    expect(vitals.bloodGroupId, 5);
    expect(vitals.bloodGroupName, 'AB+');
  });

  test('uses the backend blood group options, including Unknown', () async {
    var requests = 0;
    final api = AdmissionsApiClient(
      accessToken: 'test-token',
      client: MockClient((request) async {
        requests++;
        expect(request.url.path, endsWith('/api/lookup/blood-groups'));
        return http.Response(
          jsonEncode([
            {'id': 17, 'name': 'O+'},
            {'id': 19, 'name': 'Unknown'},
          ]),
          200,
        );
      }),
    );
    final options = await api.getBloodGroups();
    expect(options.map((option) => option.name), ['O+', 'Unknown']);
    expect(options.map((option) => option.id), [17, 19]);
    expect(identical(await api.getBloodGroups(), options), isTrue);
    expect(requests, 1);
  });

  test('failed blood group lookup can be retried', () async {
    var requests = 0;
    final api = AdmissionsApiClient(
      accessToken: 'test-token',
      client: MockClient((_) async {
        if (++requests == 1) return http.Response('Unavailable', 503);
        return http.Response('[{"id":7,"name":"O+"}]', 200);
      }),
    );
    await expectLater(
      api.getBloodGroups(),
      throwsA(isA<AdmissionsApiException>()),
    );
    expect((await api.getBloodGroups()).single.name, 'O+');
    expect(requests, 2);
  });

  test(
    'selected group survives save and reopen without changing measurements',
    () async {
      final vitals =
          AdmissionMedicalVitals.fromJson({'heightCm': 120.5, 'weightKg': 23})
            ..bloodGroupId = 5
            ..bloodGroupName = 'AB+';
      final api = AdmissionsApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(
            request.url.path,
            endsWith('/students/STU-TEST/medical-condition'),
          );
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['bloodGroupId'], 5);
          expect(payload['heightCm'], 120.5);
          expect(payload['weightKg'], 23);
          final reopened = AdmissionMedicalVitals.fromJson({
            ...payload,
            'bloodGroup': {'id': payload['bloodGroupId'], 'name': 'AB+'},
          });
          expect(reopened.bloodGroupId, 5);
          expect(reopened.bloodGroupName, 'AB+');
          return http.Response('{"customStudentId":"STU-TEST"}', 200);
        }),
      );
      await api.updateStudentMedicalCondition(
        customSchoolId: 'SCH-TEST',
        householdId: 1,
        customStudentId: 'STU-TEST',
        body: {
          ...vitals.toUpdateJson(),
          'medicalConditions': [],
          'medicalAllergies': [],
          'foodAllergies': [],
          'environmentalAllergies': [],
        },
      );
    },
  );

  test('explicit Unknown selection is saved as its real lookup ID', () {
    final vitals = AdmissionMedicalVitals()
      ..bloodGroupId = 9
      ..bloodGroupName = 'Unknown';
    expect(vitals.toUpdateJson()['bloodGroupId'], 9);
  });
}
