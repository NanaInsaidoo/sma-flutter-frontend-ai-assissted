import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';

void main() {
  test(
    'student suggestions are filtered and cached separately from the full catalogue',
    () async {
      final audiences = <String?>[];
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          audiences.add(request.url.queryParameters['audience']);
          final name = request.url.queryParameters['audience'] == 'STUDENT'
              ? 'Music'
              : 'Bookkeeping';
          return http.Response(
            jsonEncode([
              {'id': 1001, 'name': name},
            ]),
            200,
          );
        }),
      );
      expect((await api.getSkills(audience: 'STUDENT')).single.name, 'Music');
      expect((await api.getSkills()).single.name, 'Bookkeeping');
      expect((await api.getSkills(audience: 'STUDENT')).single.name, 'Music');
      expect(audiences, ['STUDENT', null]);
    },
  );
}
