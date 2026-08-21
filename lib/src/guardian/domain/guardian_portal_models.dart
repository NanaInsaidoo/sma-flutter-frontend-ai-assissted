class GuardianPortalSnapshot {
  const GuardianPortalSnapshot({
    required this.guardianName,
    required this.email,
    required this.phoneNumber,
    required this.schoolName,
    required this.academicYear,
    required this.termName,
    required this.termId,
    required this.academicYearId,
    required this.totalBalance,
    required this.children,
    required this.calendarEvents,
  });

  final String guardianName;
  final String email;
  final String phoneNumber;
  final String schoolName;
  final String academicYear;
  final String termName;
  final int termId;
  final int academicYearId;
  final double totalBalance;
  final List<GuardianChildSummary> children;
  final List<GuardianCalendarEvent> calendarEvents;

  factory GuardianPortalSnapshot.fromJson(Map<String, dynamic> json) {
    return GuardianPortalSnapshot(
      guardianName: _text(json['guardianName']),
      email: _text(json['email']),
      phoneNumber: _text(json['phoneNumber']),
      schoolName: _text(json['schoolName']),
      academicYear: _text(json['academicYear']),
      termName: _text(json['termName']),
      termId: _integer(json['termId']),
      academicYearId: _integer(json['academicYearId']),
      totalBalance: _number(json['totalBalance']),
      children: _list(json['children'])
          .map((item) => GuardianChildSummary.fromJson(_map(item)))
          .toList(growable: false),
      calendarEvents: _list(json['calendarEvents'])
          .map((item) => GuardianCalendarEvent.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class GuardianCalendarEvent {
  const GuardianCalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.schoolDay,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final bool schoolDay;

  factory GuardianCalendarEvent.fromJson(Map<String, dynamic> json) =>
      GuardianCalendarEvent(
        id: _integer(json['id']),
        title: _text(json['title']),
        description: _text(json['description']),
        category: _text(json['category']),
        startDate: _dateText(json['startDate']),
        endDate: _dateText(json['endDate']),
        startTime: _text(json['startTime']),
        endTime: _text(json['endTime']),
        schoolDay: json['schoolDay'] != false,
      );
}

class GuardianChildSummary {
  const GuardianChildSummary({
    required this.studentId,
    required this.name,
    required this.gradeLevel,
    required this.stream,
    required this.totalFees,
    required this.totalPaid,
    required this.balance,
    required this.termAverage,
    required this.attendanceDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.excusedDays,
    required this.attendancePercentage,
    required this.reportPublished,
    required this.reportCurrent,
  });

  final String studentId;
  final String name;
  final String gradeLevel;
  final String stream;
  final double totalFees;
  final double totalPaid;
  final double balance;
  final double? termAverage;
  final int attendanceDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int excusedDays;
  final double attendancePercentage;
  final bool reportPublished;
  final bool reportCurrent;

  String get className {
    if (stream.isEmpty || stream == 'Not assigned') return gradeLevel;
    return stream.toLowerCase().contains(gradeLevel.toLowerCase())
        ? stream
        : '$gradeLevel · $stream';
  }

  factory GuardianChildSummary.fromJson(Map<String, dynamic> json) {
    return GuardianChildSummary(
      studentId: _text(json['customStudentId']),
      name: _text(json['studentName']),
      gradeLevel: _text(json['gradeLevel']),
      stream: _text(json['stream']),
      totalFees: _number(json['totalFees']),
      totalPaid: _number(json['totalPaid']),
      balance: _number(json['balance']),
      termAverage: json['termAverage'] == null
          ? null
          : _number(json['termAverage']),
      attendanceDays: _integer(json['attendanceDays']),
      presentDays: _integer(json['presentDays']),
      absentDays: _integer(json['absentDays']),
      lateDays: _integer(json['lateDays']),
      excusedDays: _integer(json['excusedDays']),
      attendancePercentage: _number(json['attendancePercentage']),
      reportPublished: json['reportPublished'] == true,
      reportCurrent: json['reportCurrent'] == true,
    );
  }
}

class GuardianAcademicData {
  const GuardianAcademicData({
    required this.subjects,
    required this.activities,
  });
  final List<GuardianSubjectPerformance> subjects;
  final List<GuardianAcademicActivity> activities;
  factory GuardianAcademicData.fromJson(Map<String, dynamic> json) =>
      GuardianAcademicData(
        subjects: _list(json['subjects'])
            .map((item) => GuardianSubjectPerformance.fromJson(_map(item)))
            .toList(growable: false),
        activities: _list(json['activities'])
            .map((item) => GuardianAcademicActivity.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class GuardianSubjectPerformance {
  const GuardianSubjectPerformance({
    required this.subjectName,
    required this.currentAverage,
    required this.releasedScoreCount,
    required this.scores,
  });
  final String subjectName;
  final double? currentAverage;
  final int releasedScoreCount;
  final List<GuardianReleasedScore> scores;
  factory GuardianSubjectPerformance.fromJson(Map<String, dynamic> json) =>
      GuardianSubjectPerformance(
        subjectName: _text(json['subjectName']),
        currentAverage: json['currentAverage'] is num
            ? (json['currentAverage'] as num).toDouble()
            : null,
        releasedScoreCount: _integer(json['releasedScoreCount']),
        scores: _list(json['scores'])
            .map((item) => GuardianReleasedScore.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class GuardianReleasedScore {
  const GuardianReleasedScore({
    required this.title,
    required this.type,
    required this.date,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.remarks,
  });
  final String title;
  final String type;
  final String date;
  final double? score;
  final double? maxScore;
  final double? percentage;
  final String remarks;
  factory GuardianReleasedScore.fromJson(Map<String, dynamic> json) =>
      GuardianReleasedScore(
        title: _text(json['title']),
        type: _text(json['type']),
        date: _dateText(json['date']),
        score: json['score'] is num ? (json['score'] as num).toDouble() : null,
        maxScore: json['maxScore'] is num
            ? (json['maxScore'] as num).toDouble()
            : null,
        percentage: json['percentage'] is num
            ? (json['percentage'] as num).toDouble()
            : null,
        remarks: _text(json['remarks']),
      );
}

class GuardianAcademicActivity {
  const GuardianAcademicActivity({
    required this.subjectName,
    required this.title,
    required this.description,
    required this.type,
    required this.dueDate,
    required this.status,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.remarks,
  });
  final String subjectName;
  final String title;
  final String description;
  final String type;
  final String dueDate;
  final String status;
  final double? score;
  final double? maxScore;
  final double? percentage;
  final String remarks;
  factory GuardianAcademicActivity.fromJson(Map<String, dynamic> json) =>
      GuardianAcademicActivity(
        subjectName: _text(json['subjectName']),
        title: _text(json['title']),
        description: _text(json['description']),
        type: _text(json['type']),
        dueDate: _dateText(json['dueDate']),
        status: _text(json['status']),
        score: json['score'] is num ? (json['score'] as num).toDouble() : null,
        maxScore: json['maxScore'] is num
            ? (json['maxScore'] as num).toDouble()
            : null,
        percentage: json['percentage'] is num
            ? (json['percentage'] as num).toDouble()
            : null,
        remarks: _text(json['remarks']),
      );
}

class GuardianStudentRequirements {
  const GuardianStudentRequirements({
    required this.studentId,
    required this.studentName,
    required this.academicTermId,
    required this.items,
  });
  final String studentId;
  final String studentName;
  final int academicTermId;
  final List<GuardianRequiredItem> items;
  factory GuardianStudentRequirements.fromJson(Map<String, dynamic> json) =>
      GuardianStudentRequirements(
        studentId: _text(json['studentId']),
        studentName: _text(json['studentName']),
        academicTermId: _integer(json['academicTermId']),
        items: _list(json['items'])
            .map((item) => GuardianRequiredItem.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class GuardianRequiredItem {
  const GuardianRequiredItem({
    required this.id,
    required this.name,
    required this.category,
    required this.requiredQuantity,
    required this.receivedQuantity,
    required this.unit,
    required this.estimatedUnitPrice,
    required this.dueDate,
    required this.instructions,
    required this.optional,
    required this.status,
    required this.notes,
  });
  final int id;
  final String name;
  final String category;
  final int requiredQuantity;
  final int receivedQuantity;
  final String unit;
  final double estimatedUnitPrice;
  final String dueDate;
  final String instructions;
  final bool optional;
  final String status;
  final String notes;
  bool get complete =>
      status.toUpperCase() == 'FULFILLED' ||
      status.toUpperCase() == 'WAIVED' ||
      status.toUpperCase() == 'CASH_EQUIVALENT';
  factory GuardianRequiredItem.fromJson(Map<String, dynamic> json) =>
      GuardianRequiredItem(
        id: _integer(json['id']),
        name: _text(json['name']),
        category: _text(json['category']),
        requiredQuantity: _integer(json['requiredQuantity']),
        receivedQuantity: _integer(json['receivedQuantity']),
        unit: _text(json['unit']),
        estimatedUnitPrice: _number(json['estimatedUnitPrice']),
        dueDate: _dateText(json['dueDate']),
        instructions: _text(json['instructions']),
        optional: json['optional'] == true,
        status: _text(json['status']),
        notes: _text(json['notes']),
      );
}

class GuardianProfile {
  const GuardianProfile({
    required this.title,
    required this.guardianName,
    required this.dateOfBirth,
    required this.email,
    required this.phoneNumber,
    required this.phoneNumbers,
    required this.workPhoneNumber,
    required this.emailAddresses,
    required this.residentialAddress,
    required this.nationalities,
    required this.languages,
    required this.religion,
    required this.occupations,
    required this.skills,
    required this.socialAccounts,
    required this.proofOfIdType,
    required this.proofOfIdNumber,
    required this.emailNotifications,
    required this.smsNotifications,
  });
  final String title;
  final String guardianName;
  final String dateOfBirth;
  final String email;
  final String phoneNumber;
  final List<String> phoneNumbers;
  final String workPhoneNumber;
  final List<String> emailAddresses;
  final String residentialAddress;
  final List<String> nationalities;
  final List<String> languages;
  final String religion;
  final List<String> occupations;
  final List<String> skills;
  final List<GuardianSocialAccount> socialAccounts;
  final String proofOfIdType;
  final String proofOfIdNumber;
  final bool emailNotifications;
  final bool smsNotifications;
  factory GuardianProfile.fromJson(Map<String, dynamic> json) =>
      GuardianProfile(
        title: _text(json['title']),
        guardianName: _text(json['guardianName']),
        dateOfBirth: _text(json['dateOfBirth']),
        email: _text(json['email']),
        phoneNumber: _text(json['phoneNumber']),
        phoneNumbers: _list(
          json['phoneNumbers'],
        ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
        workPhoneNumber: _text(json['workPhoneNumber']),
        emailAddresses: _list(
          json['emailAddresses'],
        ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
        residentialAddress: _text(json['residentialAddress']),
        nationalities: _list(
          json['nationalities'],
        ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
        languages: _list(
          json['languages'],
        ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
        religion: _text(json['religion']),
        occupations: _list(
          json['occupations'],
        ).map(_text).where((v) => v.isNotEmpty).toList(),
        skills: _list(
          json['skills'],
        ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
        socialAccounts: _list(json['socialAccounts'])
            .map((item) => GuardianSocialAccount.fromJson(_map(item)))
            .toList(growable: false),
        proofOfIdType: _text(json['proofOfIdType']),
        proofOfIdNumber: _text(json['proofOfIdNumber']),
        emailNotifications: json['emailNotifications'] == true,
        smsNotifications: json['smsNotifications'] == true,
      );
}

class GuardianSocialAccount {
  const GuardianSocialAccount({required this.platform, required this.account});
  final String platform;
  final String account;
  factory GuardianSocialAccount.fromJson(Map<String, dynamic> json) =>
      GuardianSocialAccount(
        platform: _text(json['platform']),
        account: _text(json['account']),
      );
}

class HouseholdGuardian {
  const HouseholdGuardian({
    required this.guardianId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.primary,
    required this.blocked,
    required this.canManage,
  });
  final String guardianId;
  final String name;
  final String email;
  final String phoneNumber;
  final bool primary;
  final bool blocked;
  final bool canManage;
  factory HouseholdGuardian.fromJson(Map<String, dynamic> json) =>
      HouseholdGuardian(
        guardianId: _text(json['guardianId']),
        name: _text(json['name']),
        email: _text(json['email']),
        phoneNumber: _text(json['phoneNumber']),
        primary: json['primary'] == true,
        blocked: json['blocked'] == true,
        canManage: json['canManage'] == true,
      );
}

class GuardianChildDetails {
  const GuardianChildDetails({
    required this.studentId,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.idNumber,
    required this.uan,
    required this.status,
    required this.gradeLevel,
    required this.stream,
    required this.countryOfBirth,
    required this.cityOfBirth,
    required this.religion,
    required this.languages,
    required this.skillsAndInterests,
    required this.address,
    required this.medical,
    required this.vaccinations,
    required this.emergencyContacts,
  });

  final String studentId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String idNumber;
  final String uan;
  final String status;
  final String gradeLevel;
  final String stream;
  final String countryOfBirth;
  final String cityOfBirth;
  final String religion;
  final List<String> languages;
  final String skillsAndInterests;
  final GuardianChildAddress? address;
  final GuardianChildMedical? medical;
  final List<GuardianChildVaccination> vaccinations;
  final List<GuardianEmergencyContact> emergencyContacts;

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((part) => part.isNotEmpty).join(' ');

  factory GuardianChildDetails.fromJson(Map<String, dynamic> json) =>
      GuardianChildDetails(
        studentId: _text(json['customStudentId']),
        firstName: _text(json['firstName']),
        middleName: _text(json['middleName']),
        lastName: _text(json['lastName']),
        gender: _text(json['gender']),
        dateOfBirth: _dateText(json['dateOfBirth']),
        idNumber: _text(json['idNumber']),
        uan: _text(json['uan']),
        status: _text(json['status']),
        gradeLevel: _text(json['gradeLevel']),
        stream: _text(json['stream']),
        countryOfBirth: _text(json['countryOfBirth']),
        cityOfBirth: _text(json['cityOfBirth']),
        religion: _text(json['religion']),
        languages: _list(
          json['languages'],
        ).map(_text).where((v) => v.isNotEmpty).toList(),
        skillsAndInterests: _text(json['skillsAndInterests']),
        address: json['address'] is Map
            ? GuardianChildAddress.fromJson(_map(json['address']))
            : null,
        medical: json['medical'] is Map
            ? GuardianChildMedical.fromJson(_map(json['medical']))
            : null,
        vaccinations: _list(json['vaccinations'])
            .map((item) => GuardianChildVaccination.fromJson(_map(item)))
            .toList(growable: false),
        emergencyContacts: _list(json['emergencyContacts'])
            .map((item) => GuardianEmergencyContact.fromJson(_map(item)))
            .toList(growable: false),
      );
}

class GuardianChildAddress {
  const GuardianChildAddress({
    required this.houseNumber,
    required this.streetName,
    required this.city,
    required this.district,
    required this.region,
    required this.country,
    required this.ghanaPostAddress,
    required this.additionalDirection,
  });
  final String houseNumber;
  final String streetName;
  final String city;
  final String district;
  final String region;
  final String country;
  final String ghanaPostAddress;
  final String additionalDirection;
  factory GuardianChildAddress.fromJson(Map<String, dynamic> json) =>
      GuardianChildAddress(
        houseNumber: _text(json['houseNumber']),
        streetName: _text(json['streetName']),
        city: _text(json['city']),
        district: _text(json['district']),
        region: _text(json['region']),
        country: _text(json['country']),
        ghanaPostAddress: _text(json['ghanaPostAddress']),
        additionalDirection: _text(json['additionalDirection']),
      );
}

class GuardianChildMedical {
  const GuardianChildMedical({
    required this.bloodGroup,
    required this.heightCm,
    required this.weightKg,
    required this.conditions,
    required this.medicalAllergies,
    required this.foodAllergies,
    required this.environmentalAllergies,
  });
  final String bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final List<GuardianMedicalCondition> conditions;
  final List<String> medicalAllergies;
  final List<String> foodAllergies;
  final List<String> environmentalAllergies;
  factory GuardianChildMedical.fromJson(Map<String, dynamic> json) =>
      GuardianChildMedical(
        bloodGroup: _text(json['bloodGroup']),
        heightCm: json['heightCm'] is num
            ? (json['heightCm'] as num).toDouble()
            : null,
        weightKg: json['weightKg'] is num
            ? (json['weightKg'] as num).toDouble()
            : null,
        conditions: _list(json['conditions'])
            .map((item) => GuardianMedicalCondition.fromJson(_map(item)))
            .toList(growable: false),
        medicalAllergies: _list(
          json['medicalAllergies'],
        ).map(_text).where((v) => v.isNotEmpty).toList(),
        foodAllergies: _list(
          json['foodAllergies'],
        ).map(_text).where((v) => v.isNotEmpty).toList(),
        environmentalAllergies: _list(
          json['environmentalAllergies'],
        ).map(_text).where((v) => v.isNotEmpty).toList(),
      );
}

class GuardianMedicalCondition {
  const GuardianMedicalCondition({
    required this.name,
    required this.status,
    required this.notes,
  });
  final String name;
  final String status;
  final String notes;
  factory GuardianMedicalCondition.fromJson(Map<String, dynamic> json) =>
      GuardianMedicalCondition(
        name: _text(json['name']),
        status: _text(json['status']),
        notes: _text(json['notes']),
      );
}

class GuardianChildVaccination {
  const GuardianChildVaccination({
    required this.name,
    required this.diseaseProtected,
    required this.recommendedAge,
    required this.required,
    required this.status,
    required this.dateReceived,
    required this.notes,
  });
  final String name;
  final String diseaseProtected;
  final String recommendedAge;
  final bool required;
  final String status;
  final String dateReceived;
  final String notes;
  factory GuardianChildVaccination.fromJson(Map<String, dynamic> json) =>
      GuardianChildVaccination(
        name: _text(json['name']),
        diseaseProtected: _text(json['diseaseProtected']),
        recommendedAge: _text(json['recommendedAge']),
        required: json['required'] == true,
        status: _text(json['status']),
        dateReceived: _dateText(json['dateReceived']),
        notes: _text(json['notes']),
      );
}

class GuardianEmergencyContact {
  const GuardianEmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.primaryGuardian,
  });
  final String name;
  final String phoneNumber;
  final String email;
  final bool primaryGuardian;
  factory GuardianEmergencyContact.fromJson(Map<String, dynamic> json) =>
      GuardianEmergencyContact(
        name: _text(json['name']),
        phoneNumber: _text(json['phoneNumber']),
        email: _text(json['email']),
        primaryGuardian: json['primaryGuardian'] == true,
      );
}

class GuardianFeeDetail {
  const GuardianFeeDetail({
    required this.studentName,
    required this.termName,
    required this.items,
    required this.adjustments,
    required this.payments,
    required this.totalFees,
    required this.totalDiscounts,
    required this.totalPenalties,
    required this.totalPaid,
    required this.balance,
  });

  final String studentName;
  final String termName;
  final List<GuardianFeeItem> items;
  final List<GuardianFeeAdjustment> adjustments;
  final List<GuardianPayment> payments;
  final double totalFees;
  final double totalDiscounts;
  final double totalPenalties;
  final double totalPaid;
  final double balance;

  factory GuardianFeeDetail.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    return GuardianFeeDetail(
      studentName: _text(json['studentName']),
      termName: _text(json['currentTerm']),
      items: _list(json['feeItems'])
          .map((item) => GuardianFeeItem.fromJson(_map(item)))
          .toList(growable: false),
      adjustments: _list(json['adjustments'])
          .map((item) => GuardianFeeAdjustment.fromJson(_map(item)))
          .where((item) => item.status.toUpperCase() == 'APPROVED')
          .toList(growable: false),
      payments: _list(json['payments'])
          .map((item) => GuardianPayment.fromJson(_map(item)))
          .toList(growable: false),
      totalFees: _number(summary['totalFees']),
      totalDiscounts: _number(summary['totalDiscounts']),
      totalPenalties: _number(summary['totalPenalties']),
      totalPaid: _number(summary['totalPayments']),
      balance: _number(summary['outstandingBalance']),
    );
  }
}

class GuardianFeeAdjustment {
  const GuardianFeeAdjustment({
    required this.type,
    required this.description,
    required this.amount,
    required this.status,
  });

  final String type;
  final String description;
  final double amount;
  final String status;

  factory GuardianFeeAdjustment.fromJson(Map<String, dynamic> json) =>
      GuardianFeeAdjustment(
        type: _text(json['adjustmentType']),
        description: _text(json['description']),
        amount: _number(json['amount']),
        status: _text(json['status']),
      );
}

class GuardianFeeItem {
  const GuardianFeeItem({required this.name, required this.amount});
  final String name;
  final double amount;
  factory GuardianFeeItem.fromJson(Map<String, dynamic> json) =>
      GuardianFeeItem(
        name: _text(json['feeName']),
        amount: _number(json['amount']),
      );
}

class GuardianPayment {
  const GuardianPayment({
    required this.reference,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
  });
  final String reference;
  final double amount;
  final String date;
  final String method;
  final String status;
  factory GuardianPayment.fromJson(Map<String, dynamic> json) =>
      GuardianPayment(
        reference: _text(json['paymentReference']),
        amount: _number(json['amount']),
        date: _dateText(json['paymentDate']),
        method: _text(json['paymentMethod']),
        status: _text(json['status']),
      );
}

class GuardianPaymentSubmission {
  const GuardianPaymentSubmission({
    required this.paymentId,
    required this.reference,
    required this.studentName,
    required this.amount,
    required this.method,
    required this.status,
    required this.message,
  });

  final int paymentId;
  final String reference;
  final String studentName;
  final double amount;
  final String method;
  final String status;
  final String message;

  factory GuardianPaymentSubmission.fromJson(Map<String, dynamic> json) =>
      GuardianPaymentSubmission(
        paymentId: _integer(json['paymentId']),
        reference: _text(json['reference']),
        studentName: _text(json['studentName']),
        amount: _number(json['amount']),
        method: _text(json['paymentMethod']),
        status: _text(json['status']),
        message: _text(json['message']),
      );
}

class GuardianAttendanceItem {
  const GuardianAttendanceItem({
    required this.date,
    required this.status,
    required this.note,
    required this.minutesLate,
  });
  final String date;
  final String status;
  final String note;
  final int minutesLate;
  factory GuardianAttendanceItem.fromJson(Map<String, dynamic> json) =>
      GuardianAttendanceItem(
        date: _dateText(json['date']),
        status: _text(json['status']),
        note: _text(json['note']),
        minutesLate: _integer(json['minutesLate']),
      );
}

class GuardianReportItem {
  const GuardianReportItem({
    required this.termId,
    required this.academicYearId,
    required this.academicYear,
    required this.termName,
    required this.currentTerm,
    required this.status,
    required this.publishedAt,
    required this.available,
  });

  final int termId;
  final int academicYearId;
  final String academicYear;
  final String termName;
  final bool currentTerm;
  final String status;
  final String publishedAt;
  final bool available;

  factory GuardianReportItem.fromJson(Map<String, dynamic> json) =>
      GuardianReportItem(
        termId: _integer(json['termId']),
        academicYearId: _integer(json['academicYearId']),
        academicYear: _text(json['academicYear']),
        termName: _text(json['termName']),
        currentTerm: json['currentTerm'] == true,
        status: _text(json['status']),
        publishedAt: _dateText(json['publishedAt']),
        available: json['available'] == true,
      );
}

String _text(Object? value) => value?.toString().trim() ?? '';
int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<dynamic> _list(Object? value) => value is List ? value : const [];

String _dateText(Object? value) {
  if (value is List && value.length >= 3) {
    final year = _integer(value[0]);
    final month = _integer(value[1]);
    final day = _integer(value[2]);
    if (year > 0 && month > 0 && day > 0) {
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }
  }
  return _text(value);
}
