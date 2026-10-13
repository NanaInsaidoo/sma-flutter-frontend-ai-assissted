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
    path: '/super-admin/account-managers/Ama%20Mensah',
  },
  {
    id: 'PLAT-010',
    name: 'Platform Audit & Activity',
    path: '/super-admin/audit-activity',
  },
];

const schoolAdminScreens = [
  {
    id: 'ADM-001',
    name: 'Dashboard',
    label: 'Dashboard',
    path: '/school-admin?page=dashboard',
  },
  {
    id: 'ADM-002',
    name: 'Requests & Approvals',
    label: 'Requests & Approvals',
    path: '/school-admin?page=approvals',
  },
  { id: 'ADM-003', name: 'School Calendar', label: 'School Calendar', path: '/school-admin?page=calendar' },
  { id: 'ADM-004', name: 'My Leave', label: 'My Leave', path: '/school-admin?page=my-leave' },
  {
    id: 'ADM-005',
    name: 'Admissions',
    section: 'People',
    label: 'Admissions',
    path: '/school-admin?page=admissions',
  },
  {
    id: 'ADM-006',
    name: 'Students',
    section: 'People',
    label: 'Students',
    path: '/school-admin?page=students',
  },
  {
    id: 'ADM-007',
    name: 'Student Attendance',
    section: 'People',
    label: 'Student Attendance',
    path: '/school-admin?page=student-attendance',
  },
  {
    id: 'ADM-008',
    name: 'Staff Attendance',
    section: 'People',
    label: 'Staff Attendance',
    path: '/school-admin?page=staff-attendance',
  },
  {
    id: 'ADM-009',
    name: 'Households',
    section: 'People',
    label: 'Households',
    path: '/school-admin?page=households',
  },
  {
    id: 'ADM-010',
    name: 'Staff Management',
    section: 'People',
    label: 'Staff Management',
    path: '/school-admin?page=staff',
  },
  {
    id: 'ADM-011',
    name: 'Leave Management',
    section: 'People',
    label: 'Leave Management',
    path: '/school-admin?page=leave-management',
  },
  {
    id: 'ADM-012',
    name: 'Classes & Sections',
    section: 'Academics',
    label: 'Classes & Sections',
    path: '/school-admin?page=classes',
  },
  {
    id: 'ADM-013',
    name: 'Assessments',
    section: 'Academics',
    label: 'Assessments',
    path: '/school-admin?page=assessments',
  },
  {
    id: 'ADM-014',
    name: 'Evaluations & Comments',
    section: 'Academics',
    label: 'Evaluations & Comments',
    path: '/school-admin?page=evaluations',
  },
  {
    id: 'ADM-015',
    name: 'Final Reports',
    section: 'Academics',
    label: 'Final Reports',
    path: '/school-admin?page=final-reports',
  },
  {
    id: 'ADM-016',
    name: 'Term Closure',
    section: 'Academics',
    label: 'Term Closure',
    path: '/school-admin?page=term-closure',
  },
  {
    id: 'ADM-017',
    name: 'Payroll',
    section: 'Finance & Operations',
    label: 'Payroll',
    path: '/school-admin?page=payroll',
  },
  {
    id: 'ADM-018',
    name: 'Fees & Requirements',
    section: 'Finance & Operations',
    label: 'Fees & Requirements',
    path: '/school-admin?page=fees',
  },
  {
    id: 'ADM-019',
    name: 'School Shop',
    section: 'Finance & Operations',
    label: 'School Shop',
    path: '/school-admin?page=shop',
  },
  {
    id: 'ADM-020',
    name: 'Expenses & Petty Cash',
    section: 'Finance & Operations',
    label: 'Expenses & Petty Cash',
    path: '/school-admin?page=expenses',
  },
  {
    id: 'ADM-021',
    name: 'Audit & Activity',
    section: 'Insights & Oversight',
    label: 'Audit & Activity',
    path: '/school-admin?page=audit',
  },
  {
    id: 'ADM-022',
    name: 'Incident Management',
    section: 'Insights & Oversight',
    label: 'Incident Management',
    path: '/school-admin?page=incidents',
  },
  {
    id: 'ADM-023',
    name: 'Reports',
    section: 'Insights & Oversight',
    label: 'Reports',
    path: '/school-admin?page=reports',
  },
  { id: 'ADM-024', name: 'Settings', label: 'Settings', path: '/school-admin?page=settings' },
];

const guardianScreens = [
  { id: 'GUA-001', name: 'Guardian portal', path: '/guardian' },
  {
    id: 'GUA-002',
    name: 'Guardian child detail',
    path: '/guardian?child=STU-QA-001',
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
