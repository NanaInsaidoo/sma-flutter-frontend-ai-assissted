# School Shop User Guide

## Purpose

The School Shop records physical stock, who is responsible for it, sales, customer collections, returns, physical counts, cash remittances, and the information needed for accounting. It is designed for schools that sell books, uniforms, stationery, food portions, learning materials, toiletries, sports items, and similar goods.

The system does not replace the school’s bank account or general ledger. It creates controlled, auditable shop records that can be exported and given to the accountant.

## The four records that must not be confused

| Record | What it means | What changes it |
|---|---|---|
| Item type | A reusable definition such as “Exercise Book, 80 pages” | Create, edit, archive, or restore an item type |
| Inventory | The quantity physically owned by the shop | Add stock, confirmed handovers, completed sales, accepted returns, and approved adjustments |
| Sale | Money received for named items from a buyer | Sell and give now, or sell for store collection |
| Custody | Where the stock or cash is currently held | Confirmed stock handovers, releases, staff hand-backs, reconciliations, and cash remittances |

Always convert bulk goods into the unit that will be sold before recording them. For example, divide a 50 kg bag of rice into the portions the school will sell, then record the number of portions. Do not record one bag and later sell it as unrelated portions.

## Who can do what

| User | Main access |
|---|---|
| School administrator, head teacher, owner, or bursar | Manages the whole shop, inventory, sellers, reports, reconciliations, remittances, and audit records according to the school role |
| Seller | Sees and sells only stock assigned to that seller; sees only their own sales, cash responsibility, remittances, and reconciliation work |
| Store/release user | Finds a paid order and releases the reserved goods; cannot browse collection tokens |
| Independent approver/resolver | Reviews financial or stock corrections that must not be approved by their creator |

A seller is not a new school employment role. Any active staff member—including an administrator—can be added as a seller. Disabling seller access stops new sales and new stock handovers but keeps all historical records.

## Shop navigation

The tabs shown depend on the signed-in user’s responsibilities.

- **Overview** — current alerts and shop summary.
- **Item types** — reusable item definitions.
- **Inventory** — current stock, stock history, and adjustment requests.
- **Stock handovers / My stock** — stock moving from one person’s custody to another.
- **Sell items** — the two selling methods available to a seller.
- **Release goods** — find a paid collection order and hand over the goods.
- **Reconciliation** — independent physical stock and money counts.
- **Cash remittances** — cash physically passed from one staff member to another.
- **Sales** — dated sale and payment history.
- **Reports** — shop accounting and management information.
- **Returns** — customer returns, cancellations, refunds, and staff stock hand-backs.
- **Sellers** — add, view, disable, or restore sellers.
- **Audit trail** — who performed important shop actions and when.

Managers can select **All sellers** or search for one seller on the Stock handovers, Reconciliation, Cash remittances, Sales, Returns, and Audit pages. **View seller** gives one consolidated summary of that person’s stock, sales, cash, remittances, reconciliations, returns, and recent actions. A regular seller cannot use this school-wide view.

## Recommended setup order

1. Create the reusable item types.
2. Add the quantities physically entering the shop.
3. Add the staff members who will sell as Sellers.
4. Hand stock to each seller and obtain confirmation.
5. Start selling.
6. Reconcile each seller at the school’s chosen frequency.
7. Record cash remittances when cash changes custody.
8. Export the shop report for management and accounting.

## 1. Item types

An item type defines what the item is. It does not add any quantity.

### Add an item type

1. Open **Item types**.
2. Select **Add item type**.
3. Enter the item name.
4. Choose a category. If the correct category is missing, choose **Other** and type the new category.
5. Choose the selling unit, such as piece, book, bottle, set, or pack.
6. Choose whether the item code will be generated or entered manually.
7. If entering a code, use a unique value. The form visibly warns when the code is already used.
8. Enter a low-stock alert level.
9. Save.

The item code is optional when automatic generation is selected. A school should use short, understandable codes where practical, such as `EXB-80` for an 80-page exercise book.

### Edit, archive, and restore

Use the item’s Actions menu to edit its definition. An item with stock or history is archived rather than deleted. Archived items remain available through the archived filter and can be restored. Historical receipts never lose their item description.

