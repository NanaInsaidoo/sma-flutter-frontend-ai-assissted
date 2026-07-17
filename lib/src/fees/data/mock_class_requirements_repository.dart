import 'package:flutter/foundation.dart';

import '../domain/class_requirement_models.dart';

abstract class ClassRequirementsRepository extends ChangeNotifier {
  List<ClassRequirementGroup> get groups;
  List<StudentRequirementProgress> studentsForClass(String classGroupId);
  int get draftChangeCount;
  int draftChangeCountForClass(String classGroupId);
  RequirementNotificationPlan? get lastNotificationPlan;

  void addClass(ClassRequirementGroup group);
  void addRequirement(String classGroupId, ClassRequirementItem item);
  void updateRequirement(String classGroupId, ClassRequirementItem item);
  void deleteRequirement(String classGroupId, String requirementId);
  void recordReceived({
    required String studentId,
    required String requirementId,
    required int quantity,
  });
  void adjustRequirement({
    required String studentId,
    required String requirementId,
    required StudentRequirementAdjustment adjustment,
  });
  void addStudentRequirement({
    required String studentId,
    required StudentCustomRequirement requirement,
  });
  void publishChanges(RequirementNotificationPlan notificationPlan);
  void publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  );
}

class MockClassRequirementsRepository extends ClassRequirementsRepository {
  MockClassRequirementsRepository() {
    final now = DateTime.now();
    _groups = [
      ClassRequirementGroup(
        id: 'basic-1',
        className: 'Basic 1',
        studentCount: 38,
        status: RequirementStatus.published,
        hasPublishedVersion: true,
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
    _draftChangeCount = 1;
  }

  late List<ClassRequirementGroup> _groups;
  late Map<String, List<StudentRequirementProgress>> _students;
  int _draftChangeCount = 0;
  RequirementNotificationPlan? _lastNotificationPlan;

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
  int get draftChangeCount => _draftChangeCount;

  @override
  RequirementNotificationPlan? get lastNotificationPlan =>
      _lastNotificationPlan;

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
  void addClass(ClassRequirementGroup group) {
    _groups = [..._groups, group];
    _students = {..._students, group.id: const []};
    notifyListeners();
  }

  @override
  void addRequirement(String classGroupId, ClassRequirementItem item) {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        items: [
          ...group.items,
          group.hasPublishedVersion
              ? item.copyWith(updatedSincePublished: true)
              : item,
        ],
        status: RequirementStatus.draft,
        draftChangeCount: group.draftChangeCount + 1,
      );
    }).toList();
    _draftChangeCount++;
    notifyListeners();
  }

  @override
  void updateRequirement(String classGroupId, ClassRequirementItem item) {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      final replacement = group.hasPublishedVersion
          ? item.copyWith(updatedSincePublished: true)
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
  }

  @override
  void deleteRequirement(String classGroupId, String requirementId) {
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
  }

  @override
  void recordReceived({
    required String studentId,
    required String requirementId,
    required int quantity,
  }) {
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
  void adjustRequirement({
    required String studentId,
    required String requirementId,
    required StudentRequirementAdjustment adjustment,
  }) {
    _updateStudent(studentId, (student) {
      return student.copyWith(
        adjustments: {...student.adjustments, requirementId: adjustment},
      );
    });
  }

  @override
  void addStudentRequirement({
    required String studentId,
    required StudentCustomRequirement requirement,
  }) {
    _updateStudent(studentId, (student) {
      return student.copyWith(
        customRequirements: [...student.customRequirements, requirement],
      );
    });
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
                .map((item) => item.copyWith(updatedSincePublished: false))
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
  void publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  ) {
    _groups = _groups.map((group) {
      if (group.id != classGroupId) return group;
      return group.copyWith(
        items: group.items
            .map((item) => item.copyWith(updatedSincePublished: false))
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
  }
}
