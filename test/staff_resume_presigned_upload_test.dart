import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';

void main() {
  test(
    'staff resume follows request, S3 PUT, confirm, and attach flow',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/documents/upload-requests')) {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'fileName': 'teacher.pdf',
            'contentType': 'application/pdf',
            'fileSize': 4,
            'documentType': 'RESUME',
            'description': 'Staff resume',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'documentId': 'DOC-1',
                'uploadUrl':
                    'https://school-files.s3.amazonaws.com/resume.pdf?X-Amz-Signature=test',
              },
            }),
            200,
          );
        }
        if (request.url.host == 'school-files.s3.amazonaws.com') {
          expect(request.method, 'PUT');
          expect(request.headers['authorization'], isNull);
          expect(request.headers['content-type'], 'application/pdf');
          expect(request.bodyBytes, [1, 2, 3, 4]);
          return http.Response('', 200, headers: {'etag': 'resume-etag'});
        }
        if (request.url.path.endsWith('/documents/DOC-1/confirm')) {
          expect(jsonDecode(request.body), {
            'eTag': 'resume-etag',
            'fileSize': 4,
          });
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (request.url.path.endsWith('/resume/DOC-1/attach')) {
          expect(request.method, 'POST');
          return http.Response('', 204);
        }
        return http.Response('unexpected request', 500);
      });

      final api = StaffApiClient(accessToken: 'token', client: client);
      await api.uploadResume(
        customSchoolId: 'SCH-1',
        staffId: 'STAFF-1',
        bytes: [1, 2, 3, 4],
        fileName: 'teacher.pdf',
      );

      expect(requests.map((request) => request.method), [
        'POST',
        'PUT',
        'POST',
        'POST',
      ]);
    },
  );
}
