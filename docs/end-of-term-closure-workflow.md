# End-of-Term Review and Closure

## Purpose

The end-of-term workflow coordinates teacher submissions, staff reviews, finance closure, report-card publication, operational warnings, and the headmaster's final term closure.

The workflow creates an auditable closing record and preserves a snapshot used for the final management PDF. Closing a term is a deliberate final action; it is not the same as starting the next term.

## Actors and responsibilities

### Teacher

The headmaster releases a fixed term-review questionnaire to teachers. Each teacher can:

- save an unfinished response as a draft;
- submit the final response while the review window is open;
- confirm that loss or damage has been reported through Incident Management;
- maintain next-term recommendations separately until their final submission;
- complete required assessment records and student evaluations in their appropriate modules.

The teacher review includes confidential questions about the headmaster's performance, professionalism, staff support, psychological safety, freedom to express concerns, serious concerns, personal circumstances, and an open-ended suggestion for the next term.

Teacher reviews have a lifecycle of `DRAFT`, `SUBMITTED`, and `CLOSED`. An authorized administrator can reopen a submitted review with a recorded reason.

### Headmaster or administrator

The headmaster/administrator can:

- release or close the teacher review window;
- monitor teacher submissions without replacing the teacher's answers;
- complete fixed staff-performance questionnaires for each member of staff;
- reopen a completed staff review with a reason;
- inspect every end-of-term readiness item;
- record the facilities inspection;
- acknowledge non-blocking warnings with explanatory notes;
- generate the live management report PDF;
- close the term after all blockers are resolved.

### Bursar

The bursar closes finance and petty cash by recording the closing balances and confirmations. The finance workflow is:

```text
DRAFT -> SUBMITTED -> APPROVED
             |             |
             +-- REOPENED -+
                    |
                  DRAFT
```

Submission validates the required finance confirmations. Approval is a separate action. Submitted or approved finance closure can be reopened only with a reason, creating an audit record.

## Overall flow

```text
Headmaster releases teacher review
                  |
                  v
Teachers save drafts and submit reviews
                  |
                  +--------------------------+
                  |                          |
                  v                          v
Headmaster completes staff reviews   Bursar submits finance closure
                  |                          |
                  |                          v
                  |                  Finance is approved
                  |                          |
                  +------------+-------------+
                               |
                               v
Assessments completed and report cards published
                               |
                               v
Headmaster reviews final readiness checklist
                               |
                  +------------+-------------+
                  |                          |
             Resolve blockers        Acknowledge warnings
                  |                          |
                  +------------+-------------+
                               |
                               v
                    Type `CLOSE TERM`
                               |
                               v
                 Snapshot stored; term closed
                               |
                               v
                   Final management PDF
```

## Headmaster readiness checklist

The checklist distinguishes blockers from warnings.

### Blockers

A blocker must be `READY` before closure:

| Checklist item | Ready when |
|---|---|
| Teacher closing reviews | No existing teacher review remains outside `SUBMITTED` or `CLOSED` |
| Finance and petty cash | The bursar closure is `APPROVED` |
| Staff performance reviews | Completed reviews cover the staff records returned for the school |
| Student report cards | Published report-card records cover all students returned for the school |

The API rejects closure and identifies the unresolved blocker labels if any blocker remains.

### Warnings

Warnings do not automatically prevent closure, but every unresolved warning requires an acknowledgement of at least five characters:

| Checklist item | Warning condition |
|---|---|
| Incidents and loss/damage | One or more incidents within the term are not `RESOLVED` or `CLOSED` |
| Student attendance | One or more students have no attendance record within the term dates |
| Staff attendance | No staff-attendance entry exists within the term dates |
| Facilities inspection | The facilities inspection has not been recorded |

Warning details and acknowledgements are included in the closure snapshot so they are not lost after closing.

## Report-card requirement

A report card counts as complete only when its lifecycle status is `PUBLISHED`. Generating or previewing a PDF does not satisfy the closure gate.

Before publication, the backend requires:

1. every active subject to have all required assessment components graded;
2. generated student grades to exist;
3. class-teacher remarks;
4. a promotion selection;
5. either a headteacher remark or an explicit choice to ignore it.

The current assessment readiness model expects CAT 1, CAT 2, CAT 3, CAT 4, and Exam for each active, examinable subject.

## Facilities inspection

The headmaster records whether inspection was completed and may store information such as:

- inspection date;
- general condition;
- inspection notes;
- observed losses or damage.

If inspection is not completed, the term may still close only after the warning is explicitly acknowledged. Loss or damage should be recorded in Incident Management; the closure form is not a replacement incident register.

## Final closure action

The final action requires the exact confirmation text:

```text
CLOSE TERM
```

When accepted, the backend performs the following work in order:

1. recalculates live readiness;
2. rejects the request if a blocker remains;
3. checks that every unresolved warning has an acknowledgement;
4. serializes the current readiness response into an immutable closure snapshot;
5. changes the headmaster closure status to `CLOSED`;
6. records the closing user and timestamp;
7. marks the academic term as closed and records its closing user and timestamp;
8. writes a `TERM_CLOSED` audit entry.

