# Local Stable Demo School and UAT Accounts

## Purpose

This local-only environment gives testers one predictable school and permanent credentials after a clean `gogo` database rebuild. It is intended for repeatable identity, login, role, and account-boundary testing. It must not be copied to production.

The database was rebuilt with no backup and contains no legacy records or timestamped identity-test schools.

## Demonstration school

- **Name:** SMA Demonstration Academy
- **School code:** `SMA-DEMO-001`
- **Current state:** approved and operational; every required readiness item is complete.
- **Academic context:** Second Term, 2026-2027. For the local rollover test, its operational opening was moved to 21 August 2026 while teaching remains scheduled to begin on 11 January 2027 and end on 16 April 2027.
- **Class structure:** Basic 1 and Basic 2, each with two active streams (four streams total).
- **Published term fees:** Basic 1 — GH₵1,600; Basic 2 — GH₵1,700.

The three-part school code is required by the admission, student, and guardian business-ID generators.

## Permanent local credentials

| Persona | Global username | Password | Account boundary and roles |
|---|---|---|---|
| Platform administrator | `superadmin` | `Admin@123` | Platform-wide `SUPER_ADMIN` |
| School administrator, bursar, and teacher | `demo.admin` | `DemoAdmin@12345` | One staff account with `ADMINISTRATOR`, `BURSAR`, `CLASS_TEACHER`, and `SUBJECT_TEACHER` |
| Class and subject teacher | `demo.teacher` | `DemoTeacher@12345` | One staff account with `CLASS_TEACHER` and `SUBJECT_TEACHER` |
| Parent/guardian | `demo.guardian` | `DemoGuardian@12345` | Guardian account linked to the Abena Ofori household |
| Teacher's separate parent access | `demo.teacher.guardian` | `DemoTeacherGuardian@12345` | Guardian account for the same real person as `demo.teacher`, with separate credentials and sessions |

`demo.teacher` and `demo.teacher.guardian` reference one internal person identity, but remain separate staff and guardian accounts as required by the business rules.

## Expected login results

1. `demo.admin` authenticates with both Administrator and Bursar roles and opens the operational school dashboard.
2. `demo.teacher` authenticates with both Class Teacher and Subject Teacher roles and can open only Akosua Owusu's own evaluation assignment.
3. `demo.guardian` opens the parent route and resolves a real linked household in the configured current-term context.
4. `demo.teacher.guardian` signs in independently from `demo.teacher` and receives guardian-only access.

The earlier **parent account is not linked to a household** error is not expected and should be treated as a regression.

## Verified database state

- 1 school
- 5 users including the platform super administrator
- 2 households
- 2 guardian records, both linked to login accounts
- 2 staff profiles, linked to the Nana Boateng and Akosua Owusu login accounts
- 1 approved and current academic term
- 2 active grade levels and 4 active streams
- 2 published fee structures covering every active grade
- 212 districts
- 108 grade-specific subjects
- 8 fee types
- 20 expense categories
- 4 school education levels
- 9 blood groups

## Completed academic-cycle scenario

The Basic 1 Section 1 term workflow now contains real local data rather than UI-only placeholders:

- 5 active students
- 9 subjects
- 45 completed assessments (CAT 1-4 and end-of-term examination for every subject)
- 225 submitted student scores
- 3 active teacher-evaluation assignments, all submitted
- 5 finalized class-teacher evaluation reviews and comments
- 5 progression decisions to Basic 2
- 5 generated and published report cards
- 5 downloadable one-page PDF report cards

The evaluation cycle is locked. A teacher receives `403` when opening another teacher's assignment and `409` when trying to save or submit after the lock.

Both stream-level **Publish** and school-wide **Publish All** were exercised in the live UI. Each action updated the backend and refreshed the dashboard to 5 published and 0 pending.

The canonical lookup seed was run twice after the rebuild and the counts remained unchanged.

## Verified term rollover and vacation operation

The complete First Term to Second Term transition was exercised through the live Administrator UI.

- The Fee Structure screen can now select either the current term or a prepared term. This affects fee-structure setup only; payments and all other fee work remain bound to the current operational term.
- Second Term Basic 1 and Basic 2 structures were created and published before closing First Term.
- Term Review reached 10 ready checks, 0 blockers, and 0 warnings after the local test closing date was reached.
- Closing First Term applied 5 progression decisions, carried forward GH₵6090, created 15 new-term fee lines, and made Second Term operational.
- All 5 students moved from Basic 1 to Basic 2 immediately.
- Correct post-transition balances were verified: Kofi GH₵2900, Ama GH₵2400, Yaw GH₵2800, Esi GH₵3350, and Kwesi GH₵3140.
- A GH₵100 vacation payment for Ama was received against Second Term and produced receipt `RCPT-20260821-006`; her balance changed from GH₵2400 to GH₵2300.
- A reversal request for that receipt was submitted to Akosua Owusu and then cancelled by Nana Boateng. The payment remained completed, Ama's paid amount remained GH₵100, and her balance remained GH₵2300.
- Admissions remained available during the vacation operational period.
- Creating an assessment before teaching starts remained available, but displayed the required warning and rejected a reason shorter than five characters.

