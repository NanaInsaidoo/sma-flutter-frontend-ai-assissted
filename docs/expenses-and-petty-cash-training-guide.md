# Expenses & Petty Cash Training Guide

**Version:** 1.1

**Last updated:** 12 September 2026

**Audience:** School administrators, headmasters/headteachers, bursars, petty-cash custodians, finance officers, requesters, trainers, and auditors

## 1. Purpose

This guide explains how to use the **Expenses & Petty Cash** workspace to request, approve, record, replenish, reconcile, and review school spending.

The module provides an operational record and audit trail. It is not a complete accounting or general-ledger system. Accountants may use its records as source documents for formal accounting treatment.

The core control principles are:

- spending starts with a requisition;
- school-funded and petty-cash spending remain clearly separated;
- the person requesting money should not approve their own request;
- money is not treated as received until the named recipient confirms it;
- completed financial history is corrected through linked entries, never erased;
- exceptions require notes and remain visible until resolved; and
- Cash and MoMo are separate petty-cash pockets.

### Key changes in version 1.1

- Every requisition now records its requester and selected approver.
- The approver confirms the request as submitted and cannot change its amount.
- A requester may return an unspent petty-cash requisition to Draft, edit it, and resubmit it. Any earlier approval is invalidated and the new route is validated again.
- Petty-cash request and approval checks use the configured single-expense limit. The selected pocket's available balance becomes a hard blocker only when actual spend is recorded.
- Administrators can enable or disable automatic approval for small, non-emergency petty-cash requests and set a separate audited limit.
- Requisitions show their expiry date and remaining validity period.
- Higher and lower actual amounts are shown in a final confirmation. Only a percentage difference above the configured tolerance enters variance review.
- Variance decisions and notes are retained in the expense history as **Accepted** or **Escalated to follow-up**. Older correction-request events remain visible as historical audit entries.
- Financial follow-ups now show a linked expense, concise case summary, append-only activity timeline, and a separate administrator closure step.
- Open top-ups, reconciliations, and Financial follow-ups display red pending counts on the Petty Cash tabs.
- A disbursed top-up that remains unconfirmed for 15 minutes displays a persistent funds-received reminder with the minutes overdue.
- Refunds, reversals, and already-disbursed top-ups are always recorded when money has actually moved. Any resulting float overage automatically creates an urgent Financial follow-up and alerts finance managers.
- Top-up, reconciliation, and pocket-transfer controls appear above the petty-cash expense list and open dedicated history or detail workspaces.

## 2. Learning Outcomes

After training, a user should be able to:

1. Distinguish a School funds expense from a Petty cash expense.
2. Create a standard or emergency requisition.
3. Approve, decline, revoke, fulfil, or review a requisition correctly.
4. Record an actual payment and explain any variance.
5. Request, approve, disburse, and confirm a petty-cash top-up.
6. Transfer money between Cash and MoMo without recording a false expense.
7. Perform a reconciliation and resolve a shortage or surplus.
8. Use Financial follow-ups for recovery, missing evidence, refunds, and unresolved issues.
9. Understand which records may be cancelled and which require a correcting entry.

## 3. Workspace Layout

The main menu contains one finance entry: **Expenses & Petty Cash**.

Finance managers see six main tabs. Ordinary requesters see **Requisitions** and
**My Expenses** only.

| Tab | Purpose |
| --- | --- |
| **Overview** | Summarises float balance, school and petty-cash spending, pending approvals, and urgent actions. |
| **Requisitions** | Holds all requests before spending. Filter by funding source and status. |
| **My Expenses** | For ordinary requesters, shows only expenses recorded from their own requisitions. Records may be opened, printed, or downloaded, but finance correction actions are not available here. |
| **School Expenses** | Shows completed spending paid from school bank, cheque, or the main school MoMo account. |
| **Petty Cash** | Holds petty-cash expenses, Cash/MoMo pockets, top-ups, transfers, reconciliations, and financial follow-ups. |
| **Approvals** | Shows requisitions, top-ups, emergency ratifications, and variances needing an authorised decision. |
| **Reports** | Reserved for management and audit reporting. See the current-release caveats before relying on it. |

Within **Petty Cash**, use:

- **Float & expenses** for balances and petty-cash expenses. The control strip above the expense list opens top-up, reconciliation, and pocket-transfer workspaces without scrolling through the register;
- **Reconciliations** for cash and MoMo counts; and
- **Financial follow-ups** for unresolved exceptions.

The page header also keeps **Request reconciliation** available to authorised managers. The float summary keeps **Request top-up**, **Transfer pocket**, and **Settings** close to the current balances.

Red number badges count active work only. The main **Petty Cash** badge combines active top-ups, open reconciliations, and open Financial follow-ups. Each inner tab shows its own count. Completed and closed history is not counted.

The School Expenses and Petty Cash expense registers are searchable, filterable, and paginated at eight records per page. Select the **Expense**, **Amount**, **Status**, or **Date** column heading to sort; select the active heading again to reverse the order. Search or filter changes return the register to its first page.

## 4. Key Terms

| Term | Meaning |
| --- | --- |
| **Requisition** | A request describing what the school intends to buy and the estimated amount. |
| **School funds** | Money paid directly from the school bank account, cheque, or main school MoMo account. |
| **Petty cash** | A controlled short-term float held as physical Cash and/or MoMo. |
| **Actual spend** | The amount finally paid after a requisition is approved, or after emergency authorisation. |
| **Variance** | Any difference between the approved/authorised amount and the actual amount. |
| **Ratification** | Formal approval after an emergency payment has already happened. |
| **Top-up** | Money provided to replenish the petty-cash float. It is not income or an expense. |
| **Pocket transfer** | A movement between the Cash and MoMo pockets. It is not an expense. |
| **Reconciliation** | A comparison of system Cash/MoMo balances with the amounts actually counted. |
| **Financial follow-up** | A retained exception record requiring recovery, evidence, correction, refund, or a final decision. |

