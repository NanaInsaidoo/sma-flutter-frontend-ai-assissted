import '../domain/class_requirement_models.dart';
import 'class_requirements_repository.dart';
import 'fee_api_client.dart';

class ApiClassRequirementsRepository extends ClassRequirementsRepository {
  ApiClassRequirementsRepository({
    required FeeApiClient api,
    required this.customSchoolId,
    required this.academicTermId,
  }) : _api = api;

  final FeeApiClient _api;
  final String customSchoolId;
  final int academicTermId;

  List<ClassRequirementGroup> _groups = const [];
  Map<String, List<StudentRequirementProgress>> _studentsByClass = const {};
  bool _isLoading = false;
  String? _errorMessage;
  RequirementNotificationPlan? _lastNotificationPlan;
  List<PriorTermRequirement> _priorTermRequirements = const [];

  @override
  List<ClassRequirementGroup> get groups => List.unmodifiable(_groups);

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  int get draftChangeCount =>
      _groups.fold(0, (total, group) => total + group.draftChangeCount);

  @override
  int draftChangeCountForClass(String classGroupId) =>
      _findGroup(classGroupId).draftChangeCount;

  @override
  RequirementNotificationPlan? get lastNotificationPlan =>
      _lastNotificationPlan;

  @override
  List<PriorTermRequirement> get priorTermRequirements =>
      List.unmodifiable(_priorTermRequirements);

  @override
  List<StudentRequirementProgress> studentsForClass(String classGroupId) =>
      List.unmodifiable(_studentsByClass[classGroupId] ?? const []);

