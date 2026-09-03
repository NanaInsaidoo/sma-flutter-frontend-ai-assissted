import 'package:school_management_app/src/fees/data/class_requirements_repository.dart';
import 'package:school_management_app/src/fees/domain/class_requirement_models.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

class FakeClassRequirementsRepository extends ClassRequirementsRepository {
  FakeClassRequirementsRepository() {
    final now = DateTime.now();
    _groups = [
      ClassRequirementGroup(
        id: 'basic-1',
        className: 'Basic 1',
        studentCount: 38,
        status: RequirementStatus.published,
        hasPublishedVersion: true,
        publishedItems: [
          ClassRequirementItem(
            id: 'b1-rolls',
            name: 'Toilet rolls',
            category: 'Hygiene',
            quantity: 15,
            unit: 'rolls',
            estimatedUnitPrice: 4.5,
            dueDate: now.add(const Duration(days: 18)),
            instructions: 'White, unscented rolls preferred.',
          ),
          ClassRequirementItem(
            id: 'b1-tissue',
            name: 'Box of tissues',
            category: 'Hygiene',
            quantity: 2,
            unit: 'boxes',
            estimatedUnitPrice: 18,
            dueDate: now.add(const Duration(days: 18)),
          ),
          ClassRequirementItem(
            id: 'b1-pencil',
            name: 'HB pencils',
            category: 'Learning materials',
            quantity: 6,
            unit: 'pieces',
            estimatedUnitPrice: 2.5,
            dueDate: now.add(const Duration(days: 18)),
          ),
        ],
        items: [
          ClassRequirementItem(
            id: 'b1-rolls',
            name: 'Toilet rolls',
            category: 'Hygiene',
            quantity: 15,
            unit: 'rolls',
            estimatedUnitPrice: 4.5,
            dueDate: now.add(const Duration(days: 18)),
            instructions: 'White, unscented rolls preferred.',
          ),
          ClassRequirementItem(
            id: 'b1-tissue',
            name: 'Box of tissues',
            category: 'Hygiene',
            quantity: 2,
            unit: 'boxes',
            estimatedUnitPrice: 18,
            dueDate: now.add(const Duration(days: 18)),
          ),
          ClassRequirementItem(
            id: 'b1-pencil',
            name: 'HB pencils',
            category: 'Learning materials',
            quantity: 6,
            unit: 'pieces',
            estimatedUnitPrice: 2.5,
            dueDate: now.add(const Duration(days: 18)),
          ),
        ],
      ),
      ClassRequirementGroup(
        id: 'basic-2',
        className: 'Basic 2',
        studentCount: 41,
        status: RequirementStatus.draft,
        draftChangeCount: 1,
        hasPublishedVersion: true,
        publishedItems: [
          ClassRequirementItem(
            id: 'b2-soap',
            name: 'Liquid soap',
            category: 'Hygiene',
            quantity: 2,
            unit: 'bottles',
            estimatedUnitPrice: 22,
            dueDate: now.add(const Duration(days: 12)),
          ),
          ClassRequirementItem(
            id: 'b2-books',
            name: 'Exercise books',
            category: 'Learning materials',
            quantity: 10,
            unit: 'books',
            estimatedUnitPrice: 8,
            dueDate: now.add(const Duration(days: 12)),
          ),
        ],
        items: [
          ClassRequirementItem(
            id: 'b2-soap',
            name: 'Liquid soap',
            category: 'Hygiene',
            quantity: 2,
            unit: 'bottles',
            estimatedUnitPrice: 22,
            dueDate: now.add(const Duration(days: 12)),
          ),
          ClassRequirementItem(
            id: 'b2-disinfectant',
            name: 'Disinfectant',
            category: 'Hygiene',
            quantity: 1,
            unit: 'litre',
            estimatedUnitPrice: 35,
            dueDate: now.add(const Duration(days: 12)),
            updatedSincePublished: true,
            changeType: RequirementItemChange.added,
            instructions: 'Additional health requirement.',
          ),
          ClassRequirementItem(
            id: 'b2-books',
            name: 'Exercise books',
            category: 'Learning materials',
            quantity: 10,
            unit: 'books',
            estimatedUnitPrice: 8,
            dueDate: now.add(const Duration(days: 12)),
          ),
        ],
      ),
      ClassRequirementGroup(
        id: 'jhs-1',
        className: 'JHS 1',
        studentCount: 35,
        status: RequirementStatus.published,
        hasPublishedVersion: true,
        publishedItems: [
          ClassRequirementItem(
            id: 'j1-rolls',
            name: 'Toilet rolls',
            category: 'Hygiene',
            quantity: 15,
            unit: 'rolls',
            estimatedUnitPrice: 4.5,
            dueDate: now.add(const Duration(days: 20)),
          ),
          ClassRequirementItem(
            id: 'j1-graph',
            name: 'Graph books',
            category: 'Learning materials',
            quantity: 3,
            unit: 'books',
            estimatedUnitPrice: 12,
            dueDate: now.add(const Duration(days: 20)),
          ),
          ClassRequirementItem(
            id: 'j1-set',
            name: 'Mathematical set',
            category: 'Learning materials',
            quantity: 1,
            unit: 'set',
            estimatedUnitPrice: 45,
            dueDate: now.add(const Duration(days: 20)),
          ),
        ],
        items: [
          ClassRequirementItem(
            id: 'j1-rolls',
            name: 'Toilet rolls',
            category: 'Hygiene',
            quantity: 15,
            unit: 'rolls',
            estimatedUnitPrice: 4.5,
            dueDate: now.add(const Duration(days: 20)),
          ),
          ClassRequirementItem(
            id: 'j1-graph',
            name: 'Graph books',
            category: 'Learning materials',
            quantity: 3,
            unit: 'books',
            estimatedUnitPrice: 12,
            dueDate: now.add(const Duration(days: 20)),
          ),
          ClassRequirementItem(
            id: 'j1-set',
            name: 'Mathematical set',
            category: 'Learning materials',
            quantity: 1,
            unit: 'set',
            estimatedUnitPrice: 45,
            dueDate: now.add(const Duration(days: 20)),
          ),
        ],
      ),
    ];

    _students = {
      'basic-1': [
        _student('stu-ama', 'Ama Mensah', 'basic-1', {
          'b1-rolls': 15,
          'b1-tissue': 2,
          'b1-pencil': 6,
        }),
        _student('stu-kojo', 'Kojo Asare', 'basic-1', {
          'b1-rolls': 8,
          'b1-tissue': 2,
          'b1-pencil': 2,
        }),
        _student('stu-efua', 'Efua Owusu', 'basic-1', {
          'b1-rolls': 0,
          'b1-tissue': 0,
          'b1-pencil': 0,
        }),
      ],
      'basic-2': [
        _student('stu-yaw', 'Yaw Darko', 'basic-2', {
          'b2-soap': 2,
          'b2-disinfectant': 0,
          'b2-books': 10,
        }),
        _student('stu-akua', 'Akua Boateng', 'basic-2', {
          'b2-soap': 1,
          'b2-disinfectant': 0,
          'b2-books': 6,
        }),
      ],
      'jhs-1': [
        _student('stu-kofi', 'Kofi Nyarko', 'jhs-1', {
          'j1-rolls': 15,
          'j1-graph': 3,
          'j1-set': 1,
        }),
        _student('stu-adwoa', 'Adwoa Frimpong', 'jhs-1', {
          'j1-rolls': 10,
          'j1-graph': 1,
          'j1-set': 1,
        }),
      ],
    };
    _studentCandidates = _students.values.expand((students) => students).map((
      student,
    ) {
      final className = _groups
          .firstWhere((group) => group.id == student.classGroupId)
          .className;
      return StudentRequirementCandidate(
        studentId: student.id,
        studentName: student.name,
        className: className,
      );
    }).toList();
    _studentSpecificRequirements = const [];
    _draftChangeCount = 1;
    _priorTermRequirements = [
      const PriorTermRequirement(
        id: 'prior-ama-rolls',
        studentId: 'stu-ama',
        studentName: 'Ama Mensah',
        originClassName: 'Basic 1',
        originTerm: 'Term 1 · 2025/26',
        itemName: 'Toilet rolls',
        category: 'Hygiene',
        originalQuantity: 15,
        receivedQuantity: 10,
        unit: 'rolls',
        estimatedUnitPrice: 4.5,
      ),
      const PriorTermRequirement(
        id: 'prior-ama-tissue',
        studentId: 'stu-ama',
        studentName: 'Ama Mensah',
        originClassName: 'Basic 1',
        originTerm: 'Term 1 · 2025/26',
        itemName: 'Boxes of tissues',
        category: 'Hygiene',
        originalQuantity: 2,
        receivedQuantity: 0,
        unit: 'boxes',
        estimatedUnitPrice: 18,
      ),
      const PriorTermRequirement(
        id: 'prior-kojo-books',
        studentId: 'stu-kojo',
        studentName: 'Kojo Asare',
        originClassName: 'Basic 1',
        originTerm: 'Term 1 · 2025/26',
        itemName: 'Exercise books',
        category: 'Learning materials',
        originalQuantity: 10,
        receivedQuantity: 6,
        unit: 'books',
        estimatedUnitPrice: 8,
      ),
      const PriorTermRequirement(
        id: 'prior-efua-soap',
        studentId: 'stu-efua',
        studentName: 'Efua Owusu',
        originClassName: 'Basic 1',
        originTerm: 'Term 1 · 2025/26',
        itemName: 'Liquid soap',
        category: 'Hygiene',
        originalQuantity: 2,
        receivedQuantity: 1,
        unit: 'bottles',
        estimatedUnitPrice: 22,
      ),
      const PriorTermRequirement(
        id: 'prior-efua-pencils',
        studentId: 'stu-efua',
        studentName: 'Efua Owusu',
        originClassName: 'Basic 1',
        originTerm: 'Term 1 · 2025/26',
        itemName: 'HB pencils',
        category: 'Learning materials',
        originalQuantity: 6,
        receivedQuantity: 0,
        unit: 'pieces',
        estimatedUnitPrice: 2.5,
      ),
    ];
  }

