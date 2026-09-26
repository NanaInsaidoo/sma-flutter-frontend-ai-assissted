# Term Evaluations and Report Cards

## Training manual for teachers, head teachers, and administrators

This guide explains the complete end-of-term workflow, who is responsible for each step, what becomes locked, and how to resolve the most common blockers.

---

## 1. Roles and responsibilities

### Subject teacher

- Records assessment scores for the subjects and classes allocated to them.
- Completes one student evaluation for each allocated class. When the teacher teaches several subjects in the same class, those subjects are shown together under one responsibility.
- May save, submit, revise, and resubmit ratings until leadership starts reviewing the affected student.
- Cannot generate, approve, or publish report cards.

### Class teacher

- Completes the class-teacher evaluation for every student in the class.
- Reviews the consolidated ratings contributed by teachers.
- Writes and saves one final class-teacher comment for every student.
- Sends the completed class evaluation to leadership when all student comments are ready.
- May revise and resend ratings or comments until leadership starts reviewing the affected student.
- Cannot change the calculated consolidated ratings.

### Head teacher or authorized administrator

- Releases the term evaluation exercise once allocations are ready.
- Monitors teacher progress and sends reminders.
- Reviews submitted student evaluations.
- Approves an evaluation or rejects it with a reason.
- May select all eligible evaluations and approve them together.
- Generates report cards after all readiness requirements are complete.
- Selects and confirms the progression decision.
- Publishes report cards.
- Reopens a published report for an authorized correction, with a recorded reason.

### Headmaster-only controls

- Authorized final-wording corrections are restricted to the headmaster and are audited.
- School policy should name the person responsible for evaluation and report-correction decisions. The leader who approves or rejects a student evaluation is recorded.

---

## 2. Before term work starts

An administrator must confirm the following setup:

1. The correct academic year and term are active.
2. Every class has active students.
3. Subjects are assigned to each class.
4. Subject teachers are assigned through **Class subjects and teacher allocation**. Adding a role called “Subject Teacher” by itself does not allocate a teacher to a subject or class.
5. Each class has a class teacher.
6. Required assessment types and report settings are configured.

If a teacher cannot see a subject, check the class-subject allocation first. If a class appears only as “Section 2” or “Section 3,” correct the class display name so it includes its grade, for example **JHS 1 - Section 2**.

---

## 3. Record academic assessments and scores

For each allocated subject:

1. Open **My Classes** and select the class. The selected class should carry into the next screen; the teacher should not be asked to choose it again.
2. Open **Assessments**.
3. Create each required CAT, project, practical, or end-of-term examination.
4. Enter a score for every active student.
5. Confirm that the assessment displays **Fully graded**.
6. Use **Check report readiness** to identify missing scores or other work.

Important rules:

- A score cannot be negative or exceed the assessment maximum.
- A student must belong to the assessment class.
- “100% score entry” confirms score rows are present; it does not confirm evaluation review, progression, generation, or publication.
- After report generation, source records are controlled. Corrections must use the authorized correction process rather than silently changing the published result.

---

## 4. Release term evaluations

Leadership performs this once per term after teacher allocations are correct:

1. Open **Evaluations & Comments**.
2. Select **Release evaluations**.
3. Confirm the release.

Release creates teacher evaluation work from current class-teacher and subject-teacher allocations. Evaluation responsibilities are grouped by teacher and class, not by subject:

- Teaching several subjects in one class creates one evaluation responsibility.
- Teaching in several classes creates one responsibility for each class.
- If the same person is also the class teacher, the single responsibility continues into the student-comment stage after ratings are complete.

There is no routine global lock/unlock cycle. Teachers continue working until leadership starts review for an individual student. Older terms that display a legacy **Locked** cycle are treated as released for teacher entry; student-level leadership review controls the actual lock.

If a teacher allocation is added after release, refresh or release synchronization may be needed so the new evaluation work appears. The **Teacher progress** view must still show configured subject allocations even when no action is currently available.

---

## 5. Teacher evaluation workflow

Opening **Evaluations & Comments** takes the teacher directly to one dashboard containing all of their evaluation responsibilities. The teacher is not asked to choose a class first. Use the **Class** filter on the dashboard to focus on one class when needed.

### Save and submit ratings

