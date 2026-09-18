# SMA Project Status

Last updated: 2026-09-13

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
- Petty-cash requests and approvals enforce the configured single-expense
  limit without depending on the current pocket balance
- Actual spending enforces the selected Cash or MoMo pocket balance and can
  never make either pocket negative
- Actual spending blocks a Cash or MoMo pocket from becoming negative. Higher
  or lower actual amounts are retained for audit, but only differences above
  the administrator-configured variance percentage require variance review
- Expense variance review has two final administrator outcomes: accept the
  variance or escalate it to a Financial follow-up. Both require an audit note;
  correcting a posted expense uses the separate reversal workflow
- Petty Cash and its Top-up, Reconciliation, and Financial follow-up workspaces
  show red counts for active records; completed history is excluded
- Funds awaiting receiver confirmation for more than 15 minutes show a
  persistent reminder with the live overdue duration
- Confirmed incoming money is never hidden or rejected because capacity changed.
  Refunds are received into School funds and do not alter the float. Reversals
  and already-disbursed top-ups record their true pocket effect, and any newly
  created excess above the approved float opens an urgent, manager-notified
  Float overage follow-up. Closing that case requires the exact Cash/MoMo return
  allocation, a transfer or deposit reference, and a resolution note; the
  resulting Float return transaction reduces the pockets and preserves the audit
  trail. Existing active cycles already above their approved float receive one
  non-duplicating backfilled overage case
- Requisitions expire after the administrator-configured validity period;
  expiry dates and days remaining are visible in the register and details
- Administrator-controlled small-request auto-approval, with an independent
  limit, settings validation, notifications, and an append-only audit history
- Requester-only requisition cancellation with a mandatory note and a distinct
  cancellation event in the audit history
- Requester-only editing of unspent petty-cash requisitions: pressing Edit
  immediately returns the request to Draft, invalidates any previous approval,
  records the transition, and requires the updated draft to be resubmitted;
  the requester may change the funding source in Draft, with the route change
  audited and the newly selected route's business rules applied on resubmission
- Requisition forms show validation beside the affected fields instead of using
  a bottom notification; backend submission errors remain visible inside the form
- Petty-cash setup, top-up, disbursement, transfer, refund, reconciliation,
  follow-up, ratification, and variance-review forms show validation beside the
  affected fields instead of reporting form errors on the main screen
- Requester Edit and Cancel requisition actions remain fixed in the requisition
  detail footer while the request and approval history scroll independently
- Financial follow-up details use a readable field layout, retain the linked
  transaction ID, and open the related expense detail from its expense reference
- Administrator, headmaster/head teacher, bursar, and platform-admin finance
  workspaces show school-wide dashboards and registers; ordinary staff see their
  own requisitions plus a read-only My Expenses register containing only expenses
  produced from those requisitions, and cannot load another user's expense detail
- Class and subject teachers can open Expenses & Petty Cash from the main menu,
  but receive only requester-level Finance VIEW/EDIT access. They cannot approve
  finance work unless a separate authorised role or override grants that action
- Requisition approval requires a written approval note, which is validated in
  the confirmation form, enforced by the backend, and retained in approval history
- The actual-spend form gives ordinary requesters the current Cash and MoMo pocket
  balances needed to choose a valid payment method without exposing the wider
  school finance dashboard
- The overview's five most recent expenses are sorted newest first, clearly label
  School funds, Cash pocket, or MoMo pocket, and link separately to the School
  Expenses and Petty Cash registers
- School Expenses and Petty Cash use the same modern expense register with
  searchable and filterable results, sortable Expense, Amount, Status, and Date
  headings, eight records per page, result counts, and Previous/Next controls
- Finance registers preserve readable column widths on narrow screens and scroll
  horizontally; section actions and requisition filters stack without overflow
- Ordinary staff load requisition policy, their own requisitions and resulting
  expenses, and eligible approvers; float balances, school totals, reconciliations,
  follow-ups, top-ups, reports, and manager actions are not loaded into their workspace

Implemented and automated; live role-separated verification is pending:

