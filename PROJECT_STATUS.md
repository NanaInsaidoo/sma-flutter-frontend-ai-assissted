# SMA Project Status

Last updated: 2026-07-28

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
- Emergency requisition and actual-spend recording
- Mandatory second-actor ratification
- Variance review and resolution
- Top-up request, second-actor approval, and confirmation
- Cash-to-MoMo pocket transfer with a transfer fee
- Reconciliation request, concurrent-request prevention, count, variance,
  resolution, closure, and financial follow-up creation
- Receipt omission: an actual spend succeeds without a receipt attachment
- Final pocket balances and dashboard aggregates update from backend data

Automated evidence:

- `mvn -q -Dtest=FinanceRulesTest test` passed.

Real-data evidence:

- Emergency requisition `9`, transaction `14`: moved through
  `PENDING_RATIFICATION`, `PENDING_VARIANCE_REVIEW`, then `COMPLETE`.
- Self-ratification was rejected; a different authorized user succeeded.
- Top-up `15`: self-approval rejected, second actor approved, requester
  confirmed, final status `CONFIRMED`.
- Reconciliation `5`: a concurrent request was rejected; GHc2 shortage created
  an open follow-up and closed as `VARIANCE_CLOSED`.
- Transfer `17`: GHc5 cash-to-MoMo with GHc0.50 fee completed.
- Final observed pockets: cash GHc99.50, MoMo GHc80.00, total GHc179.50.

Known data and cleanup notes:

- Academic term `2` is named Second Term but its stored description says
  "First Term". This is a seed/data issue, not a frontend calculation issue.
- Legacy transaction `10` is `COMPLETE` while still carrying
  `requiresRatification=true`. It predates this verification and should be
  normalized or audited.
- Test reconciliation created financial follow-up `3`, intentionally left open
  so the follow-up workflow remains visible.
- A temporary secondary finance operator was created for separation-of-duty
  testing.

Remaining production-hardening checks:

- Upload and securely view a real S3 receipt file.
- Run the complete Flutter UI journey manually once browser semantics are
  enabled for reliable form automation.

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

1. Complete admissions approval and enrollment using the disposable application.
2. Verify real S3 uploads for finance receipts and admission documents.
3. Verify deletion of a student, guardian, and empty household.
4. Enable Flutter web semantics and add Playwright journeys for critical flows.
5. Normalize the academic-term description and legacy finance transaction.

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