The dates above were adjusted directly in the local test database solely to open the closing window on the test day. No production date rule was weakened.

### Serious issue found and fixed during rollover

Publishing a prepared-term fee structure previously assessed students immediately using their old grade. The term transition then promoted those students and assessed the destination grade as well, causing duplicate charges. The backend now refuses to assess students when publishing a non-current term. New-term charges are created only after progression is applied or when a student is admitted. A regression test covers this rule, and the 15 invalid local test lines were removed before the balances above were verified.

## Rebuild and recreation

The exact local database must be empty before running the stable demo creator. The creator establishes the stable school and accounts; the remaining school onboarding can then be completed through the platform UI using the values documented in this file.

1. Start the backend with the local profile and local testing-code exposure enabled.
2. Apply `src/main/resources/db/seed/lookup.sql` after Hibernate creates the schema.
3. Run `scripts/create-stable-demo-school.sh` once.

The creation script deliberately uses fixed school and account identifiers. It is not intended to be rerun without clearing the local database first.

## Final acceptance evidence

- Backend: 214 tests passed; 0 failures; 0 errors; 0 skipped.
- Frontend: 163 tests passed.
- Frontend analysis: no issues found.
- Live UI: platform onboarding, three required document uploads, approval, Administrator/Bursar login, operational dashboard, four-stream class list, published fee structures, teacher-option lookup, and class-teacher assignment were exercised through the real UI.
- Live finance audit: cancelled reversal details showed Nana Boateng as requester and decision maker, Akosua Owusu as assigned approver, and the original receipt remained active.
- Readiness API: all four required items return `COMPLETED` and `ready: true`.
- API/JWT: role collections were confirmed for all four permanent accounts.
- Database: staff multi-role boundaries, separate staff/guardian accounts, shared person identity, and real guardian-household links were confirmed.

## Issues found during the completed cycle

1. Bulk activation accepted `ACTIVE` but did not synchronize the student record out of Draft. The status mapping and regression coverage were added.
2. Final Report Management previously changed local UI counters without publishing the reports. Stream-level and school-wide actions now call the report publication API and reload authoritative totals.
3. Teaching allocation now checks the staff member's real account roles. If `CLASS_TEACHER` or `SUBJECT_TEACHER` is missing, the UI pauses and asks the administrator whether to grant it. Cancelling changes neither the permission nor the assignment. Confirming updates the account and the school membership before completing the assignment; the change is processed through the same audited role-management API used by **Manage roles**.
4. Publishing prepared-term fees could double-charge promoted students. Prepared-term publication now stores the structure without assessing current students; the rollover or later admission performs the assessment at the correct grade.
5. An already-open Term Review could retain the closed-term checklist after rollover. Term Review, teacher review, bursar closure, and headmaster closure now reload the new operational term immediately. The rollover regression test also exposed and fixed a dialog-controller lifecycle error.
6. Continuing students created during local setup could be labelled **New this term** after rollover. Student details now carry the actual admission-term identifier, and the register compares that identifier with the current term instead of relying on the record creation date.
7. Fee-approval choices could show a staff member's default workspace role instead of the roles that make the person eligible to approve. The API now returns all relevant approval roles, for example `ADMINISTRATOR / BURSAR`.
8. Resolved incidents now show 100% completion. A later action is described as a **Post-resolution follow-up** rather than the contradictory **Follow-up required** state.
9. Bursar recommendation quantities, unit prices, descriptions, and reasons are now separated into readable fields instead of visually running together.
10. Historical fee-adjustment and payment-reversal audit records now resolve requester, creator, updater, approver, and decision-maker IDs to display names. Internal role codes are returned with readable labels, and approver-change history shows the people involved rather than numeric identifiers.
11. Payment-reversal actions are now identity-aware in both finance dialogs. A requester sees only cancel and change-approver actions; the independently assigned approver sees only reject and approve. Regression tests cover both views, and the live requester screen was verified before the temporary request was cancelled.

The three uploaded PDF files are local workflow fixtures used to verify upload and S3 document handling. They are not genuine school registration documents and must never be treated as legal evidence.

## Before production

The current identity-code delivery uses the existing email path for pre-production testing. Before production, replace it with the approved SMS provider, test Ghanaian number delivery/retry/outage cases, and ensure `identity.testing.expose-otp` is disabled.