- Full expense reversal flow for erroneous, duplicate, unpaid, wrong-amount, or
  wrong-source entries: requester selects an independent approver and supplies
  evidence; the approver affirms, approves, or declines with a note; the requester
  may cancel while pending; approval preserves the original, creates a linked
  reversal, restores the original petty-cash pocket where applicable, updates
  school-spend totals, and appears in notifications and approval history
- Refund and reversal are mutually exclusive for one expense, preventing duplicate
  credits; reversals are full-only and approved reversals cannot be cancelled
- Refunds now start from the original expense, post to School funds in the current
  term, require receipt date, method, reference, reason, and affirmation, and never
  credit Cash or MoMo. The compact Refund register supports historical-expense
  lookup, term/month/current-result summaries, search, period filtering, paging,
  and links back to the original expense
- Expense-reversal approvals now lead with the original expense ID, description,
  amount, funding source, payment channel, payee, receipt, reason, and financial
  effect; secondary request metadata is kept compact below the decision facts
- The shared Approvals drawer now performs the assigned reversal decision directly:
  the approver reviews the summary first, clicks Approve, and must enter an audited
  decision comment before the backend posts the reversal

Automated evidence:

- `flutter analyze` passed with no issues.
- The 13 Sep 2026 live UI rerun passed the setup, separated top-up approval,
  mixed Cash/MoMo disbursement, requester receipt confirmation, pocket transfer,
  staff-scoped requisition, approval confirmation, variance affirmation and
  administrator review, School-funds refund, matched reconciliation, insufficient
  pocket balance blocker, and requester cancellation journeys.
- The focused Expenses & Petty Cash widget file passed all 17 tests, including
  the regression that keeps the MoMo wallet, payment reference, and disbursement
  note fields correctly separated after a mixed allocation is entered.
- The focused backend `FinanceWorkflowServiceTest` suite passed all 48 tests.
- The focused Expenses & Petty Cash and Approvals widget suites passed all 46 tests,
  including requester-scoped expense visibility, sorting, pagination, reversal
  submission, reversal approval affirmation, and compact approval evidence.
- `flutter test` passed: 426 tests.
- Live Flutter Web/Playwright finance checks passed: 2 tests against the real
  local API, including workspace loading and requester top-up cancellation.
- `mvn -q test` passed: 497 tests, with no failures, errors,
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
- A GH¢20,000 petty-cash request was blocked by the configured GH¢900
  single-expense limit and no request was created.
- A GH¢800 request was accepted while the current float was GH¢720, confirming
  that request and approval stages do not reserve or require current funds.
- Actual spend against a MoMo pocket with GH¢0 was blocked and did not mutate
  either pocket balance.
- A GH¢10 request was automatically approved under a temporary GH¢50 policy;
  its history identified automatic approval, and the policy was restored to off.
- A pending test requisition was cancelled by its requester with a required
  note; its register status and event history both show cancellation.
- A fresh teacher-requester requisition was created through the UI, assigned to a
  head-teacher approver, approved only after a required note was entered, and its
  approval history retained the requester, approver, amount, dates, and note.
- The approved request's live actual-spend form showed the locked description and
  vendor plus the current Cash balance of GH¢3,969 next to the payment method.
  The form was inspected without posting a fictitious payment or changing balances.
- Petty-cash settings were restored to a GH¢1,000 ceiling, GH¢500
  single-expense limit, GH¢250 refill threshold, and auto-approval off.

Known data and cleanup notes:

- Disposable finance records for the test school are removed after the final
  test run so the next manual journey starts at petty-cash setup.
- The 13 Sep 2026 final cleanup was verified in both MySQL and the live browser:
  finance cycles, requisitions, transactions, top-up events, reconciliations,
  follow-ups, notes, approval attempts, and finance notifications are empty for
  `AKW-XXX-E41A3E`.
- Test users remain available for future separation-of-duty checks.

Remaining production-hardening checks:

- Verify one complete requester-to-approver expense reversal against the local
  backend after working administrator credentials are available.
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