1. Open **Evaluations & Comments**.
2. Open one of the teacher’s class responsibilities. All subjects taught in that class are shown together.
3. Rate every student against every criterion.
4. Use **Not observed** only when the criterion genuinely could not be observed. It is a valid final rating and must not be treated as missing.
5. Save progress as needed.
6. Submit when all students and criteria are complete.

### Revise after submission

Submission sends the work forward but does not immediately make it permanent.

- Before leadership starts reviewing a student, the teacher selects **Edit ratings**, changes the rating, and resubmits. No administrator reopening step is required.
- When leadership starts reviewing that student, only that student’s evaluation becomes locked.
- Other students remain editable until their own review begins.

### Class-teacher student comments

After the class teacher submits all ratings, the screen immediately offers **Continue to student comments**. Subject teachers finish after submitting ratings; they do not write the final class-teacher comments.

The class teacher follows this sequence:

1. Review each student’s consolidated ratings.
2. Read the suggested comment, if available.
3. Use or edit the suggestion; suggestions are never saved automatically.
4. Enter the final class-teacher comment.
5. Select **Save and next student**.
6. Continue until every student displays a completed comment.
7. Select **Submit for approval**.

If another required teacher evaluation is still outstanding, the screen explains how many teacher evaluations are pending. Saved comments remain available, but the class evaluation cannot be sent until the required work is complete.

The visible workflow stages are:

| Stage | Typical status |
|---|---|
| Teacher ratings | In progress or Ratings complete |
| Student comments | Missing, Comments in progress, or Comments complete |
| Approval | Not ready, Ready to submit, Awaiting approval, Under review, Rejected, or Approved |

Before leadership starts reviewing a student, the class teacher may edit and save the comment again. The teacher does not need to repeat every criterion simply to update a saved comment.

---

## 6. Leadership evaluation review

Open **Evaluations & Comments > Overview > By class**, then select **View** for the class. The class approval register keeps each student’s ratings, class-teacher comment and approval status together. Only students marked **Awaiting approval** can be selected for bulk approval.

Comments are limited to a three-line preview so the register stays readable. Expand a student row to read the complete comment and the full rating names before deciding.

### Approve

1. Check the consolidated ratings and final comment.
2. If correct, select **Approve**.
3. The evaluation status becomes **Approved** and satisfies the evaluation part of report readiness.

### Approve several evaluations

1. Select the checkbox beside each eligible student, or use the header checkbox to select all awaiting students in the filtered class.
2. Select **Approve selected**.
3. Confirm the decision.
4. The system approves every eligible selected evaluation and reports any item that was skipped because its status changed.

Approved and rejected students remain visible for reference, but their checkboxes are disabled. They are not included in mass approval.

### Reject

1. Expand the affected student row and review the full ratings and comment.
2. Select **Reject**.
3. Enter a clear, specific reason.
4. The teacher sees the reason, corrects the ratings or comment, and sends the class evaluation to leadership again.

Status meanings:

| Status | Meaning | Teacher can edit? | Leadership action |
|---|---|---:|---|
| Not started / In progress | Ratings are incomplete | Yes | Monitor or remind |
| Ratings complete | Teacher ratings are complete | Yes | Wait for student comments |
| Comments in progress | At least one final comment is saved | Yes | Finish remaining comments |
| Awaiting approval | Ratings and comments were submitted for approval | Yes, until review starts | Start review, or include in mass approval |
| Under review | Leadership is actively reviewing | No | Approve or reject |
| Rejected | Rejected with a recorded reason | Yes | Wait for correction and resubmission |
| Approved | Accepted for reporting | No | Generate when all other requirements pass |

---

## 7. Report readiness

Readiness is based on actual report requirements, not on a global evaluation lock.

A student is ready only when all applicable checks pass:

- Required assessments exist.
- Every required score is entered.
- Teacher evaluation contributions are complete.
- The class teacher has submitted the final comment.
- Leadership has approved the student evaluation.
- A progression decision is selected.
- Any additional school report requirements are complete.

Use **More details** to see an aggregate breakdown. The first dialog should remain concise; detailed student lists belong in the next view.

Common messages:

