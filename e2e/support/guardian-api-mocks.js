const studentId = 'STU-QA-001';

const dashboard = {
  guardianName: 'Akosua Mensah',
  email: 'akosua.mensah@sma.test',
  phoneNumber: '+233 24 555 0167',
  schoolName: 'SMA Quality Academy',
  academicYear: '2026/2027',
  termName: 'Term 1',
  termId: 11,
  academicYearId: 7,
  totalBalance: 950,
  children: [
    {
      customStudentId: studentId,
      studentName: 'Nhyira Mensah',
      gradeLevel: 'Grade 6',
      stream: 'A',
      totalFees: 3200,
      totalPaid: 2250,
      balance: 950,
      termAverage: 84.6,
      attendanceDays: 36,
      presentDays: 34,
      absentDays: 1,
      lateDays: 1,
      excusedDays: 0,
      attendancePercentage: 94.4,
      reportPublished: true,
      reportCurrent: true,
    },
  ],
  calendarEvents: [
    {
      id: 1,
      title: 'Family learning conference',
      description: 'Meet the class teacher and review learning goals.',
      category: 'ACADEMIC',
      startDate: '2026-10-22',
      endDate: '2026-10-22',
      startTime: '14:00',
      endTime: '16:00',
      schoolDay: true,
    },
  ],
};

const academics = {
  subjects: [
    {
      subjectName: 'Mathematics',
      currentAverage: 88,
      releasedScoreCount: 3,
      scores: [
        {
          title: 'Fractions quiz',
          type: 'QUIZ',
          date: '2026-10-06',
          score: 18,
          maxScore: 20,
          percentage: 90,
          remarks: 'Excellent work.',
        },
      ],
    },
    {
      subjectName: 'English Language',
      currentAverage: 81,
      releasedScoreCount: 2,
      scores: [],
    },
  ],
  activities: [
    {
      subjectName: 'Science',
      title: 'Plant growth journal',
      description: 'Record daily observations for one week.',
      type: 'HOMEWORK',
      dueDate: '2026-10-19',
      status: 'UPCOMING',
      score: null,
      maxScore: 20,
      percentage: null,
      remarks: '',
    },
  ],
};

function responseFor(url) {
  const { pathname } = new URL(url);
  if (pathname.endsWith('/api/v1/guardian-portal/me')) return dashboard;
  if (pathname.endsWith(`/api/v1/guardian-portal/students/${studentId}/academics`)) {
    return academics;
  }
  if (pathname.endsWith(`/api/v1/guardian-portal/students/${studentId}/attendance`)) {
    return [
      { date: '2026-10-12', status: 'PRESENT', note: '', minutesLate: 0 },
      { date: '2026-10-11', status: 'LATE', note: 'Traffic delay', minutesLate: 8 },
    ];
  }
  if (pathname.endsWith(`/api/v1/guardian-portal/students/${studentId}/reports`)) {
    return [
      {
        termId: 11,
        academicYearId: 7,
        academicYear: '2026/2027',
        termName: 'Term 1',
        currentTerm: true,
        status: 'PUBLISHED',
        publishedAt: '2026-10-10',
        available: true,
      },
    ];
  }
  if (pathname.endsWith(`/api/v1/guardian-portal/students/${studentId}/requirements`)) {
    return {
      studentId,
      studentName: 'Nhyira Mensah',
      academicTermId: 11,
      items: [
        {
          id: 1,
          name: 'A4 exercise books',
          category: 'STATIONERY',
          requiredQuantity: 4,
          receivedQuantity: 2,
          unit: 'books',
          estimatedUnitPrice: 18,
          dueDate: '2026-10-25',
          instructions: 'Label each book with the learner name.',
          optional: false,
          status: 'PARTIALLY_RECEIVED',
          notes: '',
        },
      ],
    };
  }
  if (pathname.endsWith(`/api/v1/guardian-portal/students/${studentId}/details`)) {
    return {
      customStudentId: studentId,
      firstName: 'Nhyira',
      middleName: 'Ama',
      lastName: 'Mensah',
      gender: 'FEMALE',
      dateOfBirth: '2014-05-20',
      idNumber: 'QA-2014-001',
      uan: 'UAN-001001',
      status: 'ACTIVE',
      gradeLevel: 'Grade 6',
      stream: 'A',
      countryOfBirth: 'Ghana',
      cityOfBirth: 'Accra',
      religion: 'Christianity',
      languages: ['English', 'Twi'],
      skillsAndInterests: 'Reading, robotics, and athletics',
      address: {
        houseNumber: '18',
        streetName: 'Independence Avenue',
        city: 'Accra',
        district: 'Accra Metropolitan',
        region: 'Greater Accra',
        country: 'Ghana',
        ghanaPostAddress: 'GA-123-4567',
        additionalDirection: '',
      },
      medical: null,
      vaccinations: [],
      emergencyContacts: [],
    };
  }
  return null;
}

async function installGuardianApiMocks(page) {
  const unexpectedRequests = [];
  await page.route('**/Narellallc/sma-v1/1.0.0/api/**', async (route) => {
    const request = route.request();
    const response = responseFor(request.url());
    if (response == null) {
      const url = new URL(request.url());
      unexpectedRequests.push(`${request.method()} ${url.pathname}${url.search}`);
      await route.fulfill({
        status: 501,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'No deterministic guardian fixture exists.' }),
      });
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(response),
    });
  });
  return { unexpectedRequests };
}

module.exports = { installGuardianApiMocks, studentId };