## 5. Roles and Responsibilities

System access is permission-based. A person's job title alone does not guarantee access.

| Actor | Normal responsibilities |
| --- | --- |
| **Requester** | Creates a requisition or top-up request, provides a reason, and confirms funds received where applicable. |
| **Teacher / ordinary staff requester** | Sees Expenses & Petty Cash in the main menu, but only the Requisitions and My Expenses pages. School-wide balances, other users' records, approvals, controls, and reports remain hidden. |
| **Approver** | Reviews business need, amount, funding source, supporting evidence, and separation of duties. Approves or declines with a reason. |
| **Disburser** | Issues an approved top-up, selects the Cash/MoMo split, confirms the intended receiver, and records the date, reference, and note. |
| **Bursar / custodian** | Records spending, maintains receipts, safeguards the Cash/MoMo pockets, and performs reconciliations. |
| **Administrator / headmaster** | Has broad finance oversight, can approve where authorised, request reconciliation, reassign a disburser, resolve variances, and close follow-ups. |
| **Accountant / auditor** | Reviews retained records and uses them as source material for accounting and audit work. |

### Separation of duties

- A requester must not approve their own standard requisition or top-up.
- The selected top-up approver is the only person who may approve or decline that top-up.
- The selected disburser is the person expected to issue the money.
- An administrator may reassign an unavailable disburser and may act as disburser when authorised.
- Only the named requester/receiver confirms that top-up funds were received.
- Emergency ratification must be completed by a different authorised actor from the person who recorded the payment.
- Only an authorised administrator can make final variance and follow-up decisions.

Never share accounts. The audit trail records the signed-in user.

An ordinary requester does not see the school's float balance, total spending,
other users' expenses, reconciliations, top-ups, follow-ups, reports, or manager
actions. After spending is recorded from that requester's approved requisition,
the resulting record appears under **My Expenses**. Older linked expenses are
also resolved through their original requisition, even when the requester was not
copied directly onto the historical expense record.

## 6. Before Users Begin

An administrator must configure the finance workspace for the academic term.

### Petty-cash settings

| Setting | Training explanation |
| --- | --- |
| **Approved float amount** | The normal total amount the school has authorised for petty cash. |
| **Cash/MoMo opening balance** | The system starts at zero. Initial money enters through an approved and confirmed top-up. |
| **Single petty-cash expense limit** | The maximum permitted amount for one petty-cash requisition or actual petty-cash expense. It cannot exceed the approved float. Amounts above it must use School funds. |
| **Refill threshold** | The balance at which the system warns that petty cash is running low. It does not add money automatically. |
| **MoMo wallet** | The designated wallet used for the petty-cash MoMo pocket. |
| **Variance tolerance** | The maximum percentage difference between approved and actual spend that may complete without variance review. Both higher and lower differences use the same calculation. |
| **Requisition expiry** | The number of days from submission that a pending or approved request remains valid. It must be between 1 and 90 days. |
| **Automatic approval** | An administrator-controlled on/off setting for small, non-emergency petty-cash requests. Its amount limit must be greater than zero and no higher than the single-expense limit. |
| **Transaction fees** | Whether transfer fees are captured and reduce the source pocket. |

All settings changes are recorded in the finance history. The approved float cannot be reduced below the current combined Cash and MoMo balance, and the refill threshold must be between zero and the approved float.

Recommended operating practice:

- keep only enough petty cash for approximately one week of routine spending;
- reconcile weekly and whenever risk justifies an additional check;
- restrict custody of physical cash and the MoMo wallet;
- never enter opening money by manually editing a balance; and
- use the first approved top-up to establish the opening float.

## 7. Choosing the Funding Source

Every new requisition asks: **How will this purchase be funded?**

### School funds

Select **School funds** when payment will be made by:

- cash held outside the petty-cash float;
- bank transfer;
- cheque; or
- the main school MoMo account.

These payments appear under **School Expenses**. They do not reduce the petty-cash Cash or MoMo pockets.

Examples include utility bills, major repairs, equipment, supplier invoices, and larger purchases.

### Petty cash

Select **Petty cash** when payment will be made from:

- the controlled physical Cash pocket; or
- the designated petty-cash MoMo pocket.

These payments appear inside **Petty Cash** and reduce the selected pocket.

Examples include stationery, local transport, small repairs, cleaning supplies, and minor urgent purchases.

### Important rule

The funding source cannot be bypassed at payment time:

- a School funds request must use cash, bank transfer, cheque, or direct school MoMo; and
- a Petty cash request must use the Cash or MoMo float pocket.

If the source was chosen incorrectly, cancel the request before payment and create a correct one. Do not use a misleading payment method to force it through.

For an unspent petty-cash requisition, the requester may instead select **Edit**. This immediately returns the request to Draft and removes any earlier approval. The requester may correct the funding source and other request details, but the entire revised request is treated as new for validation and approval.

### Limit and balance checks by stage