- **Required scores are missing** — open the affected assessments and enter the missing score rows.
- **Student evaluations are not completed** — check Teacher progress for incomplete teacher work.
- **Leadership review pending** — open the submitted evaluation and approve or reject it.
- **Leadership approval pending** — use individual approval or select eligible evaluations for mass approval.
- **Final review/progression pending** — select and save the progression decision.
- **No evaluation assignments generated** — verify class and subject-teacher allocations, then synchronize the released exercise.

---

## 8. Generate, preview, and publish reports

Only authorized leadership users generate and publish report cards.

The **Final Report Management** overview shows one row per class with these checks:

| Column | Meaning |
|---|---|
| Academic grades | Complete only when every required assessment score is present for every student |
| Evaluations & comments | Incomplete, Not submitted, Awaiting approval, Approved, or Rejected |
| Progression | Selected only when every student has a progression decision |
| Report status | Not generated, Partially generated, Generated, Published, or Update required |

**Ready to submit** is a teacher-facing instruction and is not shown as an administrator status. Administrators see **Not submitted** until the teacher sends the completed ratings and comments for approval.

Select **Open class** to see each student’s four checks in separate columns: **Academic grades**, **Evaluations & comments**, **Progression**, and **Report status**. The **Generate report** button remains visible but disabled until the first three checks are complete. It changes to **View report** after generation and **Regenerate** when source data has changed.

1. Open a class from **Final Report Management**.
2. Complete any missing academic grades.
3. Ensure the student’s evaluations and comments have been approved.
4. Select the progression decision: promote, repeat, review, or graduate.
5. Select **Generate report** for one student, or select several students and use **Generate selected**.
6. Open **View report** to preview the generated report.
7. Publish the individual report from its preview page when confirmed.

For bulk publication, return to **Final Report Management**:

- Select one or more eligible classes and choose **Publish selected**. Every generated, unpublished report in those classes is included.
- Choose **Publish all generated** to publish every eligible generated report for the term.
- Classes with no generated, unpublished reports cannot be selected.
- The confirmation message states the exact number of reports and classes before publication.

Generation captures a version of academic scores, evaluation results, comment, attendance, student/class profile, and progression information. If one of those sources changes later, the report becomes out of date and must be regenerated.

Publishing makes the report visible through the school’s report distribution channels. A published report should not be silently overwritten.

---

## 9. Corrections after generation or publication

### Before publication

If a generated report is found to be wrong:

1. Reopen or return the affected source item through an authorized leadership action.
2. Record a reason.
3. Make or request the correction.
4. Regenerate the affected student’s report.
5. Preview again before publication.

### After publication

1. Leadership opens the student report.
2. Select **Reopen report**.
3. The published progression decision and head teacher comment become editable. The published version remains in history.
4. Make the correction and select **Save Correction**.
5. Enter the correction reason. The reason and saved changes are recorded in the audit log.
6. The report becomes **Correction pending** and is no longer counted as safely published for term closure.
7. Regenerate only the affected student.
8. Preview the corrected version.
9. Republish it.

Published reports are read-only before **Reopen report** is selected. Reopening by itself does not change the stored report and does not require a reason; the reason is required when the correction is saved.

The audit history records who reopened, why, when, and when the corrected version was republished. The original published history is retained; corrections create a newer controlled version.

Teachers do not directly overwrite a generated or published report. When a teacher tries to save a changed score after generation, the system opens **Request report correction**. The teacher submits one student at a time, including the proposed score, reason, and optional named approver. Leadership sees a correction banner on **Evaluations & Comments**, then approves and regenerates or rejects the request. Approval applies the proposed score and regenerates the affected student; rejection leaves the official data unchanged.

---

## 10. Banners and stale-report warnings

Act on these messages before closing the term:

- **Report not generated** — finish readiness and generate.
- **Report out of date / Update required** — source information changed after generation; regenerate.
- **Correction pending** — finish or cancel the authorized correction.
- **Newer generated version waiting for publication** — preview and publish the newer version, or explicitly revert it.
- **Progression decision pending** — choose and save the decision before generating.

Do not dismiss these as informational. Unresolved report states block a safe term close.

---

## 11. Closing the term

Before closing, leadership checks:

1. All teacher closing reviews are submitted.
2. Finance closure is approved.
3. Staff reviews are complete.
4. Every student evaluation is leadership-approved.
5. Every active student has a published, current report.
6. No report is in correction-pending or stale state.
7. No correction request is awaiting a decision.
8. The next operational term is configured.
9. Warnings such as incidents or missing attendance are reviewed and acknowledged according to school policy.

