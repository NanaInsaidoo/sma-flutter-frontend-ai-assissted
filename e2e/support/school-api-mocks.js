const schoolId = 'SMA-QA-001';

const currentTerm = {
  id: 101,
  name: 'First Term · 2026/2027',
  academicTermId: 101,
  academicYearId: 26,
  academicYear: { id: 26, name: '2026/2027' },
  termType: { id: 1, name: 'First Term' },
  termName: 'First Term',
  startDate: '2026-09-01',
  endDate: '2026-12-18',
  status: 'ACTIVE',
};

const gradeLevels = [
  {
    id: 1,
    schoolGradeLevelId: 1,
    gradeLevelId: 1,
    name: 'Basic 1',
    gradeName: 'Basic 1',
    streams: [
      { id: 11, streamId: 11, name: 'A', streamName: 'A' },
      { id: 12, streamId: 12, name: 'B', streamName: 'B' },
    ],
  },
  {
    id: 2,
    schoolGradeLevelId: 2,
    gradeLevelId: 2,
    name: 'Basic 2',
    gradeName: 'Basic 2',
    streams: [{ id: 21, streamId: 21, name: 'A', streamName: 'A' }],
  },
];

const students = [
  {
    id: 1,
    customStudentId: 'STU-2026-001',
    firstName: 'Abena',
    lastName: 'Owusu-Mensah',
    fullName: 'Abena Owusu-Mensah',
    gender: 'FEMALE',
    dateOfBirth: '2016-04-12',
    createdAt: '2026-09-01T08:00:00Z',
    status: 'ACTIVE',
    householdId: 1001,
    admissionId: 2001,
    admissionTermId: 101,
    grade: 'Basic 1',
    gradeName: 'Basic 1',
    streamName: 'A',
    gradeLevel: { id: 1, name: 'Basic 1' },
    stream: { id: 11, name: 'A' },
  },
  {
    id: 2,
    customStudentId: 'STU-2026-002',
    firstName: 'Kwame',
    lastName: 'Asante',
    fullName: 'Kwame Asante',
    gender: 'MALE',
    dateOfBirth: '2015-11-03',
    createdAt: '2026-09-01T08:00:00Z',
    status: 'ACTIVE',
    householdId: 1002,
    admissionId: 2002,
    admissionTermId: 101,
    grade: 'Basic 2',
    gradeName: 'Basic 2',
    streamName: 'A',
    gradeLevel: { id: 2, name: 'Basic 2' },
    stream: { id: 21, name: 'A' },
  },
];

const staff = [
  {
    id: 1,
    customStaffId: 'STF-001',
    firstName: 'Akosua',
    lastName: 'Boateng',
    fullName: 'Akosua Boateng',
    jobTitle: 'Class Teacher',
    department: 'Academics',
    employmentType: 'FULL_TIME',
    status: 'ACTIVE',
    email: 'akosua.boateng@sma.test',
    phoneNumber: '+233 24 555 0110',
  },
];

function pageResponse(content) {
  return {
    content,
    items: content,
    data: content,
    totalElements: content.length,
    totalPages: 1,
    number: 0,
    currentPage: 0,
    size: 20,
    pageSize: 20,
  };
}