| Stage | Single-expense limit | Current Cash/MoMo balance |
| --- | --- | --- |
| Create Draft | The form shows the configured rule. Final enforcement occurs on submission. | Not reserved or deducted. |
| Submit / approve | A petty-cash amount above the configured limit is blocked. | A low current balance does not block approval because the float may be replenished before payment. |
| Record actual spend | The actual petty-cash amount must still be within the configured limit. | The selected Cash or MoMo pocket must cover the full actual amount. A negative balance is never permitted. |

Approval therefore grants authority to spend; it does not guarantee that a particular pocket will still have enough money later.

## 8. Standard Expense Lifecycle

```text
Create requisition
        |
        v
Submitted / Pending approval
        |
        +---- Declined or Cancelled -> Closed with history retained
        |
        v
Approved
        |
        +---- Approval revoked before payment -> Closed/reviewed
        |
        v
Record actual spend and receipt details
        |
        +---- Amount matches -> Complete
        |
        +---- Amount differs -> Pending variance review -> Complete after review
```

### Step 1: Create the requisition

Select **New requisition** and enter:

- funding source;
- description;
- estimated amount;
- vendor, when known;
- category;
- reason; and
- selected approver and approval route.

Use a description that another person can understand without asking the requester. Avoid entries such as "items", "things", or "school needs".

### Step 2: Submit for approval

For normal purchases, choose **Standard approval**.

The request enters the selected approver's action queue and receives an expiry date. No money should leave the school while it is pending.

If automatic approval is enabled, an eligible non-emergency petty-cash request at or below the configured auto-approval limit moves directly to **Approved**. The history identifies the decision as a system auto-approval. School-funded and emergency requests are not auto-approved.

### Step 3: Approver reviews

The approver checks:

- whether the purchase is necessary;
- whether the category and funding source are correct;
- whether the estimated amount is reasonable;
- whether the petty-cash amount is suitable and within the configured limit;
- whether supporting information is adequate; and
- whether the requester and approver are different people.

The approver sees a concise confirmation before approving and must enter an approval note that records why the request was accepted. The note is shown in approval history. They may approve, request changes, or decline, but they cannot change the request amount. If the amount or another request fact is wrong, it must return to the requester for editing and resubmission. Approval does not itself create an expense, reserve a pocket balance, or move money.

### Step 4: Record the actual spend

After payment happens, open the approved requisition and select **Record actual spend**.

The form shows the current Cash or MoMo balance next to each petty-cash payment method. Description and vendor remain locked to the approved request. The actual amount, payment method, receipt information, and payment note describe what was paid. The selected pocket is checked again when the form is submitted and can never become negative.

Enter:

- actual amount;
- permitted payment method;
- receipt or invoice reference;
- receipt photo/PDF, when available; and
- an explanatory note where needed.

The approved description, vendor/payee, category, and funding source remain read-only during actual-spend recording. This prevents the paid record from silently becoming a different purchase. The user records only transaction facts, including the actual amount, permitted payment method, date, and receipt evidence.

Before saving, the application presents a final summary of approved amount, actual amount, difference, percentage, and tolerance outcome. The expense appears in the correct register only after this affirmation is confirmed.

For petty cash, the selected pocket balance is checked at this point. If Cash or MoMo is insufficient, the expense is not created and no balance changes. Replenish or transfer funds, then retry against the correct pocket.

### Editing an unspent petty-cash request

- Only the requester can select **Edit**.
- Selecting Edit immediately changes the requisition to **Draft**.
- Any prior approval, approval date, and expiry are invalidated.
- The requester may edit the request fields, including funding source and approver.
- Resubmission applies the revised funding source, amount limits, auto-approval setting, approver route, and a fresh expiry period.
- An expense already recorded from the requisition cannot be edited or cancelled this way.

## 9. Approval Rules and Caveats

### Pending approval

- No payment should be made.
- The requester may edit or cancel it with a note.
- Only the selected approver may approve, request changes, or decline it.
- The approver confirms the amount exactly as requested; they cannot substitute another amount.

### Approved but not paid

- Approval confirms permission to proceed; it is not proof that payment occurred.
- An authorised finance approver may revoke approval before an actual payment is recorded.
- The requester may cancel or return an unspent petty-cash request to Draft.
- If the purchase is no longer needed, cancel or revoke with a meaningful note.

### Expired request

- The expiry date and days remaining are visible in the requisition register and details.
- A pending or approved requisition cannot be approved or spent after expiry.
- Do not backdate a payment to bypass expiry.
- The requester may return an eligible unspent petty-cash request to Draft, review all details, and resubmit it for a fresh validity period. Otherwise, create a replacement requisition.

### Payment already made

- Do not cancel or delete the financial fact.
- Use variance review, ratification, refund, reversal, or a financial follow-up as appropriate.

### Notes

A meaningful note should be required for:

- decline or rejection;
- approval revocation;
- emergency ratification;
- variance review;
- top-up approval, decline, cancellation, or correction;
- expense reversal request, approval, decline, or cancellation;
- disburser reassignment;
- reconciliation confirmation and resolution; and
- financial follow-up closure.

Write what happened and why. Avoid notes such as "done", "okay", or "approved".

Form validation appears beside the affected field or inside the form. Correct the field indicated; do not repeatedly submit after a validation failure. A failed submission does not create a financial record or change a balance.

On a phone or narrow window, use the horizontal swipe area inside a finance register to view later columns and actions. The table keeps normal column widths so headings and values remain readable.

## 10. Emergency Purchase Lifecycle

Use **Emergency purchase** only where urgent circumstances prevented prior approval.

