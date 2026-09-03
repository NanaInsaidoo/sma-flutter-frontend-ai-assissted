# Staff leave management

The leave screen uses persisted school-scoped APIs, not demo data.

## Access and workflow

- Every active school employee has **My Leave**, showing only their own requests, status counts, history and balances. New requests from this page are fixed to the signed-in employee, including for administrators and head teachers.
- **Leave Management** is a separate menu for administrators and head teachers (including legacy ADMIN/HEADMASTER roles). It retains school-wide filters, sortable requests, review actions and requests on behalf of staff. These reviewers see both menus; other employees see My Leave only. The management page also checks the server's review permission before loading its list.
- My Leave always sends the authenticated employee's ID as the list/balance filter, including after sorting, filtering or changing pages. Switching between the two pages clears the prior page's scope. Staff-profile leave history retains its selected employee scope. Requests & Approvals continues to open the same permission-checked details window.
- Assistant heads, teachers, bursars and office/secretarial staff have self-service access. Review authority currently follows the administrator/head-teacher roles (including legacy ADMIN/HEADMASTER roles).
- Neither the staff member taking leave nor the account that created it can approve/reject it. At least one other eligible reviewer must exist before submission.
- Pending requests can only be withdrawn by the original requester, with a reason. Reviewers can approve, reject or request changes but cannot cancel/withdraw someone else's pending request. This is enforced in both APIs, including legacy CANCEL calls. Withdrawal retains the CANCELLED lifecycle status and a distinct WITHDRAW audit event; it releases pending balance reservations and notifies the other relevant staff.
- DRAFT → PENDING_APPROVAL → APPROVED / REJECTED / NEEDS_REVISION. Revised requests may be edited and submitted again. Eligible open requests may be CANCELLED with a reason.
- Approval comments are optional. Rejections, revision requests, cancellations and allowance changes require a reason.
- Staff may cancel their future approved leave. Only a reviewer may cancel approved leave that has started. Cancellation is recorded, never deletion.

## Days and balances

- Dates are inclusive **calendar days**, including weekends, capped at 366 days per request. This is displayed in the form and balances.
- No statutory allowance is assumed. A different administrator/head teacher configures each staff member's allowance by leave type and calendar year.
- Approved and pending days reserve the allowance. Cross-year requests charge each year's portion separately. Rejection, revision and cancellation release reservations.
- Unconfigured allowances display “Not configured” and do not impose a numeric limit. There is no automatic carry-over or accrual in this version.
- Overlapping pending/approved leave is blocked. Staff-row locks, current reads and request versions guard competing actions.
- “On leave today” uses the UTC calendar date; list date filters match any overlap with the selected range. Dashboard counts cover all dates for the selected staff.

## Privacy, audit and attendance

- Reasons, notes, supporting documents and request snapshots are visible only to the staff member, original requester and authorised reviewers.
- Notifications and the general approval inbox omit private reasons. Clicking a leave request in Requests & Approvals or Leave Management opens the same permission-checked request-details window, including comments, attachments and history.
- The Leave Management dashboard, not the main school dashboard, shows all six workflow statuses plus staff currently on leave. Status selection filters requests; individual requests open directly. Reviewer history retains decided/revised/cancelled requests, with review actions available only while pending. The shared approvals API also supports leave decisions with a mandatory current request version.
- The leave request table has sortable Reference, Staff member, Leave type, Start date, End date, Days, Status and Requested columns. Sorting is server-side before pagination, with stable reference ordering for ties. Sorting resets to page one and keeps staff/status/date filters. Smaller screens scroll horizontally; selecting a row opens the same details window.
- Both leave pages also have a Calendar view with month navigation, a month chooser and This month. It loads every page of requests overlapping the displayed month, while keeping staff/status permissions and filters. Multi-day leave appears on each covered day, including across month/year boundaries. Coloured entries open the shared details; busy days offer a full request list. Rejected/cancelled/draft requests are explicitly distinct from approved absences. My Leave calendars remain fixed to the signed-in employee.
- Leave dates consistently use an unambiguous day/month-name/year display (for example, 31 Aug 2026); calendar dates are not shifted between timezones. API requests retain ISO dates and responses support both ISO strings and Spring date arrays.
- Every create/edit, attachment change, submission and decision records the actor, time and request snapshot. Protected attachment views and allowance changes also enter the school audit log.
- Supporting files: PDF, DOC, DOCX, JPG/JPEG, PNG or WebP; maximum 5 MB. Files use the existing private school storage with short-lived view links. Upload failures preserve the draft and prevent submission. Replaced/removed file objects are retained for audit retention; removed files are no longer available through the request attachment endpoint.
- The attendance roster shows approved leave dates without exposing medical details or silently rewriting existing attendance. “Mark all present” skips people on approved leave. Their absence dialog suggests an excused “Approved leave”; saving confirms the actual attendance entry. The server blocks new present/late entries during approved leave.
- Cancel or revise leave before recording a returning staff member as present. Existing submitted attendance still follows its normal correction/audit process.

## API

Base: `/api/schools/{school}/leave`

GET `context`, `types`, root list, `{id}`, `staff/{staff}/history`, `staff/{staff}/balances?year=`, `availability?date=`. List/history support `sortBy=id|staffName|typeName|startDate|endDate|days|status|createdAt` and `direction=asc|desc`; default is createdAt descending.

POST root creates a draft; PUT `{id}` updates editable requests. POST `{id}/actions` accepts action, comment and version. Multipart POST / DELETE `{id}/attachment` require version. GET `{id}/attachment` returns a temporary private URL. PUT `staff/{staff}/allowance` sets the yearly allowance with a reason.

Requests and allowance changes enforce school/staff access on the server. The staff identifier is the existing school **user ID**, matching staff attendance. Unactivated invitations have no leave history yet.
