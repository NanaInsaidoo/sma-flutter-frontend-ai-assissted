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
         client: client,
       ),
       _fees = FeeApiClient(
         accessToken: accessToken,
         onRefreshAccessToken: onRefreshAccessToken,
         client: client,
       );

  final String customSchoolId;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  final AdmissionsApiClient _admissions;
  final FeeApiClient _fees;
  String? _accessToken;

  @override
  Future<StudentPlacement> getCurrentPlacement(
    String studentId,
  ) async => _placement(
    Map<String, dynamic>.from(
      await _json(
            'GET',
            '/api/schools/$customSchoolId/students/$studentId/placements/current',
          )
          as Map,
    ),
  );

  @override
  Future<List<StudentPlacement>> getPlacementHistory(String studentId) async {
    final value = await _json(
      'GET',
      '/api/schools/$customSchoolId/students/$studentId/placements',
    );
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((e) => _placement(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<StudentTransferDestination>> getTransferDestinations(
    String studentId,
  ) async {
    final value = await _json(
      'GET',
      '/api/schools/$customSchoolId/students/$studentId/transfer-destinations',
    );
    return (value as List? ?? const []).whereType<Map>().map((raw) {
      final e = Map<String, dynamic>.from(raw);
      return StudentTransferDestination(
        gradeLevelId: _integer(e['gradeLevelId']),
        gradeName: '${e['gradeName'] ?? ''}',
        streamId: _integer(e['streamId']),
        streamName: '${e['streamName'] ?? ''}',
        feeReady: e['feeReady'] != false,
      );
    }).toList();
  }

  @override
  Future<List<StudentTransferApprover>> getTransferApprovers(
    String studentId,
  ) async {
    final value = await _json(
      'GET',
      '/api/schools/$customSchoolId/students/$studentId/transfer-approvers',
    );
    return (value as List? ?? const []).whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return StudentTransferApprover(
        id: _integer(item['id']),
        name: '${item['name'] ?? ''}',
        role: '${item['role'] ?? ''}',
      );
    }).toList();
  }

  @override
  Future<StudentTransferPreview> previewTransfer(
    String studentId,
    StudentTransferInput input,
  ) async {
    final j = Map<String, dynamic>.from(
      await _json(
            'POST',
            '/api/schools/$customSchoolId/students/$studentId/transfers/preview',
            body: _transferBody(input),
          )
          as Map,
    );
    final d = Map<String, dynamic>.from(j['destination'] as Map);
    return StudentTransferPreview(
      previewToken: '${j['previewToken']}',
      source: _placement(Map<String, dynamic>.from(j['source'] as Map)),
      destination: StudentTransferDestination(
        gradeLevelId: _integer(d['gradeLevelId']),
        gradeName: '${d['gradeName']}',
        streamId: _integer(d['streamId']),
        streamName: '${d['streamName']}',
      ),
      effectiveDate: _requiredDate(j['effectiveDate'], 'effective date'),
      reason: '${j['reason']}',
      gradeChanged: j['gradeChanged'] == true,
      feeMessage: '${j['feeMessage']}',
      attendanceMessage: '${j['attendanceMessage']}',
    );
  }

  @override
  Future<StudentTransferOutcome> confirmTransfer(
    String studentId,
    StudentTransferInput input,
  ) async {
    final j = Map<String, dynamic>.from(
      await _json(
            'POST',
            '/api/schools/$customSchoolId/students/$studentId/transfers',
            body: _transferBody(input),
          )
          as Map,
    );
    return StudentTransferOutcome(
      placement: _placement(Map<String, dynamic>.from(j['placement'] as Map)),
      pendingApproval: j['pendingApproval'] == true,
      message: '${j['message'] ?? ''}',
    );
  }

  Map<String, Object?> _transferBody(StudentTransferInput i) => {
    'transferType': i.type == StudentTransferType.sameGradeDifferentStream
        ? 'SAME_GRADE_DIFFERENT_STREAM'
        : 'DIFFERENT_GRADE_LEVEL',
    'destinationGradeLevelId': i.destinationGradeLevelId,
    'destinationStreamId': i.destinationStreamId,
    'effectiveDate':
        '${i.effectiveDate.year.toString().padLeft(4, '0')}-${i.effectiveDate.month.toString().padLeft(2, '0')}-${i.effectiveDate.day.toString().padLeft(2, '0')}',
    'reason': i.reason.trim(),
    'previewToken': i.previewToken,
    'actorUserId': i.actorUserId,
    'approverId': i.approverId,
  };

  StudentPlacement _placement(Map<String, dynamic> j) => StudentPlacement(
    placementId: _integer(j['placementId']),
    gradeLevelId: _integer(j['gradeLevelId']),
    gradeName: '${j['gradeName'] ?? ''}',
    streamId: _integer(j['streamId']),
    streamName: '${j['streamName'] ?? ''}',
    effectiveFrom: _requiredDate(j['effectiveFrom'], 'placement start'),
    effectiveTo: _date(j['effectiveTo']),
    active: j['active'] == true,
    termStart: _date(j['termStart']),
    termEnd: _date(j['termEnd']),
    reason: '${j['reason'] ?? ''}',
  );

  Future<Object?> _json(String method, String path, {Object? body}) async {
    Future<http.Response> send() => method == 'POST'
        ? _client
              .post(
                Uri.parse('${ApiConfig.baseUrl}$path'),
                headers: {
                  'Content-Type': 'application/json',
                  if (_accessToken?.isNotEmpty == true)
                    'Authorization': 'Bearer $_accessToken',
                },
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 15))
        : _client
              .get(
                Uri.parse('${ApiConfig.baseUrl}$path'),
                headers: {
                  if (_accessToken?.isNotEmpty == true)
                    'Authorization': 'Bearer $_accessToken',
                },
              )
              .timeout(const Duration(seconds: 15));
    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      _accessToken = await onRefreshAccessToken!();
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final e = jsonDecode(response.body);
        throw ApiStudentsException(
          '${e['message'] ?? e['error'] ?? 'Request failed'}',
        );
      } catch (e) {
        if (e is ApiStudentsException) rethrow;
        throw ApiStudentsException('Request failed (${response.statusCode}).');
      }
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<List<int>> _bytes(String path) async {
    Future<http.Response> send() => _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            if (_accessToken?.isNotEmpty == true)
              'Authorization': 'Bearer $_accessToken',
          },
        )
        .timeout(const Duration(seconds: 20));
    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      _accessToken = await onRefreshAccessToken!();
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStudentsException(
        'The item receipt could not be downloaded (${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<List<FeeAdjustmentApprover>> getFeeAdjustmentApprovers() =>
      _fees.getFeeAdjustmentApprovers(customSchoolId);

  @override
  Future<StudentFeeAdjustment> createFeeAdjustment({
    required String customStudentId,
    required int termId,
    required int feeId,
    required StudentFeeAdjustmentType type,
    required double amount,
    required String description,
    required StudentFeeAdjustmentStatus status,
    int? approverId,
  }) async {
    final created = await _fees.createFeeAdjustment(
      customSchoolId: customSchoolId,
      customStudentId: customStudentId,
      termId: termId,
      feeId: feeId,
      amount: type == StudentFeeAdjustmentType.discount
          ? -amount.abs()
          : amount.abs(),
      description: description,
      status: status == StudentFeeAdjustmentStatus.draft
          ? 'DRAFT'
          : 'PENDING_APPROVAL',
      approverId: approverId,
    );
    return _studentAdjustment(created);
  }

  @override
  Future<StudentFeeAdjustment> updateFeeAdjustment({
    required StudentFeeAdjustment adjustment,
    required int feeId,
    required double amount,
    required String description,
    String? changeReason,
    int? approverId,
  }) async {
    final id = int.tryParse(adjustment.id);
    if (id == null) {
      throw const ApiStudentsException('The adjustment cannot be updated.');
    }
    var updated = await _fees.updateFeeAdjustment(
      customSchoolId: customSchoolId,
      adjustmentId: id,
      feeId: feeId,
      amount: adjustment.type == StudentFeeAdjustmentType.discount
          ? -amount.abs()
          : amount.abs(),
      description: description,
      changeReason: changeReason,
    );
    if (adjustment.status == StudentFeeAdjustmentStatus.draft &&
        approverId != null) {
      updated = await _fees.performFeeAdjustmentAction(
        customSchoolId: customSchoolId,
        adjustmentId: id,
        action: 'SUBMIT',
        reason: description,
        approverId: approverId,
      );
    }
    if (adjustment.status == StudentFeeAdjustmentStatus.pending &&
        approverId != null &&
        approverId != adjustment.assignedApproverId) {
      updated = await _fees.performFeeAdjustmentAction(
        customSchoolId: customSchoolId,
        adjustmentId: id,
        action: 'REASSIGN',
        reason: changeReason ?? '',
        approverId: approverId,
      );
    }
    return _studentAdjustment(updated);
  }

  @override
  Future<StudentFeeAdjustment> cancelFeeAdjustment({
    required StudentFeeAdjustment adjustment,
    required String reason,
  }) async {
    final id = int.tryParse(adjustment.id);
    if (id == null) {
      throw const ApiStudentsException('The adjustment cannot be cancelled.');
    }
    final cancelled = await _fees.performFeeAdjustmentAction(
      customSchoolId: customSchoolId,
      adjustmentId: id,
      action: 'CANCEL',
      reason: reason,
    );
    return _studentAdjustment(cancelled);
  }

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
    final adjustmentsFuture = (term.id ?? 0) <= 0
        ? Future.value(const <FeeAdjustment>[])
        : _fees.getFeeAdjustments(
            customSchoolId: customSchoolId,
            termId: term.id!,
          );
    final reversalsFuture = (term.id ?? 0) <= 0
        ? Future.value(const <PaymentReversal>[])
        : _fees.getSchoolPaymentReversals(customSchoolId: customSchoolId);
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
    final termAdjustments = await _optional<List<FeeAdjustment>?>(
      adjustmentsFuture,
      null,
    );
    final reversals = await _optional<List<PaymentReversal>>(
      reversalsFuture,
      const [],
    );
    final attendance = await attendanceFuture;
    final requirements = await _loadRequirements(
      studentId: studentId,
      academicTermId: term.id ?? 0,
      gradeLevelId: _studentGradeLevelId(detail.rawJson),
      gradeLevelName: detail.gradeLevel,
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
      feeAdjustments: termAdjustments == null
          ? null
          : [
              ...termAdjustments
                  .where((item) => item.customStudentId == studentId)
                  .map(_studentAdjustment),
              ..._feeAdjustments(feeAccount, onlyWaivers: true),
            ],
      paymentReversals: _paymentReversals(
        reversals.where(
          (item) =>
              item.customStudentId == studentId &&
              ((term.id ?? 0) <= 0 || item.termId == term.id),
        ),
      ),
    );
  }

  @override
  Future<StudentItemCollectionReceipt> collectStudentItems({
    required String studentId,
    required String idempotencyKey,
    required List<StudentItemCollectionEntry> items,
    String notes = '',
  }) async {
    final value = await _json(
      'POST',
      '/api/schools/$customSchoolId/students/$studentId/requirement-collections',
      body: {
        'idempotencyKey': idempotencyKey,
        'items': items
            .map(
              (item) => {
                'requirementId': int.parse(item.requirementId),
                'quantityReceived': item.quantityReceived,
              },
            )
            .toList(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return _collectionReceipt(Map<String, dynamic>.from(value as Map));
  }

  @override
  Future<List<int>> downloadStudentItemReceipt({
    required String studentId,
    required int receiptId,
  }) => _bytes(
    '/api/schools/$customSchoolId/students/$studentId/requirement-collections/$receiptId/receipt.pdf',
  );

  @override
  Future<List<StudentItemCollectionReceipt>> getStudentItemReceipts({
    required String studentId,
  }) async {
    final value = await _json(
      'GET',
      '/api/schools/$customSchoolId/students/$studentId/requirement-collections',
    );
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => _collectionReceipt(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<int>> downloadStudentItemReceipts({
    required String studentId,
    required List<int> receiptIds,
  }) {
    if (receiptIds.isEmpty) {
      throw const ApiStudentsException('Select at least one item receipt.');
    }
    return _bytes(
      '/api/schools/$customSchoolId/students/$studentId/requirement-collections/receipts.pdf?receiptIds=${receiptIds.join(',')}',
    );
  }

  @override
  Future<List<FeeAdjustmentApprover>> getItemExemptionApprovers({
    required String studentId,
  }) async {
    final value = await _json(
      'GET',
      '/api/schools/$customSchoolId/students/$studentId/requirement-collections/exemption-approvers',
    );
    return (value as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              FeeAdjustmentApprover.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<void> exemptStudentFromItem({
    required String studentId,
    required String requirementId,
    required String reason,
    int? approverId,
    required bool submit,
  }) async {
    await _json(
      'POST',
      '/api/schools/$customSchoolId/students/$studentId/requirement-collections/items/$requirementId/exemption',
      body: {
        'reason': reason.trim(),
        'submit': submit,
        if (approverId != null) 'approverId': approverId,
      },
    );
  }

  Future<List<StudentRequirement>> _loadRequirements({
    required String studentId,
    required int academicTermId,
    required int gradeLevelId,
    required String gradeLevelName,
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
    if (progress == null) {
      final normalizedGradeName = gradeLevelName.trim().toLowerCase();
      final approved = groups.where(
        (item) =>
            item.status == RequirementStatus.approved &&
            ((gradeLevelId > 0 && item.gradeLevelId == gradeLevelId) ||
                (normalizedGradeName.isNotEmpty &&
                    item.className.trim().toLowerCase() ==
                        normalizedGradeName)),
      );
      if (approved.isEmpty) return const [];
      return approved.first.items
          .map(
            (item) => StudentRequirement(
              id: '',
              name: item.name,
              requiredQuantity: item.quantity,
              receivedQuantity: 0,
              unit: item.unit,
              status: StudentRequirementStatus.awaitingPublication,
              note: item.instructions,
            ),
          )
          .toList();
    }
    final group = groups.where((item) => item.id == progress.classGroupId);
    final classItems = group.isEmpty
        ? const <ClassRequirementItem>[]
        : group.first.items;
    final byId = {for (final item in classItems) item.id: item};

    return [
      ...progress.items.map((item) {
        final definition = byId[item.itemId];
        final adjustment = progress.adjustments[item.itemId];
        final exemption =
            adjustment?.type == RequirementAdjustmentType.fullWaiver &&
                adjustment?.workflowStatus != null
            ? adjustment
            : null;
        return StudentRequirement(
          id: item.obligationId,
          name: definition?.name ?? item.itemKey,
          requiredQuantity: item.requiredQuantity,
          receivedQuantity: item.receivedQuantity,
          unit: definition?.unit ?? '',
          status: _requirementStatus(item.status),
          note: exemption?.reason ?? adjustment?.notes ?? '',
          exemptionRequestId: exemption?.adjustmentId ?? 0,
          exemptionStatus: switch (exemption?.workflowStatus) {
            StudentSpecificRequirementStatus.draft =>
              StudentItemExemptionStatus.draft,
            StudentSpecificRequirementStatus.pendingApproval =>
              StudentItemExemptionStatus.pendingApproval,
            StudentSpecificRequirementStatus.changesRequested =>
              StudentItemExemptionStatus.changesRequested,
            StudentSpecificRequirementStatus.active =>
              StudentItemExemptionStatus.approved,
            _ => null,
          },
          exemptionApproverName: exemption?.assignedApproverName ?? '',
          exemptionRejectionReason: exemption?.rejectionReason ?? '',
        );
      }),
      ...progress.customRequirements.map(
        (item) => StudentRequirement(
          id: item.id,
          name: item.name,
          requiredQuantity: item.quantity,
          receivedQuantity: item.receivedQuantity,
          unit: item.unit,
          status: switch (item.status) {
            StudentSpecificRequirementStatus.active =>
              item.receivedQuantity >= item.quantity
                  ? StudentRequirementStatus.complete
                  : item.receivedQuantity > 0
                  ? StudentRequirementStatus.partial
                  : StudentRequirementStatus.outstanding,
            StudentSpecificRequirementStatus.inactive =>
              StudentRequirementStatus.inactive,
            StudentSpecificRequirementStatus.draft ||
            StudentSpecificRequirementStatus.pendingApproval ||
            StudentSpecificRequirementStatus.changesRequested =>
              StudentRequirementStatus.awaitingPublication,
          },
          note: item.notes,
          studentSpecific: true,
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
    List<StudentFeeAdjustment>? feeAdjustments,
    List<StudentPaymentReversal> paymentReversals = const [],
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
    final newThisTerm = detail.admissionTermId != null && term.id != null
        ? detail.admissionTermId == term.id
        : enrolledOn != null &&
              termStart != null &&
              !enrolledOn.isBefore(termStart);

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
      className: detail.classAndSectionLabel,
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
      newThisTerm: newThisTerm,
      attendanceRate: attendance.rate,
      feeBalance: feeBalance,
      requirementsCompleted: requirements
          .where(
            (item) =>
                item.status == StudentRequirementStatus.complete ||
                item.status == StudentRequirementStatus.waived,
          )
          .length,
      requirementsTotal: requirements.length,
      countryOfBirth: _namedValue(json['countryOfBirth']),
      cityOfBirth: _namedValue(json['cityOfBirth']),
      religion: _namedValue(json['religion']),
      address: _address(json['address']),
      bloodGroup: _namedValue(medical?['bloodGroup']),
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
      feeAdjustments: feeAdjustments ?? _feeAdjustments(feeAccount),
      payments: _payments(feeAccount),
      paymentReversals: paymentReversals,
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
      feeTermId: feeAccount?.termId ?? term.id ?? 0,
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

String _address(Object? value) {
  final map = _map(value);
  if (map == null) return '';
  return [
    map['houseNumber'],
    map['streetName'],
    _namedValue(map['city'] ?? map['cityName']),
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
        (item) => StudentFeeItem(
          id: item.assessmentId,
          name: item.feeName,
          amount: item.amount,
          paid: 0,
        ),
      )
      .toList();
}

List<StudentFeeAdjustment> _feeAdjustments(
  FeeStudentAccount? account, {
  bool onlyWaivers = false,
}) {
  if (account == null) return const [];
  return account.adjustments
      .where(
        (item) =>
            !onlyWaivers ||
            item.adjustmentType.toUpperCase().startsWith('WAIVER:'),
      )
      .map((item) {
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
      })
      .toList();
}

StudentFeeAdjustment _studentAdjustment(FeeAdjustment item) {
  final type = item.adjustmentType.toUpperCase();
  return StudentFeeAdjustment(
    id: '${item.id}',
    feeName: item.feeName,
    type: type.contains('SURCHARGE') || item.amount > 0
        ? StudentFeeAdjustmentType.surcharge
        : StudentFeeAdjustmentType.discount,
    amount: item.amount.abs(),
    description: item.description,
    status: _adjustmentStatus(item.status),
    createdOn: item.createdDate ?? DateTime.now(),
    createdBy: item.createdByType,
    assignedApproverId: item.assignedApproverId,
    assignedApproverName: item.assignedApproverName,
  );
}

List<StudentPayment> _payments(FeeStudentAccount? account) {
  if (account == null) return const [];
  return account.payments.map((item) {
    final status = item.status.toUpperCase();
    final amountApplied = status == 'COMPLETED' ? item.netAmount : 0.0;
    return StudentPayment(
      id: item.id,
      date:
          item.paymentDate ??
          (throw const ApiStudentsException(
            'A payment is missing its payment date.',
          )),
      amount: amountApplied,
      method: item.paymentMethod,
      receiptNumber: item.referenceNumber,
      recordedAmount: item.amount,
      refundedAmount: item.refundedAmount,
      status: status,
      statusReason: item.statusReason,
      receivedBy: item.receivedBy,
      overpaymentAmount: item.overpaymentAmount,
      overpaymentReason: item.overpaymentReason,
    );
  }).toList();
}

List<StudentPaymentReversal> _paymentReversals(
  Iterable<PaymentReversal> reversals,
) => reversals
    .map(
      (item) => StudentPaymentReversal(
        id: item.id,
        paymentId: item.paymentId,
        paymentReference: item.paymentReference,
        amount: item.amount,
        status: item.status,
        reason: item.reason,
        requesterName: item.requesterName,
        approverName: item.approverName,
        decisionReason: item.decisionReason,
        decidedByName: item.decidedByName,
        reversalReference: item.reversalReference,
        createdAt: item.createdAt,
        decidedAt: item.decidedAt,
      ),
    )
    .toList(growable: false);

StudentItemCollectionReceipt _collectionReceipt(Map<String, dynamic> json) {
  final rawItems = json['items'];
  return StudentItemCollectionReceipt(
    id: _integer(json['receiptId']),
    number: '${json['receiptNumber'] ?? ''}',
    studentId: '${json['studentId'] ?? ''}',
    studentName: '${json['studentName'] ?? ''}',
    className: '${json['className'] ?? ''}',
    academicTerm: '${json['academicTerm'] ?? ''}',
    collectedAt:
        _date(json['collectedAt']) ??
        (throw const ApiStudentsException(
          'The item receipt is missing its collection date.',
        )),
    collectedBy: '${json['collectedBy'] ?? ''}',
    notes: '${json['notes'] ?? ''}',
    lines: rawItems is List
        ? rawItems.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return StudentItemCollectionReceiptLine(
              requirementId: '${item['requirementId'] ?? ''}',
              itemName: '${item['itemName'] ?? ''}',
              unit: '${item['unit'] ?? ''}',
              quantityReceived: _integer(item['quantityReceived']),
              totalReceived: _integer(item['totalReceived']),
              requiredQuantity: _integer(item['requiredQuantity']),
            );
          }).toList()
        : const [],
  );
}

int _studentGradeLevelId(Map<String, dynamic> json) {
  final direct = _integer(json['gradeLevelId']);
  if (direct > 0) return direct;
  final gradeLevel = json['gradeLevel'];
  if (gradeLevel is Map) {
    return _integer(gradeLevel['id'] ?? gradeLevel['gradeLevelId']);
  }
  return 0;
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
      'ACTIVE' => StudentFeeAdjustmentStatus.approved,
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
