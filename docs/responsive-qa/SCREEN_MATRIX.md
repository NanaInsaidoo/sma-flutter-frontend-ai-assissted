# Responsive QA Screen Matrix

## Status legend

- ✅ Passed and reviewed for the stated device.
- ◐ Automated check exists, but visual review or state coverage is incomplete.
- — Not yet covered.
- N/A Not applicable.

The matrix tracks primary user-facing surfaces. Nested states discovered during a phase are added beneath their parent or as new rows. “Visual” means an approved Playwright screenshot baseline, not merely a screenshot file.

## Public account access

| ID | Surface | Entry | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| PUB-001 | Login | `/login` | ✅ | ✅ | ✅ | ◐ | Stable mobile/tablet baseline; authentication behavior remains covered by the broader Flutter suite. |
| PUB-002 | Account activation | `/activate/:token` | ✅ | ✅ | ✅ | ✅ | Populated confirmation baseline plus verification, validation, and completion widget journeys. |
| PUB-003 | Username recovery | `/recover-username` | ✅ | ✅ | ✅ | ✅ | End-to-end widget journey passes at 360×800 and 834×1194. |
| PUB-004 | Password reset | `/reset-password` | ✅ | ✅ | ✅ | ✅ | End-to-end widget journey passes at 360×800 and 834×1194. |

## Platform administration

| ID | Surface | Entry | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| PLAT-001 | Platform overview | `/:platform-role` | ✅ | ✅ | ✅ | ◐ | Populated Super Admin baseline; responsive smoke covers all three platform roles. |
| PLAT-002 | Schools | `/:platform-role/schools` | ✅ | ✅ | ✅ | ◐ | Populated list baseline; tablet table defect fixed. |
| PLAT-003 | Create school | `/:platform-role/schools/new` | ✅ | ✅ | ✅ | ◐ | Initial multi-step form and compact footer verified. |
| PLAT-004 | School detail | `/:platform-role/schools/:schoolCode` | ✅ | ✅ | ✅ | ◐ | Populated profile overview verified; compact identity defect fixed. |
| PLAT-005 | Onboarding schools | `/:platform-role/onboarding` | ✅ | ✅ | ✅ | ◐ | Populated list/card layout verified. |
| PLAT-006 | Resume onboarding | `/:platform-role/onboarding/:schoolCode` | ✅ | ✅ | ✅ | ◐ | Populated resumed form verified; compact footer defect fixed. |
| PLAT-007 | Needs Attention | `/:platform-role/attention` | ✅ | ✅ | ✅ | ◐ | Populated visual baseline; smoke covers all three platform roles. |
| PLAT-008 | Account Managers | `/:platform-role/account-managers` | ✅ | ✅ | ✅ | ◐ | Populated baseline and Account Manager role guard verified; compact heading/action composition fixed. |
| PLAT-009 | Account manager detail | `/:platform-role/account-managers/:managerName` | ✅ | ✅ | ✅ | ◐ | Deterministic direct route added for visual coverage. |
| PLAT-010 | Platform Audit & Activity | `/:platform-role/audit-activity` | ✅ | ✅ | ✅ | ◐ | Populated metrics, filters, and activity verified. |

## School Admin primary navigation

| ID | Surface | Menu path | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| ADM-001 | Dashboard | `/school-admin?page=dashboard` | ✅ | ✅ | ✅ | ◐ | Populated administrator landing verified. |
| ADM-002 | Requests & Approvals | `/school-admin?page=approvals` | ✅ | ✅ | ✅ | ◐ | Mobile cards and tablet layout verified; detail behavior has widget coverage. |
| ADM-003 | School Calendar | `/school-admin?page=calendar` | ✅ | ✅ | ✅ | ◐ | Responsive scroll treatment fixed and verified. |
| ADM-004 | My Leave | `/school-admin?page=my-leave` | ✅ | ✅ | ✅ | ◐ | Personal role surface verified with deterministic data. |
| ADM-005 | Admissions | `/school-admin?page=admissions` | ✅ | ✅ | ✅ | ◐ | Primary list/state verified; detailed flow has Flutter tests. |
| ADM-006 | Students | `/school-admin?page=students` | ✅ | ✅ | ✅ | ◐ | Populated register verified; profile/actions have Flutter tests. |
| ADM-007 | Student Attendance | `/school-admin?page=student-attendance` | ✅ | ✅ | ✅ | ◐ | Dashboard verified; class-register behavior has Flutter tests. |
| ADM-008 | Staff Attendance | `/school-admin?page=staff-attendance` | ✅ | ✅ | ✅ | ◐ | Dashboard verified; register behavior has Flutter tests. |
| ADM-009 | Households | `/school-admin?page=households` | ✅ | ✅ | ✅ | ◐ | Populated household summary verified. |
| ADM-010 | Staff Management | `/school-admin?page=staff` | ✅ | ✅ | ✅ | ◐ | Compact header/cards fixed; staff workflows have Flutter tests. |
| ADM-011 | Leave Management | `/school-admin?page=leave-management` | ✅ | ✅ | ✅ | ◐ | Reviewer surface verified with deterministic counts. |
| ADM-012 | Classes & Sections | `/school-admin?page=classes` | ✅ | ✅ | ✅ | ◐ | Populated classes and sections verified. |
| ADM-013 | Assessments | `/school-admin?page=assessments` | ✅ | ✅ | ✅ | ◐ | Administrator surface verified; workflow has Flutter tests. |
| ADM-014 | Evaluations & Comments | `/school-admin?page=evaluations` | ✅ | ✅ | ✅ | ◐ | Compact leadership controls fixed and verified. |
| ADM-015 | Final Reports | `/school-admin?page=final-reports` | ✅ | ✅ | ✅ | ◐ | Management summary verified. |
| ADM-016 | Term Closure | `/school-admin?page=term-closure` | ✅ | ✅ | ✅ | ◐ | Administrator closure dashboard verified; role variants have Flutter tests. |
| ADM-017 | Payroll | `/school-admin?page=payroll` | ✅ | ✅ | ✅ | ◐ | Permission-authorized surface verified. |
| ADM-018 | Fees & Requirements | `/school-admin?page=fees` | ✅ | ✅ | ✅ | ◐ | Overview and tab navigation verified. |
| ADM-019 | School Shop | `/school-admin?page=shop` | ✅ | ✅ | ✅ | ◐ | Overview verified; shop/reconciliation behavior has Flutter tests. |
| ADM-020 | Expenses & Petty Cash | `/school-admin?page=expenses` | ✅ | ✅ | ✅ | ◐ | Compact header fixed; overview and tabs verified. |
| ADM-021 | Audit & Activity | `/school-admin?page=audit` | ✅ | ✅ | ✅ | ◐ | Metrics and filters verified. |
| ADM-022 | Incident Management | `/school-admin?page=incidents` | ✅ | ✅ | ✅ | ◐ | Administrator summary verified; permissions have Flutter tests. |
| ADM-023 | Reports | `/school-admin?page=reports` | ✅ | ✅ | ✅ | ◐ | Role-scoped report library verified. |
| ADM-024 | Settings | `/school-admin?page=settings` | ✅ | ✅ | ✅ | ◐ | Settings hub verified. |