The system blocks term closure when a blocking section is incomplete.

---

## 12. Scenario checks for training and acceptance testing

### Scenario A — class teacher saves and sends comments

1. Submit the class-teacher ratings.
2. Select **Continue to student comments**.
3. Save each student’s comment with **Save and next student**.
4. Select **Submit for approval**.

Expected: ratings and comments display their own progress. When both are complete, the workflow moves to Ready to submit, then Awaiting approval after submission.

### Scenario B — leadership starts review

1. Start review for Student A.
2. Attempt to edit Student A as the teacher.
3. Edit Student B, whose review has not started.

Expected: Student A is locked; Student B remains editable.

### Scenario C — evaluation rejected

1. Reject an under-review evaluation with a reason.
2. Sign in as the responsible teacher.
3. Confirm the reviewer and note are visible.
4. Correct and resubmit.

Expected: editing is restored and leadership must start a new review before approval.

### Scenario D — mass approval

1. Prepare several class evaluations with status Awaiting approval.
2. Use **Select all** in the leadership review list.
3. Select **Approve selected** and confirm.

Expected: eligible evaluations become Approved. Incomplete, rejected, already approved, or concurrently changed evaluations are excluded or reported as skipped.

### Scenario E — Not observed

1. Set one criterion to Not observed.
2. Submit all teacher work and complete the class-teacher review.

Expected: Not observed is retained as a valid wording and does not become a false “missing criterion” blocker.

### Scenario F — incomplete score sheet

1. Leave one student score blank.
2. Run readiness.

Expected: readiness reports the missing score count and report generation remains disabled.

### Scenario G — generated report source changes

1. Generate a ready student report.
2. Perform an authorized source correction.

Expected: the report displays Update required until regenerated.

### Scenario H — correction after publication

1. Publish a report.
2. Reopen it with a reason.
3. Correct, regenerate, and republish.

Expected: the term cannot close while correction is pending; the audit trail contains reopen and republish events.

### Scenario I — unauthorized access

1. Sign in as a subject teacher.
2. Try to start leadership review, change progression, generate, reopen, or publish.

Expected: all leadership-only actions are hidden and rejected by the server if called directly.

### Scenario J — allocation added after release

1. Add a subject teacher after evaluations were released.
2. Refresh the exercise.

Expected: the class appears in Teacher progress, or appears as pending synchronization with a clear action. If the teacher already teaches another subject in that class, the new subject is added to the existing responsibility rather than creating a second evaluation.

### Scenario K — term closure

1. Leave one evaluation under review or one report correction pending.
2. Attempt to close the term.

Expected: closure is blocked and identifies the unresolved section.

---

## 13. Quick troubleshooting

| Problem | Check first | Resolution |
|---|---|---|
| Teacher cannot see a subject | Class-subject teacher allocation | Assign the teacher to the subject and class; a role alone is insufficient |
| Assessments say no subjects configured | Active subjects for the selected grade/class | Activate/assign subjects and confirm the correct class is carried from My Classes |
| Scores show 100% but report is blocked | Evaluation approval and progression | Open readiness details; complete leadership approval and progression |
| Preview is disabled | Remaining blockers | Complete the listed readiness requirements |
| Ready-for-leadership evaluation can still be edited | Leadership has not started review | This is expected; Start review or approve to lock that student |
| Teacher cannot edit one student | Student is Under review or Approved | Leadership must Reject with a reason if an edit is required |
| Generated report has old information | Freshness status | Regenerate the affected student report |
| Published report needs correction | Controlled correction process | Reopen with reason, correct, regenerate, and republish |
| Term cannot close | Closure blockers | Resolve every blocker; warnings require an acknowledgement where permitted |

---

## 14. Recommended operating routine

- Teachers check score and evaluation completeness daily during the reporting window.
- Class teachers complete comments only after subject contributions are substantially complete.
- Leadership reviews students in small batches rather than globally locking every teacher.
- Use **Reject** with a recorded reason instead of informal messages so the reason stays with the record.
- Generate only after readiness is green.
- Preview every corrected report before republishing.
- Run the term-closing check early enough to resolve issues before the closing date.
