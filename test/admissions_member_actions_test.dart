import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';

void main() {
  group('household member actions', () {
    test('loads guardian detail for editing', () async {
      late http.Request captured;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'customGuardianId': 'GUA-123',
              'firstName': 'Ama',
              'lastName': 'Mensah',
              'householdId': 18,
              'contactInfo': {
                'personalPhoneNumber': ['0244000000'],
                'email': 'ama@example.com',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final guardian = await api.getGuardianDetails(
        customSchoolId: 'SCH-001',
        customGuardianId: 'GUA-123',
      );

      expect(captured.method, 'GET');
      expect(
        captured.url.path,
        endsWith('/api/v1/guardians/schools/SCH-001/guardians/GUA-123'),
      );
      expect(guardian.displayName, 'Ama Mensah');
      expect(guardian.rawJson['householdId'], 18);
    });

    test('deletes guardian from the selected household', () async {
      late http.Request captured;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await api.deleteGuardian(
        customSchoolId: 'SCH-001',
        customGuardianId: 'GUA-123',
        householdId: 18,
      );

      expect(captured.method, 'DELETE');
      expect(
        captured.url.path,
        endsWith(
          '/api/v1/guardians/schools/SCH-001/guardians/GUA-123/households/18',
        ),
      );
    });

    test('sets a guardian as primary for their household', () async {
      late http.Request captured;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'customGuardianId': 'GUA-123',
              'firstName': 'John',
              'lastName': 'Mensah',
              'isPrimary': true,
              'householdId': 19,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final guardian = await api.setPrimaryGuardian(
        customSchoolId: 'SCH-001',
        customGuardianId: 'GUA-123',
      );

      expect(captured.method, 'PUT');
      expect(
        captured.url.path,
        endsWith(
          '/api/v1/guardians/schools/SCH-001/guardians/GUA-123/set-primary',
        ),
      );
      expect(guardian.displayName, 'John Mensah');
      expect(guardian.isPrimary, isTrue);
      expect(guardian.householdId, 19);
    });

    test('deletes a non-active student admission from its household', () async {
      late http.Request captured;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await api.deleteStudent(
        customSchoolId: 'SCH-001',
        householdId: 18,
        customStudentId: 'STU-123',
      );

      expect(captured.method, 'DELETE');
      expect(
        captured.url.path,
        endsWith(
          '/api/students/schools/SCH-001/households/18/students/STU-123',
        ),
      );
    });

    test(
      'updates one student admission status using the school endpoint',
      () async {
        late http.Request captured;
        final api = AdmissionsApiClient(
          accessToken: 'token',
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'customSchoolId': 'SCH-001',
                'status': 'APPROVED',
                'studentsUpdated': 1,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await api.updateStudentAdmissionStatus(
          customSchoolId: 'SCH-001',
          customStudentId: 'STU-123',
          status: 'APPROVED',
        );

        expect(captured.method, 'PUT');
        expect(
          captured.url.path,
          endsWith('/api/students/schools/SCH-001/students/status'),
        );
        expect(jsonDecode(captured.body), {
          'studentIds': ['STU-123'],
          'status': 'APPROVED',
        });
      },
    );

    test('rejects a successful response that updated no students', () async {
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'studentsUpdated': 0}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      expect(
        () => api.updateStudentAdmissionStatus(
          customSchoolId: 'SCH-001',
          customStudentId: 'STU-404',
          status: 'REJECTED',
        ),
        throwsA(isA<AdmissionsApiException>()),
      );
    });
  });

  group('admission lookups', () {
    test('reuses a loaded lookup instead of requesting it again', () async {
      var requestCount = 0;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          requestCount += 1;
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'English'},
              {'id': 2, 'name': 'Twi'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final first = await api.getLanguages();
      final second = await api.getLanguages();

      expect(requestCount, 1);
      expect(first.map((option) => option.name), ['English', 'Twi']);
      expect(identical(first, second), isTrue);
    });

    test('reuses school grades and streams during form rebuilds', () async {
      var gradeRequests = 0;
      var streamRequests = 0;
      final api = AdmissionsApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/streams')) {
            streamRequests += 1;
            return http.Response(
              jsonEncode([
                {'id': 20, 'name': 'Basic 2A'},
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          gradeRequests += 1;
          return http.Response(
            jsonEncode([
              {'id': 10, 'gradeLevelId': 2, 'gradeName': 'Basic 2'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await api.getSchoolGradeLevels('SCH-001');
      await api.getSchoolGradeLevels('SCH-001');
      await api.getGradeLevelStreams(
        customSchoolId: 'SCH-001',
        gradeLevelId: 10,
      );
      await api.getGradeLevelStreams(
        customSchoolId: 'SCH-001',
        gradeLevelId: 10,
      );

      expect(gradeRequests, 1);
      expect(streamRequests, 1);
    });
  });
}