## 2. Inventory

Inventory is the current physical stock position. The main table emphasizes the item, available quantity, stock with staff, reserved quantity, selling price, and status. Select an item or open its Actions menu for more information.

### Add stock

1. Open **Inventory**.
2. Select **Add stock**.
3. Search for and select an existing item type. If it does not exist, open the item-type form, save the definition, and return to Add stock.
4. Enter the quantity received.
5. Enter the **unit cost price** and **unit selling price**. These are per selling unit, not totals.
6. Add another line when several items entered the shop together.
7. Optionally enter a reference and note.
8. Save the stock entry.

The line total is quantity multiplied by unit cost. Adding stock updates inventory only; it does not create a second expense or payment record. The Stock history tab keeps every stock entry as a separate line, including item, quantity, date, person, and value.

### Understanding quantities

| Quantity | Meaning |
|---|---|
| Central available | In the central shop and free to hand over or sell |
| With staff | Confirmed as physically held by sellers or store staff |
| Reserved | Committed to a pending handover, customer collection, or return process |
| Quarantined | Returned or disputed stock that must not be sold until inspected and corrected |
| Total on hand | Central stock plus confirmed staff-held stock and quarantined stock, as displayed by the system |

Reserved goods cannot be sold again. The system blocks any quantity greater than the available balance and shows a prominent explanation.

### Inventory adjustments

Use an adjustment only when the recorded balance must be corrected—for example, damage, loss, data-entry error, or a physical-count difference that is not being resolved through reconciliation.

1. Open the inventory item’s Actions menu.
2. Select the adjustment action.
3. Enter the proposed correct quantity and a specific reason.
4. Choose a different eligible approver.
5. Submit.

The balance does not change while the request is pending. Approval applies the change once and writes an audit record. Rejection keeps the original balance.

## 3. Sellers and stock handovers

### Add a seller

1. Open **Sellers**.
2. Select **Add seller**.
3. Type at least two characters of the staff member’s name or sign-in name.
4. Select the matching active staff member.

Use **View seller** for a consolidated operational view. Use **Disable** when the person must no longer receive stock or make sales. Use **Restore** to reinstate access later.

### Prepare a stock handover

1. Open **Stock handovers**, or use **Prepare handover** from an in-stock inventory item.
2. Select an active seller.
3. Select a valid item with central stock available.
4. Enter the quantity and optional location or note.
5. Review the confirmation showing the item, recipient, quantity, and central balance after reservation.
6. Confirm the preparation.

At this point the goods have not changed custody. The quantity is reserved in the issuer’s custody and cannot be sold or handed to someone else.

### Recipient confirms receipt

The recipient physically counts the goods, opens the handover, and selects **Confirm receipt**. Confirmation moves custody to the recipient in one transaction. If there is a problem, the recipient selects **Report problem**.

### Cancel before confirmation

The issuer may cancel only while confirmation is pending. The confirmation asks the issuer to affirm that the goods are still in the issuer’s custody and were not handed to the recipient. Cancellation then removes the reservation. Never cancel after physically giving the goods to the recipient.

## 4. Selling

Only an active seller can make a sale from stock assigned to that seller. A manager who will personally sell must also be added as a seller.

The buyer may be a student, staff member, guardian/other known person, or walk-in customer. For students and staff, type the name and choose a suggestion. If no appropriate match appears, the typed name can be retained for an external or temporary buyer where the form permits it.

### Sell and give now

Use this when the same person receives payment and physically hands over the item.

1. Open **Sell items**.
2. Select **Sell and give now**.
3. Find or enter the buyer.
4. Type the item name and select a suggestion showing item, availability, and unit selling price.
5. Enter the quantity.
6. Choose Cash or Mobile Money. Enter the Mobile Money reference when required.
7. Confirm payment and handover.
8. Print, download, or share the receipt if needed.

The sale, payment, and stock reduction are completed together. The cash becomes the seller’s recorded cash responsibility until remitted or reconciled.

### Sell for store collection

Use this when one person receives payment and another person or store releases the goods.