```text
Emergency requisition with verbal approver
        |
        v
Record payment already made / urgently required
        |
        v
Pending ratification
        |
        +---- Amount differs -> Pending variance review after ratification
        |
        v
Ratified by a different authorised person
        |
        v
Complete after any variance is reviewed
```

Required information includes:

- what was purchased;
- why normal approval could not be obtained;
- estimated/verbally authorised amount;
- who gave verbal authorisation;
- actual amount and payment method;
- receipt or other evidence; and
- a written ratification note.

Ratification is not permission to spend. It is an after-the-fact acknowledgement that money already moved and that the authorised reviewer accepts the transaction as legitimate.

Emergency status must never be used merely to avoid waiting for approval.

## 11. Expense Variances

A variance exists whenever actual spend is higher or lower than the approved or verbally authorised amount.

The application calculates:

```text
Variance percentage = |actual amount - approved amount| / approved amount x 100
```

- A zero difference completes normally.
- A non-zero difference at or below the configured tolerance is recorded at the true actual amount and completes without a variance-review case.
- A difference above the tolerance is recorded at the true actual amount and enters **Pending variance review**.
- The tolerance controls review routing only. It never permits an unavailable petty-cash pocket to become negative.

### Higher actual amount

Example: approved GH¢500, actual GH¢540.

- Record the true GH¢540 amount.
- Review the final variance affirmation and add an explanation where required.
- If the percentage exceeds tolerance, the transaction is flagged for review.
- An authorised administrator or headteacher decides whether to accept the variance or escalate it.

### Lower actual amount

Example: approved GH¢500, actual GH¢460.

- Record the true GH¢460 amount.
- Unused petty cash remains in the relevant pocket.
- Review the final variance affirmation.
- The difference requires a variance-review decision only when its percentage exceeds the configured tolerance.

### Administrator outcomes

| Outcome | Effect |
| --- | --- |
| **Accept variance** | Keeps the actual expense and completes the review. |
| **Escalate to follow-up** | Completes the expense review and creates a linked Financial follow-up for separate investigation. |

A review note is mandatory. This administrator decision does not require another approval. The selected outcome, reviewer, date, note, and variance amount remain in the expense's review history. Reopening the expense or review displays the prior activity; adding a note does not make it disappear. If the posted expense itself is wrong, use the separate expense-reversal workflow rather than changing it during variance review.

### Never do this

- Do not enter the approved amount when the actual amount was different.
- Do not create a false second expense to absorb the difference.
- Do not delete the original transaction.

## 12. Duplicate and Receipt Controls

The system checks for similar spending using vendor, amount, date, and receipt information.

Operational rules:

- investigate a duplicate warning before continuing;
- never reuse a physical receipt number without a documented reason;
- attach the correct receipt or invoice where available;
- ensure the category matches the purchase; and
- explain any delayed or unusual entry.

The system cannot determine whether an uploaded image is genuinely a receipt. Approvers must inspect the evidence.

Financial transaction dates cannot be in the future. A transaction backdated by more than three days requires a reason. Top-up disbursement dates also cannot be earlier than the top-up request date.

## 13. Refunds, Reversals, and Corrections

A refund is a new financial event linked to the original expense. It does not erase or rewrite the original payment.

```text
Original expense: EXP-042  GH¢450  Complete
Linked refund:    REF-001  GH¢80   Refund for EXP-042
Net spend:                 GH¢370
```

To record a refund:

1. Find and open the original completed expense.
2. Select **Record refund**.
3. Enter the amount, reference, date, and reason.
4. Save the linked refund.

A refund cannot exceed the remaining unrefunded amount. Multiple partial refunds may be linked to one expense.

For a petty-cash expense, a supported refund credits the original pocket. For a School funds expense, it does not alter petty cash.

Money that was genuinely returned must be recorded even when it makes the float exceed its approved amount. The system credits the correct pocket, creates an immediately due **Float overage** follow-up for the newly created excess, and alerts finance managers. The excess must then be moved out of petty cash and the transfer documented before the follow-up is closed.

Do not use a refund where no money was returned. A supplier credit note or expected refund should remain a Financial follow-up until it is formally handled.

### Refund versus reversal

Use this decision rule:

| Question | Correct action |
| --- | --- |
| Was the original payment valid, and did money later come back? | **Record refund** |
| Was the expense entered by mistake, duplicated, recorded at the wrong amount/source, or was no payment made? | **Request reversal** |
| Is money only expected back later? | **Financial follow-up** until money is actually returned |

A reversal is a full, approval-controlled correction. It never deletes or edits the original expense.

```text
Original expense:  EXP-042  GH¢450  Reversed
Reversal request:  REV-018  GH¢450  Approved
Net school spend:           GH¢0
```

To reverse an expense:

1. Open the original expense and select **Request reversal**.
2. Select the recording-error type: duplicate entry, no payment made, wrong amount, wrong payment source, or other recording error.
3. Enter a detailed reason/evidence note and select an independent approver.
4. Affirm that the entire expense is being submitted for reversal.
5. The selected approver sees a concise decision summary showing the original expense ID and description, full amount to reverse, funding source, payment channel, payee, receipt, reason/evidence, and the exact financial effect. The approver should compare these facts with the original expense before deciding.
6. The approver may open the request from **Requests & Approvals** or select **Review reversal** in the Expenses approval queue. Both open the same full review screen. After reviewing it, the approver selects **Approve** or **Reject**; the decision opens a required comment form, and only after that note is submitted can the reversal be completed.
7. On approval, the original expense becomes **Reversed** and the linked reversal becomes **Approved**.

