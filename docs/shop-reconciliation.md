# Shop reconciliation

Use **School Shop → Reconciliation → Start reconciliation** daily, weekly, or whenever an independent physical check is needed.

1. An administrator selects one seller or stock holder to count. The administrator doing the count cannot count themself.
2. Only the selected staff member is temporarily prevented from selling, releasing collections, moving stock, returning stock, or remitting cash. Other sellers continue working.
3. The counter physically counts every stock line shown for that staff member, counts cash held, and verifies their Mobile Money transactions. Draft entries save automatically after typing pauses.
4. Each row shows the system quantity, physical count, difference, and explanation. Any shortage or surplus needs an explanation. If there is a difference, the counter also chooses a different administrator or head teacher to resolve it.
5. The counter sends the completed count to the staff member. No stock or money balance changes at this stage.
6. The staff member either **acknowledges the count** or **disputes the count** with an explanation.
7. A balanced, acknowledged count closes immediately. A count with differences goes to the independent resolver. The resolver cannot be the counted staff member or the counter.
8. The resolver checks the evidence, records how the difference was resolved, and closes the count. Only at this point are signed stock and money differences posted once. The resolver may instead reject it for a fresh count.
9. The next count starts from the previous closed cutoff. Cancelled, disputed, or rejected records never silently change balances.

Pending customer collections, handovers, and staff returns do not need to be completed before a count begins because each quantity has an explicit physical custodian. They remain visible as separate reserved quantities so the counter knows what is physically present and what is available for sale.

## Stock custody lifecycle

### Handover to staff

1. The issuer prepares a handover. The quantity is reserved at its current location; it is not yet described as issued.
2. The recipient physically receives and counts the items.
3. When the recipient confirms receipt, custody transfers in one transaction and the items become available to that recipient.
4. If the handover is cancelled or rejected, only the reservation is released; the stock never left its original custodian in the system.

### Return from staff

1. The staff member starts a return. The quantity remains physically assigned to them but is reserved and cannot be sold.
2. The store receives and counts the returned items.
3. On confirmation, custody moves to the central store or to inspection/quarantine, as appropriate.
4. If the store rejects the return, the reservation is removed and the quantity becomes available to the staff member again.

### Customer collection

Paid items awaiting collection stay reserved at their named custodian. They cannot be sold again. Releasing the order reduces that custodian's physical stock; cancelling and refunding the order releases or restores the reservation through the audited return/refund workflow.

## Cash remittances

Cash remittances are a separate workflow under **School Shop → Cash remittances**. They do not require a reconciliation to be open. The sender records shop-sales cash physically passed to another administrator or head teacher. The recipient counts the cash and confirms receipt; that confirmation is the approval and completes the custody transfer. Until then, the cash remains assigned to the sender.

The remittance register shows a permanent remittance number, sent date, sender, recipient, amount, status, and confirmation date. It can be searched, filtered by status or date, sorted by any business column, paginated, opened for a clean detail view, and exported to CSV for the accountant. The export follows the active filters. Confirmed remittances transfer cash responsibility only; they are not additional sales income and must not be counted as new revenue.

The sender can cancel only while pending and must confirm that the money remains in their custody or has been returned. The recipient can report non-receipt. Every action is retained in the audit trail.

## Accounting boundary

This is shop inventory and staff-money reconciliation, not a general ledger or bank integration. It does not automatically deduct salary, create a staff debt, book a missing sale, initiate a refund, or move real money. An unexplained difference remains an investigation; a note alone must not be treated as evidence that missing money was recovered.

Quarantined stock is excluded from saleable-stock counts, and Mobile Money verification uses the shop's existing CASH/MOMO payment methods.

## Verification

Automated coverage includes reservation-based handovers and returns, signed shortages and surpluses, seller acknowledgement and disputes, independent resolution, stale counts, duplicate decisions, reserved-stock protection, refunds, autosaved drafts, cash remittances, register filtering/sorting/export, and school isolation.
