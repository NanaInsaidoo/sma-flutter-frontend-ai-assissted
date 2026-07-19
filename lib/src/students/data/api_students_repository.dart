import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../admissions/data/admissions_api_client.dart';
import '../../config/api_config.dart';
import '../../fees/data/fee_api_client.dart';
import '../../fees/domain/class_requirement_models.dart';
import '../../fees/domain/fee_models.dart';
import '../domain/student_models.dart';

class ApiStudentsRepository implements StudentsRepository {
  ApiStudentsRepository({
    required this.customSchoolId,
    required String? accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _accessToken = accessToken,
       _admissions = AdmissionsApiClient(
         accessToken: accessToken,
         onRefreshAccessToken: onRefreshAccessToken,
       ),
       _fees = FeeApiClient(
         accessToken: accessToken,
         onRefreshAccessToken: onRefreshAccessToken,
       );

  final String customSchoolId;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  final AdmissionsApiClient _admissions;
  final FeeApiClient _fees;
  String? _accessToken;

  @override
  Future<List<EnrolledStudent>> getEnrolledStudents() async {
    final term = await _admissions.getCurrentTerm(customSchoolId);
    final students = await _admissions.getStudents(
      customSchoolId: customSchoolId,
    );
    final active = students
        .where((student) => student.status.toUpperCase() == 'ACTIVE')
        .toList(growable: false);
    if (active.isEmpty) return const [];

    FeeStudentFeesPage? feePage;
    try {
      feePage = await _fees.getFeeManagementStudents(
        customSchoolId: customSchoolId,
        termId: term.id,
        size: 500,
      );
    } on FeeApiException {
      // Student registration remains available even before fees are configured.
    }
    final feeRows = {
      for (final row in feePage?.content ?? const <FeeStudentFeeRow>[])
        row.customStudentId: row,
    };
    final guardiansByHousehold = <int, List<AdmissionGuardian>>{};
    for (final householdId
        in active
            .map((student) => student.householdId)
            .whereType<int>()
            .toSet()) {
      guardiansByHousehold[householdId] = await _admissions.getGuardians(
        customSchoolId: customSchoolId,
        householdId: householdId,
      );
    }

    return Future.wait(
      active.map((summary) async {
        final detail = await _admissions.getStudentDetails(
          customSchoolId: customSchoolId,
          customStudentId: summary.customStudentId,
        );
        final attendance = await _getAttendanceSummary(
          summary.customStudentId,
          term.startDate,
          term.endDate,
        );
        return _mapStudent(
          detail: detail,
          guardians: guardiansByHousehold[detail.householdId] ?? const [],
          feeRow: feeRows[detail.customStudentId],
          attendance: attendance,
          term: term,
        );
      }),
    );
  }

  @override
  Future<EnrolledStudent> getStudent(String studentId) async {
    final term = await _admissions.getCurrentTerm(customSchoolId);
    final detail = await _admissions.getStudentDetails(
      customSchoolId: customSchoolId,
      customStudentId: studentId,
    );

    final guardiansFuture = detail.householdId == null
        ? Future.value(const <AdmissionGuardian>[])
        : _admissions.getGuardians(
            customSchoolId: customSchoolId,
            householdId: detail.householdId,
          );
    final householdStudentsFuture = detail.householdId == null
        ? Future.value(const <AdmissionStudent>[])
        : _admissions.getStudents(
            customSchoolId: customSchoolId,
            householdId: detail.householdId,
          );
    final documentsFuture = _admissions.getStudentDocuments(
      customSchoolId: customSchoolId,
      customStudentId: studentId,
    );
    final feeAccountFuture = _fees.getStudentFeeAccount(
      customSchoolId: customSchoolId,
      customStudentId: studentId,
      academicTermId: term.id ?? 0,
    );
    final attendanceFuture = _getAttendanceSummary(
      studentId,
      term.startDate,
      term.endDate,
    );

    final guardians = await guardiansFuture;
    final householdStudents = await householdStudentsFuture;
    final documents = await _optional(
      documentsFuture,
      const <AdmissionStudentDocument>[],
    );
    final feeAccount = await _optional<FeeStudentAccount?>(
      feeAccountFuture,
      null,
    );
    final attendance = await attendanceFuture;
    final requirements = await _loadRequirements(
      studentId: studentId,
      academicTermId: term.id ?? 0,
    );

    return _mapStudent(
      detail: detail,
      guardians: guardians,
      feeAccount: feeAccount,
      attendance: attendance,
      term: term,
      householdStudents: householdStudents,
      documents: documents,
      requirements: requirements,
    );
  }

  Future<List<StudentRequirement>> _loadRequirements({
    required String studentId,
    required int academicTermId,
  }) async {
    if (academicTermId <= 0) return const [];
    final groups = await _optional(
      _fees.getClassRequirements(
        customSchoolId: customSchoolId,
        academicTermId: academicTermId,
      ),
      const <ClassRequirementGroup>[],
    );
    if (groups.isEmpty) return const [];

    final progress = await _optional<StudentRequirementProgress?>(
      _fees.getStudentRequirements(
        customSchoolId: customSchoolId,
        customStudentId: studentId,
        academicTermId: academicTermId,
      ),
      null,
    );
    if (progress == null) return const [];
    final group = groups.where((item) => item.id == progress.classGroupId);
    final classItems = group.isEmpty
        ? const <ClassRequirementItem>[]
        : group.first.items;
    final byId = {for (final item in classItems) item.id: item};

    return [
      ...progress.items.map((item) {
        final definition = byId[item.itemId];
        return StudentRequirement(
          name: definition?.name ?? item.itemKey,
          requiredQuantity: item.requiredQuantity,
          receivedQuantity: item.receivedQuantity,
          unit: definition?.unit ?? '',
          status: _requirementStatus(item.status),
          note: progress.adjustments[item.itemId]?.notes ?? '',
        );
      }),
      ...progress.customRequirements.map(
        (item) => StudentRequirement(
          name: item.name,
          requiredQuantity: item.quantity,
          receivedQuantity: 0,
          unit: item.unit,
          status: StudentRequirementStatus.outstanding,
          note: item.notes,
        ),
      ),
    ];
  }

  EnrolledStudent _mapStudent({
    required AdmissionStudent detail,
    required List<AdmissionGuardian> guardians,
    required _StudentAttendanceSummary attendance,
    required AdmissionTermContext term,
    FeeStudentFeeRow? feeRow,
    FeeStudentAccount? feeAccount,
    List<AdmissionStudent> householdStudents = const [],
    List<AdmissionStudentDocument> documents = const [],
    List<StudentRequirement> requirements = const [],
  }) {
    final json = detail.rawJson;
    final primary = guardians.where((guardian) => guardian.isPrimary);
    final guardian = primary.isNotEmpty
        ? primary.first
        : guardians.isEmpty
        ? null
        : guardians.first;
    final medical = _map(json['medicalCondition']);
    final feeBalance = feeAccount?.balance ?? feeRow?.balance ?? 0;
    final enrolledOn = _date(json['enrolledOn'] ?? json['createdAt']);
    final termStart = _date(term.startDate);

    final householdMembers = <StudentHouseholdMember>[
      ...guardians.map(
        (item) => StudentHouseholdMember(
          id: item.customGuardianId,
          name: item.displayName,
          relationship: item.relationship,
          type: StudentHouseholdMemberType.guardian,
          subtitle: item.phone,
          primary: item.isPrimary,
        ),
      ),
      ...householdStudents
          .where((item) => item.customStudentId != detail.customStudentId)
          .map(
            (item) => StudentHouseholdMember(
              id: item.customStudentId,
              name: item.displayName,
              relationship: 'Student',
              type: StudentHouseholdMemberType.student,
              subtitle: item.gradeLevel,
            ),
          ),
    ];

    return EnrolledStudent(
      id: detail.customStudentId,
      name: detail.displayName,
      className: _className(json, detail.gradeLevel),
      gender: _namedValue(json['gender'], fallback: detail.gender),
      dateOfBirth: _requiredDate(detail.dateOfBirth, 'date of birth'),
      guardianName: guardian?.displayName ?? 'Not provided',
      guardianRelationship: guardian?.relationship ?? '',
      guardianPhone: guardian?.phone ?? '',
      householdId: detail.householdId == null
          ? ''
          : 'Household ${detail.householdId}',
      status: _studentStatus(detail.status),
      enrolledOn: enrolledOn,
      newThisTerm:
          enrolledOn != null &&
          termStart != null &&
          !enrolledOn.isBefore(termStart),
      attendanceRate: attendance.rate,
      feeBalance: feeBalance,
      requirementsCompleted: requirements
          .where((item) => item.status == StudentRequirementStatus.complete)
          .length,
      requirementsTotal: requirements.length,
      countryOfBirth: _namedValue(json['countryOfBirth']),
      cityOfBirth: _namedValue(json['cityOfBirth']),
      religion: _namedValue(json['religion']),
      address: _address(json['address']),
      bloodGroup: '${json['bloodGroup'] ?? ''}',
      medicalAlerts: _medicalAlerts(medical),
      medicalConditions: _medicalConditions(medical),
      allergies: StudentAllergies(
        food: _names(medical?['foodAllergies']),
        medication: _names(medical?['medicalAllergies']),
        environmental: _names(medical?['environmentalAllergies']),
      ),
      vaccinations: _vaccinations(json['vaccinationRecords']),
      householdMembers: householdMembers,
      attendance: attendance.records,
      fees: _feeItems(feeAccount),
      feeAdjustments: _feeAdjustments(feeAccount),
      payments: _payments(feeAccount),
      requirements: requirements,
      documents: documents
          .map(
            (item) => StudentDocument(
              name: item.documentType,
              fileName: item.fileName,
              status: item.status,
              updatedOn: null,
            ),
          )
          .toList(),
      activity: const [],
    );
  }

  Future<_StudentAttendanceSummary> _getAttendanceSummary(
    String studentId,
    String startDate,
    String endDate,
  ) async {
    if (startDate.isEmpty || endDate.isEmpty) {
      return const _StudentAttendanceSummary();
    }
    final response = await _send(
      '/api/schools/$customSchoolId/attendance/student/$studentId/summary'
      '?startDate=$startDate&endDate=$endDate',
    );
    final json = jsonDecode(response.body);
    if (json is! Map) return const _StudentAttendanceSummary();
    final map = Map<String, dynamic>.from(json);
    final records = map['recentAttendanceRecords'] is List
        ? (map['recentAttendanceRecords'] as List).whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return StudentAttendanceEntry(
              date: _requiredDate(item['attendanceDate'], 'attendance date'),
              status: '${item['attendanceStatus'] ?? ''}',
              note: '${item['remarks'] ?? ''}',
            );
          }).toList()
        : const <StudentAttendanceEntry>[];
    return _StudentAttendanceSummary(
      rate: _double(map['attendanceRate']),
      records: records,
    );
  }