If restoring a petty-cash expense pushes the float above its approved total, the reversal still completes because the accounting correction must remain truthful. An urgent **Float overage** follow-up is created for the excess and finance managers are notified.

For petty cash, approval restores the full amount to the same Cash or MoMo pocket debited by the original expense. For School Expenses, it offsets school spend and never changes petty-cash pockets.

The requester may cancel a pending reversal with a note. Nobody may cancel an approved reversal or edit its amount. If the original amount or payment source was wrong, reverse it in full and use a new approved requisition to record the correct expense.

An expense that already has any refund cannot also be reversed. This prevents the same money being credited twice. Send such a case to finance administration or accounting for a separately documented correction; the current release does not provide a refund-reversal screen. Likewise, a pending or completed expense reversal blocks new refunds and duplicate reversal requests.

All finance administrators receive a reversal alert. The assigned approver also sees it in the Approvals action queue and badge. The expense detail and approval history retain requester, approver, reason, decision note, dates, original expense reference, and reversal reference.

## 14. Petty-Cash Top-up Lifecycle

A top-up restores the petty-cash float. It is not an expense and does not appear as school income.

```text
Requester selects approver and requests top-up
        |
        v
Selected approver approves and selects disburser
        |
        v
Selected disburser confirms receiver, Cash/MoMo split, date and note
        |
        v
Named requester confirms the same funds were received
        |
        v
Cash/MoMo pocket balances increase
```

### Requester

- enters the requested amount and reason;
- selects the intended approver; and
- may cancel while the request is still pending, with a note.

Before submission, a confirmation shows the requested amount. The request cannot exceed the amount needed to restore the approved float, and no request is allowed when the float is already full. Only one active top-up may exist at a time.

### Approver

- cannot approve their own request;
- verifies the amount against the current balance and approved float;
- approves the exact requested amount or declines with a note; and
- selects the person who will disburse the funds.

The approver cannot edit the requested amount. The approver may revoke approval before disbursement. Once money has been disbursed, it cannot simply be cancelled.

### Disburser

- explicitly selects the requester as the receiver;
- records how much is Cash and how much is MoMo;
- enters the wallet when MoMo is used;
- enters a date that is not before the request and not in the future;
- adds a reference where available; and
- adds a disbursement note.

Cash plus MoMo must exactly equal the approved top-up amount.

The assigned disburser sees an action notification until disbursement is recorded. An authorised administrator may reassign the case, including to another administrator or eligible bursar, when the original disburser is unavailable.

### Requester confirmation

The petty-cash balance does not increase merely because the disburser clicked **Disburse**. The named requester continues to see a confirmation action until they affirm the same Cash amount, MoMo amount, and wallet allocation.

After 15 minutes without confirmation, a red reminder remains visible throughout the Expenses & Petty Cash workspace and states how many minutes late the confirmation is. The pending badges remain until the funds are confirmed or the case is otherwise resolved.

If other valid activity has filled the float after the top-up was approved or disbursed, confirmation is not blocked: money that was actually received must be recorded. The system credits the confirmed Cash/MoMo allocation, creates an immediately due **Float overage** follow-up for the excess, and alerts finance managers. The excess must be removed from petty cash through a documented transfer.

### Problem or dispute

If the money or allocation is wrong, the requester selects **Report a problem** and adds a note.

- The top-up remains unresolved and visible.
- The original disburser or an administrator may record a correction.
- An administrator may reassign the case if the original disburser is unavailable.
- After correction, the requester confirms the corrected funds.
- If the requester later verifies that the original disbursement was correct, they may confirm it even while a problem is recorded.

There is no approval code in this workflow. Identity comes from signed-in users, assigned actors, explicit receiver selection, and the event timeline.

The completed top-up detail retains requester, approver, disburser, receiver, allocations, references, notes, disputes, corrections, and confirmation history. Approval removes the item from the approver's current action queue but does not remove it from history.

## 15. Cash and MoMo Pocket Transfers

Use **Pocket transfer** when value moves between the two petty-cash pockets.

Examples:

- MoMo is cashed out and placed in the physical cash box.
- Physical cash is deposited into the designated MoMo wallet.

Record:

- direction;
- amount;
- editable transfer/agent fee, including zero;
- date;
- reference; and
- note.

The transfer amount leaves one pocket and enters the other. Any fee reduces the source pocket and reduces total float. A transfer is not an expense and must not be entered as one.

The source pocket must cover both the transfer amount and any fee. Before recording, the application shows a direct affirmation of the route, amount, fee, resulting Cash balance, resulting MoMo balance, and total float. If the route or result is wrong, cancel the confirmation and correct the form. A completed transfer is retained in its dedicated history and must be corrected through a linked, documented movement rather than deleted.

## 16. Reconciliation Lifecycle

The recommended routine is weekly, but an administrator may request a reconciliation at any time.

Typical triggers include:

- week-end, month-end, or term-end;
- before a sensitive top-up;
- a change of custodian;
- a suspected cash or MoMo issue; or
- an unusual transaction.

Only one reconciliation may be open at a time.

```text
Administrator requests and assigns reconciliation
        |
        v
Custodian starts count
System snapshots expected Cash and MoMo at that moment
        |
        v
Custodian enters actual Cash, actual MoMo, evidence and note
        |
        +---- Match -> Confirmed
        |
        +---- Difference -> Variance open
                              |
                              v
                  Administrator records resolution
                              |
                              v
                  Reconciliation closes; follow-up remains if needed
```

### When is the balance measured?

