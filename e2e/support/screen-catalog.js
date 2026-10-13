const publicScreens = [
  { id: 'PUB-001', name: 'Login', path: '/login' },
  { id: 'PUB-002', name: 'Account activation', path: '/activate/e2e-token' },
  { id: 'PUB-003', name: 'Username recovery', path: '/recover-username' },
  { id: 'PUB-004', name: 'Password reset', path: '/reset-password' },
];

const platformScreens = [
  { id: 'PLAT-001', name: 'Platform overview', path: '/super-admin' },
  { id: 'PLAT-002', name: 'Schools', path: '/super-admin/schools' },
  { id: 'PLAT-003', name: 'Create school', path: '/super-admin/schools/new' },
  {
    id: 'PLAT-004',
    name: 'School detail',
    path: '/super-admin/schools/SMA-1001',
  },
  {
    id: 'PLAT-005',
    name: 'Onboarding schools',
    path: '/super-admin/onboarding',
  },
  {
    id: 'PLAT-006',
    name: 'Resume onboarding',
    path: '/super-admin/onboarding/SMA-1003',
  },
  {
    id: 'PLAT-007',
    name: 'Needs Attention',
    path: '/super-admin/attention',
  },
  {
    id: 'PLAT-008',
    name: 'Account Managers',
    path: '/super-admin/account-managers',
  },
  {
    id: 'PLAT-009',
    name: 'Account manager detail',
    navigation: 'Account Managers → first manager',
  },
  {
    id: 'PLAT-010',
    name: 'Platform Audit & Activity',
    path: '/super-admin/audit-activity',
  },
];

const schoolAdminScreens = [
  { id: 'ADM-001', name: 'Dashboard', label: 'Dashboard' },
  {
    id: 'ADM-002',
    name: 'Requests & Approvals',
    label: 'Requests & Approvals',
  },
  { id: 'ADM-003', name: 'School Calendar', label: 'School Calendar' },
  { id: 'ADM-004', name: 'My Leave', label: 'My Leave' },
  {
    id: 'ADM-005',
    name: 'Admissions',
    section: 'People',
    label: 'Admissions',
  },
  {
    id: 'ADM-006',
    name: 'Students',
    section: 'People',
    label: 'Students',
  },
  {
    id: 'ADM-007',
    name: 'Student Attendance',
    section: 'People',
    label: 'Student Attendance',
  },
  {
    id: 'ADM-008',
    name: 'Staff Attendance',
    section: 'People',
    label: 'Staff Attendance',
  },
  {
    id: 'ADM-009',
    name: 'Households',
    section: 'People',
    label: 'Households',
  },
  {
    id: 'ADM-010',
    name: 'Staff Management',
    section: 'People',
    label: 'Staff Management',
  },
  {
    id: 'ADM-011',
    name: 'Leave Management',
    section: 'People',
    label: 'Leave Management',
  },
  {
    id: 'ADM-012',
    name: 'Classes & Sections',
    section: 'Academics',
    label: 'Classes & Sections',
  },
  {
    id: 'ADM-013',
    name: 'Assessments',
    section: 'Academics',
    label: 'Assessments',
  },
  {
    id: 'ADM-014',
    name: 'Evaluations & Comments',
    section: 'Academics',
    label: 'Evaluations & Comments',
  },
  {
    id: 'ADM-015',
    name: 'Final Reports',
    section: 'Academics',
    label: 'Final Reports',
  },
  {
    id: 'ADM-016',
    name: 'Term Closure',
    section: 'Academics',
    label: 'Term Closure',
  },
  {
    id: 'ADM-017',
    name: 'Payroll',
    section: 'Finance & Operations',
    label: 'Payroll',
  },
  {
    id: 'ADM-018',
    name: 'Fees & Requirements',
    section: 'Finance & Operations',
    label: 'Fees & Requirements',
  },
  {
    id: 'ADM-019',
    name: 'School Shop',
    section: 'Finance & Operations',
    label: 'School Shop',
  },
  {
    id: 'ADM-020',
    name: 'Expenses & Petty Cash',
    section: 'Finance & Operations',
    label: 'Expenses & Petty Cash',
  },
  {
    id: 'ADM-021',
    name: 'Audit & Activity',
    section: 'Insights & Oversight',
    label: 'Audit & Activity',
  },
  {
    id: 'ADM-022',
    name: 'Incident Management',
    section: 'Insights & Oversight',
    label: 'Incident Management',
  },
  {
    id: 'ADM-023',
    name: 'Reports',
    section: 'Insights & Oversight',
    label: 'Reports',
  },
  { id: 'ADM-024', name: 'Settings', label: 'Settings' },
];

const guardianScreens = [
  { id: 'GUA-001', name: 'Guardian portal', path: '/guardian' },
  {
    id: 'GUA-002',
    name: 'Guardian child detail',
    navigation: 'Guardian portal → first child',
  },
];

const primaryScreens = [
  ...publicScreens,
  ...platformScreens,
  ...schoolAdminScreens,
  ...guardianScreens,
];

module.exports = {
  guardianScreens,
  platformScreens,
  primaryScreens,
  publicScreens,
  schoolAdminScreens,
};
