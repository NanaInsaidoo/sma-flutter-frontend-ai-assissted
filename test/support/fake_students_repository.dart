import 'package:school_management_app/src/students/domain/student_models.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

class FakeStudentsRepository implements StudentsRepository {
  const FakeStudentsRepository();

  static final List<EnrolledStudent> _students = [
    _student(
      id: 'STU-FA1BC0-9043',
      name: 'Kwame Yaw Asante',
      className: 'JHS 1A',
      gender: 'Male',
      guardianName: 'Kofi Asante',
      relationship: 'Father',
      guardianPhone: '024 123 4567',
      householdId: 'HH-1042',
      attendanceRate: 96.8,
      feeBalance: 150,
      completed: 2,
      total: 3,
      newThisTerm: false,
      medicalAlerts: const ['Peanut allergy'],
      medicalConditions: const [
        StudentMedicalCondition(
          name: 'Asthma',
          hasCondition: true,
          notes: 'Uses a reliever inhaler when symptoms occur.',
        ),
        StudentMedicalCondition(
          name: 'Sickle cell disease',
          hasCondition: false,
        ),
        StudentMedicalCondition(name: 'Epilepsy', hasCondition: false),
      ],
      allergies: const StudentAllergies(
        food: ['Peanuts'],
        environmental: ['Dust mites'],
      ),
      relatedStudents: const [
        StudentHouseholdMember(
          id: 'STU-FA1BC0-3391',
          name: 'Abena Asante',
          relationship: 'Sibling',
          type: StudentHouseholdMemberType.student,
          subtitle: 'Basic 4B',
        ),
      ],
      additionalGuardians: const [
        StudentHouseholdMember(
          id: 'GUA-FA1BC0-2044',
          name: 'Adwoa Asante',
          relationship: 'Mother',
          type: StudentHouseholdMemberType.guardian,
          subtitle: '020 987 6543',
        ),
      ],
      feeAdjustments: [
        StudentFeeAdjustment(
          id: 'ADJ-1042-01',
          feeName: 'ICT / Computer',
          type: StudentFeeAdjustmentType.discount,
          amount: 50,
          description: 'Sibling discount for two enrolled children',
          status: StudentFeeAdjustmentStatus.approved,
          createdOn: DateTime(2026, 7, 3),
          createdBy: 'Ama Owusu',
        ),
        StudentFeeAdjustment(
          id: 'ADJ-1042-02',
          feeName: 'Tuition fee',
          type: StudentFeeAdjustmentType.surcharge,
          amount: 20,
          description: 'Late payment charge',
          status: StudentFeeAdjustmentStatus.complete,
          createdOn: DateTime(2026, 7, 8),
          createdBy: 'Ama Owusu',
        ),
        StudentFeeAdjustment(
          id: 'ADJ-1042-03',
          feeName: 'ICT / Computer',
          type: StudentFeeAdjustmentType.discount,
          amount: 25,
          description: 'Temporary financial support request',
          status: StudentFeeAdjustmentStatus.pending,
          createdOn: DateTime(2026, 7, 15),
          createdBy: 'Eric Amozini',
          assignedApproverId: 12,
          assignedApproverName: 'Efua Nyarko',
        ),
      ],
    ),
    _student(
      id: 'STU-FA1BC0-3391',
      name: 'Abena Asante',
      className: 'Basic 4B',
      gender: 'Female',
      guardianName: 'Adwoa Asante',
      relationship: 'Mother',
      guardianPhone: '020 987 6543',
      householdId: 'HH-1042',
      attendanceRate: 98.2,
      feeBalance: 0,
      completed: 3,
      total: 3,
      newThisTerm: false,
      relatedStudents: const [
        StudentHouseholdMember(
          id: 'STU-FA1BC0-9043',
          name: 'Kwame Yaw Asante',
          relationship: 'Sibling',
          type: StudentHouseholdMemberType.student,
          subtitle: 'JHS 1A',
        ),
      ],
      additionalGuardians: const [
        StudentHouseholdMember(
          id: 'GUA-FA1BC0-1022',
          name: 'Kofi Asante',
          relationship: 'Father',
          type: StudentHouseholdMemberType.guardian,
          subtitle: '024 123 4567',
        ),
      ],
    ),
    _student(
      id: 'STU-FA1BC0-7591',
      name: 'Nana Kofi Mensah',
      className: 'Basic 2A',
      gender: 'Male',
      guardianName: 'Efua Mensah',
      relationship: 'Mother',
      guardianPhone: '055 421 8890',
      householdId: 'HH-1088',
      attendanceRate: 89.5,
      feeBalance: 320,
      completed: 1,
      total: 3,
      newThisTerm: true,
      medicalAlerts: const ['Asthma'],
      medicalConditions: const [
        StudentMedicalCondition(
          name: 'Asthma',
          hasCondition: true,
          notes: 'Exercise can trigger symptoms. Inhaler kept at the office.',
        ),
        StudentMedicalCondition(name: 'Diabetes', hasCondition: false),
      ],
    ),
    _student(
      id: 'STU-FA1BC0-8817',
      name: 'Akosua Owusu',
      className: 'KG 2',
      gender: 'Female',
      guardianName: 'Yaw Owusu',
      relationship: 'Father',
      guardianPhone: '024 310 2774',
      householdId: 'HH-1104',
      attendanceRate: 94.1,
      feeBalance: 80,
      completed: 3,
      total: 3,
      newThisTerm: true,
    ),
    _student(
      id: 'STU-FA1BC0-9122',
      name: 'Kojo Amankwah',
      className: 'JHS 3B',
      gender: 'Male',
      guardianName: 'Mabel Amankwah',
      relationship: 'Guardian',
      guardianPhone: '027 889 0142',
      householdId: 'HH-1120',
      attendanceRate: 91.7,
      feeBalance: 0,
      completed: 2,
      total: 3,
      newThisTerm: false,
    ),
    _student(
      id: 'STU-FA1BC0-9348',
      name: 'Esi Nyarko',
      className: 'Basic 6A',
      gender: 'Female',
      guardianName: 'Daniel Nyarko',
      relationship: 'Father',
      guardianPhone: '050 663 1902',
      householdId: 'HH-1141',
      attendanceRate: 86.4,
      feeBalance: 470,
      completed: 0,
      total: 3,
      newThisTerm: false,
      medicalAlerts: const ['Sickle cell disease'],
      medicalConditions: const [
        StudentMedicalCondition(
          name: 'Sickle cell disease',
          hasCondition: true,
          notes: 'Contact the guardian if severe pain begins.',
        ),
      ],
    ),
  ];