The request itself does not contain an amount. Expected balances are captured when the custodian selects **Start count**.

If another Cash or MoMo transaction occurs while a count is in progress, the application warns users. The custodian should restart the count so the snapshot and physical count refer to the same moment.

The single-open rule includes a requested count, a count in progress, and an unresolved reconciliation variance. A second reconciliation cannot be requested until the current record is confirmed and closed.

### Calculation

```text
Expected pocket balance
  = confirmed opening/top-ups
  + incoming transfers and supported refunds
  - completed expenses
  - outgoing transfers and fees

Variance = actual counted amount - expected amount
```

- Negative variance: shortage.
- Positive variance: surplus.
- A Cash shortage and equal MoMo surplus are still two pocket differences; they do not silently cancel each other.

### Resolution options

| Resolution | Use when |
| --- | --- |
| **Recover from staff** | A named person is responsible for repaying a shortage. |
| **Write off** | Authorised management accepts the loss with evidence and a final note. |
| **Correct entry** | The difference came from a missing or incorrect transaction record. |
| **Excess return** | A genuine surplus must be returned or formally routed. |

Confirming a variance does not silently alter the pocket. The balance changes only when an administrator records a formal resolution, which creates an auditable adjustment. A shortage may also create a Financial follow-up.

Opening a reconciliation shows the expected and actual pocket amounts, evidence, notes, resolution, and status. Notes are retained in its activity history. Only a user with finance-approval authority may record the resolution and close the reconciliation.

## 17. Financial Follow-ups

Financial follow-ups keep operational exceptions visible without pretending they are normal expenses.

Examples include:

- staff recovery;
- cash shortage or loss under investigation;
- missing receipt;
- supplier refund due;
- unconfirmed MoMo movement;
- incorrect entry requiring correction;
- unexplained surplus;
- confirmed funds that temporarily take petty cash above its approved float; or
- approved write-off.

### Lost money example

```text
System expected Cash                 GH¢835
Actual Cash counted                  GH¢805
Shortage                              GH¢30

Administrator resolution:
1. Post an explicit reconciliation adjustment to show actual Cash of GH¢805.
2. Create a GH¢30 Staff recovery follow-up.
3. Keep the recovery open until repayment or another authorised decision.
```

The float may later be replenished to its normal amount. That does not clear the staff recovery. The follow-up stays open across future cycles and is not repeatedly recorded as an expense.

When repayment arrives, record the repayment/evidence against the follow-up and close it with a final administrator note. If management authorises a write-off, the write-off is documented as the resolution; it is not disguised as an ordinary purchase.

### Working a follow-up

1. Open **Petty Cash**, then **Financial follow-ups**.
2. Open the follow-up reference to view its type, amount, status, responsible party, due date, and attention reason.
3. Select the linked expense reference to open the original expense detail. The expense is never replaced by the follow-up.
4. Add investigation notes or evidence references. Each update appears immediately in the append-only activity timeline with its author and date.
5. Keep the case open while recovery, correction, evidence, or management action remains outstanding.
6. A user with finance-approval authority closes the case using a separate resolution note. Closing preserves the case and all prior activity.

### Resolving a Float overage

A **Float overage** is created by the system, not manually. It means a refund, approved reversal, or confirmed top-up caused the total Cash and MoMo balance to exceed the approved float. The incoming money is recorded first because it has actually arrived.

When this control is introduced to an existing school, any active cycle that is already above its approved float receives one backfilled overage case. This does not change the recorded balance; it brings the pre-existing excess into the same visible resolution process without creating duplicate cases.

To close the overage:

1. Move the excess back to the school operating account or other authorised school-funds location.
2. Open the **Float overage** follow-up.
3. Select **Close follow-up**.
4. Enter how much was returned from Cash and how much was returned from MoMo. The two amounts must total the exact overage amount, and neither entry may exceed its available pocket balance.
5. Enter the bank deposit, transfer, or journal reference.
6. Add a resolution note stating where the funds went and who verified the movement.
7. Select **Record return & close**.

The system immediately reduces the selected petty-cash pockets and creates a linked **Float return** transaction to School funds. The original refund, reversal, or top-up remains unchanged. The overage case, return reference, administrator, amounts, and notes remain in the audit trail.

Do not close a Float overage using only a note. Do not use **Pocket transfer**, because that control only moves money between Cash and MoMo and does not reduce the total float. If the exact return would make either pocket negative, the system blocks closure; verify the physical balances and investigate the difference first.

An overdue follow-up remains visible; it does not automatically become an expense or disappear at term rollover. A note alone also does not close the case.

## 18. Records and Statuses

### Requisition statuses

| Status | Meaning |
| --- | --- |
| Draft | Created but not submitted. |
| Pending | Awaiting approval. |
| Approved | Permission granted manually or by an eligible system auto-approval; payment not necessarily made. |
| Changes requested | Returned to the requester for clarification or editing. |
| Rejected | Not authorised to proceed. |
| Revoked | Earlier approval withdrawn before payment. |
| Expired | The configured validity period ended before approval or actual spend. |
| Cancelled | The requester closed the unspent request with a note. |
| Fulfilled | Actual spending has been recorded. |

### Expense statuses

| Status | Meaning |
| --- | --- |
| Complete | Payment is recorded and required reviews are complete. |
| Pending ratification | Emergency payment awaits formal after-the-fact review. |
| Pending variance review | The actual and approved amounts differ by more than the configured tolerance. |
| Pending reversal | A full correction request is awaiting its selected independent approver. The expense remains posted until approval. |
| Reversed | An approved linked reversal offsets the full expense; original history remains. |
| Partially / fully refunded | Money was returned after a valid payment; linked refund entries reduce net spend. |