## Guardian

| ID | Surface | Entry | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| GUA-001 | Guardian portal | `/guardian` | ✅ | ✅ | ✅ | ◐ | Populated family summary and mobile bottom navigation verified. |
| GUA-002 | Guardian child detail | `/guardian?child=:studentId` | ✅ | ✅ | ✅ | ◐ | Populated learning/attendance overview and return action verified. |

## Cross-cutting states

| ID | State | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---:|---:|---:|---:|---|
| STATE-001 | Platform navigation drawer open | ✅ | ✅ | ✅ | ✅ | Existing baseline. |
| STATE-002 | School Admin navigation drawer open | ✅ | ✅ | ✅ | ✅ | Top and bottom drawer baselines prove the long menu remains scrollable and reachable. |
| STATE-003 | Empty data | ◐ | ◐ | ◐ | ◐ | Representative empty states exist across platform, academics, finance, and reports. |
| STATE-004 | API error and retry | ◐ | ◐ | ◐ | ◐ | Known rendered error states are rejected by browser tests; focused retry behavior remains in Flutter tests. |
| STATE-005 | Form validation errors | ✅ | ✅ | ◐ | ✅ | Critical public access validation and major workflow validation are covered by Flutter tests. |
| STATE-006 | Long text and long names | ✅ | ✅ | ✅ | N/A | Deterministic fixtures include long school, person, and request names. |
| STATE-007 | Keyboard and focus | ✅ | ✅ | N/A | ✅ | Recovery journeys scroll fields/actions into view at compact-mobile and tablet sizes. |
| STATE-008 | Browser zoom/text scaling | ✅ | ✅ | N/A | ✅ | Mobile body typography is 16 px; all 40 primary screens pass a 720 px reflow width equivalent to a 1440 px desktop at 200% zoom. |

## Explicit `*Screen` widget inventory

This source-derived list prevents nested screens from disappearing from scope. Some widgets map to a primary row above; others become nested-state rows during their phase.

1. AccountActivationScreen
2. AccountRecoveryScreen
3. _ApplicantDetailScreen
4. _GuardianDetailScreen
5. AdmissionsScreen
6. _StudentProfileScreen
7. _HouseholdPickerScreen
8. _HouseholdDashboardScreen
9. HouseholdsGuardiansScreen
10. _AdmissionFlowScreen
11. ApprovalsScreen
12. AssessmentDashboardScreen
13. EvaluationManagementScreen
14. TermEvaluationWorkflowScreen
15. AttendanceDashboardScreen
16. AttendanceScreen
17. AuditActivityScreen
18. AuthScreen
19. ClassTeacherSettingsScreen
20. ClassStreamSettingsScreen
21. ClassSubjectConfigurationScreen
22. GradeDetailScreen
23. GradeStreamsScreen
24. TeacherClassesScreen
25. ExpensesScreen
26. ClassRequirementsScreen
27. FeeManagementScreen
28. PriorTermRequirementsScreen
29. GuardianPortalScreen
30. IncidentsScreen
31. LeaveManagementScreen
32. PayrollScreen
33. AccountManagersScreen
34. _OnboardingSchoolsScreen
35. _AttentionSchoolsScreen
36. _SchoolsScreen
37. SchoolCreationScreen
38. SchoolDetailScreen
39. AccountManagerDetailScreen
40. AcademicTermSetupScreen
41. ReportsLibraryScreen
42. AcademicTermManagementScreen
43. SchoolSettingsScreen
44. SchoolShopScreen
45. ShopReconciliationScreen
46. StaffScreen
47. StaffAttendanceScreen
48. StaffAuthorisationsScreen
49. StudentsScreen
50. BursarTermClosingScreen
51. HeadmasterTermClosureScreen
52. TeacherTermClosingScreen
53. TermReviewScreen