  @override
  Future<List<EnrolledStudent>> getEnrolledStudents() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(_students);
  }

  @override
  Future<EnrolledStudent> getStudent(String studentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _students.firstWhere((student) => student.id == studentId);
  }

  @override
  Future<StudentItemCollectionReceipt> collectStudentItems({
    required String studentId,
    required String idempotencyKey,
    required List<StudentItemCollectionEntry> items,
    String notes = '',
  }) async {
    final student = _students.firstWhere((value) => value.id == studentId);
    return StudentItemCollectionReceipt(
      id: 1,
      number: 'ITEM-20260829-DEMO0001',
      studentId: student.id,
      studentName: student.name,
      className: student.className,
      academicTerm: 'First Term 2026-2027',
      collectedAt: DateTime(2026, 8, 29, 10, 30),
      collectedBy: 'Current administrator',
      notes: notes,
      lines: items.map((entry) {
        final requirement = student.requirements.firstWhere(
          (value) => value.id == entry.requirementId,
        );
        return StudentItemCollectionReceiptLine(
          requirementId: requirement.id,
          itemName: requirement.name,
          unit: requirement.unit,
          quantityReceived: entry.quantityReceived,
          totalReceived: requirement.receivedQuantity + entry.quantityReceived,
          requiredQuantity: requirement.requiredQuantity,
        );
      }).toList(),
    );
  }

  @override
  Future<List<int>> downloadStudentItemReceipt({
    required String studentId,
    required int receiptId,
  }) async => const <int>[37, 80, 68, 70];

  @override
  Future<List<StudentItemCollectionReceipt>> getStudentItemReceipts({
    required String studentId,
  }) async {
    final student = _students.firstWhere((value) => value.id == studentId);
    final requirements = student.requirements
        .where((item) => item.id.isNotEmpty)
        .take(2)
        .toList();
    if (requirements.isEmpty) return const [];
    return [
      StudentItemCollectionReceipt(
        id: 2,
        number: 'ITEM-20260829-DEMO0002',
        studentId: student.id,
        studentName: student.name,
        className: student.className,
        academicTerm: 'First Term 2026-2027',
        collectedAt: DateTime(2026, 8, 29, 14, 15),
        collectedBy: 'Adjoa Mensah',
        notes: 'Received at the school office.',
        lines: requirements
            .map(
              (item) => StudentItemCollectionReceiptLine(
                requirementId: item.id,
                itemName: item.name,
                unit: item.unit,
                quantityReceived: 1,
                totalReceived: item.receivedQuantity,
                requiredQuantity: item.requiredQuantity,
              ),
            )
            .toList(),
      ),
      StudentItemCollectionReceipt(
        id: 1,
        number: 'ITEM-20260820-DEMO0001',
        studentId: student.id,
        studentName: student.name,
        className: student.className,
        academicTerm: 'First Term 2026-2027',
        collectedAt: DateTime(2026, 8, 20, 9, 30),
        collectedBy: 'Kofi Nketia',
        lines: [
          StudentItemCollectionReceiptLine(
            requirementId: requirements.first.id,
            itemName: requirements.first.name,
            unit: requirements.first.unit,
            quantityReceived: 2,
            totalReceived: requirements.first.receivedQuantity,
            requiredQuantity: requirements.first.requiredQuantity,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<int>> downloadStudentItemReceipts({
    required String studentId,
    required List<int> receiptIds,
  }) async => const <int>[37, 80, 68, 70];

  @override
  Future<List<FeeAdjustmentApprover>> getItemExemptionApprovers({
    required String studentId,
  }) async => const [
    FeeAdjustmentApprover(id: 12, name: 'Efua Nyarko', role: 'Administrator'),
  ];

  @override
  Future<void> exemptStudentFromItem({
    required String studentId,
    required String requirementId,
    required String reason,
    int? approverId,
    required bool submit,
  }) async {}

  @override
  Future<List<FeeAdjustmentApprover>> getFeeAdjustmentApprovers() async =>
      const [
        FeeAdjustmentApprover(
          id: 12,
          name: 'Efua Nyarko',
          role: 'ADMINISTRATOR',
        ),
      ];

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
  }) async => StudentFeeAdjustment(
    id: 'ADJ-SERVER-1',
    feeName: 'Tuition fee',
    type: type,
    amount: amount,
    description: description,
    status: status,
    createdOn: DateTime(2026, 7, 19),
    createdBy: 'Current administrator',
  );

  @override
  Future<StudentFeeAdjustment> updateFeeAdjustment({
    required StudentFeeAdjustment adjustment,
    required int feeId,
    required double amount,
    required String description,
    String? changeReason,
    int? approverId,
  }) async => adjustment.copyWith(
    amount: amount,
    description: description,
    status:
        adjustment.status == StudentFeeAdjustmentStatus.draft &&
            approverId != null
        ? StudentFeeAdjustmentStatus.pending
        : adjustment.status,
    assignedApproverId: approverId ?? adjustment.assignedApproverId,
    assignedApproverName: approverId == null
        ? adjustment.assignedApproverName
        : 'Efua Nyarko',
  );

  @override
  Future<StudentFeeAdjustment> cancelFeeAdjustment({
    required StudentFeeAdjustment adjustment,
    required String reason,
  }) async => adjustment.copyWith(status: StudentFeeAdjustmentStatus.cancelled);

  @override
  Future<StudentPlacement> getCurrentPlacement(String studentId) async =>
      StudentPlacement(
        placementId: 1,
        gradeLevelId: 1,
        gradeName: 'JHS 1',
        streamId: 11,
        streamName: 'A',
        effectiveFrom: DateTime(2026, 7, 1),
        active: true,
        termStart: DateTime(2026, 7, 1),
        termEnd: DateTime(2026, 9, 30),
      );

  @override
  Future<List<StudentPlacement>> getPlacementHistory(String studentId) async =>
      [await getCurrentPlacement(studentId)];

  @override
  Future<List<StudentTransferDestination>> getTransferDestinations(
    String studentId,
  ) async => const [
    StudentTransferDestination(
      gradeLevelId: 1,
      gradeName: 'JHS 1',
      streamId: 12,
      streamName: 'B',
    ),
    StudentTransferDestination(
      gradeLevelId: 1,
      gradeName: 'JHS 1',
      streamId: 13,
      streamName: 'C',
      feeReady: false,
    ),
    StudentTransferDestination(
      gradeLevelId: 2,
      gradeName: 'JHS 2',
      streamId: 21,
      streamName: 'A',
    ),
  ];

  @override
  Future<StudentTransferPreview> previewTransfer(
    String studentId,
    StudentTransferInput input,
  ) async => StudentTransferPreview(
    previewToken: 'preview-token',
    source: await getCurrentPlacement(studentId),
    destination: (await getTransferDestinations(
      studentId,
    )).firstWhere((x) => x.streamId == input.destinationStreamId),
    effectiveDate: input.effectiveDate,
    reason: input.reason,
    gradeChanged: input.destinationGradeLevelId != 1,
    feeMessage: input.destinationGradeLevelId != 1
        ? 'Fees will be recalculated only after approval. Existing discounts and waivers will then be cancelled and must be reapplied manually. Payments and receipts remain recorded.'
        : 'No grade-level fee change is expected.',
    attendanceMessage:
        'Attendance before the effective date remains with the previous class.',
  );

  @override
  Future<List<StudentTransferApprover>> getTransferApprovers(
    String studentId,
  ) async => const [
    StudentTransferApprover(
      id: 41,
      name: 'Adjoa Mensah',
      role: 'Administrator',
    ),
  ];

  @override
  Future<StudentTransferOutcome> confirmTransfer(
    String studentId,
    StudentTransferInput input,
  ) async => StudentTransferOutcome(
    pendingApproval: input.type == StudentTransferType.differentGrade,
    message: input.type == StudentTransferType.differentGrade
        ? 'Grade-change request submitted for approval.'
        : '',
    placement: StudentPlacement(
      placementId: 2,
      gradeLevelId: input.type == StudentTransferType.differentGrade
          ? 1
          : input.destinationGradeLevelId,
      gradeName: input.type == StudentTransferType.differentGrade
          ? 'JHS 1'
          : (input.destinationGradeLevelId == 1 ? 'JHS 1' : 'JHS 2'),
      streamId: input.type == StudentTransferType.differentGrade
          ? 11
          : input.destinationStreamId,
      streamName: input.type == StudentTransferType.differentGrade
          ? 'A'
          : (input.destinationStreamId == 12 ? 'B' : 'A'),
      effectiveFrom: input.effectiveDate,
      active: true,
      reason: input.reason,
    ),
  );
}

EnrolledStudent _student({
  required String id,
  required String name,
  required String className,
  required String gender,
  required String guardianName,
  required String relationship,
  required String guardianPhone,
  required String householdId,
  required double attendanceRate,
  required double feeBalance,
  required int completed,
  required int total,
  required bool newThisTerm,
  List<String> medicalAlerts = const [],
  List<StudentMedicalCondition> medicalConditions = const [],
  StudentAllergies allergies = const StudentAllergies(),
  List<StudentHouseholdMember> relatedStudents = const [],
  List<StudentHouseholdMember> additionalGuardians = const [],
  List<StudentFeeAdjustment> feeAdjustments = const [],
}) {
  final paid = (600 - feeBalance).clamp(0, 600).toDouble();
  final tuitionPaid = paid.clamp(0, 450).toDouble();
  final ptaPaid = (paid - tuitionPaid).clamp(0, 50).toDouble();
  final ictPaid = (paid - tuitionPaid - ptaPaid).clamp(0, 100).toDouble();
  return EnrolledStudent(
    id: id,
    feeTermId: 44,
    name: name,
    className: className,
    gender: gender,
    dateOfBirth: DateTime(gender == 'Female' ? 2016 : 2015, 3, 15),
    guardianName: guardianName,
    guardianRelationship: relationship,
    guardianPhone: guardianPhone,
    householdId: householdId,
    status: EnrolledStudentStatus.active,
    enrolledOn: newThisTerm ? DateTime(2026, 6, 4) : DateTime(2023, 9, 5),
    newThisTerm: newThisTerm,
    attendanceRate: attendanceRate,
    feeBalance: feeBalance,
    requirementsCompleted: completed,
    requirementsTotal: total,
    countryOfBirth: 'Ghana',
    cityOfBirth: 'Accra',
    religion: 'Christianity',
    address: 'No. 14, Nii Amon Street, Accra',
    bloodGroup: 'O+',
    medicalAlerts: medicalAlerts,
    medicalConditions: medicalConditions.isEmpty
        ? const [
            StudentMedicalCondition(name: 'Asthma', hasCondition: false),
            StudentMedicalCondition(name: 'Diabetes', hasCondition: false),
            StudentMedicalCondition(name: 'Epilepsy', hasCondition: false),
          ]
        : medicalConditions,
    allergies: allergies,
    vaccinations: [
      StudentVaccination(
        name: 'BCG',
        status: StudentVaccinationStatus.received,
        required: true,
        receivedOn: DateTime(2016, 3, 18),
      ),
      StudentVaccination(
        name: 'Hepatitis B',
        status: StudentVaccinationStatus.received,
        required: true,
        receivedOn: DateTime(2016, 4, 18),
      ),
      const StudentVaccination(
        name: 'Measles-Rubella',
        status: StudentVaccinationStatus.received,
        required: true,
      ),
      const StudentVaccination(
        name: 'Yellow Fever',
        status: StudentVaccinationStatus.pending,
        required: true,
        notes: 'Vaccination date has not been supplied.',
      ),
      const StudentVaccination(
        name: 'COVID-19',
        status: StudentVaccinationStatus.notReceived,
        required: false,
      ),
    ],
    householdMembers: [
      StudentHouseholdMember(
        id: 'GUA-${householdId.replaceAll('HH-', '')}-01',
        name: guardianName,
        relationship: relationship,
        type: StudentHouseholdMemberType.guardian,
        subtitle: guardianPhone,
        primary: true,
      ),
      ...additionalGuardians,
      StudentHouseholdMember(
        id: id,
        name: name,
        relationship: 'Student',
        type: StudentHouseholdMemberType.student,
        subtitle: className,
      ),
      ...relatedStudents,
    ],
    attendance: [
      StudentAttendanceEntry(date: DateTime(2026, 7, 16), status: 'Present'),
      StudentAttendanceEntry(date: DateTime(2026, 7, 15), status: 'Present'),
      StudentAttendanceEntry(
        date: DateTime(2026, 7, 14),
        status: attendanceRate < 90 ? 'Absent' : 'Present',
        note: attendanceRate < 90 ? 'Guardian notified' : '',
      ),
      StudentAttendanceEntry(date: DateTime(2026, 7, 13), status: 'Present'),
    ],
    fees: [
      StudentFeeItem(
        id: 501,
        name: 'Tuition fee',
        amount: 450,
        paid: tuitionPaid,
      ),
      StudentFeeItem(id: 502, name: 'PTA levy', amount: 50, paid: ptaPaid),
      StudentFeeItem(
        id: 503,
        name: 'ICT / Computer',
        amount: 100,
        paid: ictPaid,
      ),
    ],
    feeAdjustments: feeAdjustments,
    payments: [
      StudentPayment(
        id: 70,
        date: DateTime(2026, 7, 10),
        amount: paid,
        recordedAmount: paid,
        method: 'Mobile Money',
        receiptNumber: 'REC-0070',
        receivedBy: 'School cashier',
        status: 'COMPLETED',
      ),
      StudentPayment(
        id: 71,
        date: DateTime(2026, 7, 8),
        amount: 0,
        recordedAmount: 300,
        refundedAmount: 300,
        method: 'Cash',
        receiptNumber: 'REC-0071',
        receivedBy: 'School cashier',
        status: 'REVERSED',
        statusReason: 'Reversed under REV-0071',
      ),
    ],
    paymentReversals: [
      StudentPaymentReversal(
        id: 91,
        paymentId: 71,
        paymentReference: 'REC-0071',
        amount: 300,
        status: 'APPROVED',
        reason: 'Payment was recorded against the wrong student.',
        requesterName: 'School cashier',
        approverName: 'Efua Nyarko',
        decisionReason: 'Approved',
        decidedByName: 'Efua Nyarko',
        reversalReference: 'REV-0071',
        createdAt: DateTime(2026, 7, 9, 9),
        decidedAt: DateTime(2026, 7, 9, 10),
      ),
    ],
    requirements: [
      const StudentRequirement(
        id: 'REQ-BOOKS',
        name: 'Liquid soap',
        requiredQuantity: 2,
        receivedQuantity: 2,
        unit: 'bottles',
        status: StudentRequirementStatus.complete,
      ),
      StudentRequirement(
        id: 'REQ-UNIFORM',
        name: 'Disinfectant',
        requiredQuantity: 1,
        receivedQuantity: completed >= 2 ? 1 : 0,
        unit: 'litre',
        isFromPreviousTerm: true,
        sourceTerm: 'Term 1 · 2025/26',
        status: completed >= 2
            ? StudentRequirementStatus.complete
            : StudentRequirementStatus.outstanding,
      ),
      StudentRequirement(
        id: 'REQ-ART',
        name: 'Exercise books',
        requiredQuantity: 10,
        receivedQuantity: completed >= 3
            ? 10
            : completed == 2
            ? 6
            : 0,
        unit: 'books',
        status: completed >= 3
            ? StudentRequirementStatus.complete
            : completed == 2
            ? StudentRequirementStatus.partial
            : StudentRequirementStatus.outstanding,
      ),
    ],
    documents: [
      StudentDocument(
        name: 'Birth certificate',
        fileName: 'birth-certificate.pdf',
        status: 'Verified',
        updatedOn: DateTime(2026, 6, 2),
      ),
      StudentDocument(
        name: 'Immunisation card',
        fileName: 'immunisation-card.pdf',
        status: 'On file',
        updatedOn: DateTime(2026, 6, 2),
      ),
    ],
    activity: [
      StudentActivity(
        title: 'Attendance marked',
        description: 'Recorded present for today.',
        occurredOn: DateTime(2026, 7, 16, 8, 4),
      ),
      StudentActivity(
        title: 'Payment recorded',
        description:
            'GH\u20b5 ${paid.toStringAsFixed(0)} received by Mobile Money.',
        occurredOn: DateTime(2026, 7, 10, 10, 20),
      ),
    ],
  );
}
