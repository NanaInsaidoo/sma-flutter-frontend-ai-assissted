class FeeSummary {
  const FeeSummary({
    required this.totalFees,
    required this.activeFees,
    required this.inactiveFees,
    required this.totalAmount,
    required this.fees,
  });

  final int totalFees;
  final int activeFees;
  final int inactiveFees;
  final double totalAmount;
  final List<SchoolFee> fees;

  factory FeeSummary.fromJson(Map<String, dynamic> json) {
    final rawFees = json['fees'];
    return FeeSummary(
      totalFees: _intValue(json['totalFees']),
      activeFees: _intValue(json['activeFees']),
      inactiveFees: _intValue(json['inactiveFees']),
      totalAmount: _doubleValue(json['totalAmount']),
      fees: rawFees is List
          ? rawFees
                .whereType<Map<String, dynamic>>()
                .map(SchoolFee.fromJson)
                .toList()
          : const [],
    );
  }
}

class SchoolFee {
  const SchoolFee({
    required this.feeId,
    required this.gradeLevelId,
    required this.customSchoolId,
    required this.termId,
    required this.feeName,
    required this.amount,
    required this.category,
    required this.description,
    required this.status,
  });

  final int feeId;
  final int gradeLevelId;
  final String customSchoolId;
  final int termId;
  final String feeName;
  final double amount;
  final String category;
  final String description;
  final String status;

  factory SchoolFee.fromJson(Map<String, dynamic> json) {
    return SchoolFee(
      feeId: _intValue(json['feeId']),
      gradeLevelId: _intValue(json['gradeLevelId']),
      customSchoolId: '${json['customSchoolId'] ?? ''}',
      termId: _intValue(json['termId']),
      feeName: '${json['feeName'] ?? ''}',
      amount: _doubleValue(json['amount']),
      category: '${json['category'] ?? ''}',
      description: '${json['description'] ?? ''}',
      status: '${json['status'] ?? ''}',
    );
  }
}

class FeeCategory {
  const FeeCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory FeeCategory.fromJson(Map<String, dynamic> json) {
    return FeeCategory(
      id: _intValue(json['id'] ?? json['schoolFeeCategoryId']),
      name: '${json['name'] ?? json['categoryName'] ?? ''}',
    );
  }
}

class FeeGradeLevel {
  const FeeGradeLevel({
    required this.id,
    required this.curriculumGradeLevelId,
    required this.name,
  });

  /// School-specific grade-level record ID, used by fee setup and requirements.
  final int id;

  /// Shared curriculum grade ID, used by student and reporting filters.
  final int curriculumGradeLevelId;
  final String name;

  factory FeeGradeLevel.fromJson(Map<String, dynamic> json) {
    final nested = json['gradeLevel'];
    final source = nested is Map<String, dynamic> ? nested : json;
    final schoolGradeLevelId = _intValue(
      json['id'] ??
          source['schoolGradeLevelId'] ??
          source['id'] ??
          source['gradeLevelId'],
    );
    return FeeGradeLevel(
      id: schoolGradeLevelId,
      curriculumGradeLevelId: _intValue(
        json['gradeLevelId'] ??
            source['gradeLevelId'] ??
            (nested is Map<String, dynamic> ? source['id'] : null) ??
            schoolGradeLevelId,
      ),
      name:
          '${source['name'] ?? source['gradeName'] ?? source['gradeLevelName'] ?? json['gradeName'] ?? ''}',
    );
  }
}

class CurrentAcademicTerm {
  const CurrentAcademicTerm({required this.id, required this.name});

  final int id;
  final String name;

  factory CurrentAcademicTerm.fromJson(Map<String, dynamic> json) {
    final academicTerm = json['academicTerm'];
    final termSource = academicTerm is Map<String, dynamic>
        ? academicTerm
        : json;
    final termType = termSource['termType'];
    final academicYear = json['academicYear'];
    final termName = termType is Map<String, dynamic>
        ? '${termType['name'] ?? termType['termName'] ?? ''}'
        : '${termSource['name'] ?? termSource['termName'] ?? ''}';
    final yearName = academicYear is Map<String, dynamic>
        ? '${academicYear['year'] ?? academicYear['name'] ?? ''}'
        : '';
    final label = [
      if (termName.trim().isNotEmpty) termName.trim(),
      if (yearName.trim().isNotEmpty) yearName.trim(),
    ].join(' · ');
    return CurrentAcademicTerm(
      id: _intValue(termSource['id'] ?? termSource['termId']),
      name: label.isEmpty ? 'Current term' : label,
    );
  }
}

