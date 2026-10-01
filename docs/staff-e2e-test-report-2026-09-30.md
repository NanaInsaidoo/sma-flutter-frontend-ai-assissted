# Staff end-to-end test report

**Application:** SMA one-port application at `http://localhost:3000`
**School:** Akwaaba Learning Academy
**Test date:** 30 September 2026
**Primary test account:** Existing school administrator account
**Browser:** Codex in-app browser, Flutter web accessibility enabled

## Outcome

The staff area was exercised from the UI across creation/onboarding, directory and profiles, roles, assignments, attendance, leave, notifications, editing, lifecycle safeguards, validation, and role-based navigation. Six defects were confirmed and repaired. The affected workflows were rebuilt and retested in the one-port application.

The synthetic staff record **E2E Tester** was created for this run. It contains the test employment profile, payroll/tax values, resume, two synthetic references, the `CLASS_TEACHER` and `BURSAR` roles, and a pending activation invitation. Existing operational records were not deleted. The temporary edit to Sena Owusu's first name and the temporary `SECRETARY` role were restored immediately; their audit entries remain as expected. Adjoa Mensah was temporarily suspended to verify sign-in denial, then reactivated and verified able to sign in again.

## Defects found and fixed

| ID | Severity | Defect | Fix | Retest |
|---|---|---|---|---|
| STAFF-01 | High | Staff profiles always showed “No assignments yet” because the UI hard-coded an empty assignment list, even though Classes & Sections showed Sena Owusu assigned to multiple classes and a subject. | Loaded active class-teacher and subject-teacher assignments for every configured stream and mapped them by staff profile ID. | Pass. Sena's profile now lists 11 current assignments, including Basic 1, Creche, KG1, KG2, JHS 1 and JHS 3. |
| STAFF-02 | High | Invited staff profiles lost the entered email/phone and role set, used the job title as the role, and classified teaching invitations as support staff. This also made the staff metrics wrong. | Added invitation email, masked phone, primary role and role set to the staff-profile response; parsed them in Flutter and derived category from the primary role. | Pass. E2E Tester displays the supplied email, masked phone, `Class Teacher · Bursar`, and Teaching category. Metrics changed from 2 teaching / 5 support to the correct 3 teaching / 4 support. |
| STAFF-03 | High | Payroll & Tax always displayed “Not configured,” even when onboarding had successfully saved finance data. | Added profile finance loading and rendered basic salary, total allowances, gross salary, SSNIT and TIN values. | Pass. E2E Tester displays GH₵1.00 basic/gross salary and the saved synthetic SSNIT/TIN values. |
| STAFF-04 | High | The Activity tab fabricated three “Today” entries whenever a profile was opened. | Replaced generated entries with the user's recent audit-log endpoint and a truthful empty state. | Pass. Sena's profile shows real login and profile-edit audit events with actors and timestamps. |
| STAFF-05 | High | Active staff profiles had no UI for editing or account lifecycle management. | Added validated profile editing; reversible suspension/reactivation; clearly separated permanent deactivation with a mandatory audit reason; and blocked lifecycle actions on the signed-in account. | Pass. Profile editing persisted and was restored; role changes persisted and were restored; suspension immediately blocked sign-in with HTTP 403; reactivation restored Active status and sign-in with HTTP 200; validation, warnings, and self-action prevention also passed. |
| STAFF-06 | Critical | Staff-management endpoints were authenticated but not consistently role- or tenant-restricted. A restricted same-school account could potentially call staff endpoints directly, and the profiles endpoint did not enforce school membership. | Applied an administrator/head/secretary role boundary to the staff-management controller, added `USER_MANAGEMENT:VIEW` checks to profile/payroll reads, enforced school access on profile listing, and added tenant verification for staff-ID lookups. | Pass. The existing administrator receives 200 for its school, a cross-tenant profile request receives 403, and the access contract test excludes Bursar/Class Teacher/Subject Teacher. |

## Workflow coverage

| Area | UI checks | Result |
|---|---|---|
| Staff creation | Manual creation; required identity fields; email and phone validation; role selection; employment details; required basic pay; resume requirement and upload; two complete references; invitation/profile persistence | Pass. Synthetic invited staff record retained for inspection. |
| Directory and search data | Active/invited states, current-user badge, email/phone, roles, department, start date, metric totals | Pass after STAFF-02. |
| Profiles | Overview, employment, assignments, payroll/tax, documents, leave, activity | Pass after STAFF-01, STAFF-03 and STAFF-04. |
| Roles and permissions | Manage Roles dialog; primary role lock; additional role controls; subject-teacher guidance; live persistence/restore; restricted Bursar navigation | Pass. `Secretary` was temporarily added to Sena Owusu, appeared on the refreshed profile, then was removed; the original `Class Teacher · Subject Teacher` role set was restored. |
| Assignments | Cross-checked Classes & Sections against Sena Owusu's staff profile | Pass after STAFF-01. |
| Staff attendance | Term dashboard, missing-register list, new register, incomplete-submit validation, submitted-register view and correction state | Pass. No attendance record was changed. |
| Leave | Management totals, request list, approved request details, personal profile leave, blank request validation | Pass. No leave record was changed. |
| Notifications | Notification panel and staff-generated correction notifications | Pass. |
| Editing | Invalid email rejection, successful name edit, refreshed profile, restoration to original value, audit history | Pass after STAFF-05. |
| Suspension/reactivation | UI action availability, mandatory reason, live status change, suspended sign-in denial, reactivation, restored sign-in, self-action block | Pass. Adjoa Mensah changed from Active to Suspended, a fresh sign-in was rejected with HTTP 403, reactivation restored Active status, and a fresh sign-in succeeded with HTTP 200. |
| Permanent deactivation | Separate irreversible warning, mandatory reason, self-action block | Safeguards pass. Not executed against an existing account to avoid irreversible test-data loss. |
| Access restrictions | Bursar workspace hides Staff Management and Staff Attendance; controller role contract; cross-tenant 403 | Pass after STAFF-06. |

## Automated verification

- Flutter static analysis passed for the changed staff files.
- All 13 Flutter staff regression tests passed, including assignment aggregation, invitation fields, payroll parsing, audit activity parsing, lifecycle endpoint contracts, attendance, approved-leave handling, performance review, current-user badge, and resume upload.
- Spring backend compilation passed.
- `StaffManagementAccessContractTest` passed.
- Flutter web production build passed.
- The rebuilt Spring/Flutter one-port application was restarted successfully on port 3000.

## Data preservation

- Existing staff names and contact information were restored after the edit test.
- The user-confirmed temporary role and account-status changes were restored: Sena Owusu is `Class Teacher · Subject Teacher`, and Adjoa Mensah is Active. Attendance registers and leave requests were not changed.
- No existing invitation or staff account was deleted or permanently deactivated.
- Unrelated working-tree changes were left untouched.