  @override
  Future<void> loadStudentsForClass(String classGroupId) async {
    final requirementId = int.tryParse(classGroupId);
    if (requirementId == null) {
      throw StateError('The class checklist has not been saved');
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final students = await _api.getClassRequirementStudents(
        customSchoolId: customSchoolId,
        requirementId: requirementId,
      );
      _studentsByClass = {..._studentsByClass, classGroupId: students};
    } catch (error) {
      _errorMessage = '$error';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _groups = await _api.getClassRequirements(
        customSchoolId: customSchoolId,
        academicTermId: academicTermId,
      );
      _priorTermRequirements = await _api.getPriorTermRequirements(
        customSchoolId: customSchoolId,
      );
    } catch (error) {
      _errorMessage = '$error';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> loadPriorTermRequirements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _priorTermRequirements = await _api.getPriorTermRequirements(
        customSchoolId: customSchoolId,
      );
    } catch (error) {
      _errorMessage = '$error';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<ClassRequirementGroup> addClass(ClassRequirementGroup group) async {
    if (group.gradeLevelId <= 0) {
      throw ArgumentError('Select a valid class');
    }
    return _runMutation(() async {
      final saved = await _api.createClassRequirement(
        customSchoolId: customSchoolId,
        academicTermId: academicTermId,
        gradeLevelId: group.gradeLevelId,
      );
      _replaceGroup(saved);
      return saved;
    });
  }

  @override
  Future<ClassRequirementGroup> addRequirement(
    String classGroupId,
    ClassRequirementItem item,
  ) {
    final group = _findGroup(classGroupId);
    return _saveItems(group, [...group.items, item]);
  }

  @override
  Future<ClassRequirementGroup> updateRequirement(
    String classGroupId,
    ClassRequirementItem item,
  ) {
    final group = _findGroup(classGroupId);
    return _saveItems(
      group,
      group.items
          .map((current) => current.id == item.id ? item : current)
          .toList(),
    );
  }

  @override
  Future<ClassRequirementGroup> deleteRequirement(
    String classGroupId,
    String requirementId,
  ) {
    final group = _findGroup(classGroupId);
    return _saveItems(
      group,
      group.items.where((item) => item.id != requirementId).toList(),
    );
  }

  @override
  Future<ClassRequirementGroup> publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  ) async {
    final group = _findGroup(classGroupId);
    final requirementId = int.tryParse(group.id);
    if (requirementId == null) {
      throw StateError('The class checklist has not been saved');
    }
    return _runMutation(() async {
      final published = await _api.publishClassRequirement(
        customSchoolId: customSchoolId,
        requirementId: requirementId,
      );
      _lastNotificationPlan = notificationPlan;
      _replaceGroup(published, previousId: group.id);
      if (published.id != group.id) {
        final currentStudents = _studentsByClass[group.id];
        final updated = Map<String, List<StudentRequirementProgress>>.from(
          _studentsByClass,
        )..remove(group.id);
        if (currentStudents != null) {
          updated[published.id] = currentStudents;
        }
        _studentsByClass = updated;
      }
      await loadStudentsForClass(published.id);
      return published;
    });
  }

  Future<ClassRequirementGroup> _saveItems(
    ClassRequirementGroup group,
    List<ClassRequirementItem> items,
  ) async {
    final requirementId = int.tryParse(group.id);
    if (requirementId == null) {
      throw StateError('The class checklist has not been saved');
    }
    return _runMutation(() async {
      final saved = await _api.updateClassRequirement(
        customSchoolId: customSchoolId,
        requirementId: requirementId,
        items: items,
      );
      _replaceGroup(saved, previousId: group.id);
      return saved;
    });
  }

  Future<ClassRequirementGroup> _runMutation(
    Future<ClassRequirementGroup> Function() action,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _errorMessage = '$error';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _replaceGroup(ClassRequirementGroup replacement, {String? previousId}) {
    final matchId = previousId ?? replacement.id;
    final index = _groups.indexWhere(
      (group) =>
          group.id == matchId ||
          (replacement.gradeLevelId > 0 &&
              group.gradeLevelId == replacement.gradeLevelId),
    );
    if (index < 0) {
      _groups = [..._groups, replacement];
      return;
    }
    final updated = [..._groups];
    updated[index] = replacement;
    _groups = updated;
  }

  ClassRequirementGroup _findGroup(String id) {
    return _groups.firstWhere(
      (group) => group.id == id,
      orElse: () => throw StateError('Class checklist is no longer available'),
    );
  }

  @override
  void publishChanges(RequirementNotificationPlan notificationPlan) {
    throw UnsupportedError('Publish each class checklist separately');
  }

  @override
  Future<void> recordPriorTermReceived({
    required String requirementId,
    required int quantity,
    required String notes,
  }) async {
    await _resolvePriorTerm(
      requirementId: requirementId,
      action: 'RECEIVED',
      quantity: quantity,
      notes: notes,
      notifyGuardian: false,
    );
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
  }) async {
    final current = _priorTermRequirements.firstWhere(
      (item) => item.id == requirementId,
      orElse: () => throw StateError('Prior-term requirement is unavailable'),
    );
    final action = switch (status) {
      PriorTermRequirementStatus.carriedForward =>
        carriedQuantity != null && carriedQuantity != current.remainingQuantity
            ? 'ADJUST_AND_CARRY'
            : 'CARRY_ITEM_FORWARD',
      PriorTermRequirementStatus.convertedToCash => 'CONVERT_TO_CASH',
      PriorTermRequirementStatus.waived => 'WAIVE',
      PriorTermRequirementStatus.writtenOff => 'WRITE_OFF',
      PriorTermRequirementStatus.fulfilled => 'RECEIVED',
      PriorTermRequirementStatus.pending => throw ArgumentError(
        'Select a final resolution action',
      ),
    };
    await _resolvePriorTerm(
      requirementId: requirementId,
      action: action,
      quantity: carriedQuantity,
      cashAmount: convertedCashAmount,
      dueDate: carriedDueDate,
      notes: notes,
      notifyGuardian: notifyGuardian,
    );
  }

  Future<void> _resolvePriorTerm({
    required String requirementId,
    required String action,
    int? quantity,
    double? cashAmount,
    DateTime? dueDate,
    required String notes,
    required bool notifyGuardian,
  }) async {
    final id = int.tryParse(requirementId);
    if (id == null) {
      throw StateError('The prior-term requirement has not been saved');
    }
    await _runStudentMutation(() async {
      final updated = await _api.resolvePriorTermRequirement(
        customSchoolId: customSchoolId,
        requirementId: id,
        action: action,
        quantity: quantity,
        cashAmount: cashAmount,
        dueDate: dueDate,
        notes: notes,
        notifyGuardian: notifyGuardian,
      );
      final index = _priorTermRequirements.indexWhere(
        (item) => item.id == requirementId,
      );
      if (index < 0) {
        _priorTermRequirements = [..._priorTermRequirements, updated];
      } else {
        final values = [..._priorTermRequirements];
        values[index] = updated;
        _priorTermRequirements = values;
      }
    });
  }

  @override
  Future<void> recordReceived({
    required String studentId,
    required String requirementId,
    required int quantity,
  }) async {
    final itemId = int.tryParse(requirementId);
    if (itemId == null) {
      throw StateError('The requirement item has not been saved');
    }
    await _runStudentMutation(() async {
      final updated = await _api.recordRequirementReceived(
        customSchoolId: customSchoolId,
        customStudentId: studentId,
        itemId: itemId,
        receivedQuantity: quantity,
      );
      _replaceStudentProgress(updated);
    });
  }

  @override
  Future<void> adjustRequirement({
    required String studentId,
    required String requirementId,
    required StudentRequirementAdjustment adjustment,
  }) async {
    final itemId = int.tryParse(requirementId);
    if (itemId == null) {
      throw StateError('The requirement item has not been saved');
    }
    await _runStudentMutation(() async {
      final updated = await _api.adjustStudentRequirement(
        customSchoolId: customSchoolId,
        customStudentId: studentId,
        itemId: itemId,
        adjustment: adjustment,
      );
      _replaceStudentProgress(updated);
    });
  }

  @override
  Future<void> addStudentRequirement({
    required String studentId,
    required StudentCustomRequirement requirement,
  }) async {
    await _runStudentMutation(() async {
      final updated = await _api.addStudentCustomRequirement(
        customSchoolId: customSchoolId,
        customStudentId: studentId,
        academicTermId: academicTermId,
        requirement: requirement,
      );
      _replaceStudentProgress(updated);
    });
  }

  Future<void> _runStudentMutation(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = '$error';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _replaceStudentProgress(StudentRequirementProgress replacement) {
    final classGroupId = replacement.classGroupId;
    final current = <StudentRequirementProgress>[
      ...(_studentsByClass[classGroupId] ??
          const <StudentRequirementProgress>[]),
    ];
    final index = current.indexWhere((student) => student.id == replacement.id);
    if (index < 0) {
      current.add(replacement);
    } else {
      current[index] = replacement;
    }
    _studentsByClass = {..._studentsByClass, classGroupId: current};
  }
}
