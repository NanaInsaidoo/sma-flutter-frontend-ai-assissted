# Staff roles and authorisations — implementation and test report

**Date:** 30 September 2026
**Frontend branch:** `feature/staff-roles-authorisations`
**Backend branch:** `feature/staff-roles-authorisations`
**Jira:** [SMA-21](https://narella.atlassian.net/browse/SMA-21)

## Delivered behaviour

- Job title and system authority are separate concepts. Schools can add their own job titles by choosing **Same authority as** an existing authority template.
- The standard titles are Headmaster, Headmistress, Principal, Assistant Headmaster, Assistant Headmistress, Assistant Principal, Head Teacher, Assistant Head Teacher, Administrator, Office Administrator, Secretary, Proprietor, Proprietress, Teacher, Bursar, Accountant, Cook, Security, Pastor, and Staff.
- Teacher is one job title. Class and subject responsibilities are controlled by assignments and scope, not by extra onboarding titles.
- Built-in authority templates cover School owner, Administrator, School leader, Assistant school leader, Teacher, Finance, Front office, and Staff only.
- A school can clone a built-in authority and add a precise allow or block rule without changing the built-in template.
- An administrator can add a one-person allow or block rule for a module, workflow resource, action, and scope. A block always wins over an allow.
- Authority and exception scopes support School, Assigned, Class, Subject, Campus, and Financial account.
- Finance supports a specific `PETTY_CASH_TOP_UP` workflow resource. A Bursar permission for that resource does not silently grant the same action throughout Finance.
- Sensitive grants, including Administrator and School owner, remain pending until a different authorised manager approves them.
- Ordinary one-person blocks are effective immediately. Revocation and expiry remove their effect.
- Access changes increment the user's authentication version so previously issued sessions are invalidated.
- Every access grant, block, approval, rejection, revocation, title change, and automatic expiry is audited.
- Affected staff and relevant managers receive in-application notifications for access changes and pending approvals.
- Staff onboarding uses the selected job title's authority. Employment type is optional, and references remain optional unless a reference section has been started.
- Inactive, suspended, or deleted users cannot regain access through a role, authority template, or individual exception.

## Safety rules

1. A manager cannot change their own authority or individual permission exceptions.
2. A manager cannot grant an authority or permission they do not hold themselves.
3. A sensitive change needs a second authorised manager; the requester cannot approve it.
4. The last active school manager cannot be removed or blocked from management access.
5. Every staff, authority, title, assignment, and exception is checked against the requested school tenant.
6. Individual blocks take precedence over individual allows, template allows, and legacy roles.
7. A scoped authority is evaluated only inside its matching scope; it never becomes a school-wide role.
8. Expired, revoked, rejected, or future-dated rules do not affect access.

## Defects found and fixed

| ID | Defect | Resolution | Verification |
|---|---|---|---|
| AUTH-01 | Onboarding used a hard-coded list of technical roles and mixed job titles with permissions. | Added configurable job titles linked to reusable authority templates. | API, onboarding widget, and screen tests. |
| AUTH-02 | Class teacher and subject teacher appeared as separate job choices even though the difference is an assignment. | Replaced both onboarding choices with Teacher; preserved class/subject assignment behaviour. | Staff onboarding widget tests and full regression suite. |
| AUTH-03 | Access was additive only; one Bursar could not be blocked from editing petty-cash top-ups without changing every Bursar. | Added per-user ALLOW/DENY exceptions with DENY precedence and resource-level evaluation. | Permission service tests cover one affected Bursar, an unaffected Bursar, retained view/delete, and unrelated Finance actions. |
| AUTH-04 | Authority grants could not be limited to assigned classes, subjects, campuses, or accounts. | Added typed scope and scope identifier to assignments, exceptions, permission checks, and the UI. | Matching and non-matching scope tests. |
| AUTH-05 | High-privilege changes could be applied by one person. | Added pending state, independent approval, requester/approver separation, grantor ceiling, and last-manager protection. | Authorisation service tests and live restriction checks. |
| AUTH-06 | A scoped authority was initially also added to the user's global role set. | Global role derivation now includes school-wide authority only; scoped authority is evaluated per request. | Regression test proves the same permission is denied outside its scope. |
| AUTH-07 | Existing legacy roles could have lost access when the new model was introduced. | Added a compatibility bridge for legacy roles while making explicit individual blocks authoritative. | Tests cover every persisted role and confirm ordinary Staff, Guardian, and Student users gain no administrative access. |
| AUTH-08 | Expiry could silently remove sensitive access without informing anyone. | Added a scheduled expiry job, audit events, staff notifications, and manager notification for sensitive expiry. | Expiry and notification tests. |
| AUTH-09 | Employment type was unnecessarily required during staff onboarding. | Removed the mandatory constraint while retaining conditional validation for started sections. | Backend validation and onboarding widget tests. |
| AUTH-10 | The authorisation error view accepted a retry callback but exposed no retry control. | Added a visible Try again action. | Static analysis and authorisation screen tests. |
| AUTH-11 | Cancelling or failing early in the Add job title dialog left text controllers undisposed. | Disposed both controllers on every exit path. | Static analysis and widget regression suite. |
| AUTH-12 | The live staff endpoint returned its records in a `users` list, but the Individual access client only decoded `content`, `data`, or `items`; the Staff member dropdown therefore appeared empty. | Added support for the live paginated `users` envelope while continuing to exclude non-staff accounts. | API regression test uses the real envelope shape, and the UI test opens the selector and verifies the staff option is displayed. |
| AUTH-13 | The page title, safety guidance, and tabs remained fixed above the workspace, consuming almost half of a short viewport and leaving too little room for the actual settings. | Moved the title and guidance into the scrollable header and kept only the tab bar pinned. | A constrained-height widget test scrolls the guidance away and verifies the tabs remain visible and usable. |
| AUTH-14 | Equivalent role values could be returned in different formats, causing duplicate labels such as `Teacher` and `Teacher` on one staff member. | Normalised and deduplicated role labels after applying the user-facing formatter, while preserving genuinely different roles. | The individual-access UI test supplies `TEACHER` and `Teacher` and verifies that only one `Teacher` label is rendered. |
| STAFF-15 | Manual staff onboarding calculated gross salary only when saving, leaving the visible Gross salary field blank even after pay and allowances were entered. | Gross salary now updates live as basic pay plus house, transport, and other allowances; the calculated field is read-only and the same value is submitted. | Calculation test verifies `5000 + 50 + 200 + 567 = 5817`, and an end-to-end onboarding widget test verifies the displayed `5,817.00` value. |
| PAYROLL-16 | Staff onboarding mixed identity and employment capture with salary, tax, pension, and allowance configuration. | Replaced the Payroll step with an optional Payment account step. Salary, SSNIT, PAYE, allowances, deductions, and reliefs now live in a dedicated Payroll workspace. | End-to-end onboarding test confirms salary and tax fields are absent and a bank account can be saved; `Add later` remains the default. |
| PAYROLL-17 | Staff Management preloaded every employee's salary record under the general user-management permission. | Removed payroll loading and the Payroll & Tax profile tab from Staff Management, introduced a separate `PAYROLL` permission module, and protected every payroll read/write endpoint independently. | Permission tests cover Administrator, Head Teacher, Bursar, Teacher, individual deny, and retained general-finance access. |
| PAYROLL-18 | A payment account added later could not be completed from payroll, and activation could proceed without a payment destination. | Added masked Bank/Mobile Money management to Payroll, draft saving without an account, and server-side rejection of activation until an account and effective date exist. | Service and widget tests cover masking, draft setup, activation calculation, missing-account rejection, and view-only controls. |

No known staff-authorisation product defect remains open from this test pass.

## Automated test scope

### Backend

- Default authority and job-title creation.
- Individual allow and block precedence.
- Resource-specific petty-cash top-up permissions.
- School, assigned, class, subject, campus, and financial-account scope matching.
- Active, pending, rejected, revoked, expired, and future-dated rules.
- Legacy role compatibility and every persisted user role.
- Inactive, suspended, and deleted account denial.
- Self-change prevention, grantor ceiling, tenant isolation, duplicate prevention, second-person approval, and last-manager protection.
- Audit, session invalidation, affected-user notifications, manager notifications, and automatic expiry.
- Staff onboarding, invitation activation, optional employment type, optional references, and sensitive-title approval.
- Existing attendance, leave, approval, evaluation, finance, staff, guardian, and platform tests through the complete backend regression suite.

Result: `mvn -q test` passed.

### Frontend

- Settings navigation to Staff roles & authorisations.
- Job-title listing, human-readable role labels, custom title creation, and activation/deactivation.
- Authority listing and safe custom-authority creation.
- Staff selection, scoped authority assignment, individual allow/block rule creation, effective-access display, and revocation controls.
- Sensitive approval queue actions.
- Staff onboarding with configurable titles, one Teacher title, optional employment type, and optional references.
- Staff onboarding payment account capture, confirmation matching, and add-later behaviour without salary fields.
- Dedicated payroll staff directory, draft/active states, masked payment accounts, server-authoritative gross-to-net calculation, and activation safeguards.
- Separate payroll view/edit permissions, individual restrictions, and view-only UI behaviour.
- API payload/response handling and server safety messages.
- Regression coverage for staff, attendance, leave, approvals, evaluations, finance, students, guardians, and related screens.

Results:

- `flutter analyze` passed with no issues.
- Focused authorisation and staff-onboarding tests passed.
- Full Flutter test suite passed (539 tests).

## Live one-port verification

The complete application was built and run at `http://127.0.0.1:3000`.

Verified against the current Akwaaba Learning Academy data:

- home application response: HTTP 200;
- authorisation catalog, eight built-in authorities, twenty standard job titles, pending queues, and effective access: HTTP 200 for an Administrator;
- teacher, school leader, guardian, anonymous, and cross-school access to management endpoints: HTTP 403;
- self-assignment and self-exception safety requests: HTTP 403 with no records created;
- teacher's own evaluation workflow: HTTP 200;
- teacher access to attendance management: HTTP 403;
- administrator attendance workflow: HTTP 200;
- guardian's own portal workflow: HTTP 200.

### Live individual-access lifecycle

A real create-and-revoke test was completed using Kofi Nketia as the acting Administrator and Adjoa Mensah as the affected Administrator:

1. Confirmed both users initially inherited **Finance → Petty cash top-up → Edit**.
2. Created a school-scoped individual `DENY` exception for Adjoa only.
3. Confirmed Adjoa's effective decision changed to **Blocked — individual restriction**.
4. Confirmed Kofi's matching decision remained **Allowed — inherited from Administrator**.
5. Revoked the test exception.
6. Confirmed Adjoa's effective decision returned to **Allowed — inherited from Administrator**.
7. Confirmed the exception is stored as `REVOKED`, request and revocation audit events exist, both staff notifications exist, and Adjoa's authentication version advanced to invalidate sessions issued before either access change.

Result: live individual-access lifecycle passed.

The current local database contains Akwaaba accounts whose passwords are private and different from the obsolete credentials in `docs/local-demo-uat.md`; the documented `demo.*` users are not present. Those accounts were not reset or replaced because unrelated data must be preserved. Live access was verified with a short-lived signed local session. The individual-access lifecycle deliberately retained its revoked exception, audit events, and notifications as the required trace of the test; no active test grant or block remains.

## Data preservation

- No existing staff account, job title, authority assignment, password, or school record was deleted or overwritten.
- The temporary individual block was revoked and effective access was restored. Its revoked record, audit history, notifications, and session-version changes remain by design.
- Rejected live safety requests created zero records.
- Existing unrelated working-tree changes were left untouched.
- The application remains running on port 3000.
