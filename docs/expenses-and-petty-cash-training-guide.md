# Expenses & Petty Cash Training Guide

**Version:** 1.0

**Last updated:** 7 September 2026

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

Inside it are six main tabs:

| Tab | Purpose |
| --- | --- |
| **Overview** | Summarises float balance, school and petty-cash spending, pending approvals, and urgent actions. |
| **Requisitions** | Holds all requests before spending. Filter by funding source and status. |
| **School Expenses** | Shows completed spending paid from school bank, cheque, or the main school MoMo account. |
| **Petty Cash** | Holds petty-cash expenses, Cash/MoMo pockets, top-ups, transfers, reconciliations, and financial follow-ups. |
| **Approvals** | Shows requisitions, top-ups, emergency ratifications, and variances needing an authorised decision. |
| **Reports** | Reserved for management and audit reporting. See the current-release caveats before relying on it. |

Within **Petty Cash**, use:

- **Float & expenses** for balances, petty-cash expenses, top-ups, and pocket transfers;
- **Reconciliations** for cash and MoMo counts; and
- **Financial follow-ups** for unresolved exceptions.

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

## 6. Before Users Begin

An administrator must configure the finance workspace for the academic term.

### Petty-cash settings

| Setting | Training explanation |
| --- | --- |
| **Approved float amount** | The normal total amount the school has authorised for petty cash. |
| **Cash/MoMo opening balance** | The system starts at zero. Initial money enters through an approved and confirmed top-up. |
| **Float ceiling / single-expense ceiling** | The intended control limit for petty-cash use. See the implementation caveat in section 19. |
| **Refill threshold** | The balance at which the system warns that petty cash is running low. It does not add money automatically. |
| **MoMo wallet** | The designated wallet used for the petty-cash MoMo pocket. |
| **Variance tolerance** | A configured reference for comparing approved and actual spending. Current policy sends every non-zero difference for review. |
| **Requisition expiry** | The number of days an approved request remains available before it must be reviewed again. |
| **Transaction fees** | Whether transfer fees are captured and reduce the source pocket. |

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

- a School funds request must use bank transfer, cheque, or direct school MoMo; and
- a Petty cash request must use the Cash or MoMo float pocket.

If the source was chosen incorrectly, cancel the request before payment and create a correct one. Do not use a misleading payment method to force it through.

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
- approval route.

Use a description that another person can understand without asking the requester. Avoid entries such as "items", "things", or "school needs".

### Step 2: Submit for approval

For normal purchases, choose **Standard approval**.

The request enters the approval queue. No money should leave the school while it is pending.

### Step 3: Approver reviews

The approver checks:

- whether the purchase is necessary;
- whether the category and funding source are correct;
- whether the estimated amount is reasonable;
- whether sufficient petty cash exists, when applicable;
- whether supporting information is adequate; and
- whether the requester and approver are different people.

The approver may approve or decline. Approval does not itself create an expense or move money.

### Step 4: Record the actual spend

After payment happens, open the approved requisition and select **Record actual spend**.

Enter:

- actual amount;
- vendor/payee;
- permitted payment source;
- receipt or invoice reference;
- receipt photo/PDF, when available; and
- an explanatory note where needed.

The expense appears in the correct register only after actual spend is recorded.

## 9. Approval Rules and Caveats

### Pending approval

- No payment should be made.
- The request may still be cancelled.
- An approver may decline it.

### Approved but not paid

- Approval confirms permission to proceed; it is not proof that payment occurred.
- The approval may be revoked before an actual payment is recorded.
- If the purchase is no longer needed, cancel/revoke with a meaningful note.

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
- disburser reassignment;
- reconciliation confirmation and resolution; and
- financial follow-up closure.

Write what happened and why. Avoid notes such as "done", "okay", or "approved".

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

### Higher actual amount

Example: approved GH¢500, actual GH¢540.

- Record the true GH¢540 amount.
- Add an explanation.
- The transaction is flagged for review.
- An authorised reviewer decides whether to accept, request correction, or escalate it.

### Lower actual amount

Example: approved GH¢500, actual GH¢460.

- Record the true GH¢460 amount.
- Unused petty cash remains in the relevant pocket.
- The difference still requires review because the approval and payment do not match.

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

## 13. Refunds and Corrections

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

Do not use a refund where no money was returned. A supplier credit note or expected refund should remain a Financial follow-up until it is formally handled.

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

Only one active top-up may exist at a time.

### Approver

- cannot approve their own request;
- verifies the amount against the current balance and approved float;
- approves or declines with a note; and
- selects the person who will disburse the funds.

The approver may revoke approval before disbursement. Once money has been disbursed, it cannot simply be cancelled.

