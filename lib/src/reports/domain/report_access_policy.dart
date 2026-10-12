enum ReportArea {
  owner,
  management,
  term,
  finance,
  academic,
  attendance,
  admissions,
  incidents,
  facilities,
  staff,
  other,
}

/// The client-side report catalogue policy.
///
/// The API remains responsible for enforcing access to report data and PDF
/// downloads. This policy keeps reports that do not belong to the active
/// workspace out of the interface and deliberately denies unrecognised report
/// types to restricted roles.
abstract final class ReportAccessPolicy {
  static const schoolRoles = <String>{
    'OWNER',
    'ADMINISTRATOR',
    'HEADMASTER',
    'HEAD_TEACHER',
    'ASSISTANT_HEAD_TEACHER',
    'CLASS_TEACHER',
    'SUBJECT_TEACHER',
    'TEACHER',
    'BURSAR',
    'SECRETARY',
  };

  static String normalizeRole(String? value) {
    final role = value?.trim().toUpperCase().replaceAll('-', '_') ?? '';
    return switch (role) {
      'ADMIN' || 'OFFICE_ADMINISTRATOR' => 'ADMINISTRATOR',
      'PROPRIETOR' || 'SCHOOL_OWNER' => 'OWNER',
      _ => role,
    };
  }

  static bool canOpenLibrary(String? role) =>
      schoolRoles.contains(normalizeRole(role));

  static bool canViewReport({
    required String? role,
    required String type,
    required String category,
  }) {
    final normalizedRole = normalizeRole(role);
    if (!canOpenLibrary(normalizedRole)) return false;

    final normalizedType = _normalize(type);
    final area = classify(type: normalizedType, category: category);

    if (normalizedRole == 'OWNER') return true;
    if (normalizedType == 'OWNER' &&
        const {
          'ADMINISTRATOR',
          'HEADMASTER',
          'HEAD_TEACHER',
        }.contains(normalizedRole)) {
      return true;
    }
    if (normalizedRole == 'HEADMASTER') return area != ReportArea.owner;

    if (_isTeacher(normalizedRole)) {
      return _teacherReportTypes.any(normalizedType.contains);
    }

    final allowedAreas = switch (normalizedRole) {
      'HEAD_TEACHER' => const {
        ReportArea.management,
        ReportArea.term,
        ReportArea.finance,
        ReportArea.academic,
        ReportArea.attendance,
        ReportArea.admissions,
        ReportArea.incidents,
        ReportArea.facilities,
        ReportArea.staff,
      },
      'ASSISTANT_HEAD_TEACHER' => const {
        ReportArea.term,
        ReportArea.academic,
        ReportArea.attendance,
        ReportArea.admissions,
        ReportArea.incidents,
        ReportArea.facilities,
      },
      'ADMINISTRATOR' => const {
        ReportArea.term,
        ReportArea.finance,
        ReportArea.academic,
        ReportArea.attendance,
        ReportArea.admissions,
        ReportArea.incidents,
        ReportArea.facilities,
        ReportArea.staff,
      },
      'BURSAR' => const {ReportArea.term, ReportArea.finance},
      'SECRETARY' => const {
        ReportArea.term,
        ReportArea.attendance,
        ReportArea.admissions,
        ReportArea.facilities,
      },
      _ => const <ReportArea>{},
    };
    return allowedAreas.contains(area);
  }

