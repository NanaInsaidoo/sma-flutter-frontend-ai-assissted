# Petty Cash Reconciliation and Financial Follow-ups

## Purpose

This guide defines how the school records, checks, and resolves petty-cash and MoMo wallet differences. It is an operational control process, not a replacement for the school accountant's general ledger.

The process applies to the two petty-cash pockets:

- Cash pocket: physical cash held by the custodian.
- MoMo pocket: money held in the school's designated MoMo wallet.

Expenses, approved top-ups, and pocket transfers change the system's expected balances. A reconciliation compares those expected balances with what is actually counted or confirmed at the time of the check.

## Roles

| Role | Responsibility |
| --- | --- |
| Administrator / Headteacher | Requests reconciliation, reviews variances, opens and closes financial follow-ups, and approves final resolution notes. |
| Bursar / custodian | Performs the physical cash count and MoMo confirmation, attaches evidence, and adds investigation notes. |
| Staff requester | May provide evidence or explanation for a related expense, transfer, or requisition. |
| Accountant | Can use the follow-up register and exported records as source material for accounting treatment outside this module. |

Only an administrator can close a financial follow-up or approve a write-off/recovery decision.

## When to Reconcile

The recommended default is a weekly reconciliation because schools should not hold excessive petty cash. An administrator can also request one at any time, for example:

- before approving a top-up;
- after a suspected cash or MoMo issue;
- at month-end or term-end;
- when the custodian changes; or
- after a high-value expense or transfer.

A top-up does not automatically force an immediate reconciliation. The administrator may require one before approving a top-up when the risk or balance warrants it.

## Reconciliation Lifecycle

1. **Requested**
   - An administrator creates a request and assigns it to the bursar/custodian.
   - The request contains the reason, assignee, and requested time.
   - It does **not** lock a money amount at this point.

2. **Count started**
   - When the custodian starts the count, the system captures the current expected Cash and MoMo balances.
   - This timestamp and snapshot are the basis of the reconciliation.
   - The custodian should complete the count promptly.

3. **Transactions during a count**
   - Staff can still make valid Cash or MoMo transactions.
   - The application should warn them that a reconciliation count is in progress.
   - If a transaction changes either pocket before the count is submitted, the expected balance has changed. The custodian should restart the count to take a fresh snapshot.

4. **Count confirmed**
   - The custodian enters actual physical cash and actual MoMo balance.
   - They add evidence such as a cash-count sheet, MoMo statement reference, receipt-book reference, or explanatory note.
   - If actual and expected balances match, the reconciliation is **Confirmed**.
   - If they do not match, it becomes **Variance needs review**.

5. **Variance resolved**
   - An administrator investigates and records the decision.
   - The reconciliation is then closed, while any continuing obligation is retained in Financial Follow-ups.

## Calculation

For each pocket:

```text
Expected balance = opening/last confirmed balance
                 + approved top-ups
                 + incoming pocket transfers
                 - completed expenses
                 - outgoing pocket transfers

Variance = actual counted balance - expected balance
```

- A negative variance is a shortage.
- A positive variance is a surplus.

Example:

```text
Opening cash float              GH¢1,000
Verified cash expenses           GH¢165
Expected cash                    GH¢835
Physical cash counted            GH¢805
Cash shortage                     GH¢30
```

## What Is Not an Expense

A variance must not be silently converted into a normal school expense merely to make the pocket balance appear correct.

Normal expenses represent approved school spending, such as stationery or transport. A missing GH¢30 has a different financial meaning and must remain auditable as a reconciliation adjustment and, where necessary, a financial follow-up.

## Variance Decisions

When closing a variance, the administrator selects an appropriate route and adds a mandatory resolution note.

