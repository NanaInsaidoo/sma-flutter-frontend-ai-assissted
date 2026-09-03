# Fees and Requirements Training Manual

## Purpose

This manual explains how school administrators, headmasters, bursars, and accountants use every area under **Fees and Requirements**. It covers setup, approvals, publishing, collections, corrections, items and supplies, waivers, and the most common business scenarios.

The system separates preparation from information that is already in use:

- **Draft** work can be edited and has no effect on a student or parent.
- **Pending approval** work is waiting for a different authorized person.
- **Approved** work has passed review but may still require publishing.
- **Published/Active** work is the version used on student accounts and visible in the appropriate portals and reports.

The creator must not approve their own financial request.

## Who can do what

| Role | Typical responsibilities |
|---|---|
| Bursar / Accountant | Prepare fee structures, collect payments, create adjustments, request reversals, prepare waivers, manage required items |
| Administrator | Perform the same operational work when permitted, review school-wide status, approve another person's requests |
| Headmaster | Review and approve requests, monitor completion, publish approved school information when authorized |
| Teacher | Does not normally manage school fees or financial approvals |

Actual access follows the roles assigned to the user's account. A staff member with more than one role can use the relevant workspace.

## Navigation

Open the school workspace and select **Fees and Requirements**. The available tabs are:

1. Overview
2. Student Fees
3. Fee Structure
4. Fee Catalogue
5. Fee Adjustments
6. Payment Reversals
7. Items & Supplies
8. Waivers

The left menu also shows **Requests & Approvals**. Its counts update when a request is created, submitted, withdrawn, approved, or rejected.

## 1. Overview

The Overview is the daily finance dashboard. It summarizes expected fees, collections, outstanding balances, collection progress, and records needing attention.

Use the quick actions to:

- collect fees;
- find a student;
- record an expense;
- open requests and approvals;
- review incomplete fee setup.

### Fee setup warning

If one or more streams do not have published fees, a warning remains visible. It disappears as soon as every applicable stream has an active fee structure. A successful “fees are active” message is temporary and should not remain as permanent dashboard clutter.

## 2. Student Fees

This tab is the quickest way to find a student's financial account.

### Find a student

Search by the student's full or partial name or student ID. You can also filter by class and payment status. Select a row to open the student fee panel.

The panel shows:

- total expected amount;
- total paid;
- balance or overpayment;
- fee-by-fee breakdown;
- approved discounts, surcharges, and waivers;
- payment history and reversals;
- the actions **Collect Fees**, **Assign Waiver**, and **Print Statement**.

### Collect fees

1. Select the student.
2. Select **Collect Fees**.
3. Enter the amount received and payment date.
4. Select the payment method.
5. Enter the physical receipt number when required.
6. Optionally attach the receipt image.
7. Review the resulting balance.
8. Save the payment.

The system allows an overpayment. A reason is required, and administrators are notified. At term close, approved remaining credit can be carried into the next term balance.

### Financial activity

Payments, approved adjustments, reversals, waivers, and carried balances form one dated financial history. Use the table headings to sort and the filters to narrow the activity by date or type.

## 3. Fee Structure

A fee structure is the list of fee items and amounts applied to a stream for a specific term.

### Create a fee structure

1. Choose the academic term.
2. Select a stream.
3. Open the stream card or row; it opens directly in the side panel.
4. Add fee items from the Fee Catalogue.
5. Enter each amount and any relevant description or due date.
6. Select **Save draft** to continue later, or **Submit for approval**.

Every applicable stream must contain at least one fee item before the school's fee setup is complete.

### Copy fees to other streams

From a stream's fee editor, select fee items and use **Copy to streams**. Choose the destination streams. If the same fee item already exists, the confirmation names up to three affected streams and then shows “and X more.” Continuing overwrites that fee item's value in the selected streams and returns any affected pending version to Draft.

### Fee structure workflow

```text
Draft
  ├─ Save draft → Draft
  └─ Submit to a different approver → Pending approval

Pending approval
  ├─ Creator withdraws → Draft
  ├─ Approver rejects with reason → Draft / changes requested
  └─ Approver approves → Approved

Approved
  └─ Authorized user publishes → Published / Active / Locked

Published
  └─ Edit → New modified Draft; the published version remains active
```

