const schools = [
  {
    id: 'school-1',
    customSchoolId: 'SMA-1001',
    schoolName: 'Accra Horizon Academy',
    region: 'Greater Accra',
    district: 'La Nkwantanang Madina',
    town: 'Madina',
    students: 842,
    staff: 64,
    registrationStatus: 'APPROVED',
    progress: 100,
    accountManagerName: 'Ama Mensah',
    subscriptionPlan: 'Growth',
    lastActive: 'Today, 9:42 AM',
  },
  {
    id: 'school-2',
    customSchoolId: 'SMA-1002',
    schoolName: 'Cape Coast Preparatory School',
    region: 'Central',
    district: 'Cape Coast Metro',
    town: 'Cape Coast',
    students: 516,
    staff: 41,
    registrationStatus: 'PENDING_APPROVAL',
    progress: 92,
    accountManagerName: 'Kojo Asare',
    subscriptionPlan: 'Standard',
    lastActive: 'Yesterday, 4:18 PM',
  },
  {
    id: 'school-3',
    customSchoolId: 'SMA-1003',
    schoolName: 'Tamale Learning Centre',
    region: 'Northern',
    district: 'Tamale Metro',
    town: 'Tamale',
    students: 694,
    staff: 52,
    registrationStatus: 'IN_PROGRESS',
    progress: 67,
    accountManagerName: 'Efua Owusu',
    subscriptionPlan: 'Standard',
    lastActive: '2 days ago',
  },
  {
    id: 'school-4',
    customSchoolId: 'SMA-1004',
    schoolName: 'Kumasi Ridge School',
    region: 'Ashanti',
    district: 'Kumasi Metro',
    town: 'Kumasi',
    students: 731,
    staff: 58,
    registrationStatus: 'NEEDS_REVISION',
    progress: 78,
    accountManagerName: 'Ama Mensah',
    subscriptionPlan: 'Growth',
    lastActive: '3 days ago',
  },
  {
    id: 'school-5',
    customSchoolId: 'SMA-1005',
    schoolName: 'Volta Community Academy',
    region: 'Volta',
    district: 'Ho Municipal',
    town: 'Ho',
    students: 388,
    staff: 33,
    registrationStatus: 'APPROVED',
    progress: 100,
    accountManagerName: 'Kojo Asare',
    subscriptionPlan: 'Standard',
    lastActive: '5 days ago',
  },
];

const accountManagers = [
  {
    id: 'manager-1',
    userId: '101',
    name: 'Ama Mensah',
    email: 'ama.mensah@sma.test',
    phoneNumber: '+233 24 555 0101',
    region: 'Greater Accra',
    schoolCount: 12,
    activeSchoolCount: 10,
    status: 'ACTIVE',
    lastActive: 'Today, 10:12 AM',
    createdAt: '15 Jan 2026',
    verified: true,
  },
  {
    id: 'manager-2',
    userId: '102',
    name: 'Kojo Asare',
    email: 'kojo.asare@sma.test',
    phoneNumber: '+233 20 555 0184',
    region: 'Central',
    schoolCount: 9,
    activeSchoolCount: 8,
    status: 'ACTIVE',
    lastActive: 'Yesterday, 3:47 PM',
    createdAt: '03 Feb 2026',
    verified: true,
  },
  {
    id: 'manager-3',
    userId: '103',
    name: 'Efua Owusu',
    email: 'efua.owusu@sma.test',
    phoneNumber: '+233 55 555 0138',
    region: 'Northern',
    schoolCount: 7,
    activeSchoolCount: 5,
    status: 'ACTIVE',
    lastActive: '2 days ago',
    createdAt: '20 Mar 2026',
    verified: true,
  },
  {
    id: 'manager-4',
    userId: '104',
    name: 'Yaw Boateng',
    email: 'yaw.boateng@sma.test',
    phoneNumber: '+233 27 555 0162',
    region: 'Ashanti',
    schoolCount: 0,
    activeSchoolCount: 0,
    status: 'INVITED',
    lastActive: 'Not yet active',
    createdAt: '08 Oct 2026',
    verified: false,
  },
  {
    id: 'manager-5',
    userId: '105',
    name: 'Adwoa Nyarko',
    email: 'adwoa.nyarko@sma.test',
    phoneNumber: '+233 50 555 0199',
    region: 'Volta',
    schoolCount: 0,
    activeSchoolCount: 0,
    status: 'PENDING',
    lastActive: 'Awaiting approval',
    createdAt: '10 Oct 2026',
    verified: false,
  },
];

