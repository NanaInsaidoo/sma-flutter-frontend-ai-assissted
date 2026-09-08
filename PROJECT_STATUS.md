# SMA Project Status

Last updated: 2026-09-08

This file is the durable source of truth for implementation and verification
status across the Flutter frontend and Spring Boot backend.

## Status Vocabulary

- `VERIFIED`: exercised successfully against the real local backend.
- `PARTIALLY_VERIFIED`: core behavior passed, but identified edge flows remain.
- `IMPLEMENTED_NOT_VERIFIED`: code exists but has not passed a real-data test.
- `FAILING`: a reproducible defect is known.
- `BLOCKED`: verification cannot proceed because of an external dependency.

## Repositories

- Frontend: `/Users/matic/Documents/SMA-Fontend/school_management_app`
- Backend: `/Users/matic/Documents/spring-server-generated`
- Local API: `http://localhost:8080/Narellallc/sma-v1/1.0.0`

Do not use mock or fallback data for connected production workflows. Do not
commit or push unless explicitly requested.

## Expenses & Petty Cash

Overall status: `VERIFIED`

Verified against the real local backend:

- Current academic context and active petty-cash cycle loading
- Petty-cash setup and initial-float lifecycle
- Standard petty-cash requisition, approval, lower actual spend, and variance review
- Emergency petty-cash spend, mandatory second-actor ratification, variance
  escalation, and financial follow-up creation
- School-funds requisition, approval, bank spend, and partial refund without
  changing the petty-cash float
- Top-up request, named approver, named disburser, Cash/MoMo allocation,
  requester confirmation, cancellation, decline, approval revocation, dispute,
  correction, and final confirmation
- Cash-to-MoMo pocket transfer with an editable transfer fee
- Reconciliation request, concurrent-request prevention, count, evidence,
  shortage resolution, closure, and pocket correction
- Manual and reconciliation-generated financial follow-ups, due dates, linked
  references, append-only notes, and administrator closure
- Actor restrictions for requester, selected approver, disburser, and receiver
- Final pocket balances and dashboard aggregates updating from backend data

Automated evidence:

- `flutter analyze` passed with no issues.
- `flutter test` passed: 409 tests.
- Live Flutter Web/Playwright finance checks passed: 2 tests against the real
  local API, including workspace loading and requester top-up cancellation.
- `mvn -q test` passed: 460 tests across 77 reports, with no failures, errors,
  or skipped tests.
- Focused `FinanceWorkflowServiceTest` actor, refund, follow-up, and
  reconciliation tests passed.

Real-data evidence:

- A disposable school finance cycle was exercised through the UI with separate
  requester and approver/disburser accounts.
- A disputed top-up was corrected from the wrong split and confirmed by the
  original requester; its event timeline remained visible.
- A shortage reconciliation corrected the Cash pocket and created a linked
  staff-recovery follow-up, which retained notes through closure.
- An attempted refund beyond the remaining refundable amount was rejected and
  did not create another refund record.

Known data and cleanup notes:

- Disposable finance records for the test school are removed after the final
  test run so the next manual journey starts at petty-cash setup.
- Test users remain available for future separation-of-duty checks.

Remaining production-hardening checks:

- Upload and securely view a real S3 receipt file.
- Expand the reusable Playwright suite beyond its current workspace and top-up
  mutation coverage; the remaining actor journeys were exercised interactively.
- Complete and validate management reports before treating the Reports tab as
  production-ready.

## Admissions

Overall status: `PARTIALLY_VERIFIED`

Verified against the real local backend:

- Lookup-backed guardian fields, including genders, nationality, religion,
  languages, identity types, regions, districts, and cities
- Guardian multistep persistence for basic details, contact, address,
  identification, occupation, and skills
- Guardian final review and primary-guardian persistence
- Student multistep persistence and hydration
- Student address, medical condition notes, allergies, vaccination record,
  previous-school data, and navigation/completion metadata
- Student review submission and appearance in the real admissions list
- Admissions list status transition to `PENDING_REVIEW`
- `flutter analyze` passed with no issues

Real-data evidence:

- Household `6` was created with guardian `GUA-7F6C0D-5658`.
- Guardian review returned 7/7 completed steps, 100%, and `PENDING_REVIEW`.
- Student `STU-7F6C0D-7550` returned 7/7 completed steps and hydrated:
  Asthma notes, three allergy groups, BCG status/date, address, and school data.
- The admissions list returned the student with `PENDING_REVIEW`.
- Authenticated `GET /api/v1/guardians/genders` returned Male and Female.

Not yet verified:

- Administrator approval followed by final student enrollment
- Routing from approved admission to the enrolled student profile
- Real applicant document upload and secure S3 viewing
- Delete student, guardian, and now-empty household end to end

Cleanup note:

- The disposable household `6`, guardian `GUA-7F6C0D-5658`, and student
  `STU-7F6C0D-7550` may still exist. The cleanup command response was truncated,
  so deletion is intentionally not claimed as successful.

## Current Priorities

1. Verify real S3 uploads for finance receipts and admission documents.
2. Expand automated Playwright coverage for the remaining finance actor flows.
3. Complete admissions approval and enrollment using a disposable application.
4. Verify deletion of a student, guardian, and empty household.
5. Implement and validate the finance Reports workspace.

## Assessment Dashboard

Overall status: `UI_PROTOTYPE_COMPLETE`

Implemented with dummy data:

- School-admin sidebar navigation to Assessments
- Overview dashboard with assessment, grading, evaluation, and report-card
  summaries
- Functional quick actions and workspace tabs
- Assessment search and an in-memory Create Assessment flow
- Student terminal-evaluation controls and teacher remarks
- Report-card preview containing:
  - School and student information
  - Class score, examination score, total, grade, and remarks by subject
  - Average, overall grade, and class position
  - Attendance and punctuality summary
  - Conduct evaluation
  - Class-teacher and head-teacher remarks
  - Promotion, next-term date, and next-term fees
- Responsive table and card layouts for the initial web prototype
- `flutter analyze` passed with no issues

Backend integration still required:

- Term-scoped assessment definitions and score-entry APIs
- Grade-generation rules and persisted calculated results
- Student evaluation and teacher-remark persistence
- Report-card review, approval, publication, printing, and export
- Real school, student, attendance, promotion, and fee data
- Role and permission enforcement for assessment actions

## Verification Policy

- Initial tab/page data must come from real APIs.
- Mutations must refresh only affected data plus dependent dashboard summaries.
- No silent mock fallback is allowed when a real API fails.
- Financial workflows require an audit trail and separation of duties.
- Unknown or truncated results must be recorded as unverified, never passed.