class FeeStudent {
  const FeeStudent({
    required this.customStudentId,
    required this.fullName,
    required this.gradeLevelName,
    required this.streamName,
    required this.status,
  });

  final String customStudentId;
  final String fullName;
  final String gradeLevelName;
  final String streamName;
  final String status;

  factory FeeStudent.fromJson(Map<String, dynamic> json) {
    final firstName = '${json['firstName'] ?? ''}'.trim();
    final middleName = '${json['middleName'] ?? ''}'.trim();
    final lastName = '${json['lastName'] ?? json['LastName'] ?? ''}'.trim();
    final name = [
      if (firstName.isNotEmpty) firstName,
      if (middleName.isNotEmpty) middleName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ');
    return FeeStudent(
      customStudentId:
          '${json['customStudentId'] ?? json['studentId'] ?? json['id'] ?? ''}',
      fullName: name.isEmpty
          ? '${json['name'] ?? json['studentName'] ?? 'Unnamed student'}'
          : name,
      gradeLevelName:
          '${json['gradeLevelName'] ?? json['class'] ?? json['className'] ?? ''}',
      streamName: '${json['streamName'] ?? json['section'] ?? ''}',
      status: '${json['status'] ?? ''}',
    );
  }
}

class FeeAdjustment {
  const FeeAdjustment({
    required this.id,
    required this.customStudentId,
    required this.studentName,
    required this.studentId,
    required this.termId,
    required this.termName,
    required this.feeId,
    required this.feeName,
    required this.adjustmentTypeId,
    required this.adjustmentType,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdByType,
    required this.createdById,
    required this.createdDate,
    required this.updatedByType,
    required this.updatedById,
    required this.updatedDate,
  });

  final int id;
  final String customStudentId;
  final String studentName;
  final int studentId;
  final int termId;
  final String termName;
  final int feeId;
  final String feeName;
  final int adjustmentTypeId;
  final String adjustmentType;
  final double amount;
  final String description;
  final String status;
  final String createdByType;
  final int createdById;
  final DateTime? createdDate;
  final String updatedByType;
  final int updatedById;
  final DateTime? updatedDate;

  factory FeeAdjustment.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final fee = json['fee'];
    final type = json['adjustmentType'];
    return FeeAdjustment(
      id: _intValue(json['id'] ?? json['adjustmentId']),
      customStudentId:
          '${json['customStudentId'] ?? (student is Map ? student['customStudentId'] : '') ?? ''}',
      studentName:
          '${json['studentName'] ?? (student is Map ? student['fullName'] ?? student['name'] : '') ?? ''}',
      studentId: _intValue(json['studentId']),
      termId: _intValue(json['termId']),
      termName: '${json['termName'] ?? ''}',
      feeId: _intValue(json['feeId'] ?? (fee is Map ? fee['feeId'] : null)),
      feeName: '${json['feeName'] ?? (fee is Map ? fee['feeName'] : '') ?? ''}',
      adjustmentTypeId: _intValue(json['adjustmentTypeId']),
      adjustmentType:
          '${type is Map ? type['type'] ?? type['name'] : type ?? ''}',
      amount: _doubleValue(json['amount'] ?? json['adjustmentAmount']),
      description: '${json['description'] ?? json['note'] ?? ''}',
      status: '${json['status'] ?? ''}',
      createdByType: '${json['createdByType'] ?? ''}',
      createdById: _intValue(json['createdById']),
      createdDate: _dateValue(json['createdDate'] ?? json['createdAt']),
      updatedByType: '${json['updatedByType'] ?? ''}',
      updatedById: _intValue(json['updatedById']),
      updatedDate: _dateValue(json['updatedDate'] ?? json['updatedAt']),
    );
  }
}