const attentionCategories = [
  {
    category: 'SCHOOL_APPROVALS',
    label: 'School approvals',
    count: 2,
    priority: 'HIGH',
  },
  {
    category: 'ACCOUNT_MANAGER_APPROVALS',
    label: 'Account manager approvals',
    count: 1,
    priority: 'MEDIUM',
  },
  {
    category: 'ONBOARDING_STALLED',
    label: 'Onboarding stalled',
    count: 2,
    priority: 'MEDIUM',
  },
];

const attentionItems = [
  {
    id: 'attention-1',
    category: 'SCHOOL_APPROVALS',
    priority: 'HIGH',
    title: 'Cape Coast Preparatory School',
    description: 'Registration is complete and ready for review.',
    entityType: 'SCHOOL',
    entityId: 'school-2',
    status: 'OPEN',
    ageInDays: 2,
    actionTarget: 'SCHOOL_REVIEW',
    createdAt: '10 Oct 2026',
  },
  {
    id: 'attention-2',
    category: 'SCHOOL_APPROVALS',
    priority: 'HIGH',
    title: 'Kumasi Ridge School',
    description: 'Revised compliance documents need another review.',
    entityType: 'SCHOOL',
    entityId: 'school-4',
    status: 'OPEN',
    ageInDays: 4,
    actionTarget: 'SCHOOL_REVIEW',
    createdAt: '08 Oct 2026',
  },
];

const dashboard = {
  managerName: 'System Administrator',
  stats: {
    totalSchools: { value: 42, label: 'Across 10 regions' },
    activeSchools: { value: 34, label: '81% of all schools' },
    accountManagers: { value: 15, label: '12 active · 3 invited' },
    pendingApprovals: { value: 3, label: '3 pending approval' },
  },
};

function pageResponse(content) {
  return {
    content,
    totalElements: content.length,
    totalPages: 1,
    number: 0,
    currentPage: 0,
    size: 20,
    pageSize: 20,
  };
}

function lookupResponse(pathname) {
  if (pathname.endsWith('/api/lookup/regions')) {
    return {
      data: [
        { id: 1, name: 'Ashanti' },
        { id: 2, name: 'Central' },
        { id: 3, name: 'Greater Accra' },
        { id: 4, name: 'Northern' },
        { id: 5, name: 'Volta' },
      ],
    };
  }
  return { data: [] };
}

function responseFor(url) {
  const { pathname, searchParams } = new URL(url);

  if (pathname.endsWith('/api/super-admin/dashboard/schools')) {
    return pageResponse(schools);
  }
  if (pathname.endsWith('/api/super-admin/dashboard')) {
    return { data: dashboard };
  }
  if (pathname.endsWith('/api/account-managers/')) {
    const statuses = searchParams.getAll('userStatuses');
    const filtered = statuses.length
      ? accountManagers.filter((manager) => statuses.includes(manager.status))
      : accountManagers;
    return pageResponse(filtered);
  }
  if (pathname.endsWith('/api/super-admin/needs-attention/summary')) {
    return { data: { total: 5, categories: attentionCategories } };
  }
  if (pathname.endsWith('/api/super-admin/needs-attention')) {
    const category = searchParams.get('category');
    return pageResponse(
      category
        ? attentionItems.filter((item) => item.category === category)
        : attentionItems,
    );
  }
  if (pathname.includes('/api/lookup/')) {
    return lookupResponse(pathname);
  }

  return null;
}

async function installPlatformApiMocks(page) {
  const unexpectedRequests = [];
  await page.route('**/Narellallc/sma-v1/1.0.0/api/**', async (route) => {
    const request = route.request();
    const response = responseFor(request.url());
    if (response == null) {
      const url = new URL(request.url());
      unexpectedRequests.push(
        `${request.method()} ${url.pathname}${url.search}`,
      );
      await route.fulfill({
        status: 501,
        contentType: 'application/json',
        body: JSON.stringify({
          message: 'No deterministic Playwright fixture exists for this API.',
        }),
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

module.exports = {
  installPlatformApiMocks,
};