### Top-up statuses

| Status | Meaning |
| --- | --- |
| Pending | Awaiting the selected approver. |
| Approved | Approved and assigned for disbursement. |
| Declined | Closed without changing the balance. |
| Disbursed | Money was issued and awaits requester confirmation. |
| Disbursement disputed | Requester reported a problem. |
| Correction awaiting confirmation | A correction was recorded; requester must verify it. |
| Approval revoked | Approval was withdrawn before disbursement. |
| Confirmed | Recipient verified funds; pockets were credited. |
| Cancelled | Requester cancelled before approval/disbursement. |

### Reconciliation statuses

| Status | Meaning |
| --- | --- |
| Requested | Assigned but count not started. |
| In progress | Expected balances were snapshotted and counting is underway. |
| Confirmed | Count matched the expected pockets. |
| Variance open | A difference requires an administrator decision. |
| Variance closed | Resolution was recorded and the reconciliation closed. |

### Financial follow-up statuses

| Status | Meaning |
| --- | --- |
| Open | Investigation or action is outstanding. |
| Awaiting evidence | A receipt, statement, explanation, or other evidence is required. |
| Under investigation | Responsibility or treatment is still being established. |
| Partially recovered | Some, but not all, of the expected recovery or refund has been resolved. |
| Closed | An authorised final resolution note was recorded. |

## 19. Current-Release Caveats and Go-Live Cautions

Trainers and administrators must understand these remaining limitations and operational cautions. Do not represent an unverified integration as a completed control.

1. **Reports are not production-ready.** The Reports tab is currently outside the verified finance scope. Use transaction and detail records for operational review until reports are implemented and validated.
2. **Receipt storage still needs a real S3 verification.** The upload flow exists, but secure upload/view of a real receipt remains a production-hardening check.
3. **The app cannot verify receipt content.** A user can upload the wrong image or PDF. Human review remains mandatory.
4. **Duplicate handling needs a complete user confirmation flow.** The backend detects a possible duplicate, but the current UI does not yet provide the final intentional-duplicate confirmation journey. Stop and investigate rather than retrying blindly.
5. **Follow-up entries are operational records, not accounting postings.** Manual and system-generated follow-ups, due dates, linked references, notes, and administrator closure are persisted. Accountants must still decide and post the formal accounting treatment outside this module.
6. **Closed-cycle and different-method refunds need further routing work.** The present refund process links the refund and protects against over-refunding, but changing the refund destination or routing a late refund into a newer cycle/general account is not fully supported in the UI.
7. **School-funded requisitions currently depend on the term finance workspace being configured.** The two spending registers are separated, but both use the same term-scoped finance service.
8. **Intermediate follow-up states require operational discipline.** Notes and closure are persisted, but staff must keep responsibility, due dates, evidence, and any partial recovery clear in the timeline until richer accounting treatment is integrated.
9. **Permissions must match real duties.** A visible action is not a substitute for management authorisation. Review FINANCE VIEW, EDIT, and APPROVE access whenever staff responsibilities change.
10. **Do not delete completed finance records.** Corrections must use refund, reversal, reconciliation adjustment, or follow-up records. Expense reversal is now implemented as a full, independently approved correction. It does not support partial reversal; use refund only when money genuinely came back.

The following controls are now implemented and should be taught as active rules: named requisition approvers, immutable approval amounts, audited petty-cash auto-approval, requisition expiry, the single-expense limit, selected-pocket balance enforcement at actual spend, percentage-based variance routing, persistent variance notes, and linked follow-up activity history.

Before production launch, the school should define:

- who holds FINANCE VIEW, EDIT, and APPROVE permissions;
- who may serve as requester, approver, disburser, and custodian;
- the weekly reconciliation day;
- evidence requirements by spending amount/type;
- escalation routes for loss, suspected fraud, and overdue recovery;
- who can authorise write-offs; and
- how finance records are handed to the accountant.

## 20. Audit Checklist

For every expenditure, confirm that the record answers:

- Who requested it?
- What was needed and why?
- Which funding source was selected?
- Who approved or verbally authorised it?
- Was it manually approved or system auto-approved?
- What amount was approved?
- What amount was actually paid?
- Was the requisition still valid on the payment date?
- How and when was it paid?
- Who recorded it?
- Is there a receipt/reference?
- Was there a variance, ratification, refund, or follow-up?
- Did the variance exceed the configured tolerance, and was the final affirmation confirmed?
- Who made the final decision and what note did they provide?

For every top-up, confirm:

- requester;
- selected approver;
- selected disburser;
- named receiver;
- approved amount;
- Cash/MoMo allocation and wallet;
- disbursement date/reference/note;
- requester confirmation or dispute; and
- complete event timeline.

For every reconciliation, confirm:

- requester and assigned custodian;
- snapshot time;
- expected Cash and MoMo;
- actual Cash and MoMo;
- evidence and confirmation note;
- variance resolution;
- linked follow-up; and
- closure actor and note.

## 21. Training Scenarios

### Scenario A: Standard school expense

Request GH¢2,000 of textbooks from School funds, obtain approval, pay by bank transfer, record the actual GH¢1,950 and supplier invoice, then review the lower variance.

Expected learning: School Expenses register, standard approval, actual spend, lower variance review.

### Scenario B: Routine petty-cash purchase