1. Select **Sell for store collection**.
2. Find the buyer and add items.
3. Record payment.
4. Give the buyer the receipt and collection token.
5. The quantity becomes reserved immediately and cannot be sold again.

The receipt can be reopened from Sales or the issuing person’s receipt list. It supports print, download, and share.

## 5. Release goods

1. Open **Release goods**.
2. Enter the buyer’s collection token or search using the buyer’s name/reference where available.
3. Select **Find order**.
4. Check the buyer, receipt, item lines, quantities, payment status, and collection status.
5. Physically count the goods.
6. Confirm release.

The store person cannot browse collection tokens. Repeated invalid token attempts are logged and the interface warns the user. A valid token reveals the matching paid order so it can be checked. A collected or cancelled order cannot be released again.

## 6. Sales and receipts

The Sales page is the historical register. Use the date presets and sortable columns to review date, receipt, buyer, collection method, seller, payment method, status, and total. Managers see school-wide activity and can focus on one seller. Regular sellers receive only their own records from the server.

Select a receipt reference or Details to open the sale. The stored receipt remains the official historical version even if an item name or selling price changes later.

## 7. Customer returns, cancellations, and refunds

Returns preserve the original sale. They never delete or rewrite it.

### Customer returns collected goods

1. Open the original sale or receipt.
2. Select the return action.
3. Choose the item and quantity being returned.
4. Record the condition and reason.
5. Submit to a different approver.
6. The approver approves or rejects.
7. If approved, the authorized person records the refund method and reference.
8. The receiving staff member confirms the physical item condition.

Good items return to saleable central stock. Damaged or uncertain items go to quarantined stock. The return log includes the name of the person who returned the goods.

### Cancel a paid order awaiting collection

Use the cancellation request on a paid but uncollected order. Approval releases the reserved stock and moves the request to refund pending. The refund is separately recorded with its method and reference. The original payment, cancellation approval, refund, and stock release remain linked and auditable.

### Staff hands stock back to the store

The current holder starts a staff hand-back. Another authorized store person physically counts the quantity and accepts or rejects it. Accepted good stock returns to central inventory; damaged stock is quarantined. The record identifies who returned it, who received it, the quantity, condition, date, and any discrepancy.

## 8. Reconciliation

Reconciliation is an independent physical check of one seller’s stock and shop money for a defined period. It is not the same as a cash remittance.

### Start a reconciliation

1. A manager opens **Reconciliation** and selects **Start reconciliation**.
2. Search for the seller being counted. Only sellers who have received stock are offered.
3. Starting the count temporarily stops new selling and stock movement for that seller. Other sellers can continue operating.
4. Count each displayed stock location and enter the physical quantity.
5. Count the physical cash attributed to the seller.
6. Verify the Mobile Money amount against the recorded transaction evidence.
7. Explain every shortage or surplus.

The draft saves automatically during the count and can be reopened. Reserved customer collections and transfers are shown separately so they are not accidentally counted twice. Resolve ambiguous physical movements before the final submission whenever possible.

### Review and close

1. The counter submits the completed count.
2. The seller reviews the expected and counted stock, cash, and Mobile Money amounts.
3. The seller acknowledges or disputes the result.
4. If everything matches, the reconciliation closes balanced.
5. If there are differences, an independent manager—not the seller and not the original counter—reviews the evidence.
6. The resolver confirms the final action using the clear warning: the recorded balances will be updated using the confirmed differences and the reconciliation will be permanently closed.

The system posts each approved difference once. A note does not itself prove that missing stock or money was recovered; supporting investigation should follow the school’s financial policy.

## 9. Cash remittances

A cash remittance records physical shop cash passed from one staff member to another. It can happen whenever cash changes custody; it does not require a reconciliation to be open.

1. Open **Cash remittances**.
2. Select **Remit cash**.
3. Choose the receiving administrator, head teacher, or bursar.
4. Enter the physical amount handed over and an optional note/reference.
5. Submit.
6. The recipient counts the cash and confirms or rejects receipt.

Until confirmation, the cash remains recorded under the sender. Confirmation transfers the cash responsibility to the recipient and creates the accounting evidence. The sortable, dated remittance table can be exported at any time.

