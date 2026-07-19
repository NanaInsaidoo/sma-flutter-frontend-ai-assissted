#!/usr/bin/env bash
set -euo pipefail

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

: "${SMA_LOGIN:?Set SMA_LOGIN to the test user's username, email, or phone number}"
: "${SMA_PASSWORD:?Set SMA_PASSWORD to the test user's password}"

BASE_URL="${SMA_BASE_URL:-http://localhost:8080/Narellallc/sma-v1/1.0.0}"
LOGIN_FIELD="${SMA_LOGIN_FIELD:-email}"
SCHOOL_ID="${SMA_SCHOOL_ID:-CTK-XXX-FA1BC0}"
GUARDIAN_ID="${SMA_GUARDIAN_ID:-GUA-FA1BC0-0936}"
STUDENT_ID="${SMA_STUDENT_ID:-STU-FA1BC0-2632}"
TERM_ID="${SMA_TERM_ID:-3}"
GRADE_LEVEL_ID="${SMA_GRADE_LEVEL_ID:-25}"
STREAM_ID="${SMA_STREAM_ID:-25}"
PAYMENT_ID="${SMA_PAYMENT_ID:-1}"
ADJUSTMENT_ID="${SMA_ADJUSTMENT_ID:-1}"
REQUIREMENT_ID="${SMA_REQUIREMENT_ID:-1}"
ATTENDANCE_DATE="${SMA_ATTENDANCE_DATE:-2026-07-17}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

auth_payload="$(jq -n \
  --arg field "$LOGIN_FIELD" \
  --arg login "$SMA_LOGIN" \
  --arg password "$SMA_PASSWORD" \
  '{password: $password} + {($field): $login}')"

curl -fsS -X POST \
  -H 'Content-Type: application/json' \
  "$BASE_URL/api/auth/login" \
  --data "$auth_payload" > "$tmp_dir/login.json"

token="$(jq -r '.accessToken // .token // .data.accessToken // empty' "$tmp_dir/login.json")"
if [[ -z "$token" ]]; then
  echo "Login succeeded but no access token was returned." >&2
  exit 1
fi

api_get() {
  local path="$1"
  local output="$2"
  curl -fsS -H "Authorization: Bearer $token" "$BASE_URL$path" > "$output"
}

assert_jq() {
  local file="$1"
  local expression="$2"
  local label="$3"
  if jq -e "$expression" "$file" >/dev/null; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label" >&2
    jq . "$file" >&2
    exit 1
  fi
}

echo "Real ecosystem verification"
echo "School: $SCHOOL_ID | Student: $STUDENT_ID | Term: $TERM_ID"
echo

api_get "/api/v1/guardians/schools/$SCHOOL_ID/guardians/$GUARDIAN_ID" "$tmp_dir/guardian.json"
assert_jq "$tmp_dir/guardian.json" \
  "(.customGuardianId == \"$GUARDIAN_ID\") and ((.firstName // \"\") | length > 0) and ((.lastName // \"\") | length > 0)" \
  "guardian is persisted with identity details"

api_get "/api/students/schools/$SCHOOL_ID/students/$STUDENT_ID" "$tmp_dir/student.json"
assert_jq "$tmp_dir/student.json" \
  "((.firstName // \"\") | length > 0) and ((.lastName // \"\") | length > 0) and ((.status // .studentStatus // \"\") | ascii_upcase == \"ACTIVE\")" \
  "approved applicant is an active student"

api_get "/api/schools/$SCHOOL_ID/students/$STUDENT_ID/fee-account?academicTermId=$TERM_ID" "$tmp_dir/fee-account.json"
assert_jq "$tmp_dir/fee-account.json" \
  '(.totalFees == 1450) and (.totalAdjustments == -100) and (.totalExpected == 1350) and (.totalPaid == 600) and (.balance == 750) and (.paymentStatus == "PARTIAL")' \
  "fee account reconciles structure, adjustment, payment, and balance"

api_get "/api/payments/$PAYMENT_ID/receipt" "$tmp_dir/receipt.json"
assert_jq "$tmp_dir/receipt.json" \
  '(.totalOwed == 1350) and (.totalAdjustments == -100) and (.totalPaid == 600) and (.balance == 750) and ((.receiptNumber // "") | length > 0)' \
  "payment receipt matches the student ledger"

api_get "/api/schools/$SCHOOL_ID/fee-adjustments/paginated?termId=$TERM_ID&page=0&size=100" "$tmp_dir/adjustments.json"
assert_jq "$tmp_dir/adjustments.json" \
  "any(.content[]?; (.id == $ADJUSTMENT_ID) and (.customStudentId == \"$STUDENT_ID\") and (.status == \"APPROVED\") and (.amount == -100))" \
  "approved tuition adjustment is visible in the term ledger"

api_get "/api/schools/$SCHOOL_ID/class-requirements/$REQUIREMENT_ID/students" "$tmp_dir/class-progress.json"
assert_jq "$tmp_dir/class-progress.json" \
  "any(.[]?; .studentId == \"$STUDENT_ID\")" \
  "published class requirements include the enrolled student"

api_get "/api/schools/$SCHOOL_ID/students/$STUDENT_ID/requirements?academicTermId=$TERM_ID" "$tmp_dir/student-requirements.json"
assert_jq "$tmp_dir/student-requirements.json" \
  '([.items[]? | .status] | index("PARTIAL") != null) and ([.items[]? | .status] | index("CASH_EQUIVALENT") != null) and (any(.customRequirements[]?; .name == "HB Pencils"))' \
  "requirement receipt, waiver, cash equivalent, and custom item persist"

api_get "/api/schools/$SCHOOL_ID/attendance/grade-levels/$GRADE_LEVEL_ID/streams/$STREAM_ID/status?date=$ATTENDANCE_DATE" "$tmp_dir/attendance-status.json"
assert_jq "$tmp_dir/attendance-status.json" '. == true' \
  "class attendance is submitted"

api_get "/api/schools/$SCHOOL_ID/attendance/student/$STUDENT_ID/summary?startDate=$ATTENDANCE_DATE&endDate=$ATTENDANCE_DATE" "$tmp_dir/attendance-summary.json"
assert_jq "$tmp_dir/attendance-summary.json" \
  '(.totalSchoolDays == 1) and (.presentDays == 1) and (.attendanceRate == 100)' \
  "student attendance summary is calculated from persisted attendance"

echo
echo "All real ecosystem assertions passed."