function schoolResponse(pathname, searchParams) {
  if (pathname.endsWith(`/api/schools/${schoolId}/readiness`)) {
    return { ready: true, currentBlockingStep: null, items: [] };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/dashboard/statistics`)) {
    return {
      totalStudents: 482,
      totalActiveStudents: 476,
      totalClasses: 18,
      totalActiveClasses: 18,
      totalGradeLevels: 9,
    };
  }
  if (
    pathname.endsWith(`/api/schools/${schoolId}/academic-context/current`) ||
    pathname.endsWith(`/api/v1/current-term/${schoolId}`)
  ) {
    return currentTerm;
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/fee-management/overview`)) {
    return {
      totalBilled: 780000,
      totalCollected: 624000,
      outstanding: 156000,
      collectionRate: 80,
      studentCount: 482,
    };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/attendance/overview`)) {
    return {
      currentDate: '2026-10-13',
      schoolDay: true,
      schoolStats: {
        today: {
          attendanceRate: 94.6,
          present: 456,
          absent: 18,
          late: 8,
          totalStudents: 482,
        },
        week: { attendanceRate: 93.8, totalStudents: 482 },
        month: { avgAttendanceRate: 94.1, totalStudents: 482 },
        term: {
          attendanceRate: 94.2,
          present: 456,
          absent: 18,
          late: 8,
          totalRecords: 482,
          studentsNeedingAttention: 6,
        },
      },
      summary: { today: { streamsPending: 2 } },
      gradeStreamBreakdown: [],
      alerts: [],
      recentSchoolDates: ['2026-10-13'],
    };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/approvals`)) {
    return {
      pendingMyApproval: 1,
      pendingMyRequests: 1,
      myApprovals: [
        {
          key: 'expense-1',
          type: 'EXPENSE',
          entityId: 1,
          category: 'Finance',
          title: 'Science laboratory supplies',
          subtitle: 'GHS 1,250.00 · requested by Akosua Boateng',
          status: 'PENDING_APPROVAL',
          amount: 1250,
          requesterName: 'Akosua Boateng',
          approverName: 'School Administrator',
          reason: 'Restock practical science materials.',
          submittedAt: '2026-10-12T09:30:00Z',
          canApprove: true,
          canReject: true,
          canWithdraw: false,
          sourcePage: 'expenses',
          stateToken: 'qa-expense-1',
        },
      ],
      myRequests: [
        {
          key: 'leave-1',
          type: 'LEAVE',
          entityId: 2,
          category: 'People',
          title: 'Personal leave request',
          subtitle: 'Two school days',
          status: 'PENDING_APPROVAL',
          requesterName: 'School Administrator',
          approverName: 'Headmaster',
          reason: 'Family appointment.',
          submittedAt: '2026-10-11T08:00:00Z',
          canApprove: false,
          canReject: false,
          canWithdraw: true,
          sourcePage: 'leave',
          stateToken: 'qa-leave-1',
        },
      ],
    };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/notifications`)) {
    return {
      unreadCount: 2,
      notifications: [
        {
          id: 1,
          type: 'ATTENDANCE',
          title: 'Attendance follow-up',
          message: 'Two class registers are still pending today.',
          sourceType: 'ATTENDANCE',
          sourceId: 1,
          createdAt: '2026-10-13T08:30:00Z',
          read: false,
        },
      ],
    };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/shop/context`)) {
    return {
      isAdmin: true,
      canSell: true,
      canTakePayment: true,
      canRelease: true,
      canHoldStock: true,
      canBuy: true,
      canConsign: true,
      canReceiveStaffReturns: true,
      canIssueRefunds: true,
    };
  }
  if (pathname.endsWith(`/api/schools/${schoolId}/payroll/access`)) {
    return { canView: true, canEdit: true };
  }
  if (pathname.endsWith(`/api/v2/staff-attendance/school/${schoolId}/dashboard`)) {
    return {
      expectedStaffDays: 21,
      presentDays: 20,
      lateDays: 1,
      excusedAbsences: 0,
      unexcusedAbsences: 0,
      missingRegisters: 0,
      attendanceRate: 95.2,
      punctualityRate: 95,
      days: [],
    };
  }
  if (pathname.endsWith(`/api/v1/guardians/schools/${schoolId}/directory`)) {
    return {
      guardians: [
        {
          customGuardianId: 'GUA-QA-001',
          name: 'Yaa Owusu',
          householdId: 1001,
          phone: '+233 24 555 0102',
          email: 'yaa.owusu@sma.test',
          isPrimary: true,
          status: 'ACTIVE',
          createdAt: '2026-09-01',
        },
      ],
      studentCounts: { '1001': 1 },
    };
  }
  if (pathname.endsWith(`/api/grade-levels/allstatus/school/${schoolId}`)) {
    return gradeLevels.map((grade, index) => ({
      ...grade,
      gradeLevelId: grade.id,
      status: 'ACTIVE',
      displayOrder: index + 1,
      gradeLevelStudentCount: index === 0 ? 54 : 48,
    }));
  }
  if (pathname.endsWith('/api/grade-levels/default')) return [];
  if (pathname.endsWith(`/api/v2/staff-performance-reviews/school/${schoolId}/dashboard`)) {
    return {
      termId: 101,
      termName: 'First Term · 2026/2027',
      total: 1,
      notStarted: 1,
      draft: 0,
      completed: 0,
      reviews: [
        {
          staffId: '1',
          staffName: 'Akosua Boateng',
          role: 'CLASS_TEACHER',
          status: 'NOT_STARTED',
        },
      ],
    };
  }
  if (pathname.endsWith(`/api/v2/headmaster-term-closures/school/${schoolId}`)) {
    return {
      termId: 101,
      closureStatus: 'IN_PROGRESS',
      termClosed: false,
      readyToClose: false,
      items: [],
      warningAcknowledgements: {},
      facilities: {},
      summary: {},
      transitionPreview: { available: false },
      transition: {},
    };
  }
  if (pathname.includes(`/api/schools/${schoolId}/finance/overview`)) {
    return {
      cycle: { status: 'OPEN', cashBalance: 1800, momoBalance: 3250 },
      pockets: { cash: 1800, momo: 3250 },
    };
  }
  if (pathname.includes(`/api/schools/${schoolId}/finance/policy`)) {
    return { status: 'OPEN', cashBalance: 1800, momoBalance: 3250 };
  }
  if (pathname.includes(`/api/schools/${schoolId}/finance/top-up-actors`)) {
    return { approvers: [], disbursers: [] };
  }
  if (pathname.includes(`/api/schools/${schoolId}/finance/`)) return [];
  if (pathname.endsWith(`/api/v2/management-reports/school/${schoolId}`)) {
    return { reports: [] };
  }
  if (pathname.endsWith('/api/term-events/search')) return [];
  if (pathname.endsWith(`/api/schools/${schoolId}`)) {
    return { customSchoolId: schoolId, schoolName: 'SMA Quality Academy' };
  }
  if (pathname.includes('/student-waivers')) return [];
  if (pathname.includes('/payment-reversals')) return [];
  if (pathname.includes('/api/payments/') && pathname.endsWith('/reversals')) {
    return [];
  }
  if (pathname.endsWith(`/api/admissions/school/${schoolId}`)) {
    return pageResponse([]);
  }
  if (pathname.includes('/api/grade-levels/school/')) return gradeLevels;
  if (pathname.endsWith(`/api/students/schools/${schoolId}/students/filter`)) {
    return pageResponse(students);
  }
  const studentDetailPrefix = `/api/students/schools/${schoolId}/students/`;
  if (pathname.includes(studentDetailPrefix)) {
    const studentId = decodeURIComponent(
      pathname.slice(pathname.indexOf(studentDetailPrefix) + studentDetailPrefix.length),
    );
    return students.find((student) => student.customStudentId === studentId) ?? {};
  }
  if (pathname.includes('/attendance/student/') && pathname.endsWith('/summary')) {
    return { attendanceRate: 94.5, recentAttendanceRecords: [] };
  }
  if (pathname.includes('/api/v1/guardians/') && pathname.endsWith('/filter')) {
    return pageResponse([
      {
        customGuardianId: 'GUA-QA-001',
        firstName: 'Yaa',
        lastName: 'Owusu',
        householdId: 1001,
        phoneNumber: '+233 24 555 0102',
        email: 'yaa.owusu@sma.test',
        relationship: 'Mother',
        status: 'ACTIVE',
        isPrimary: true,
      },
    ]);
  }
  if (pathname.includes('/fee-management/students')) return pageResponse([]);
  if (pathname.includes('/user-management/schools/') && pathname.endsWith('/users')) {
    return staff.map((person) => ({
      id: person.id,
      userName: 'akosua.boateng',
      firstName: person.firstName,
      lastName: person.lastName,
      email: person.email,
      phoneNumber: person.phoneNumber,
      userType: 'STAFF',
      role: 'CLASS_TEACHER',
      roles: ['CLASS_TEACHER'],
      accountStatus: 'ACTIVE',
      createdAt: '2026-08-15',
    }));
  }
  if (pathname.includes('/staff-management/schools/') && pathname.endsWith('/profiles')) {
    return staff.map((person) => ({
      staffId: person.customStaffId,
      userId: `${person.id}`,
      position: person.jobTitle,
      departmentName: person.department,
      employmentType: person.employmentType,
      startDate: '2026-08-15',
      resumeDocuments: [],
    }));
  }
  if (pathname.includes('/api/lookup/')) return [];
  if (pathname.endsWith('/api/academic-terms')) return [currentTerm];
  if (pathname.includes('/api/academic-terms')) return [currentTerm];
  if (
    pathname.includes('/fee-workflow-summary') ||
    pathname.includes('/fee-structures/workflow-summary')
  ) {
    return {
      streamsWithoutActiveFees: 0,
      pendingMyApproval: 0,
      masterPendingMyApproval: 0,
      requiredItemsPendingMyApproval: 0,
    };
  }
  if (pathname.includes('/payroll/staff')) return staff;
  if (pathname.includes('/payroll')) return [];
  if (pathname.includes('/shop/dashboard')) return {};
  if (pathname.includes('/shop/')) return [];
  if (pathname.includes('/audit')) return pageResponse([]);
  if (pathname.includes('/reports')) return pageResponse([]);
  if (pathname.includes('/incidents')) return pageResponse([]);
  if (pathname.endsWith(`/api/schools/${schoolId}/leave/context`)) {
    return {
      currentUserId: 501,
      canReview: true,
      canCreateForOthers: true,
      types: [
        { id: 1, name: 'Annual leave', active: true },
        { id: 2, name: 'Sick leave', active: true },
      ],
      staff: staff.map((person) => ({
        id: person.id,
        name: person.fullName,
      })),
    };
  }
  if (pathname.includes(`/api/schools/${schoolId}/leave/staff/`) && pathname.includes('/balances')) {
    return [];
  }
  if (pathname === `/Narellallc/sma-v1/1.0.0/api/schools/${schoolId}/leave`) {
    return {
      items: [],
      total: 0,
      totalPages: 0,
      page: 0,
      size: 25,
      counts: {
        DRAFT: 0,
        PENDING_APPROVAL: 0,
        APPROVED: 0,
        REJECTED: 0,
        CANCELLED: 0,
        NEEDS_REVISION: 0,
        ON_LEAVE: 0,
        CHANGE_PENDING_APPROVAL: 0,
      },
    };
  }
  if (pathname.includes('/leave')) return { items: [], total: 0, totalPages: 0 };
  if (pathname.includes('/attendance')) return pageResponse([]);
  if (pathname.includes('/assessments')) return pageResponse([]);
  if (pathname.includes('/term-evaluations/dashboard')) {
    return {
      released: false,
      teacherEntryOpen: false,
      responsibilityRows: [],
      assignments: [],
      readiness: { students: [] },
    };
  }
  if (pathname.includes('/report-corrections/schools/')) return [];
  if (pathname.includes('/api/report-card-remarks/')) return [];
  if (pathname.includes('/evaluations')) return pageResponse([]);
  if (pathname.includes('/subjects')) return [];
  if (pathname.includes('/streams')) return [];

  // Empty deterministic payloads are intentionally returned during the
  // catalogue pass. Each path is recorded so the fixture can be tightened
  // when a screen requires a richer state.
  return null;
}

async function installSchoolApiMocks(page) {
  const fallbackRequests = [];
  await page.route('**/Narellallc/sma-v1/1.0.0/api/**', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    let response = schoolResponse(url.pathname, url.searchParams);
    if (response == null) {
      fallbackRequests.push(`${request.method()} ${url.pathname}${url.search}`);
      response = request.method() === 'GET' ? {} : { success: true };
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(response),
    });
  });
  return { fallbackRequests };
}

module.exports = {
  installSchoolApiMocks,
  schoolId,
};