| Situation | Reconciliation outcome | Financial follow-up |
| --- | --- | --- |
| Missing cash is recoverable from staff/custodian | Record the pocket correction to actual cash. | **Staff recovery** for the recoverable amount. |
| Missing cash is not yet explained | Record the pocket correction to actual cash. | **Cash shortage / loss** under investigation. |
| Cash was lost and is approved for write-off | Record the pocket correction to actual cash. | Close as an approved write-off with evidence and administrator note. |
| Cash surplus is found | Record the pocket correction to actual cash. | **Cash surplus** until explained and closed. |
| Expense has no receipt | The underlying expense remains unchanged. | **Missing receipt** follow-up. |
| Supplier owes school a credit/refund | The underlying expense remains unchanged. | **Supplier refund due** follow-up. |
| MoMo movement lacks a matching reference | Do not classify it as a normal expense. | **Unconfirmed MoMo** follow-up. |

## Example: Recovering a Cash Shortage

Using the GH¢30 shortage example:

1. The custodian counts GH¢805 while the system expects GH¢835.
2. The reconciliation is submitted with a shortage of GH¢30.
3. The administrator investigates and decides it is recoverable from the custodian.
4. The Cash pocket receives a system-generated reconciliation adjustment from GH¢835 to GH¢805. This is an audit correction, not an ordinary expense.
5. A Financial Follow-up is created for GH¢30 with type **Staff recovery**.
6. The follow-up remains open until repayment or another approved resolution is recorded.
7. When repayment is received, it is recorded against the follow-up and the administrator closes the follow-up with a note.

If the staff member does not repay within the current petty-cash cycle, the follow-up remains open across future cycles. It is not duplicated or repeatedly added as an expense each cycle.

The next approved top-up may restore the practical float when needed:

```text
Cash after verified expenses and shortage    GH¢805
Approved replenishment                       GH¢195
Restored cash float                        GH¢1,000
```

The recovery record remains open and visible even after the float is restored.

## Financial Follow-ups Register

Financial Follow-ups is a dedicated tab in **Expenses & Imprest**. It is the operational exception register for items that need action beyond the original transaction.

### Required record fields

- Reference number
- Follow-up type
- Related transaction, expense, transfer, or reconciliation reference
- Responsible person or supplier
- Amount
- Summary
- Created date and optional due date
- Status
- Append-only notes and evidence references

### Statuses

| Status | Meaning |
| --- | --- |
| Open | Action has been assigned but is not complete. |
| Awaiting evidence | A receipt, statement, or document is still required. |
| Under investigation | The cause or liability is still being checked. |
| Partially recovered | Only part of the expected recovery/refund has been received or verified. |
| Closed | An administrator recorded the final resolution. |

### Notes and evidence

Anyone involved may add notes, such as a receipt number, staff explanation, supplier confirmation, or MoMo statement reference. Notes are append-only so the investigation history remains visible.

An administrator must add a final resolution note to close a record. Closing a follow-up never deletes or rewrites the original expense, transfer, or reconciliation.

## Relationship to Petty-cash Cycles

A petty-cash cycle is the period between replenishments or scheduled closes. For most schools, a weekly cycle is appropriate.

- A reconciliation may happen inside a cycle at any time.
- A shortage does not disappear when a new cycle begins.
- The pocket balance reflects verified cash on hand after any documented adjustment.
- Outstanding recoveries, supplier credits, missing receipts, and other exceptions persist in Financial Follow-ups until resolved.
- Accounting can later post the appropriate accounting entries using the export/audit trail; this module retains the source operational facts.

## User Interface Expectations

- The **Reconciliations** tab shows requests, in-progress counts, confirmed counts, and variances.
- Opening a reconciliation displays expected vs actual Cash/MoMo, variance, evidence, and the resolution status.
- The **Financial Follow-ups** tab displays a searchable/filterable register with links to the related record.
- Opening a follow-up displays its amount, owner, due date, status, note timeline, and closure action.
- Only administrators see the final close action. Staff can add evidence and notes.
- Financial records should use dedicated detail pages or dialogs rather than attempting to expose all actions directly in long lists.

## Audit Requirements

The system must retain:

- who requested and performed each reconciliation;
- the system snapshot at the start of the count;
- actual Cash and MoMo confirmed by the custodian;
- all variances and their resolution notes;
- the linked Financial Follow-up, where applicable;
- all notes, evidence references, and status changes; and
- who closed the follow-up and when.

No completed reconciliation, closed follow-up, expense, transfer, or top-up should be deleted from the audit history.
