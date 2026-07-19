# Real Data Ecosystem Test Story

## Purpose

Prove that Admissions, Fees & Requirements, and Attendance operate as one
persisted school workflow. This is not a mock-data UI scenario. Every assertion
reads data back from the Spring Boot API after a real mutation.

## Test Persona

**Ama Owusu**, a school administrator, is admitting a child into Basic 1 for
the current academic term. She completes the household and student records,
enrolls the student, assesses fees and supplies, receives a partial payment,
approves a support adjustment, and records class attendance.

## Lifecycle

### 1. Household and guardian

1. Start a new admission and create a household.
2. Add the primary guardian with identity, contact, address, occupation,
   language, social-media, and skill data.
3. Complete the guardian review step.
4. Verify that reopening the guardian hydrates every completed section.

Expected result: the guardian and household are persisted and available to new
student applications.

### 2. Student application and enrollment

1. Add a student to the household.
2. Complete basic information, address, medical conditions and allergies,
   vaccinations, previous-school history, documents, and review.
3. Submit and approve the application.
4. Verify that the applicant becomes an `ACTIVE` student in Basic 1 and remains
   linked to the household.

Expected result: the approved student is available to Fees & Requirements and
Attendance without manual database changes.

### 3. Fee structure and assessment

1. Create the Basic 1 fee structure for the current term.
2. Add Tuition Fee, ICT and Computer Levy, and Examination Fee.
3. Publish the structure.
4. Verify that the student receives an assessment for each published fee item.

Expected result: gross fees are **GHc 1,450**.

### 4. Payment and adjustment

1. Record a **GHc 600** Mobile Money payment.
2. Create and approve a **GHc 100 tuition discount**.
3. Open the student's fee account and payment receipt.

Expected ledger:

| Entry | Amount |
| --- | ---: |
| Gross fees | GHc 1,450 |
| Approved adjustment | (GHc 100) |
| Net expected | GHc 1,350 |
| Paid | GHc 600 |
| Balance | GHc 750 |

Expected result: status is `PARTIAL`; the receipt and fee account show the same
net expected, paid, and balance values.

### 5. Items and supplies

1. Publish Basic 1 requirements for exercise books, liquid soap, and
   disinfectant.
2. Record four exercise books received.
3. Reduce the student's required exercise-book quantity from ten to six with a
   partial waiver and notes.
4. Record disinfectant as a cash equivalent with a payment reference.
5. Add two HB pencils as a student-specific requirement.

Expected result: the student has a partial item, a cash-equivalent item, one
outstanding class item, and one custom item. The audit notes and payment
reference remain available when the student is reopened.

### 6. Attendance

1. Load the real Basic 1 / Section 1 roster for a school day.
2. Mark one student present, one absent, and one 15 minutes late.
3. Submit the class attendance.
4. Verify stream submission status, class totals, and the target student's
   period summary.

Expected result: the stream contains one present, one absent, and one late;
attendance rate is **66.67%** because late students attended. The target
student's one-day rate is **100%**.

## Verification Layers

1. **API lifecycle verification**: `tool/verify_real_ecosystem.sh` reads all
   persisted outcomes and fails on ledger or cross-module inconsistencies.
2. **Flutter contract and widget tests**: repository tests validate paths,
   payloads, term scoping, hydration, and key interactions.
3. **Browser smoke test**: confirms login and the school-admin routes render and
   remain navigable. Flutter canvas output limits reliable DOM text assertions,
   so business-state assertions stay at the API and widget layers.

## Run the persisted verifier

Do not put credentials in the repository or shell history. Export them in the
current terminal session, then run:

```bash
cd /Users/matic/Documents/SMA-Fontend/school_management_app
SMA_LOGIN_FIELD=email \
SMA_LOGIN="$SMA_TEST_EMAIL" \
SMA_PASSWORD="$SMA_TEST_PASSWORD" \
./tool/verify_real_ecosystem.sh
```

The script accepts overrides such as `SMA_SCHOOL_ID`, `SMA_STUDENT_ID`,
`SMA_TERM_ID`, `SMA_PAYMENT_ID`, and `SMA_ATTENDANCE_DATE`, allowing the same
assertions to run against another prepared lifecycle.

## Rerun policy

Use a unique suffix for every new household and student. Never reuse a payment,
attendance date, or published adjustment when testing creation endpoints,
because these are intentionally duplicate-protected. The verifier itself is
read-only and can be rerun safely.
