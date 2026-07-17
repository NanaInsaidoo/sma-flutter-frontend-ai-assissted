import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class AdmissionsApiClient {
  AdmissionsApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  final Map<String, Future<List<AdmissionLookupOption>>> _lookupFutures = {};
  Future<List<AdmissionMedicalConditionOption>>? _medicalConditionsFuture;
  Future<List<AdmissionVaccinationOption>>? _vaccinationsFuture;

  Future<List<AdmissionListItem>> getAdmissions({
    required String customSchoolId,
    String status = 'DRAFT,PENDING_REVIEW,APPROVED,REJECTED',
    String personType = 'STUDENT',
    String? startDate,
    String? endDate,
    int page = 0,
    int size = 100,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/admissions/school/$customSchoolId', {
        'status': status,
        'personType': personType,
        if (startDate != null) 'startDate': '${startDate}T00:00:00',
        if (endDate != null) 'endDate': '${endDate}T23:59:59',
        'page': '$page',
        'size': '$size',
      }),
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionListItem.fromJson)
        .toList();
  }

  Future<AdmissionTermContext> getCurrentTerm(String customSchoolId) async {
    final response = await _send('GET', '/api/v1/current-term/$customSchoolId');
    return AdmissionTermContext.fromJson(_decodeMap(response));
  }

  Future<List<AdmissionGuardian>> getGuardians({
    required String customSchoolId,
    int? householdId,
    bool? isPrimary,
    int page = 0,
    int size = 200,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/v1/guardians/schools/$customSchoolId/filter', {
        if (householdId != null) 'householdId': '$householdId',
        if (isPrimary != null) 'isPrimary': '$isPrimary',
        'page': '$page',
        'size': '$size',
      }),
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionGuardian.fromJson)
        .where((guardian) => guardian.displayName.trim().isNotEmpty)
        .toList();
  }

  Future<AdmissionGuardian> getGuardianDetails({
    required String customSchoolId,
    required String customGuardianId,
  }) async {
    final response = await _send(
      'GET',
      '/api/v1/guardians/schools/$customSchoolId/guardians/$customGuardianId',
    );
    return AdmissionGuardian.fromJson(_decodeMap(response));
  }

  Future<void> deleteGuardian({
    required String customSchoolId,
    required String customGuardianId,
    required int householdId,
  }) async {
    await _send(
      'DELETE',
      '/api/v1/guardians/schools/$customSchoolId/guardians/$customGuardianId/households/$householdId',
    );
  }

  Future<List<AdmissionStudent>> getStudents({
    required String customSchoolId,
    int? householdId,
    int page = 0,
    int size = 300,
  }) async {
    final response = await _send(
      'POST',
      '/api/students/schools/$customSchoolId/students/filter',
      body: {
        if (householdId != null) 'householdId': householdId,
        'page': page,
        'size': size,
      },
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionStudent.fromJson)
        .where((student) => student.displayName.trim().isNotEmpty)
        .toList();
  }

  Future<AdmissionStudent> getStudentDetails({
    required String customSchoolId,
    required String customStudentId,
  }) async {
    final response = await _send(
      'GET',
      '/api/students/schools/$customSchoolId/students/$customStudentId',
    );
    return AdmissionStudent.fromJson(_decodeMap(response));
  }

  Future<void> updateStudentAdmissionStatus({
    required String customSchoolId,
    required String customStudentId,
    required String status,
  }) async {
    final response = await _send(
      'PUT',
      '/api/students/schools/$customSchoolId/students/status',
      body: {
        'studentIds': [customStudentId],
        'status': status,
      },
    );
    final payload = _decodeMap(response);
    final updated = _intValue(payload['studentsUpdated']);
    if (updated != null && updated < 1) {
      throw const AdmissionsApiException(
        'The application status could not be updated.',
      );
    }
  }

  Future<void> deleteStudent({
    required String customSchoolId,
    required int householdId,
    required String customStudentId,
  }) async {
    await _send(
      'DELETE',
      '/api/students/schools/$customSchoolId/households/$householdId/students/$customStudentId',
    );
  }

  Future<List<AdmissionMedicalConditionOption>> getDefaultMedicalConditions() {
    final existing = _medicalConditionsFuture;
    if (existing != null) return existing;

    late final Future<List<AdmissionMedicalConditionOption>> future;
    future = _loadDefaultMedicalConditions().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (identical(_medicalConditionsFuture, future)) {
        _medicalConditionsFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _medicalConditionsFuture = future;
    return future;
  }

  Future<List<AdmissionMedicalConditionOption>>
  _loadDefaultMedicalConditions() async {
    final response = await _send(
      'GET',
      '/api/students/medical-conditions/default',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionMedicalConditionOption.fromJson)
        .where((condition) => condition.name.trim().isNotEmpty)
        .toList();
  }

  Future<List<AdmissionVaccinationOption>> getDefaultVaccinations() {
    final existing = _vaccinationsFuture;
    if (existing != null) return existing;

    late final Future<List<AdmissionVaccinationOption>> future;
    future = _loadDefaultVaccinations().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (identical(_vaccinationsFuture, future)) {
        _vaccinationsFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _vaccinationsFuture = future;
    return future;
  }

  Future<List<AdmissionVaccinationOption>> _loadDefaultVaccinations() async {
    final response = await _send('GET', '/api/vaccinations/default');
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionVaccinationOption.fromJson)
        .where((vaccination) => vaccination.name.trim().isNotEmpty)
        .toList();
  }

  Future<List<AdmissionLookupOption>> getGenders() =>
      _cachedLookup('genders', () => _loadLookup('/api/v1/guardians/genders'));

  Future<List<AdmissionLookupOption>> getNationalities() => _cachedLookup(
    'nationalities',
    () => _loadLookup('/api/lookup/nationalities'),
  );

  Future<List<AdmissionLookupOption>> getProofOfIdTypes() => _cachedLookup(
    'proof-of-id-types',
    () => _loadLookup('/api/lookup/proof-of-id-types'),
  );

  Future<List<AdmissionLookupOption>> getOccupations() => _cachedLookup(
    'occupations',
    () => _loadLookup('/api/lookup/occupations'),
  );

  Future<List<AdmissionLookupOption>> getReligions() =>
      _cachedLookup('religions', () => _loadLookup('/api/lookup/religions'));

  Future<List<AdmissionLookupOption>> getLanguages() =>
      _cachedLookup('languages', () => _loadLookup('/api/lookup/languages'));

  Future<List<AdmissionLookupOption>> getRegions() =>
      _cachedLookup('regions', () => _loadLookup('/api/lookup/regions'));

  Future<List<AdmissionLookupOption>> getDistricts(int regionId) =>
      _cachedLookup(
        'districts:$regionId',
        () => _loadLookup(
          _withQuery('/api/lookup/districts', {'regionId': '$regionId'}),
        ),
      );

  Future<List<AdmissionLookupOption>> searchCities(String query) async {
    final response = await _send(
      'GET',
      _withQuery('/api/lookup/cities', {'search': query}),
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionLookupOption.fromJson)
        .where((option) => option.id != null && option.name.isNotEmpty)
        .toList();
  }

  Future<List<AdmissionLookupOption>> getSocialMediaPlatforms() =>
      _cachedLookup(
        'social-media-platforms',
        () => _loadLookup('/api/lookup/social-media-platforms'),
      );

  Future<List<AdmissionLookupOption>> getSchoolGradeLevels(
    String customSchoolId,
  ) => _cachedLookup('school-grade-levels:$customSchoolId', () async {
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$customSchoolId',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AdmissionLookupOption(
            id: _intValue(item['gradeLevelId']),
            name: _text(item['gradeName'] ?? item['gradeLevelName']),
            code: _text(item['id']),
          ),
        )
        .where((option) => option.id != null && option.name.isNotEmpty)
        .toList();
  });

  Future<List<AdmissionLookupOption>> getGradeLevelStreams({
    required String customSchoolId,
    required int gradeLevelId,
  }) => _cachedLookup(
    'grade-level-streams:$customSchoolId:$gradeLevelId',
    () async {
      final response = await _send(
        'GET',
        _withQuery('/api/grade-levels/school/$customSchoolId/streams', {
          'gradeLevelId': '$gradeLevelId',
        }),
      );
      return _extractList(_decode(response))
          .whereType<Map<String, dynamic>>()
          .map(AdmissionLookupOption.fromJson)
          .where((option) => option.id != null && option.name.isNotEmpty)
          .toList();
    },
  );

  Future<List<AdmissionLookupOption>> getSkills() =>
      _cachedLookup('skills', () => _loadLookup('/api/v1/skills'));

  Future<List<AdmissionLookupOption>> _cachedLookup(
    String key,
    Future<List<AdmissionLookupOption>> Function() loader,
  ) {
    final existing = _lookupFutures[key];
    if (existing != null) return existing;

    late final Future<List<AdmissionLookupOption>> future;
    future = loader().catchError((Object error, StackTrace stackTrace) {
      if (identical(_lookupFutures[key], future)) {
        _lookupFutures.remove(key);
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _lookupFutures[key] = future;
    return future;
  }

  Future<List<AdmissionLookupOption>> _loadLookup(String path) async {
    final response = await _send('GET', path);
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(AdmissionLookupOption.fromJson)
        .where((option) => option.id != null && option.name.isNotEmpty)
        .toList();
  }

  Future<AdmissionSavedPerson> createGuardian({
    required bool additionalGuardian,
    required String customSchoolId,
    required int? householdId,
    required Map<String, dynamic> body,
  }) async {
    final path = additionalGuardian && householdId != null
        ? '/api/v1/guardians/schools/$customSchoolId/households/$householdId/guardians/init'
        : '/api/v1/guardians';
    final response = await _send('POST', path, body: body);
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateGuardianStep({
    required String customSchoolId,
    required String customGuardianId,
    required String step,
    required Map<String, dynamic> body,
  }) async {
    final endpointStep = switch (step) {
      'basic-info' => 'basic-info',
      'contact-info' => 'contact-info',
      'address' => 'address',
      'proof-of-id' => 'proof-of-id',
      'occupation' => 'occupation',
      'skills' => 'skills',
      _ => step,
    };
    final response = await _send(
      'PUT',
      '/api/v1/guardians/schools/$customSchoolId/guardians/$customGuardianId/$endpointStep',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> completeGuardianReview({
    required String customSchoolId,
    required String customGuardianId,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/guardians/schools/$customSchoolId/guardians/$customGuardianId/review/complete',
      body: {},
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> createStudent({
    required String customSchoolId,
    required int householdId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'POST',
      '/api/students/schools/$customSchoolId/households/$householdId/students',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateStudentBasicInfo({
    required String customSchoolId,
    required int householdId,
    required String customStudentId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'PUT',
      '/api/students/schools/$customSchoolId/households/$householdId/students/$customStudentId/basic-info',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateStudentMedicalCondition({
    required String customSchoolId,
    required int householdId,
    required String customStudentId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'PUT',
      '/api/students/schools/$customSchoolId/households/$householdId/students/$customStudentId/medical-condition',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateStudentAddress({
    required String customSchoolId,
    required int householdId,
    required String customStudentId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'PUT',
      '/api/students/schools/$customSchoolId/households/$householdId/students/$customStudentId/address',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateStudentVaccinations({
    required String customSchoolId,
    required int householdId,
    required String customStudentId,
    required List<Map<String, dynamic>> body,
  }) async {
    final response = await _sendListBody(
      'PUT',
      '/api/students/schools/$customSchoolId/households/$householdId/students/$customStudentId/vaccination',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> updateStudentPreviousSchool({
    required String customSchoolId,
    required String customStudentId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'PUT',
      '/api/students/schools/$customSchoolId/students/$customStudentId/previous-school',
      body: body,
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<AdmissionSavedPerson> completeStudentDocuments({
    required String customSchoolId,
    required String customStudentId,
  }) async {
    final response = await _send(
      'POST',
      '/api/students/schools/$customSchoolId/students/$customStudentId/documents/complete',
      body: {},
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<List<AdmissionStudentDocument>> getStudentDocuments({
    required String customSchoolId,
    required String customStudentId,
  }) async {
    final response = await _send(
      'GET',
      '/api/students/$customSchoolId/students/$customStudentId/documents',
    );
    final student = _decodeMap(response);
    return _extractList(student['documents'])
        .whereType<Map<String, dynamic>>()
        .map(AdmissionStudentDocument.fromJson)
        .where((document) => document.status.toUpperCase() != 'DELETED')
        .toList();
  }

  Future<void> uploadStudentDocument({
    required String customSchoolId,
    required String customStudentId,
    required String documentType,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const AdmissionsApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$baseUrl/api/students/$customSchoolId/students/$customStudentId/documents/$documentType',
        ),
      );
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      return http.Response.fromStream(streamed);
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final nextToken = await onRefreshAccessToken!.call();
        if (nextToken != null && nextToken.isNotEmpty) {
          accessToken = nextToken;
          response = await send();
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AdmissionsApiException(_messageFromResponse(response));
      }
    } on TimeoutException {
      throw const AdmissionsApiException(
        'The document upload took too long. Please try again.',
      );
    } on AdmissionsApiException {
      rethrow;
    } catch (_) {
      throw const AdmissionsApiException(
        'Unable to upload the document right now.',
      );
    }
  }

  Future<void> deleteStudentDocument({
    required String customSchoolId,
    required String customStudentId,
    required String fileUrl,
  }) async {
    await _send(
      'DELETE',
      _withQuery(
        '/api/students/$customSchoolId/students/$customStudentId/documents',
        {'fileUrl': fileUrl},
      ),
    );
  }

  Future<String> getStudentDocumentDownloadUrl({
    required String customSchoolId,
    required String customStudentId,
    required String documentId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery(
        '/api/students/$customSchoolId/students/$customStudentId/documents/$documentId/download-url',
        const {'expirationMinutes': '15'},
      ),
    );
    final payload = _decodeMap(response);
    final downloadUrl = _text(
      payload['downloadUrl'] ?? payload['presignedUrl'] ?? payload['url'],
    );
    if (downloadUrl.isEmpty) {
      throw const AdmissionsApiException(
        'The secure document link could not be created.',
      );
    }
    return downloadUrl;
  }

  Future<AdmissionSavedPerson> completeStudentReview({
    required String customSchoolId,
    required String customStudentId,
  }) async {
    final response = await _send(
      'POST',
      '/api/students/schools/$customSchoolId/students/$customStudentId/review/complete',
      body: {},
    );
    return AdmissionSavedPerson.fromJson(_decodeMap(response));
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const AdmissionsApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final encodedBody = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 15));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final nextToken = await onRefreshAccessToken!.call();
        if (nextToken != null && nextToken.isNotEmpty) {
          accessToken = nextToken;
          response = await send();
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw AdmissionsApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const AdmissionsApiException(
        'The admissions information took too long to load. Please try again.',
      );
    } on AdmissionsApiException {
      rethrow;
    } catch (_) {
      throw const AdmissionsApiException(
        'Unable to reach the admissions service right now.',
      );
    }
  }

  Future<http.Response> _sendListBody(
    String method,
    String path, {
    required List<Map<String, dynamic>> body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const AdmissionsApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final encodedBody = jsonEncode(body);
      return switch (method) {
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        _ => _client.post(uri, headers: headers, body: encodedBody),
      }.timeout(const Duration(seconds: 15));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final nextToken = await onRefreshAccessToken!.call();
        if (nextToken != null && nextToken.isNotEmpty) {
          accessToken = nextToken;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw AdmissionsApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const AdmissionsApiException(
        'The admissions information took too long to load. Please try again.',
      );
    } on AdmissionsApiException {
      rethrow;
    } catch (_) {
      throw const AdmissionsApiException(
        'Unable to reach the admissions service right now.',
      );
    }
  }

  String _withQuery(String path, Map<String, String> query) {
    final clean = query.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    if (clean.isEmpty) return path;
    return '$path?$clean';
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      return decoded;
    }
    return const {};
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['content'],
        decoded['data'],
        decoded['items'],
        decoded['students'],
        decoded['guardians'],
        decoded['results'],
      ];
      for (final candidate in candidates) {
        if (candidate is List) return candidate;
      }
    }
    return const [];
  }

  String _messageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return 'Admissions request failed with status ${response.statusCode}.';
  }
}

class AdmissionsApiException implements Exception {
  const AdmissionsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdmissionListItem {
  const AdmissionListItem({
    required this.id,
    required this.displayName,
    required this.personType,
    required this.householdId,
    required this.admissionId,
    required this.status,
    required this.createdAt,
    required this.gender,
    required this.customStudentId,
    required this.gradeLevelName,
    required this.guardianName,
    required this.guardianPhone,
  });

  factory AdmissionListItem.fromJson(Map<String, dynamic> json) {
    final firstName = _text(json['firstName']);
    final lastName = _text(json['lastName']);
    return AdmissionListItem(
      id: _intValue(json['id']),
      displayName: _joinName(firstName, lastName),
      personType: _text(json['personType']),
      householdId: _intValue(json['householdId']),
      admissionId: _intValue(json['admissionId']),
      status: _text(json['status']),
      createdAt: _text(json['createdAt']),
      gender: _text(json['gender']),
      customStudentId: _text(json['customStudentId']),
      gradeLevelName: _text(json['gradeLevelName']),
      guardianName: _text(json['guardianName']),
      guardianPhone: _text(json['guardianPhone']),
    );
  }

  final int? id;
  final String displayName;
  final String personType;
  final int? householdId;
  final int? admissionId;
  final String status;
  final String createdAt;
  final String gender;
  final String customStudentId;
  final String gradeLevelName;
  final String guardianName;
  final String guardianPhone;
}

class AdmissionTermContext {
  const AdmissionTermContext({
    required this.id,
    required this.academicYear,
    required this.term,
    required this.startDate,
    required this.endDate,
  });

  factory AdmissionTermContext.fromJson(Map<String, dynamic> json) {
    final academicYear = _map(json['academicYear']);
    final termType = _map(json['termType']);
    final result = AdmissionTermContext(
      id: _intValue(json['id']),
      academicYear: _text(academicYear?['name']),
      term: _text(termType?['name']),
      startDate: _dateText(json['startDate']),
      endDate: _dateText(json['endDate']),
    );
    if (result.startDate.isEmpty || result.endDate.isEmpty) {
      throw const AdmissionsApiException(
        'The current academic term has not been configured.',
      );
    }
    return result;
  }

  final int? id;
  final String academicYear;
  final String term;
  final String startDate;
  final String endDate;
}

class AdmissionGuardian {
  const AdmissionGuardian({
    required this.customGuardianId,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.relationship,
    required this.householdId,
    required this.admissionId,
    required this.status,
    required this.isPrimary,
    required this.createdAt,
    required this.rawJson,
  });

  factory AdmissionGuardian.fromJson(Map<String, dynamic> json) {
    final firstName = _text(json['firstName']);
    final lastName = _text(json['lastName']);
    final contact = _map(json['contactInfo']) ?? _map(json['contact']);
    final personalPhones = _list(contact?['personalPhoneNumber']);
    final phone = personalPhones.isNotEmpty
        ? _text(personalPhones.first)
        : _text(json['phoneNumber'] ?? json['phone']);
    return AdmissionGuardian(
      customGuardianId: _text(json['customGuardianId']),
      displayName: _joinName(firstName, lastName),
      phone: phone,
      email: _text(contact?['email'] ?? json['email']),
      relationship: _relationshipText(json),
      householdId: _intValue(json['householdId']),
      admissionId: _intValue(json['admissionId']),
      status: _text(json['status'] ?? json['admissionStatus']),
      isPrimary: json['isPrimary'] == true,
      createdAt: _text(json['createdAt']),
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  final String customGuardianId;
  final String displayName;
  final String phone;
  final String email;
  final String relationship;
  final int? householdId;
  final int? admissionId;
  final String status;
  final bool isPrimary;
  final String createdAt;
  final Map<String, dynamic> rawJson;
}

class AdmissionStudent {
  const AdmissionStudent({
    required this.customStudentId,
    required this.displayName,
    required this.householdId,
    required this.admissionId,
    required this.status,
    required this.gradeLevel,
    required this.gender,
    required this.dateOfBirth,
    required this.rawJson,
  });

  factory AdmissionStudent.fromJson(Map<String, dynamic> json) {
    final firstName = _text(json['firstName']);
    final middleName = _text(json['middleName']);
    final lastName = _text(json['lastName']);
    final grade = _map(json['gradeLevel']);
    final gender = _map(json['gender']);
    return AdmissionStudent(
      customStudentId: _text(json['customStudentId']),
      displayName: [
        firstName,
        middleName,
        lastName,
      ].where((part) => part.trim().isNotEmpty).join(' '),
      householdId: _intValue(json['householdId']),
      admissionId: _intValue(json['admissionId']),
      status: _text(json['status'] ?? json['admissionStatus']),
      gradeLevel: _text(
        grade?['name'] ??
            json['gradeName'] ??
            json['gradeLevelName'] ??
            json['class_'],
      ),
      gender: _text(gender?['name'] ?? json['genderName'] ?? json['gender']),
      dateOfBirth: _dateText(json['dateOfBirth'] ?? json['dob']),
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  final String customStudentId;
  final String displayName;
  final int? householdId;
  final int? admissionId;
  final String status;
  final String gradeLevel;
  final String gender;
  final String dateOfBirth;
  final Map<String, dynamic> rawJson;
}

class AdmissionStudentDocument {
  const AdmissionStudentDocument({
    required this.documentId,
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.fileSize,
    required this.status,
    required this.documentType,
  });

  factory AdmissionStudentDocument.fromJson(Map<String, dynamic> json) {
    return AdmissionStudentDocument(
      documentId: _text(json['documentId'] ?? json['id']),
      fileName: _text(json['fileName']),
      fileType: _text(json['fileType'] ?? json['contentType']),
      fileUrl: _text(json['fileUrl'] ?? json['url']),
      fileSize: _intValue(json['fileSize']) ?? 0,
      status: _text(json['status']),
      documentType: _text(json['documentType']),
    );
  }

  final String documentId;
  final String fileName;
  final String fileType;
  final String fileUrl;
  final int fileSize;
  final String status;
  final String documentType;
}

class AdmissionMedicalConditionOption {
  const AdmissionMedicalConditionOption({
    required this.id,
    required this.name,
    required this.description,
  });

  factory AdmissionMedicalConditionOption.fromJson(Map<String, dynamic> json) {
    return AdmissionMedicalConditionOption(
      id: _intValue(json['id']),
      name: _text(json['name']),
      description: _text(json['description']),
    );
  }

  final int? id;
  final String name;
  final String description;
}

class AdmissionVaccinationOption {
  const AdmissionVaccinationOption({
    required this.id,
    required this.name,
    required this.recommendedAge,
    required this.protectedDisease,
    required this.isRequired,
  });

  factory AdmissionVaccinationOption.fromJson(Map<String, dynamic> json) {
    return AdmissionVaccinationOption(
      id: _intValue(json['id']),
      name: _text(json['name']),
      recommendedAge: _text(json['ageRecommended']),
      protectedDisease: _text(json['diseaseProtected']),
      isRequired: json['required'] == true || json['isRequired'] == true,
    );
  }

  final int? id;
  final String name;
  final String recommendedAge;
  final String protectedDisease;
  final bool isRequired;
}

class AdmissionLookupOption {
  const AdmissionLookupOption({
    required this.id,
    required this.name,
    this.code,
  });

  factory AdmissionLookupOption.fromJson(Map<String, dynamic> json) {
    return AdmissionLookupOption(
      id: _intValue(
        json['id'] ??
            json['countryId'] ??
            json['languageId'] ??
            json['religionId'] ??
            json['skillId'] ??
            json['occupationId'] ??
            json['gradeLevelId'] ??
            json['streamId'],
      ),
      name: _text(
        json['name'] ??
            json['countryName'] ??
            json['languageName'] ??
            json['religionName'] ??
            json['typeName'] ??
            json['proofOfIdTypeName'] ??
            json['occupationName'] ??
            json['gradeName'] ??
            json['gradeLevelName'] ??
            json['streamName'] ??
            json['alias'] ??
            json['description'],
      ),
      code: _text(json['countryId'] ?? json['code']),
    );
  }

  final int? id;
  final String name;
  final String? code;
}

class AdmissionSavedPerson {
  const AdmissionSavedPerson({
    required this.customGuardianId,
    required this.customStudentId,
    required this.householdId,
    required this.admissionId,
  });

  factory AdmissionSavedPerson.fromJson(Map<String, dynamic> json) {
    return AdmissionSavedPerson(
      customGuardianId: _text(json['customGuardianId']),
      customStudentId: _text(json['customStudentId']),
      householdId: _intValue(json['householdId']),
      admissionId: _text(json['admissionId']),
    );
  }

  final String customGuardianId;
  final String customStudentId;
  final int? householdId;
  final String admissionId;
}

String _text(Object? value) {
  if (value == null) return '';
  if (value is List) return value.join('-');
  return value.toString().trim();
}

String _dateText(Object? value) {
  if (value is List && value.length >= 3) {
    final year = _intValue(value[0]);
    final month = _intValue(value[1]);
    final day = _intValue(value[2]);
    if (year != null && month != null && day != null) {
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }
  }
  return _text(value);
}

String _joinName(String firstName, String lastName) {
  final name = [
    firstName,
    lastName,
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  return name;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  return const [];
}

String _relationshipText(Map<String, dynamic> json) {
  final relationship = _map(json['relationship']);
  final relationshipName = _text(
    relationship?['name'] ??
        json['relationshipName'] ??
        json['relationshipType'] ??
        json['guardianRelationship'],
  );
  return relationshipName;
}