### Disburser

- explicitly selects the requester as the receiver;
- records how much is Cash and how much is MoMo;
- enters the wallet when MoMo is used;
- enters a date that is not before the request and not in the future;
- adds a reference where available; and
- adds a disbursement note.

Cash plus MoMo must exactly equal the approved top-up amount.

### Requester confirmation

The petty-cash balance does not increase merely because the disburser clicked **Disburse**. It increases only after the named requester confirms the same Cash amount, MoMo amount, and wallet allocation.

### Problem or dispute

If the money or allocation is wrong, the requester selects **Report a problem** and adds a note.

- The top-up remains unresolved and visible.
- The original disburser or an administrator may record a correction.
- An administrator may reassign the case if the original disburser is unavailable.
- After correction, the requester confirms the corrected funds.
- If the requester later verifies that the original disbursement was correct, they may confirm it even while a problem is recorded.

There is no approval code in this workflow. Identity comes from signed-in users, assigned actors, explicit receiver selection, and the event timeline.

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

## 17. Financial Follow-ups

Financial follow-ups keep operational exceptions visible without pretending they are normal expenses.

Examples include:

- staff recovery;
- cash shortage or loss under investigation;
- missing receipt;
- supplier refund due;
- unconfirmed MoMo movement;
- incorrect entry requiring correction;
- unexplained surplus; or
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

## 18. Records and Statuses

### Requisition statuses

| Status | Meaning |
| --- | --- |
| Draft | Created but not submitted. |
| Pending | Awaiting approval. |
| Approved | Permission granted; payment not necessarily made. |
| Query | Returned for clarification. |
| Rejected | Not authorised to proceed. |
| Revoked | Earlier approval withdrawn before payment. |
| Fulfilled | Actual spending has been recorded. |

### Expense statuses

| Status | Meaning |
| --- | --- |
| Complete | Payment is recorded and required reviews are complete. |
| Pending ratification | Emergency payment awaits formal after-the-fact review. |
| Pending variance review | Actual and approved amounts differ. |
| Reversed / refunded | A linked correcting transaction exists; original history remains. |

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

## 19. Current-Release Caveats and Go-Live Cautions

Trainers and administrators must understand these limitations. Do not represent them as completed controls.

1. **Reports are not production-ready.** The Reports tab is currently outside the verified finance scope. Use transaction and detail records for operational review until reports are implemented and validated.
2. **Receipt storage still needs a real S3 verification.** The upload flow exists, but secure upload/view of a real receipt remains a production-hardening check.
3. **The app cannot verify receipt content.** A user can upload the wrong image or PDF. Human review remains mandatory.
4. **Duplicate handling needs a complete user confirmation flow.** The backend detects a possible duplicate, but the current UI does not yet provide the final intentional-duplicate confirmation journey. Stop and investigate rather than retrying blindly.
5. **Follow-up entries are operational records, not accounting postings.** Manual and system-generated follow-ups, due dates, linked references, notes, and administrator closure are persisted. Accountants must still decide and post the formal accounting treatment outside this module.
6. **Closed-cycle and different-method refunds need further routing work.** The present refund process links the refund and protects against over-refunding, but changing the refund destination or routing a late refund into a newer cycle/general account is not fully supported in the UI.
7. **Float ceiling semantics need final alignment.** The screen describes it as a single-expense ceiling, but current backend enforcement does not yet provide a complete per-expense ceiling control. Approvers must manually check petty-cash size until this rule is hardened.
8. **Every non-zero expense difference currently requires review.** Do not assume the configured tolerance will automatically clear a small difference.
9. **School-funded requisitions currently depend on the term finance workspace being configured.** The two spending registers are separated, but both use the same term-scoped finance service.
10. **Requisition approver selection differs from top-ups.** Top-ups have a named approver and disburser. Standard expense requisitions currently enter the authorised approval queue rather than being routed to a requester-selected individual.
11. **Some requisition decision notes are generic in the current UI.** Reviewers should add meaningful operational explanations wherever possible; the approval/rejection note interface requires further hardening.
12. **Do not delete completed finance records.** Corrections must use refund, reversal, reconciliation adjustment, or follow-up records.

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
- What amount was approved?
- What amount was actually paid?
- How and when was it paid?
- Who recorded it?
- Is there a receipt/reference?
- Was there a variance, ratification, refund, or follow-up?
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

## 22. Trainer Delivery Checklist

- [ ] Explain School funds versus Petty cash before showing forms.
- [ ] Demonstrate the six main tabs and Petty Cash sub-sections.
- [ ] Demonstrate one standard requisition end to end.
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