Request GH¢80 of cleaning supplies from Petty cash, obtain approval, pay from Cash, attach the receipt, and verify the Cash pocket decreases.

Expected learning: Petty-cash funding, pocket selection, receipt, balance impact.

### Scenario C: Emergency repair

Record an urgent GH¢300 plumbing repair with verbal authorisation, actual payment of GH¢320, receipt, ratification, and variance review.

Expected learning: emergency justification, ratification versus approval, higher variance.

### Scenario D: Top-up with Cash and MoMo

Request GH¢500, select an approver, have the approver select a disburser, allocate GH¢300 to Cash and GH¢200 to MoMo, then have the requester confirm both amounts.

Expected learning: named actors, allocation, confirmation before pocket credit.

### Scenario E: Disbursement problem

The disburser records the wrong MoMo wallet. The requester reports a problem, an administrator reassigns or corrects the case, and the requester confirms only after correction.

Expected learning: no cancellation after money moves, dispute notes, correction and audit timeline.

### Scenario F: Cash shortage

Expected Cash is GH¢835 but actual Cash is GH¢805. Record the shortage, choose recovery from staff, post the auditable adjustment, and keep the GH¢30 recovery open.

Expected learning: variance is not an expense, balance correction, continuing follow-up.

### Scenario G: Approved request with insufficient pocket balance

Submit and approve a GH¢200 petty-cash request while the selected MoMo pocket has only GH¢100. Attempt to record the actual spend from MoMo, confirm that the transaction is blocked without changing either pocket, transfer or replenish the required funds, then record it successfully.

Expected learning: approval does not reserve money; available balance is enforced only at actual spend; pockets cannot become negative.

### Scenario H: Edit and reroute a request

Create and approve a petty-cash request, select **Edit** as the requester, change the amount or funding source, and resubmit it. Confirm that the request returned to Draft, the earlier approval disappeared, the route change appears in history, and the revised business rules were applied.

Expected learning: requester-only editing, approval invalidation, full revalidation, fresh expiry.

### Scenario I: Variance tolerance boundary

Record one actual amount exactly at the configured percentage tolerance and another just above it. Confirm that the first completes normally and the second requires variance review, then add a review note and reopen the expense history.

Expected learning: tolerance boundary, higher/lower symmetry, persistent review notes.

## 22. Trainer Delivery Checklist

- [ ] Explain School funds versus Petty cash before showing forms.
- [ ] Demonstrate the six main tabs and Petty Cash sub-sections.
- [ ] Demonstrate expense search, sortable headings, and page navigation.
- [ ] Demonstrate one standard requisition end to end.
- [ ] Show named approver selection and that the approver cannot alter the amount.
- [ ] Show requester Edit returning an unspent petty-cash requisition to Draft.
- [ ] Explain expiry, the single-expense limit, automatic approval, and when balance is checked.
- [ ] Demonstrate emergency ratification and a variance.
- [ ] Demonstrate top-up roles using different accounts.
- [ ] Show that Disbursed does not yet mean received.
- [ ] Demonstrate Cash/MoMo transfer and fee treatment.
- [ ] Perform a matching reconciliation.
- [ ] Perform a shortage reconciliation and create a follow-up.
- [ ] Explain refunds as linked entries rather than edits.
- [ ] Review the current-release caveats.
- [ ] Confirm each trainee understands notes, evidence, and separation of duties.

## 23. Quick Answers

**Do all expenses start with a requisition?**

Yes. Normal expenses wait for approval. Emergency expenses still use a requisition but record verbal authorisation and require later ratification.

**Does approving a requisition reduce a balance?**

No. The balance changes when actual spending is recorded from a petty-cash pocket.

**When is petty-cash availability checked?**

The current pocket balance does not block the request or approval. It is a hard blocker when actual spend is recorded. The amount must also remain within the configured single-expense limit.

**Can the approver change the amount?**

No. The approver must affirm the amount submitted by the requester. A wrong amount must return to the requester for editing and resubmission.

**What happens when the requester edits an approved petty-cash request?**

It immediately returns to Draft. The earlier approval and expiry are invalidated, the edit is audited, and all rules are checked again on resubmission.

**Which small requests can be auto-approved?**

Only non-emergency petty-cash requests at or below the administrator-configured auto-approval limit, while the feature is enabled. The system decision is recorded in history.

**What happens when a requisition expires?**

It can no longer be approved or used to record actual spend. Review and resubmit an eligible unspent petty-cash draft or create a replacement request.

**Does every amount difference require variance review?**

No. The true actual amount is always recorded, but only a percentage difference above the configured tolerance enters variance review.

**Can an approver approve their own request?**

No. Use a different authorised user.

**Can an approved request be cancelled?**

Yes, before payment. Once money has moved, use the appropriate correction or refund route.

**Can a top-up be cancelled after disbursement?**

No. Report a problem and record a correction so the audit trail remains intact.

**When does a top-up increase the float?**

Only after the named requester confirms receipt and allocation.

**Is a pocket transfer an expense?**

No. Only its transfer fee reduces total float.

**Is missing money an expense?**

No. It is a reconciliation adjustment and, where needed, a Financial follow-up.

**Does a recovery disappear when a new cycle starts?**

No. It remains open until repaid, written off, corrected, or otherwise closed by an authorised administrator.

**Can users delete old financial records?**

No. Add linked correcting records and notes instead.

## 24. Related Document

For additional detail on shortages, surpluses, and recoveries, see [Petty Cash Reconciliation and Financial Follow-ups](petty-cash-reconciliation-process.md).