Publishing a revised version replaces the active fee list only after approval. Existing receipts are never rewritten. If a financial correction is required after payments exist, use an approved student adjustment rather than changing historical payment records.

## 4. Fee Catalogue

The Fee Catalogue is the school's reusable list of fee names. It keeps fee naming consistent when building stream fee structures.

The catalogue contains:

- protected system items supplied by the application;
- custom items created for the school.

System items cannot be deleted. A school can create, edit, deactivate, restore, or remove its own custom items. Fee amounts are not stored in the catalogue; amounts belong to each stream's term fee structure.

Custom catalogue codes are school-scoped in the database, so two schools may use the same visible code without colliding. Users see the simple school code rather than the internal tenant-qualified value.

## 5. Fee Adjustments

Use an adjustment for a student-specific discount or surcharge without changing the published fee structure for the whole class.

### Create an adjustment

1. Find and select the student by name or student ID.
2. Select the fee item.
3. Choose **Discount** or **Surcharge**.
4. Enter a positive amount; the selected type controls whether it reduces or increases the fee.
5. Enter the reason.
6. Save as Draft or submit to a different approver.

The preview shows the selected fee's own result and does not misleadingly combine unrelated adjustments.

Approved adjustments appear in the student's financial activity. A pending or draft adjustment does not change the student's balance.

## 6. Payment Reversals

Reversals correct a payment that should not remain on the account. They do not delete the original payment.

1. Open the payment from the student's financial activity.
2. Select **Request reversal**.
3. Enter the reason and choose an eligible approver.
4. Submit the request.

The original payment remains visible. After approval, the system records a linked reversal entry so the audit trail and receipt history remain intact.

## 7. Items & Supplies

This area manages physical items students are expected to bring. It contains two main views:

- **Requirements by class**
- **Student-specific requirements**

The tab badge shows the single useful action count: records that are not yet published.

### Class requirements

Open a class to see two clearly separated sections:

- **Currently published** — the list visible in portals and reports;
- **Draft changes** — new, modified, or removed items being prepared.

Each row shows the required quantity prominently. Estimated price is supporting information only.

### Add or change a class item

1. Open the class requirement.
2. Select **Add class item**, or edit a published item.
3. Enter name, category, required quantity, unit, due date, estimated unit price, and instructions.
4. Save the draft.
5. Submit the draft section for approval.

Editing an approved or published item creates a revised Draft. The live published item remains available until the revised list is approved and published.

### Approval and publishing

After approval, a visible banner explains the next step: publish the approved items so they appear in parent/student portals and reports. The publication review lists the entire final set with **New**, **Modified**, **Unchanged**, or **Removed** indicators.

### Student-specific requirements

Use this tab when one student needs an item that is not required from the entire class.

1. Select **Add student item**.
2. Search by student name or ID; do not choose from a long dropdown.
3. Confirm the suggestion using full name, student ID, and class.
4. Enter item and quantity details.
5. Save as Draft or submit for approval.

The item appears on the student's Items & Supplies page after publication.

### Exempt a student

Open the student's Items & Supplies page, open the item's action menu, and select **Exempt student from this item**. The item remains visible but is clearly marked **Exempted**. This preserves the class requirement and the audit trail.

### Collect physical items

Collections are recorded from the student's page:

1. Open **Items & Supplies**.
2. Select **Collect items**.
3. Enter the quantities received for one or more items.
4. Save.

The system generates a receipt, updates received and remaining quantities, and retains the transaction for later viewing and download. Partial collections are supported.

### Completion dashboard

Overall completion is based on published, non-exempt requirements. Draft items do not count until published. A student is complete when every applicable published item has been fully received or is exempted.

## 8. Waivers & Discounts

A waiver or discount reduces a student's assessed fees. It never changes the class fee structure. The screen uses both words because some users may not be familiar with the term “waiver.”

The **Waivers & Discounts** page shows:

