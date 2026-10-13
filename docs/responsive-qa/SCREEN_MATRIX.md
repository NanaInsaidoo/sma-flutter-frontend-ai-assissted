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
| PUB-001 | Login | `/login` | ✅ | ✅ | ✅ | ◐ | Baselines exist; full validation/error matrix remains. |
| PUB-002 | Account activation | `/activate/:token` | ◐ | ◐ | ◐ | — | Initial populated confirmation baseline; invalid, expired, verified, and completed states remain. |
| PUB-003 | Username recovery | `/recover-username` | ◐ | ◐ | ◐ | — | Initial form baseline; validation, verification, success, and error states remain. |
| PUB-004 | Password reset | `/reset-password` | ◐ | ◐ | ◐ | — | Initial form baseline; validation, verification, success, and error states remain. |

## Platform administration

| ID | Surface | Entry | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| PLAT-001 | Platform overview | `/:platform-role` | ✅ | ✅ | ◐ | ◐ | Visual baseline is Super Admin; smoke covers three roles. |
| PLAT-002 | Schools | `/:platform-role/schools` | ✅ | ✅ | ◐ | ◐ | Visual baseline is Super Admin; tablet table defect fixed. |
| PLAT-003 | Create school | `/:platform-role/schools/new` | — | — | — | — | Multi-step form and validation states. |
| PLAT-004 | School detail | `/:platform-role/schools/:schoolCode` | — | — | — | — | Include actions, documents, and assignment sections. |
| PLAT-005 | Onboarding schools | `/:platform-role/onboarding` | — | — | — | — | List/card layout. |
| PLAT-006 | Resume onboarding | `/:platform-role/onboarding/:schoolCode` | — | — | — | — | Multi-step responsive form. |
| PLAT-007 | Needs Attention | `/:platform-role/attention` | ✅ | ✅ | — | ◐ | Smoke covers three roles; populated visuals pending. |
| PLAT-008 | Account Managers | `/:platform-role/account-managers` | ✅ | ✅ | ◐ | ◐ | Visual baseline is Super Admin; role guard covered. |
| PLAT-009 | Account manager detail | In-app selection | — | — | — | — | Include assignment and profile actions. |
| PLAT-010 | Platform Audit & Activity | `/:platform-role/audit-activity` | — | — | — | — | Dense data/cards and filters. |

## School Admin primary navigation

| ID | Surface | Menu path | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| ADM-001 | Dashboard | Dashboard | — | — | — | — | Administrator and teacher landings differ. |
| ADM-002 | Requests & Approvals | Requests & Approvals | — | — | — | — | Include mobile approval cards and detail dialog. |
| ADM-003 | School Calendar | School Calendar | — | — | — | — | Event details/add/edit dialogs. |
| ADM-004 | My Leave | My Leave | — | — | — | — | Personal role variant. |
| ADM-005 | Admissions | People → Admissions | — | — | — | — | Nested flow inventory required. |
| ADM-006 | Students | People → Students | — | — | — | — | Register, filters, profile, and actions. |
| ADM-007 | Student Attendance | People → Student Attendance | — | — | — | — | Dashboard and class register. |
| ADM-008 | Staff Attendance | People → Staff Attendance | — | — | — | — | Register and report preview. |
| ADM-009 | Households | People → Households | — | — | — | — | Household and guardian details. |
| ADM-010 | Staff Management | People → Staff Management | — | — | — | — | List, onboarding, profile tabs, account actions. |
| ADM-011 | Leave Management | People → Leave Management | — | — | — | — | Reviewer role variant. |
| ADM-012 | Classes & Sections | Academics → Classes & Sections | — | — | — | — | Grade, stream, subjects, and settings. |
| ADM-013 | Assessments | Academics → Assessments | — | — | — | — | Administrator and teacher variants. |
| ADM-014 | Evaluations & Comments | Academics → Evaluations & Comments | — | — | — | — | Workflow and class selection. |
| ADM-015 | Final Reports | Academics → Final Reports | — | — | — | — | Report generation and preview. |
| ADM-016 | Term Closure | Academics → Term Closure | — | — | — | — | Headmaster, teacher, and bursar variants. |
| ADM-017 | Payroll | Finance & Operations → Payroll | — | — | — | — | Permission-dependent. |
| ADM-018 | Fees & Requirements | Finance & Operations → Fees & Requirements | — | — | — | — | Eight tabs plus overview drill-downs. |
| ADM-019 | School Shop | Finance & Operations → School Shop | — | — | — | — | Fourteen pages plus reconciliation. |
| ADM-020 | Expenses & Petty Cash | Finance & Operations → Expenses & Petty Cash | — | — | — | — | Tabs, ledger pages, and dialogs. |
| ADM-021 | Audit & Activity | Insights & Oversight → Audit & Activity | — | — | — | — | Filters, cards/table, and details. |
| ADM-022 | Incident Management | Insights & Oversight → Incident Management | — | — | — | — | Administrator and teacher variants. |
| ADM-023 | Reports | Insights & Oversight → Reports | — | — | — | — | Role-scoped library and previews. |
| ADM-024 | Settings | Settings | — | — | — | — | Hub plus four destinations. |

## Guardian

| ID | Surface | Entry | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---|---:|---:|---:|---:|---|
| GUA-001 | Guardian portal | `/guardian` | — | — | — | — | Membership and multi-child variants. |
| GUA-002 | Guardian child detail | In-app selection | — | — | — | — | Profile sections and return behavior. |

## Cross-cutting states

| ID | State | Mobile | Tablet | Visual | Interaction | Notes |
|---|---|---:|---:|---:|---:|---|
| STATE-001 | Platform navigation drawer open | ✅ | ✅ | ✅ | ✅ | Existing baseline. |
| STATE-002 | School Admin navigation drawer open | — | — | — | — | Verify accordion and scroll reachability. |
| STATE-003 | Empty data | — | — | — | — | Sample per major product area. |
| STATE-004 | API error and retry | — | — | — | — | Sample per major product area. |
| STATE-005 | Form validation errors | — | — | — | — | Every critical form workflow. |
| STATE-006 | Long text and long names | — | — | — | — | Ghanaian school/person examples. |
| STATE-007 | Keyboard and focus | — | — | N/A | — | Mobile viewport and keyboard-safe scrolling. |
| STATE-008 | Browser zoom/text scaling | — | — | — | — | 200% zoom and large text stress. |

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