class FeeAdjustmentsPage {
  const FeeAdjustmentsPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<FeeAdjustment> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  factory FeeAdjustmentsPage.fromJson(Map<String, dynamic> json) {
    final rows = json['content'] is List ? json['content'] as List : const [];
    return FeeAdjustmentsPage(
      content: rows
          .whereType<Map>()
          .map(
            (item) => FeeAdjustment.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      page: _intValue(json['number'] ?? json['page']),
      size: _intValue(json['size']),
      totalElements: _intValue(json['totalElements']),
      totalPages: _intValue(json['totalPages']),
    );
  }
}

class FeeSaveRequest {
  const FeeSaveRequest({
    required this.customSchoolId,
    required this.gradeLevelId,
    required this.termId,
    required this.schoolFeeCategoryId,
    required this.feeName,
    required this.amount,
    required this.description,
    required this.status,
  });

  final String customSchoolId;
  final int gradeLevelId;
  final int termId;
  final int schoolFeeCategoryId;
  final String feeName;
  final double amount;
  final String description;
  final String status;

  Map<String, dynamic> toJson() => {
    'customSchoolId': customSchoolId,
    'gradeLevelId': gradeLevelId,
    'termId': termId,
    'schoolFeeCategoryId': schoolFeeCategoryId,
    'feeName': feeName,
    'amount': amount,
    'description': description.trim().isEmpty ? null : description.trim(),
    'status': status,
  };
}

class FeeManagementOverview {
  const FeeManagementOverview({
    required this.termId,
    required this.termName,
    required this.academicYear,
    required this.totalExpected,
    required this.totalCollected,
    required this.outstanding,
    required this.arrearsPriorTerms,
    required this.totalStudents,
    required this.unpaidOrPartialStudents,
    required this.arrearsStudentCount,
    required this.collectionRate,
    required this.collectionByClass,
    required this.outstandingArrears,
  });

  final int termId;
  final String termName;
  final String academicYear;
  final double totalExpected;
  final double totalCollected;
  final double outstanding;
  final double arrearsPriorTerms;
  final int totalStudents;
  final int unpaidOrPartialStudents;
  final int arrearsStudentCount;
  final double collectionRate;
  final List<FeeClassCollectionSummary> collectionByClass;
  final List<FeeStudentFeeRow> outstandingArrears;