  Future<http.Response> _send(String path) async {
    if (_accessToken?.isNotEmpty != true) {
      throw const ApiStudentsException('Please sign in again to continue.');
    }

    Future<http.Response> send() => _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {'Authorization': 'Bearer $_accessToken'},
        )
        .timeout(const Duration(seconds: 15));

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final token = await onRefreshAccessToken!.call();
        if (token?.isNotEmpty == true) {
          _accessToken = token;
          _admissions.accessToken = token;
          _fees.accessToken = token;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw ApiStudentsException(
        'Student information could not be loaded (${response.statusCode}).',
      );
    } on TimeoutException {
      throw const ApiStudentsException(
        'Student information took too long to load.',
      );
    } on ApiStudentsException {
      rethrow;
    } catch (_) {
      throw const ApiStudentsException(
        'Unable to reach the student service right now.',
      );
    }
  }
}

class _StudentAttendanceSummary {
  const _StudentAttendanceSummary({this.rate = 0, this.records = const []});

  final double rate;
  final List<StudentAttendanceEntry> records;
}

class ApiStudentsException implements Exception {
  const ApiStudentsException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<T> _optional<T>(Future<T> operation, T fallback) async {
  try {
    return await operation;
  } catch (_) {
    return fallback;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _namedValue(Object? value, {String fallback = ''}) {
  final map = _map(value);
  if (map == null) {
    final text = '$value'.trim();
    return text == 'null' || text.isEmpty ? fallback : text;
  }
  for (final key in const [
    'name',
    'countryName',
    'cityName',
    'religionName',
    'genderName',
  ]) {
    final text = '${map[key] ?? ''}'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _className(Map<String, dynamic> json, String fallback) {
  final grade = '${json['gradeName'] ?? fallback}'.trim();
  final stream = '${json['streamAlias'] ?? json['streamName'] ?? ''}'.trim();
  if (stream.isEmpty || stream.toLowerCase().contains(grade.toLowerCase())) {
    return grade;
  }
  return '$grade $stream'.trim();
}

String _address(Object? value) {
  final map = _map(value);
  if (map == null) return '';
  return [
    map['houseNumber'],
    map['streetName'],
    _namedValue(map['city']),
    _namedValue(map['district']),
    _namedValue(map['region']),
  ].map((item) => '$item'.trim()).where((item) => item.isNotEmpty).join(', ');
}

List<String> _names(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          return '${map['name'] ?? map['allergyName'] ?? map['value'] ?? ''}'
              .trim();
        }
        return '$item'.trim();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

List<StudentMedicalCondition> _medicalConditions(
  Map<String, dynamic>? medical,
) {
  final raw = medical?['medicalConditions'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final value = '${map['value'] ?? ''}'.toUpperCase();
    final description = '${map['valueDescription'] ?? ''}'.toUpperCase();
    return StudentMedicalCondition(
      name: '${map['conditionName'] ?? ''}',
      hasCondition: value == '1' || description == 'YES',
      notes: '${map['notes'] ?? ''}',
    );
  }).toList();
}

List<String> _medicalAlerts(Map<String, dynamic>? medical) {
  return _medicalConditions(
    medical,
  ).where((item) => item.hasCondition).map((item) => item.name).toList();
}

List<StudentVaccination> _vaccinations(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((raw) {
    final item = Map<String, dynamic>.from(raw);
    final status = '${item['status'] ?? ''}'.toUpperCase();
    return StudentVaccination(
      name: '${item['name'] ?? ''}',
      status: switch (status) {
        'YES' ||
        'RECEIVED' ||
        'VACCINATED' => StudentVaccinationStatus.received,
        'NO' ||
        'NOT_RECEIVED' ||
        'NOT VACCINATED' => StudentVaccinationStatus.notReceived,
        _ => StudentVaccinationStatus.pending,
      },
      required: item['required'] == true,
      receivedOn: _date(item['dateReceived']),
      notes: '${item['notes'] ?? ''}',
    );
  }).toList();
}

List<StudentFeeItem> _feeItems(FeeStudentAccount? account) {
  if (account == null) return const [];
  return account.assessments
      .map(
        (item) =>
            StudentFeeItem(name: item.feeName, amount: item.amount, paid: 0),
      )
      .toList();
}

List<StudentFeeAdjustment> _feeAdjustments(FeeStudentAccount? account) {
  if (account == null) return const [];
  return account.adjustments.map((item) {
    final type = item.adjustmentType.toUpperCase();
    return StudentFeeAdjustment(
      id: '${item.adjustmentId}',
      feeName: item.feeName.isEmpty ? 'Overall fee account' : item.feeName,
      type: type.contains('SURCHARGE') || item.amount > 0
          ? StudentFeeAdjustmentType.surcharge
          : StudentFeeAdjustmentType.discount,
      amount: item.amount.abs(),
      description: item.description,
      status: _adjustmentStatus(item.status),
      createdOn:
          item.createdDate ??
          (throw const ApiStudentsException(
            'A fee adjustment is missing its creation date.',
          )),
      createdBy: 'School administration',
    );
  }).toList();
}

List<StudentPayment> _payments(FeeStudentAccount? account) {
  if (account == null) return const [];
  return account.payments
      .map(
        (item) => StudentPayment(
          date:
              item.paymentDate ??
              (throw const ApiStudentsException(
                'A payment is missing its payment date.',
              )),
          amount: item.netAmount,
          method: item.paymentMethod,
          receiptNumber: item.referenceNumber,
        ),
      )
      .toList();
}

EnrolledStudentStatus _studentStatus(String status) =>
    switch (status.toUpperCase()) {
      'ACTIVE' || 'APPROVED' => EnrolledStudentStatus.active,
      'TRANSFERRED' => EnrolledStudentStatus.transferred,
      _ => EnrolledStudentStatus.inactive,
    };

StudentRequirementStatus _requirementStatus(String status) => switch (status
    .toUpperCase()) {
  'FULFILLED' || 'COMPLETE' || 'RECEIVED' => StudentRequirementStatus.complete,
  'PARTIAL' => StudentRequirementStatus.partial,
  'WAIVED' => StudentRequirementStatus.waived,
  _ => StudentRequirementStatus.outstanding,
};

StudentFeeAdjustmentStatus _adjustmentStatus(String status) =>
    switch (status.toUpperCase()) {
      'DRAFT' => StudentFeeAdjustmentStatus.draft,
      'PENDING' || 'PENDING_APPROVAL' => StudentFeeAdjustmentStatus.pending,
      'CHANGES_REQUESTED' => StudentFeeAdjustmentStatus.changesRequested,
      'APPROVED' => StudentFeeAdjustmentStatus.approved,
      'COMPLETE' || 'COMPLETED' => StudentFeeAdjustmentStatus.complete,
      'REJECTED' => StudentFeeAdjustmentStatus.rejected,
      'REVERSED' => StudentFeeAdjustmentStatus.reversed,
      'CANCELLED' => StudentFeeAdjustmentStatus.cancelled,
      _ => StudentFeeAdjustmentStatus.draft,
    };

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is List && value.length >= 3) {
    final year = _integer(value[0]);
    final month = _integer(value[1]);
    final day = _integer(value[2]);
    if (year > 0 && month > 0 && day > 0) return DateTime(year, month, day);
  }
  return null;
}

DateTime _requiredDate(Object? value, String fieldName) {
  final parsed = _date(value);
  if (parsed != null) return parsed;
  throw ApiStudentsException('The student $fieldName is missing or invalid.');
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