After closure, editing the closure draft is rejected with HTTP `400` and the message `The term is already closed`. Grade generation also checks the academic term's closed state.

## Management report PDF

The management report is available before and after closure:

- before closure, it reflects live readiness;
- after closure, it reads the preserved snapshot rather than recalculating historical data.

The PDF contains checklist outcomes and key summary counts, including students, published reports, unresolved incidents, completed staff reviews, staff total, finance status, and teacher-review count.

## User interface

For a school administrator:

1. sign in to the new frontend;
2. scroll the navigation and select **Term Review**;
3. review the **Term readiness and closure** section;
4. resolve all red blocker items in their linked modules;
5. enter acknowledgements for outstanding warnings;
6. record the facilities inspection or acknowledge why it is outstanding;
7. save the draft when work is incomplete;
8. generate the management report for review;
9. enter `CLOSE TERM` and complete the final closure.

The screen displays the current closure status, ready-item count, blocker count, warning count, student count, and the detail behind every checklist item. Once closed, the status badge displays `CLOSED`.

## API reference

All calls require normal authentication and school/tenant context.

### Teacher reviews

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v2/teacher-term-reviews/school/{schoolId}/dashboard` | Review-window and submission dashboard |
| POST | `/api/v2/teacher-term-reviews/school/{schoolId}/release` | Release the fixed questionnaire |
| POST | `/api/v2/teacher-term-reviews/school/{schoolId}/close` | Close the review window |
| GET | `/api/v2/teacher-term-reviews/school/{schoolId}/teacher/{userId}` | Load a teacher response |
| PUT | `/api/v2/teacher-term-reviews/school/{schoolId}/teacher/{userId}/draft` | Save draft |
| PUT | `/api/v2/teacher-term-reviews/school/{schoolId}/teacher/{userId}/submit` | Submit review |
| POST | `/api/v2/teacher-term-reviews/school/{schoolId}/teacher/{userId}/reopen` | Reopen with reason |

### Staff-performance reviews

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v2/staff-performance-reviews/school/{schoolId}/dashboard` | Staff review progress |
| GET | `/api/v2/staff-performance-reviews/school/{schoolId}/staff/{staffId}` | Load review |
| PUT | `/api/v2/staff-performance-reviews/school/{schoolId}/staff/{staffId}/draft` | Save draft |
| PUT | `/api/v2/staff-performance-reviews/school/{schoolId}/staff/{staffId}/complete` | Complete review |
| POST | `/api/v2/staff-performance-reviews/school/{schoolId}/staff/{staffId}/reopen` | Reopen with reason |

### Finance closure

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v2/bursar-term-closures/school/{schoolId}` | Load finance readiness and closure |
| PUT | `/api/v2/bursar-term-closures/school/{schoolId}/draft` | Save draft |
| PUT | `/api/v2/bursar-term-closures/school/{schoolId}/submit` | Validate and submit |
| POST | `/api/v2/bursar-term-closures/school/{schoolId}/approve` | Approve submitted closure |
| POST | `/api/v2/bursar-term-closures/school/{schoolId}/reopen` | Reopen with reason |

### Headmaster closure

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v2/headmaster-term-closures/school/{schoolId}` | Calculate readiness |
| PUT | `/api/v2/headmaster-term-closures/school/{schoolId}/draft` | Save acknowledgements and facilities data |
| POST | `/api/v2/headmaster-term-closures/school/{schoolId}/close` | Validate and close term |
| GET | `/api/v2/headmaster-term-closures/school/{schoolId}/report` | Generate management PDF |

## Audit and persistence

Separate audit tables record significant actions for teacher reviews, staff reviews, bursar closure, and headmaster closure. Audit records include the action, actor, time, and a reason where the operation requires one.

The final headmaster record stores:

- school and term identifiers;
- status;
- warning acknowledgements as JSON;
- facilities data as JSON;
- the final management snapshot as JSON;
- closing user and timestamp.

## Verification checklist

Use this condensed test whenever the flow changes:

1. Confirm closure fails while finance or reports are incomplete.
2. Save and reload warning acknowledgements and facilities data.
3. Submit and approve finance.
4. Complete assessments, generate grades, enter remarks, and publish every report.
5. Confirm readiness reports zero blockers.
6. Confirm an unresolved warning cannot close without an explanation.
7. Close using the exact confirmation phrase.
8. Reload and confirm the UI displays `CLOSED`.
9. Generate the PDF and confirm it is a valid, readable PDF.
10. Attempt to save another closure draft and confirm HTTP `400`.
11. Attempt grade generation for the closed term and confirm it is rejected.

## Current limitations and planned work

The following work is intentionally not represented as complete:

- There is no guided **Begin next term** handoff yet.
- Student promotion and new class/stream assignment are not performed by closure.
- Outstanding balances and unresolved operational items are not yet carried forward by a dedicated transition process.
- Closed-term write protection is not yet centrally enforced across every mutation endpoint in every module. Closure drafts and grade generation are protected, while remaining modules require a systematic lock audit.
- The management PDF is functional but is currently a concise operational report rather than the final visual executive report with previous-term comparisons.

These limitations mean the term can be closed and reported safely within this workflow, but an administrator must not assume that closure automatically creates or activates the next academic term.