  factory FeeManagementOverview.fromJson(Map<String, dynamic> json) {
    return FeeManagementOverview(
      termId: _intValue(json['termId']),
      termName: '${json['termName'] ?? 'Current term'}',
      academicYear: '${json['academicYear'] ?? ''}',
      totalExpected: _doubleValue(json['totalExpected']),
      totalCollected: _doubleValue(json['totalCollected']),
      outstanding: _doubleValue(json['outstanding']),
      arrearsPriorTerms: _doubleValue(json['arrearsPriorTerms']),
      totalStudents: _intValue(json['totalStudents']),
      unpaidOrPartialStudents: _intValue(json['unpaidOrPartialStudents']),
      arrearsStudentCount: _intValue(json['arrearsStudentCount']),
      collectionRate: _doubleValue(json['collectionRate']),
      collectionByClass:
          (json['collectionByClass'] is List
                  ? json['collectionByClass'] as List
                  : const [])
              .whereType<Map<String, dynamic>>()
              .map(FeeClassCollectionSummary.fromJson)
              .toList(),
      outstandingArrears:
          (json['outstandingArrears'] is List
                  ? json['outstandingArrears'] as List
                  : const [])
              .whereType<Map<String, dynamic>>()
              .map(FeeStudentFeeRow.fromJson)
              .toList(),
    );
  }
}

class FeeStudentFeesPage {
  const FeeStudentFeesPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<FeeStudentFeeRow> content;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  factory FeeStudentFeesPage.fromJson(Map<String, dynamic> json) {
    return FeeStudentFeesPage(
      content: (json['content'] is List ? json['content'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(FeeStudentFeeRow.fromJson)
          .toList(),
      totalElements: _intValue(json['totalElements']),
      totalPages: _intValue(json['totalPages']),
      currentPage: _intValue(json['currentPage']),
      pageSize: _intValue(json['pageSize']),
    );
  }
}

class FeeStudentFeeRow {
  const FeeStudentFeeRow({
    required this.studentId,
    required this.customStudentId,
    required this.studentName,
    required this.gradeLevelId,
    required this.className,
    required this.totalFees,
    required this.totalAdjustments,
    required this.paid,
    required this.balance,
    required this.paymentStatus,
    required this.lastPaymentDate,
  });

  final int studentId;
  final String customStudentId;
  final String studentName;
  final int gradeLevelId;
  final String className;
  final double totalFees;
  final double totalAdjustments;
  final double paid;
  final double balance;
  final String paymentStatus;
  final DateTime? lastPaymentDate;

  factory FeeStudentFeeRow.fromJson(Map<String, dynamic> json) {
    return FeeStudentFeeRow(
      studentId: _intValue(json['studentId']),
      customStudentId: '${json['customStudentId'] ?? ''}',
      studentName: '${json['studentName'] ?? 'Unnamed student'}',
      gradeLevelId: _intValue(json['gradeLevelId']),
      className: '${json['className'] ?? ''}',
      totalFees: _doubleValue(json['totalFees']),
      totalAdjustments: _doubleValue(json['totalAdjustments']),
      paid: _doubleValue(json['paid']),
      balance: _doubleValue(json['balance']),
      paymentStatus: '${json['paymentStatus'] ?? ''}',
      lastPaymentDate: _dateValue(json['lastPaymentDate']),
    );
  }
}

class FeeClassCollectionSummary {
  const FeeClassCollectionSummary({
    required this.gradeLevelId,
    required this.className,
    required this.students,
    required this.expected,
    required this.collected,
    required this.outstanding,
    required this.collectionRate,
  });

  final int gradeLevelId;
  final String className;
  final int students;
  final double expected;
  final double collected;
  final double outstanding;
  final double collectionRate;

  factory FeeClassCollectionSummary.fromJson(Map<String, dynamic> json) {
    return FeeClassCollectionSummary(
      gradeLevelId: _intValue(json['gradeLevelId']),
      className: '${json['className'] ?? ''}',
      students: _intValue(json['students']),
      expected: _doubleValue(json['expected']),
      collected: _doubleValue(json['collected']),
      outstanding: _doubleValue(json['outstanding']),
      collectionRate: _doubleValue(json['collectionRate']),
    );
  }
}

class FeeClassStructure {
  const FeeClassStructure({
    required this.structureId,
    required this.gradeLevelId,
    required this.levelCode,
    required this.fullName,
    required this.studentCount,
    required this.version,
    required this.status,
    required this.totalPerTerm,
    required this.publishedAt,
    required this.feeItems,
  });

  final int structureId;
  final int gradeLevelId;
  final String levelCode;
  final String fullName;
  final int studentCount;
  final int version;
  final String status;
  final double totalPerTerm;
  final DateTime? publishedAt;
  final List<FeeStructureItem> feeItems;

  factory FeeClassStructure.fromJson(Map<String, dynamic> json) {
    return FeeClassStructure(
      structureId: _intValue(json['structureId']),
      gradeLevelId: _intValue(json['gradeLevelId']),
      levelCode: '${json['levelCode'] ?? ''}',
      fullName: '${json['fullName'] ?? ''}',
      studentCount: _intValue(json['studentCount']),
      version: _intValue(json['version']),
      status: '${json['status'] ?? ''}',
      totalPerTerm: _doubleValue(json['totalPerTerm']),
      publishedAt: _dateValue(json['publishedAt']),
      feeItems: (json['feeItems'] is List ? json['feeItems'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(FeeStructureItem.fromJson)
          .toList(),
    );
  }
}

class FeeStructureItem {
  const FeeStructureItem({
    required this.feeId,
    required this.categoryId,
    required this.category,
    required this.feeName,
    required this.amount,
    required this.description,
    required this.status,
    required this.dueDate,
  });

  final int feeId;
  final int categoryId;
  final String category;
  final String feeName;
  final double amount;
  final String description;
  final String status;
  final DateTime? dueDate;

  factory FeeStructureItem.fromJson(Map<String, dynamic> json) {
    final active = json['active'];
    return FeeStructureItem(
      feeId: _intValue(json['itemId'] ?? json['feeId']),
      categoryId: _intValue(json['categoryId']),
      category: '${json['category'] ?? ''}',
      feeName: '${json['feeName'] ?? ''}',
      amount: _doubleValue(json['amount']),
      description: '${json['description'] ?? ''}',
      status: json['status'] == null
          ? (active == false ? 'INACTIVE' : 'ACTIVE')
          : '${json['status']}',
      dueDate: _dateValue(json['dueDate']),
    );
  }

  Map<String, dynamic> toJson() => {
    'feeId': feeId == 0 ? null : feeId,
    'categoryId': categoryId == 0 ? null : categoryId,
    'category': category.trim().isEmpty ? null : category.trim(),
    'feeName': feeName.trim(),
    'amount': amount,
    'description': description.trim().isEmpty ? null : description.trim(),
    'status': status.trim().isEmpty ? 'ACTIVE' : status.trim(),
    'dueDate': dueDate == null ? null : _dateOnly(dueDate!),
  };
}

class FeeWaiverSummary {
  const FeeWaiverSummary({
    required this.adjustmentId,
    required this.waiverType,
    required this.description,
    required this.amount,
    required this.status,
    required this.studentName,
    required this.customStudentId,
    required this.className,
    required this.feeName,
    required this.createdDate,
  });

  final int adjustmentId;
  final String waiverType;
  final String description;
  final double amount;
  final String status;
  final String studentName;
  final String customStudentId;
  final String className;
  final String feeName;
  final DateTime? createdDate;

  factory FeeWaiverSummary.fromJson(Map<String, dynamic> json) {
    return FeeWaiverSummary(
      adjustmentId: _intValue(json['adjustmentId']),
      waiverType: '${json['waiverType'] ?? 'Waiver'}',
      description: '${json['description'] ?? ''}',
      amount: _doubleValue(json['amount']),
      status: '${json['status'] ?? ''}',
      studentName: '${json['studentName'] ?? ''}',
      customStudentId: '${json['customStudentId'] ?? ''}',
      className: '${json['className'] ?? ''}',
      feeName: '${json['feeName'] ?? ''}',
      createdDate: _dateValue(json['createdDate']),
    );
  }
}

class FeeWaiverType {
  const FeeWaiverType({
    required this.id,
    required this.name,
    required this.description,
    required this.valueType,
    required this.defaultValue,
    required this.scope,
    required this.active,
  });

  final int id;
  final String name;
  final String description;
  final String valueType;
  final double defaultValue;
  final String scope;
  final bool active;

  bool get isPercentage => valueType == 'PERCENTAGE';
  bool get appliesToAllFees => scope == 'ALL_FEES';

  factory FeeWaiverType.fromJson(Map<String, dynamic> json) => FeeWaiverType(
    id: _intValue(json['id']),
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    valueType: '${json['valueType'] ?? ''}'.toUpperCase(),
    defaultValue: _doubleValue(json['defaultValue']),
    scope: '${json['scope'] ?? ''}'.toUpperCase(),
    active: json['active'] != false,
  );
}

class FeeWaiverAssessment {
  const FeeWaiverAssessment({
    required this.assessmentId,
    required this.feeName,
    required this.amount,
  });

  final int assessmentId;
  final String feeName;
  final double amount;

  factory FeeWaiverAssessment.fromJson(Map<String, dynamic> json) =>
      FeeWaiverAssessment(
        assessmentId: _intValue(json['assessmentId']),
        feeName: '${json['feeName'] ?? ''}',
        amount: _doubleValue(json['amount']),
      );
}

class FeeWaiverAssignment {
  const FeeWaiverAssignment({
    required this.id,
    required this.academicTermId,
    required this.customStudentId,
    required this.studentName,
    required this.className,
    required this.waiverTypeId,
    required this.waiverType,
    required this.valueType,
    required this.value,
    required this.scope,
    required this.eligibleAmount,
    required this.waivedAmount,
    required this.reason,
    required this.status,
    required this.assessments,
    required this.createdAt,
  });

  final int id;
  final int academicTermId;
  final String customStudentId;
  final String studentName;
  final String className;
  final int waiverTypeId;
  final String waiverType;
  final String valueType;
  final double value;
  final String scope;
  final double eligibleAmount;
  final double waivedAmount;
  final String reason;
  final String status;
  final List<FeeWaiverAssessment> assessments;
  final DateTime? createdAt;

  factory FeeWaiverAssignment.fromJson(Map<String, dynamic> json) =>
      FeeWaiverAssignment(
        id: _intValue(json['id']),
        academicTermId: _intValue(json['academicTermId']),
        customStudentId: '${json['customStudentId'] ?? ''}',
        studentName: '${json['studentName'] ?? ''}',
        className: '${json['className'] ?? ''}',
        waiverTypeId: _intValue(json['waiverTypeId']),
        waiverType: '${json['waiverType'] ?? ''}',
        valueType: '${json['valueType'] ?? ''}'.toUpperCase(),
        value: _doubleValue(json['value']),
        scope: '${json['scope'] ?? ''}'.toUpperCase(),
        eligibleAmount: _doubleValue(json['eligibleAmount']),
        waivedAmount: _doubleValue(json['waivedAmount']),
        reason: '${json['reason'] ?? ''}',
        status: '${json['status'] ?? ''}'.toUpperCase(),
        assessments:
            (json['assessments'] is List
                    ? json['assessments'] as List
                    : const [])
                .whereType<Map<String, dynamic>>()
                .map(FeeWaiverAssessment.fromJson)
                .toList(),
        createdAt: _dateValue(json['createdAt']),
      );
}

class FeePaymentMethod {
  const FeePaymentMethod({
    required this.id,
    required this.method,
    required this.description,
  });

  final int id;
  final String method;
  final String description;

  factory FeePaymentMethod.fromJson(Map<String, dynamic> json) {
    return FeePaymentMethod(
      id: _intValue(json['id']),
      method: '${json['method'] ?? json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
    );
  }
}

class FeePaymentRequest {
  const FeePaymentRequest({
    required this.customStudentId,
    required this.customSchoolId,
    required this.payerName,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethodId,
    required this.referenceNumber,
    required this.receivedBy,
    required this.description,
    required this.termId,
    required this.physicalReceiptNumber,
    this.receiptPhotoBytes,
    this.receiptPhotoFileName,
  });

  final String customStudentId;
  final String customSchoolId;
  final String payerName;
  final double amount;
  final DateTime paymentDate;
  final int paymentMethodId;
  final String referenceNumber;
  final String receivedBy;
  final String description;
  final int termId;
  final String physicalReceiptNumber;
  final List<int>? receiptPhotoBytes;
  final String? receiptPhotoFileName;
}

class FeePaymentReceipt {
  const FeePaymentReceipt({
    required this.receiptNumber,
    required this.studentName,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
  });

  final String receiptNumber;
  final String studentName;
  final double amount;
  final String paymentMethod;
  final DateTime? paymentDate;

  factory FeePaymentReceipt.fromJson(Map<String, dynamic> json) {
    return FeePaymentReceipt(
      receiptNumber:
          '${json['receiptNumber'] ?? json['paymentReference'] ?? ''}',
      studentName: '${json['studentName'] ?? ''}',
      amount: _doubleValue(json['amount']),
      paymentMethod: '${json['paymentMethod'] ?? ''}',
      paymentDate: _dateValue(json['paymentDate']),
    );
  }
}

class FeeStudentAccount {
  const FeeStudentAccount({
    required this.termId,
    required this.termName,
    required this.academicYear,
    required this.customStudentId,
    required this.studentName,
    required this.className,
    required this.totalFees,
    required this.totalAdjustments,
    required this.totalExpected,
    required this.totalPaid,
    required this.balance,
    required this.paymentStatus,
    required this.assessments,
    required this.adjustments,
    required this.payments,
  });

  final int termId;
  final String termName;
  final String academicYear;
  final String customStudentId;
  final String studentName;
  final String className;
  final double totalFees;
  final double totalAdjustments;
  final double totalExpected;
  final double totalPaid;
  final double balance;
  final String paymentStatus;
  final List<FeeAssessmentLine> assessments;
  final List<FeeAccountAdjustment> adjustments;
  final List<FeeStudentPayment> payments;

  factory FeeStudentAccount.fromJson(Map<String, dynamic> json) {
    return FeeStudentAccount(
      termId: _intValue(json['termId']),
      termName: '${json['termName'] ?? ''}',
      academicYear: '${json['academicYear'] ?? ''}',
      customStudentId: '${json['customStudentId'] ?? ''}',
      studentName: '${json['studentName'] ?? ''}',
      className: '${json['className'] ?? ''}',
      totalFees: _doubleValue(json['totalFees']),
      totalAdjustments: _doubleValue(json['totalAdjustments']),
      totalExpected: _doubleValue(json['totalExpected']),
      totalPaid: _doubleValue(json['totalPaid']),
      balance: _doubleValue(json['balance']),
      paymentStatus: '${json['paymentStatus'] ?? ''}',
      assessments:
          (json['assessments'] is List ? json['assessments'] as List : const [])
              .whereType<Map<String, dynamic>>()
              .map(FeeAssessmentLine.fromJson)
              .toList(),
      adjustments:
          (json['adjustments'] is List ? json['adjustments'] as List : const [])
              .whereType<Map<String, dynamic>>()
              .map(FeeAccountAdjustment.fromJson)
              .toList(),
      payments: (json['payments'] is List ? json['payments'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(FeeStudentPayment.fromJson)
          .toList(),
    );
  }
}

class FeeAssessmentLine {
  const FeeAssessmentLine({
    required this.assessmentId,
    required this.itemKey,
    required this.feeName,
    required this.categoryName,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  final int assessmentId;
  final String itemKey;
  final String feeName;
  final String categoryName;
  final String description;
  final double amount;
  final DateTime? dueDate;
  final String status;

  factory FeeAssessmentLine.fromJson(Map<String, dynamic> json) {
    return FeeAssessmentLine(
      assessmentId: _intValue(json['assessmentId']),
      itemKey: '${json['itemKey'] ?? ''}',
      feeName: '${json['feeName'] ?? 'Fee item'}',
      categoryName: '${json['categoryName'] ?? ''}',
      description: '${json['description'] ?? ''}',
      amount: _doubleValue(json['amount']),
      dueDate: _dateValue(json['dueDate']),
      status: '${json['status'] ?? ''}',
    );
  }
}

class FeeAccountAdjustment {
  const FeeAccountAdjustment({
    required this.adjustmentId,
    required this.adjustmentType,
    required this.feeName,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdDate,
  });

  final int adjustmentId;
  final String adjustmentType;
  final String feeName;
  final String description;
  final double amount;
  final String status;
  final DateTime? createdDate;

  factory FeeAccountAdjustment.fromJson(Map<String, dynamic> json) {
    return FeeAccountAdjustment(
      adjustmentId: _intValue(json['adjustmentId']),
      adjustmentType: '${json['adjustmentType'] ?? 'Adjustment'}',
      feeName: '${json['feeName'] ?? ''}',
      description: '${json['description'] ?? ''}',
      amount: _doubleValue(json['amount']),
      status: '${json['status'] ?? ''}',
      createdDate: _dateValue(json['createdDate']),
    );
  }
}

class FeeStudentPayment {
  const FeeStudentPayment({
    required this.id,
    required this.amount,
    required this.netAmount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.referenceNumber,
    required this.receivedBy,
    required this.termId,
    required this.status,
  });

  final int id;
  final double amount;
  final double netAmount;
  final DateTime? paymentDate;
  final String paymentMethod;
  final String referenceNumber;
  final String receivedBy;
  final int termId;
  final String status;

  factory FeeStudentPayment.fromJson(Map<String, dynamic> json) {
    return FeeStudentPayment(
      id: _intValue(json['id'] ?? json['paymentId']),
      amount: _doubleValue(json['amount']),
      netAmount: _doubleValue(json['netAmount'] ?? json['amount']),
      paymentDate: _dateValue(json['paymentDate']),
      paymentMethod:
          '${json['paymentMethodName'] ?? json['paymentMethod'] ?? ''}',
      referenceNumber: '${json['referenceNumber'] ?? ''}',
      receivedBy: '${json['receivedBy'] ?? ''}',
      termId: _intValue(json['termId']),
      status: '${json['status'] ?? ''}',
    );
  }
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is List && value.length >= 3) {
    final year = _intValue(value[0]);
    final month = _intValue(value[1]);
    final day = _intValue(value[2]);
    if (year > 0 && month > 0 && day > 0) {
      final hour = value.length > 3 ? _intValue(value[3]) : 0;
      final minute = value.length > 4 ? _intValue(value[4]) : 0;
      final second = value.length > 5 ? _intValue(value[5]) : 0;
      return DateTime(year, month, day, hour, minute, second);
    }
  }
  return null;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