## 10. Reports and accounting handoff

Open **Reports** and choose Today, Last 7 days, Last 30 days, This term, All time, or **Custom dates: From / To**. Select the sections required, then view or export the report.

The report can include:

- sales and payment entries;
- daily sales summaries;
- item performance;
- inventory position and cost value;
- stock held by staff;
- customer returns and refunds;
- reconciliation decisions and posted differences;
- cash remittances;
- current cash responsibility.

For accounting, export a closed period and provide it with source documents such as supplier invoices, Mobile Money statements, deposit slips, and refund evidence. The accountant can use the records to prepare journals, cost of sales, inventory values, cash controls, management accounts, and final accounts. The report is source information; formal ledger posting remains an accounting responsibility.

## 11. Audit and control rules

- No one should approve their own financial correction.
- A seller cannot reconcile their own stock and cash.
- A seller sees only their own operational records; managers may view all sellers or select one.
- A stock handover changes custody only after the recipient confirms.
- Paid but uncollected stock is reserved and unavailable for another sale.
- Collection tokens are not browseable by release staff.
- Original sales and payments are retained when a return, refund, cancellation, or correction occurs.
- Inventory changes, approvals, releases, remittances, and reconciliation decisions are timestamped and auditable.
- Cost prices are management information and should not be shown to ordinary sellers or customers.

## Daily checklist

### Seller

- Confirm any stock received before selling it.
- Record every buyer, item, quantity, payment method, and Mobile Money reference.
- Give or send the official receipt.
- Keep pending collection goods separate from available goods.
- Remit cash when required and obtain confirmation.
- Respond promptly to reconciliation acknowledgment requests.

### Manager or store staff

- Review low-stock and pending-action alerts.
- Complete or investigate pending stock handovers and collections.
- Confirm physical cash remittances only after counting.
- Review returns, refunds, quarantined items, and exceptions.
- Reconcile the selected seller before ending the control period when required.

## Weekly or periodic checklist

- Reconcile each active seller separately.
- Review disabled sellers who still hold stock or cash.
- Check quarantined stock and decide the approved next action.
- Compare cash remittances with deposits or the finance-office record.
- Export the period report and retain supporting documents.
- Review the audit trail for unusual reversals, failed token searches, shortages, or repeated adjustments.

## Getting help

When reporting a problem, provide the school, page, user role, item or receipt reference, date and time, action attempted, and the exact on-screen message. Do not send passwords or collection tokens in ordinary support messages.

## Common messages and what to do

| Message | Meaning | Action |
|---|---|---|
| No active sellers available | No eligible staff member can receive a new handover | Add or restore a seller first |
| Only X units are available | The requested quantity exceeds free stock | Reduce the quantity or add/return stock |
| Item code already used | Another item type has the same code | Enter another code or select Auto-generate |
| Pending collection | Payment is complete but goods have not been released | Use Release goods or request an approved cancellation |
| Pending receipt | A stock or cash handover awaits the recipient’s physical confirmation | Recipient must count and confirm or reject |
| Reconciliation in progress | Operations for that seller are temporarily locked | Finish or cancel the reconciliation |
| Quarantined | The item is not approved for sale | Inspect it and use the authorized correction process |
| Refresh and recount | Stock or money changed after the count began | Refresh the snapshot and repeat affected counts |

## Status quick reference

| Status | Plain meaning |
|---|---|
| Pending acceptance / receipt | Waiting for the recipient to count and confirm |
| Active | Available for the permitted next action |
| Reserved | Committed and unavailable for another transaction |
| Pending collection | Paid; waiting for goods to be released |
| Collected | Goods were handed to the buyer |
| Pending approval | Waiting for a different authorized person |
| Refund pending | Return/cancellation approved; refund still must be recorded |
| Completed | All required steps finished |
| Rejected | Reviewer did not approve the request |
| Cancelled | The process ended without completing its intended movement |
| Disputed | The counted seller disagreed with the reconciliation |
| Closed balanced | Reconciliation completed with no difference |
| Closed with differences | Reconciliation completed and confirmed differences were posted |