  @override
  RequirementCompletionSummary get completionSummary =>
      const RequirementCompletionSummary(
        activeObligations: 8,
        completedObligations: 3,
        completionPercentage: 53.1,
      );

  late List<ClassRequirementGroup> _groups;
  late Map<String, List<StudentRequirementProgress>> _students;
  int _draftChangeCount = 0;
  RequirementNotificationPlan? _lastNotificationPlan;
  late List<PriorTermRequirement> _priorTermRequirements;
  late List<StudentCustomRequirement> _studentSpecificRequirements;
  late List<StudentRequirementCandidate> _studentCandidates;

  static StudentRequirementProgress _student(
    String id,
    String name,
    String classGroupId,
    Map<String, int> received,
  ) {
    return StudentRequirementProgress(
      id: id,
      name: name,
      classGroupId: classGroupId,
      receivedQuantities: received,
      adjustments: const {},
      customRequirements: const [],
    );
  }

  @override
  List<ClassRequirementGroup> get groups => List.unmodifiable(_groups);

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> loadStudentsForClass(String classGroupId) async {}

  @override
  int get draftChangeCount => _draftChangeCount;

  @override
  RequirementNotificationPlan? get lastNotificationPlan =>
      _lastNotificationPlan;

  @override
  List<PriorTermRequirement> get priorTermRequirements =>
      List.unmodifiable(_priorTermRequirements);