  static ReportArea classify({required String type, required String category}) {
    final normalizedType = _normalize(type);
    final normalizedCategory = _normalize(category);
    if (normalizedType == 'OWNER' || normalizedType.contains('BOARD')) {
      return ReportArea.owner;
    }
    if (_containsAny(normalizedType, const [
      'HEADMASTER',
      'MANAGEMENT',
      'EXECUTIVE',
    ])) {
      return ReportArea.management;
    }
    if (_containsAny(normalizedType, const [
      'FINANCE',
      'FEE',
      'COLLECTION',
      'PAYMENT',
      'EXPENSE',
      'PETTY_CASH',
      'SHOP',
      'REFUND',
      'REVERSAL',
    ])) {
      return ReportArea.finance;
    }
    if (_containsAny(normalizedType, const [
      'ATTENDANCE',
      'LATENESS',
      'PUNCTUALITY',
    ])) {
      return ReportArea.attendance;
    }
    if (_containsAny(normalizedType, const [
      'ADMISSION',
      'ENROLMENT',
      'ENROLLMENT',
    ])) {
      return ReportArea.admissions;
    }
    if (normalizedType.contains('INCIDENT')) return ReportArea.incidents;
    if (_containsAny(normalizedType, const [
      'FACILITY',
      'FACILITIES',
      'MAINTENANCE',
      'INSPECTION',
    ])) {
      return ReportArea.facilities;
    }
    if (_containsAny(normalizedType, const [
      'STAFF_PERFORMANCE',
      'STAFF_REVIEW',
      'PAYROLL',
      'HR_',
    ])) {
      return ReportArea.staff;
    }
    if (_containsAny(normalizedType, const [
      'ACADEMIC',
      'ASSESSMENT',
      'STUDENT_REPORT',
      'CLASS_PERFORMANCE',
      'TEACHER_CLASS',
      'MY_CLASS',
    ])) {
      return ReportArea.academic;
    }
    if (_containsAny(normalizedType, const [
      'READINESS',
      'TERM_CLOSURE',
      'CLOSURE_PACK',
      'TERM_SUMMARY',
    ])) {
      return ReportArea.term;
    }

    return switch (normalizedCategory) {
      'FINANCE' => ReportArea.finance,
      'ACADEMIC' => ReportArea.academic,
      'TERM' => ReportArea.term,
      _ => ReportArea.other,
    };
  }

  static String roleLabel(String? role) => switch (normalizeRole(role)) {
    'OWNER' => 'Owner / Proprietor',
    'ADMINISTRATOR' => 'Administrator',
    'HEADMASTER' => 'Headmaster',
    'HEAD_TEACHER' => 'Head teacher',
    'ASSISTANT_HEAD_TEACHER' => 'Assistant head teacher',
    'CLASS_TEACHER' || 'SUBJECT_TEACHER' || 'TEACHER' => 'Teacher',
    'BURSAR' => 'Bursar',
    'SECRETARY' => 'Secretary',
    _ => 'School staff',
  };

  static String accessDescription(String? role) => switch (normalizeRole(
    role,
  )) {
    'OWNER' =>
      'Complete school-wide management, finance, academic and operational reports.',
    'HEADMASTER' =>
      'Full school management report and detailed leadership and operational reports.',
    'HEAD_TEACHER' =>
      'Full school management report plus academic, finance and operational reports.',
    'ASSISTANT_HEAD_TEACHER' =>
      'Academic, attendance, admissions, incident and facilities reports.',
    'ADMINISTRATOR' =>
      'Full school management report plus operational, finance, academic and staff reports.',
    'BURSAR' =>
      'Finance, collections, expenses, petty cash, shop and term finance reports.',
    'SECRETARY' =>
      'Admissions, attendance, facilities and term administration reports.',
    'CLASS_TEACHER' || 'SUBJECT_TEACHER' || 'TEACHER' =>
      'Student, attendance and class reports permitted for your teaching assignments.',
    _ => 'No management reports are assigned to this workspace.',
  };

  static const _teacherReportTypes = <String>[
    'STUDENT_REPORT',
    'STUDENT_ATTENDANCE',
    'TEACHER_CLASS',
    'CLASS_REPORT',
    'MY_CLASS',
    'MY_ATTENDANCE',
  ];

  static bool _isTeacher(String role) =>
      const {'TEACHER', 'CLASS_TEACHER', 'SUBJECT_TEACHER'}.contains(role);

  static String _normalize(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static bool _containsAny(String value, Iterable<String> needles) =>
      needles.any(value.contains);
}