- **Total waiver value** — active waiver value for the selected term;
- **Students on waivers** — unique students with active waivers;
- **Waivers pending** — requests awaiting a decision;
- **Waiver & discount types** — the reusable types available to this school, such as sibling discount, scholarship, or staff-child discount;
- **Students on waivers & discounts** — a searchable, sortable student list showing active awards, total value, and pending requests.

Select a student's name in the second tab to open that student's record. The student page is where staff review the individual fee account and its related history.

### Assign a waiver from the Waivers & Discounts page

1. Select **Assign waiver**.
2. Search using the student's name or ID.
3. Confirm the suggestion showing full name, student ID, and class.
4. Select the waiver type.
5. Enter percentage or amount.
6. For a fee-specific waiver, select the eligible fee items.
7. Enter the business reason.
8. Select **Save draft** or **Submit for approval**.

### Assign a waiver from Student Fees

1. Open **Student Fees**.
2. Find and open the student.
3. Select **Assign Waiver**.
4. Complete the same waiver form. The student is already selected.

### Waiver workflow

```text
New waiver → Draft → Pending approval → Active
                     └─ Rejected → Draft for correction

Active waiver edited → Modified Draft → Pending approval → New Active version
Active waiver revocation → Revocation Draft → Pending approval → Revoked
```

Important rules:

- Draft and pending waivers do not reduce a balance.
- The creator may edit a Draft.
- The creator may withdraw a pending request; it returns to Draft on the same screen.
- A different eligible person must approve.
- Rejection requires a reason and returns the request to Draft.
- Editing an Active waiver creates a new modified Draft; the current waiver stays active until approval.
- Revocation follows approval; it does not immediately remove the waiver.
- Only one open revision is allowed for the same active waiver.

## Requests & Approvals

The unified page contains requests from fee structures, fee adjustments, payment reversals, class requirements, student-specific requirements, student transfers, and waivers.

- **My Requests** shows work you created and its status.
- **My Approvals** shows requests assigned to you.
- Opening a request shows the original submitted information in read-only form.
- Before an action is applied, the backend checks the latest status. If another user already acted, the application explains that the request changed and refreshes it.

## Common scenarios

### A new school is setting up fees

Create class/stream fee structures, submit them to another administrator/headmaster, approve, then publish. The setup warning disappears only when every applicable stream has active fees.

### An existing school is preparing next term

Select the prepared term, build Draft structures and requirements, complete approval, and publish at the appropriate time. The current term remains unaffected until the new term's versions become active.

### A student's fee should differ from classmates

Do not edit the class fee structure. Use a student fee adjustment for a one-off discount/surcharge or a waiver for an approved reduction policy.

### A published item needs changing

Edit the published item. The system creates Draft changes while keeping the published list live. Submit, approve, and publish the revision.

### A request cannot be approved

Confirm that:

- it is assigned to the signed-in user;
- it is still Pending approval;
- the approver is not the creator;
- the approver has Administrator, Headmaster, Bursar, or another configured approval role;
- another browser session has not already acted on it.

## End-of-term checks

Before closing a term, review:

- published fee structures for all applicable streams;
- outstanding balances and approved overpayment credits;
- pending fee adjustments and reversals;
- active and pending waivers;
- published class and student-specific item requirements;
- uncollected physical items and exemptions;
- all pending Requests & Approvals.

Do not close the term while a financial request that affects the closing balance is still pending.

## Glossary

| Term | Meaning |
|---|---|
| Fee Catalogue | Reusable school list of fee names; it does not hold stream amounts |
| Fee Structure | Term-specific fee items and amounts applied to a stream |
| Adjustment | Student-specific discount or surcharge |
| Reversal | An auditable correction that offsets a recorded payment |
| Waiver | Approved reduction of a student's assessed fees |
| Requirement | Physical item a class or individual student must provide |
| Draft | Editable work that is not yet active |
| Pending approval | Submitted work awaiting another authorized user |
| Approved | Reviewed work awaiting publication where publication is required |
| Published / Active | Live information used in accounts, portals, or reports |