  @override
  List<StudentCustomRequirement> get studentSpecificRequirements =>
      List.unmodifiable(_studentSpecificRequirements);

  @override
  List<StudentRequirementCandidate> get studentCandidates =>
      List.unmodifiable(_studentCandidates);

  @override
  int get unpublishedClassRequirementCount => _groups
      .where((group) => group.status != RequirementStatus.published)
      .length;

  @override
  int get unpublishedStudentRequirementCount =>
      _studentSpecificRequirements.where((item) => !item.isPublished).length;

  @override
  Future<void> loadPriorTermRequirements() async {}

  @override
  List<StudentRequirementProgress> studentsForClass(String classGroupId) {
    return List.unmodifiable(_students[classGroupId] ?? const []);
  }

  @override
  int draftChangeCountForClass(String classGroupId) {
    return _groups
        .where((group) => group.id == classGroupId)
        .fold<int>(0, (sum, group) => sum + group.draftChangeCount);
  }

  @override
  Future<ClassRequirementGroup> addClass(ClassRequirementGroup group) async {
    _groups = [..._groups, group];
    _students = {..._students, group.id: const []};
    notifyListeners();
    return group;
  }

  @override
  Future<ClassRequirementGroup> addRequirement(
    String classGroupId,
    ClassRequirementItem item, {
    String? revisionReason,
  }) async {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        items: [
          ...group.items,
          group.hasPublishedVersion
              ? item.copyWith(
                  updatedSincePublished: true,
                  changeType: RequirementItemChange.added,
                )
              : item,
        ],
        status: RequirementStatus.draft,
        draftChangeCount: group.draftChangeCount + 1,
      );
    }).toList();
    _draftChangeCount++;
    notifyListeners();
    return _groups.firstWhere((group) => group.id == classGroupId);
  }

  @override
  Future<ClassRequirementGroup> updateRequirement(
    String classGroupId,
    ClassRequirementItem item, {
    String? revisionReason,
  }) async {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      final replacement = group.hasPublishedVersion
          ? item.copyWith(
              updatedSincePublished: true,
              changeType: RequirementItemChange.modified,
            )
          : item;
      return group.copyWith(
        items: group.items
            .map((current) => current.id == item.id ? replacement : current)
            .toList(),
        status: RequirementStatus.draft,
        draftChangeCount: group.draftChangeCount + 1,
      );
    }).toList();
    _draftChangeCount++;
    notifyListeners();
    return _groups.firstWhere((group) => group.id == classGroupId);
  }

  @override
  Future<ClassRequirementGroup> deleteRequirement(
    String classGroupId,
    String requirementId, {
    String? revisionReason,
  }) async {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        items: group.items.where((item) => item.id != requirementId).toList(),
        status: RequirementStatus.draft,
        draftChangeCount: group.draftChangeCount + 1,
      );
    }).toList();
    final students = _students[classGroupId] ?? const [];
    _students = {
      ..._students,
      classGroupId: students.map((student) {
        final received = Map<String, int>.from(student.receivedQuantities)
          ..remove(requirementId);
        final adjustments = Map<String, StudentRequirementAdjustment>.from(
          student.adjustments,
        )..remove(requirementId);
        return student.copyWith(
          receivedQuantities: received,
          adjustments: adjustments,
        );
      }).toList(),
    };
    _draftChangeCount++;
    notifyListeners();
    return _groups.firstWhere((group) => group.id == classGroupId);
  }

  @override
  Future<void> recordPriorTermReceived({
    required String requirementId,
    required int quantity,
    required String notes,
  }) async {
    _priorTermRequirements = _priorTermRequirements.map((item) {
      if (item.id != requirementId) return item;
      final received = item.receivedQuantity + quantity;
      final fulfilled = received >= item.originalQuantity;
      return item.copyWith(
        receivedQuantity: received > item.originalQuantity
            ? item.originalQuantity
            : received,
        status: fulfilled
            ? PriorTermRequirementStatus.fulfilled
            : PriorTermRequirementStatus.pending,
        resolutionNotes: notes,
        resolvedAt: fulfilled ? DateTime.now() : null,
      );
    }).toList();
    notifyListeners();
  }

  @override
  Future<void> resolvePriorTermRequirement({
    required String requirementId,
    required PriorTermRequirementStatus status,
    int? carriedQuantity,
    double? convertedCashAmount,
    DateTime? carriedDueDate,
    required String notes,
    required bool notifyGuardian,
  }) {
    _priorTermRequirements = _priorTermRequirements.map((item) {
      if (item.id != requirementId) return item;
      return item.copyWith(
        status: status,
        carriedQuantity: carriedQuantity,
        convertedCashAmount: convertedCashAmount,
        carriedDueDate: carriedDueDate,
        resolutionNotes: notes,
        resolvedAt: DateTime.now(),
        guardianNotificationQueued: notifyGuardian,
      );
    }).toList();
    notifyListeners();
    return Future.value();
  }

  @override
  Future<void> recordReceived({
    required String studentId,
    required String requirementId,
    required int quantity,
  }) async {
    _updateStudent(studentId, (student) {
      return student.copyWith(
        receivedQuantities: {
          ...student.receivedQuantities,
          requirementId: quantity,
        },
      );
    });
  }

  @override
  Future<void> adjustRequirement({
    required String studentId,
    required String requirementId,
    required StudentRequirementAdjustment adjustment,
  }) async {
    _updateStudent(studentId, (student) {
      return student.copyWith(
        adjustments: {...student.adjustments, requirementId: adjustment},
      );
    });
  }

  @override
  Future<void> addStudentRequirement({
    required String studentId,
    required StudentCustomRequirement requirement,
  }) async {
    final student = _studentCandidates.firstWhere(
      (candidate) => candidate.studentId == studentId,
    );
    final saved = _copyStudentRequirement(
      requirement,
      studentId: student.studentId,
      studentName: student.studentName,
      className: student.className,
      status: StudentSpecificRequirementStatus.draft,
      creatorOwned: true,
    );
    _studentSpecificRequirements = [..._studentSpecificRequirements, saved];
    _updateStudent(studentId, (student) {
      return student.copyWith(
        customRequirements: [...student.customRequirements, saved],
      );
    });
  }

  @override
  Future<void> loadStudentSpecificRequirements() async {}

  @override
  Future<StudentCustomRequirement> updateStudentRequirement(
    StudentCustomRequirement requirement,
  ) async {
    final updated = _copyStudentRequirement(
      requirement,
      status: StudentSpecificRequirementStatus.draft,
      creatorOwned: true,
    );
    _replaceStudentRequirement(updated);
    return updated;
  }

  @override
  Future<void> deleteStudentRequirement(String requirementId) async {
    _studentSpecificRequirements = _studentSpecificRequirements
        .where((item) => item.id != requirementId)
        .toList();
    notifyListeners();
  }

  @override
  Future<List<FeeApprover>> getStudentRequirementApprovers() async => const [
    FeeApprover(id: 99, name: 'Test Headmaster', role: 'Headmaster'),
  ];

  @override
  Future<StudentCustomRequirement> submitStudentRequirement(
    String requirementId,
    int approverId, {
    String note = '',
  }) async {
    return _setStudentRequirementWorkflow(
      requirementId,
      StudentSpecificRequirementStatus.pendingApproval,
      assignedApproverId: approverId,
      assignedApproverName: 'Test Headmaster',
      requesterNote: note,
    );
  }

  @override
  Future<StudentCustomRequirement> withdrawStudentRequirement(
    String requirementId,
  ) async => _setStudentRequirementWorkflow(
    requirementId,
    StudentSpecificRequirementStatus.draft,
  );

  @override
  Future<StudentCustomRequirement> approveStudentRequirement(
    String requirementId,
  ) async => _setStudentRequirementWorkflow(
    requirementId,
    StudentSpecificRequirementStatus.active,
  );

  @override
  Future<StudentCustomRequirement> rejectStudentRequirement(
    String requirementId,
    String reason,
  ) async => _setStudentRequirementWorkflow(
    requirementId,
    StudentSpecificRequirementStatus.changesRequested,
    rejectionReason: reason,
  );

  @override
  Future<StudentCustomRequirement> recordStudentRequirementReceived(
    String requirementId,
    int receivedQuantity,
  ) async {
    final current = _studentSpecificRequirements.firstWhere(
      (item) => item.id == requirementId,
    );
    final updated = StudentCustomRequirement(
      id: current.id,
      name: current.name,
      quantity: current.quantity,
      unit: current.unit,
      dueDate: current.dueDate,
      notes: current.notes,
      studentId: current.studentId,
      studentName: current.studentName,
      className: current.className,
      receivedQuantity: receivedQuantity,
      estimatedUnitPrice: current.estimatedUnitPrice,
      status: current.status,
      creatorOwned: current.creatorOwned,
      canApprove: current.canApprove,
      canWithdraw: current.canWithdraw,
      assignedApproverId: current.assignedApproverId,
      assignedApproverName: current.assignedApproverName,
      requesterName: current.requesterName,
      requesterNote: current.requesterNote,
      rejectionReason: current.rejectionReason,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      submittedAt: current.submittedAt,
      approvedAt: current.approvedAt,
    );
    _replaceStudentRequirement(updated);
    return updated;
  }

  StudentCustomRequirement _setStudentRequirementWorkflow(
    String requirementId,
    StudentSpecificRequirementStatus status, {
    int? assignedApproverId,
    String assignedApproverName = '',
    String requesterNote = '',
    String rejectionReason = '',
  }) {
    final current = _studentSpecificRequirements.firstWhere(
      (item) => item.id == requirementId,
    );
    final updated = _copyStudentRequirement(
      current,
      status: status,
      assignedApproverId: assignedApproverId,
      assignedApproverName: assignedApproverName,
      requesterNote: requesterNote,
      rejectionReason: rejectionReason,
      creatorOwned: true,
      canApprove: status == StudentSpecificRequirementStatus.pendingApproval,
      canWithdraw: status == StudentSpecificRequirementStatus.pendingApproval,
    );
    _replaceStudentRequirement(updated);
    return updated;
  }

  void _replaceStudentRequirement(StudentCustomRequirement replacement) {
    _studentSpecificRequirements = _studentSpecificRequirements
        .map((item) => item.id == replacement.id ? replacement : item)
        .toList();
    notifyListeners();
  }

  StudentCustomRequirement _copyStudentRequirement(
    StudentCustomRequirement source, {
    String? studentId,
    String? studentName,
    String? className,
    StudentSpecificRequirementStatus? status,
    bool? creatorOwned,
    bool? canApprove,
    bool? canWithdraw,
    int? assignedApproverId,
    String? assignedApproverName,
    String? requesterNote,
    String? rejectionReason,
  }) {
    return StudentCustomRequirement(
      id: source.id,
      name: source.name,
      quantity: source.quantity,
      unit: source.unit,
      dueDate: source.dueDate,
      notes: source.notes,
      studentId: studentId ?? source.studentId,
      studentName: studentName ?? source.studentName,
      className: className ?? source.className,
      receivedQuantity: source.receivedQuantity,
      estimatedUnitPrice: source.estimatedUnitPrice,
      status: status ?? source.status,
      creatorOwned: creatorOwned ?? source.creatorOwned,
      canApprove: canApprove ?? source.canApprove,
      canWithdraw: canWithdraw ?? source.canWithdraw,
      assignedApproverId: assignedApproverId ?? source.assignedApproverId,
      assignedApproverName: assignedApproverName ?? source.assignedApproverName,
      requesterName: source.requesterName,
      requesterNote: requesterNote ?? source.requesterNote,
      rejectionReason: rejectionReason ?? source.rejectionReason,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
      submittedAt: source.submittedAt,
      approvedAt: source.approvedAt,
    );
  }

  void _updateStudent(
    String studentId,
    StudentRequirementProgress Function(StudentRequirementProgress) update,
  ) {
    _students = _students.map((classId, students) {
      return MapEntry(
        classId,
        students
            .map(
              (student) => student.id == studentId ? update(student) : student,
            )
            .toList(),
      );
    });
    notifyListeners();
  }

  @override
  void publishChanges(RequirementNotificationPlan notificationPlan) {
    _groups = _groups
        .map(
          (group) => group.copyWith(
            items: group.items
                .map(
                  (item) => item.copyWith(
                    updatedSincePublished: false,
                    changeType: RequirementItemChange.current,
                  ),
                )
                .toList(),
            publishedItems: group.items
                .map(
                  (item) => item.copyWith(
                    updatedSincePublished: false,
                    changeType: RequirementItemChange.current,
                  ),
                )
                .toList(),
            status: RequirementStatus.published,
            draftChangeCount: 0,
            hasPublishedVersion: true,
          ),
        )
        .toList();
    _lastNotificationPlan = notificationPlan;
    _draftChangeCount = 0;
    notifyListeners();
  }

  @override
  Future<ClassRequirementGroup> publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  ) async {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        items: group.items
            .map(
              (item) => item.copyWith(
                updatedSincePublished: false,
                changeType: RequirementItemChange.current,
              ),
            )
            .toList(),
        publishedItems: group.items
            .map(
              (item) => item.copyWith(
                updatedSincePublished: false,
                changeType: RequirementItemChange.current,
              ),
            )
            .toList(),
        status: RequirementStatus.published,
        draftChangeCount: 0,
        hasPublishedVersion: true,
      );
    }).toList();
    _lastNotificationPlan = notificationPlan;
    _draftChangeCount = _groups.fold<int>(
      0,
      (sum, group) => sum + group.draftChangeCount,
    );
    notifyListeners();
    return _groups.firstWhere((group) => group.id == classGroupId);
  }

  @override
  Future<List<FeeApprover>> getApprovers() async => const [
    FeeApprover(id: 99, name: 'Test Headmaster', role: 'Headmaster'),
  ];

  @override
  Future<ClassRequirementGroup> submitClass(
    String classGroupId,
    int approverId, {
    String note = '',
  }) async => _setWorkflow(
    classGroupId,
    RequirementStatus.pendingApproval,
    approverId: approverId,
    approverName: 'Test Headmaster',
  );

  @override
  Future<ClassRequirementGroup> withdrawClass(String classGroupId) async =>
      _setWorkflow(classGroupId, RequirementStatus.draft);

  @override
  Future<ClassRequirementGroup> approveClass(String classGroupId) async =>
      _setWorkflow(classGroupId, RequirementStatus.approved);

  @override
  Future<ClassRequirementGroup> rejectClass(
    String classGroupId,
    String reason,
  ) async => _setWorkflow(
    classGroupId,
    RequirementStatus.draft,
    rejectionReason: reason,
  );

  ClassRequirementGroup _setWorkflow(
    String classGroupId,
    RequirementStatus status, {
    int approverId = 0,
    String approverName = '',
    String rejectionReason = '',
  }) {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        status: status,
        assignedApproverId: approverId,
        assignedApproverName: approverName,
        rejectionReason: rejectionReason,
      );
    }).toList();
    notifyListeners();
    return _groups.firstWhere((group) => group.id == classGroupId);
  }
}
