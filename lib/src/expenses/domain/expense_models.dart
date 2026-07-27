class ExpenseLookup {
  const ExpenseLookup({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.symbol,
  });

  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? symbol;

  factory ExpenseLookup.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'] ?? json['categoryId'] ?? json['paymentMethodId'];
    final nameValue =
        json['name'] ?? json['code'] ?? json['status'] ?? json['label'];
    return ExpenseLookup(
      id: _intValue(idValue),
      name: '${nameValue ?? ''}'.trim(),
      code: _stringValue(json['code'] ?? json['category']),
      description: _stringValue(json['description']),
      symbol: _stringValue(json['symbol']),
    );
  }

  static ExpenseLookup fromStatus(String value) {
    return ExpenseLookup(id: value.hashCode, name: value);
  }
}

class ExpenseDocument {
  const ExpenseDocument({
    this.id,
    required this.fileName,
    this.fileType,
    this.uploadedBy,
    this.uploadedAt,
    this.url,
  });

  final int? id;
  final String fileName;
  final String? fileType;
  final String? uploadedBy;
  final DateTime? uploadedAt;
  final String? url;

  factory ExpenseDocument.fromJson(Map<String, dynamic> json) {
    return ExpenseDocument(
      id: _nullableInt(json['id'] ?? json['documentId']),
      fileName: _stringValue(json['fileName'] ?? json['name']) ?? 'Document',
      fileType: _stringValue(json['fileType'] ?? json['contentType']),
      uploadedBy: _stringValue(json['uploadedBy']),
      uploadedAt: _dateTimeValue(json['uploadedAt']),
      url: _stringValue(json['url'] ?? json['documentUrl'] ?? json['fileUrl']),
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.expenseId,
    required this.description,
    required this.amount,
    required this.status,
    this.customSchoolId,
    this.date,
    this.currencyCode,
    this.category,
    this.paymentMethod,
    this.vendorPayee,
    this.receiptNumber,
    this.department,
    this.approvedBy,
    this.enteredBy,
    this.createdAt,
    this.updatedAt,
    this.documents = const [],
  });

  final String expenseId;
  final String? customSchoolId;
  final DateTime? date;
  final double amount;
  final String? currencyCode;
  final String? category;
  final String description;
  final String? paymentMethod;
  final String? vendorPayee;
  final String? receiptNumber;
  final String? department;
  final String status;
  final String? approvedBy;
  final String? enteredBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ExpenseDocument> documents;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    final docs = json['attachedDocuments'] ?? json['documents'];
    return ExpenseRecord(
      expenseId: '${json['expenseId'] ?? json['id'] ?? ''}'.trim(),
      customSchoolId: _stringValue(json['customSchoolId']),
      date: _dateTimeValue(json['date']),
      amount: _doubleValue(json['amount']),
      currencyCode: _stringValue(json['currencyCode']),
      category: _stringValue(json['category']),
      description: _stringValue(json['description']) ?? 'Expense',
      paymentMethod: _stringValue(json['paymentMethod']),
      vendorPayee: _stringValue(json['vendorPayee']),
      receiptNumber: _stringValue(json['receiptNumber']),
      department: _stringValue(json['department']),
      status: (_stringValue(json['status']) ?? 'PENDING').toUpperCase(),
      approvedBy: _stringValue(json['approvedBy']),
      enteredBy: _stringValue(json['enteredBy']),
      createdAt: _dateTimeValue(json['createdAt']),
      updatedAt: _dateTimeValue(json['updatedAt']),
      documents: docs is List
          ? docs
                .whereType<Map>()
                .map((item) => ExpenseDocument.fromJson(item.cast()))
                .toList()
          : const [],
    );
  }
}

class ExpensePage {
  const ExpensePage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
  });

  final List<ExpenseRecord> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;

  factory ExpensePage.fromJson(dynamic decoded) {
    if (decoded is List) {
      final records = decoded
          .whereType<Map>()
          .map((item) => ExpenseRecord.fromJson(item.cast()))
          .toList();
      return ExpensePage(
        content: records,
        page: 0,
        size: records.length,
        totalPages: 1,
        totalElements: records.length,
      );
    }

    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final content = map['content'] ?? map['data']?['content'] ?? map['data'];
    final records = content is List
        ? content
              .whereType<Map>()
              .map((item) => ExpenseRecord.fromJson(item.cast()))
              .toList()
        : <ExpenseRecord>[];
    return ExpensePage(
      content: records,
      page: _intValue(map['number'] ?? map['currentPage']),
      size: _intValue(map['size'] ?? map['pageSize'] ?? records.length),
      totalPages: _intValue(map['totalPages'] ?? 1),
      totalElements: _intValue(map['totalElements'] ?? records.length),
    );
  }
}

class ExpenseReferenceData {
  const ExpenseReferenceData({
    required this.categories,
    required this.currencies,
    required this.paymentMethods,
    required this.departments,
    required this.statuses,
  });

  final List<ExpenseLookup> categories;
  final List<ExpenseLookup> currencies;
  final List<ExpenseLookup> paymentMethods;
  final List<ExpenseLookup> departments;
  final List<ExpenseLookup> statuses;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double _doubleValue(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is List && value.length >= 3) {
    return DateTime(
      _intValue(value[0]),
      _intValue(value[1]),
      _intValue(value[2]),
      value.length > 3 ? _intValue(value[3]) : 0,
      value.length > 4 ? _intValue(value[4]) : 0,
      value.length > 5 ? _intValue(value[5]) : 0,
    );
  }
  return DateTime.tryParse('$value');
}
