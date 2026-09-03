#!/usr/bin/env bash
set -euo pipefail

# Creates persistent local API records for household-dashboard acceptance
# testing. It never writes fixture values into the Flutter UI and is safe to
# rerun: existing guardians, children, approvals, and seeded payments are
# detected before a new request is made.

BASE_URL="${SMA_API_BASE_URL:-http://127.0.0.1:8080/Narellallc/sma-v1/1.0.0}"
SCHOOL_ID="${SMA_TEST_SCHOOL_ID:-AKW-XXX-E41A3E}"
USERNAME="${SMA_TEST_USERNAME:-}"
PASSWORD="${SMA_TEST_PASSWORD:-}"
TERM_ID="${SMA_TEST_TERM_ID:-1}"

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  printf 'Set SMA_TEST_USERNAME and SMA_TEST_PASSWORD for a local school administrator.\n' >&2
  exit 2
fi

HTTP_CODE=''
RESPONSE_BODY=''
ACCESS_TOKEN=''
CREATED_HOUSEHOLDS=0
CREATED_GUARDIANS=0
CREATED_STUDENTS=0
CREATED_PAYMENTS=0

request() {
  local method="$1" path="$2" body="${3:-}"
  local response
  local args=(-sS -w $'\n%{http_code}' -X "$method" "$BASE_URL$path")
  if [[ -n "$ACCESS_TOKEN" ]]; then
    args+=(-H "Authorization: Bearer $ACCESS_TOKEN")
  fi
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' --data "$body")
  fi
  response="$(curl "${args[@]}")"
  HTTP_CODE="${response##*$'\n'}"
  RESPONSE_BODY="${response%$'\n'*}"
}

expect() {
  local label="$1"
  shift
  local allowed
  for allowed in "$@"; do
    if [[ "$HTTP_CODE" == "$allowed" ]]; then
      return
    fi
  done
  printf 'FAILED: %s (HTTP %s)\n%s\n' "$label" "$HTTP_CODE" "$RESPONSE_BODY" >&2
  exit 1
}

request POST /api/auth/login "$(jq -nc --arg username "$USERNAME" --arg password "$PASSWORD" \
  '{userName:$username,password:$password}')"
expect 'sign in' 200
ACCESS_TOKEN="$(jq -er '.accessToken' <<<"$RESPONSE_BODY")"

load_guardians() {
  request GET "/api/v1/guardians/schools/$SCHOOL_ID/filter?page=0&size=500"
  expect 'load guardians' 200
  GUARDIANS_JSON="$RESPONSE_BODY"
}

load_students() {
  local household_id="$1"
  request POST "/api/students/schools/$SCHOOL_ID/students/filter" \
    "$(jq -nc --argjson householdId "$household_id" \
      '{householdId:$householdId,page:0,size:100}')"
  expect "load students for household $household_id" 200
  STUDENTS_JSON="$(jq -c '.students // .content // .data // []' <<<"$RESPONSE_BODY")"
}

ensure_primary_guardian() {
  local first="$1" last="$2" dob="$3" gender_id="$4" phone="$5" email="$6"
  load_guardians
  HOUSEHOLD_ID="$(jq -r --arg first "$first" --arg last "$last" \
    '[.[] | select(.firstName == $first and .lastName == $last)][0].householdId // empty' \
    <<<"$GUARDIANS_JSON")"
  GUARDIAN_ID="$(jq -r --arg first "$first" --arg last "$last" \
    '[.[] | select(.firstName == $first and .lastName == $last)][0].customGuardianId // empty' \
    <<<"$GUARDIANS_JSON")"

  if [[ -z "$HOUSEHOLD_ID" || -z "$GUARDIAN_ID" ]]; then
    local title='Mr'
    if [[ "$gender_id" == '2' ]]; then title='Ms'; fi
    request POST /api/v1/guardians "$(jq -nc \
      --arg title "$title" --arg firstName "$first" --arg lastName "$last" \
      --arg dob "$dob" --arg schoolId "$SCHOOL_ID" --argjson genderId "$gender_id" \
      '{title:$title,firstName:$firstName,lastName:$lastName,isPrimary:true,dob:$dob,customSchoolId:$schoolId,genderId:$genderId,languageSpoken:["English"]}')"
    expect "create $first $last household" 200 201
    HOUSEHOLD_ID="$(jq -er '.householdId' <<<"$RESPONSE_BODY")"
    GUARDIAN_ID="$(jq -er '.customGuardianId' <<<"$RESPONSE_BODY")"
    CREATED_HOUSEHOLDS=$((CREATED_HOUSEHOLDS + 1))
    CREATED_GUARDIANS=$((CREATED_GUARDIANS + 1))
  fi

  request PUT "/api/v1/guardians/schools/$SCHOOL_ID/guardians/$GUARDIAN_ID/contact-info" \
    "$(jq -nc --arg phone "$phone" --arg email "$email" \
      '{personalPhoneNumber:[$phone],phoneNetworks:["MTN"],workPhoneNumber:"",workPhoneNetwork:"",email:$email,emails:[$email],socialMediaAccount:[]}')"
  expect "update contact for $first $last" 200
}

ensure_additional_guardian() {
  local household_id="$1" first="$2" last="$3" dob="$4" gender_id="$5" phone="$6" email="$7"
  load_guardians
  local guardian_id
  guardian_id="$(jq -r --arg first "$first" --arg last "$last" --argjson householdId "$household_id" \
    '[.[] | select(.firstName == $first and .lastName == $last and .householdId == $householdId)][0].customGuardianId // empty' \
    <<<"$GUARDIANS_JSON")"
  if [[ -z "$guardian_id" ]]; then
    local title='Mr'
    if [[ "$gender_id" == '2' ]]; then title='Ms'; fi
    request POST "/api/v1/guardians/schools/$SCHOOL_ID/households/$household_id/guardians/init" \
      "$(jq -nc --arg title "$title" --arg firstName "$first" --arg lastName "$last" \
        --arg dob "$dob" --arg schoolId "$SCHOOL_ID" --argjson householdId "$household_id" \
        --argjson genderId "$gender_id" \
        '{title:$title,firstName:$firstName,lastName:$lastName,isPrimary:false,dob:$dob,customSchoolId:$schoolId,householdId:$householdId,genderId:$genderId,languageSpoken:["English"]}')"
    expect "add $first $last to household $household_id" 200 201
    guardian_id="$(jq -er '.customGuardianId' <<<"$RESPONSE_BODY")"
    CREATED_GUARDIANS=$((CREATED_GUARDIANS + 1))
  fi
  request PUT "/api/v1/guardians/schools/$SCHOOL_ID/guardians/$guardian_id/contact-info" \
    "$(jq -nc --arg phone "$phone" --arg email "$email" \
      '{personalPhoneNumber:[$phone],phoneNetworks:["Telecel"],workPhoneNumber:"",workPhoneNetwork:"",email:$email,emails:[$email],socialMediaAccount:[]}')"
  expect "update contact for $first $last" 200
}

ensure_student() {
  local household_id="$1" first="$2" last="$3" dob="$4" gender_id="$5" grade_id="$6" stream_id="$7"
  load_students "$household_id"
  STUDENT_ID="$(jq -r --arg first "$first" --arg last "$last" \
    '[.[] | select(.firstName == $first and .lastName == $last)][0].customStudentId // empty' \
    <<<"$STUDENTS_JSON")"
  if [[ -z "$STUDENT_ID" ]]; then
    request POST "/api/students/schools/$SCHOOL_ID/households/$household_id/students" \
      "$(jq -nc --arg firstName "$first" --arg lastName "$last" --arg dateOfBirth "$dob" \
        --argjson genderId "$gender_id" --argjson gradeLevelId "$grade_id" --argjson streamId "$stream_id" \
        '{firstName:$firstName,lastName:$lastName,dateOfBirth:$dateOfBirth,genderId:$genderId,gradeLevelId:$gradeLevelId,streamId:$streamId,languageSpoken:["English"]}')"
    expect "create student $first $last" 200 201
    STUDENT_ID="$(jq -er '.customStudentId' <<<"$RESPONSE_BODY")"
    CREATED_STUDENTS=$((CREATED_STUDENTS + 1))
  fi
}

approve_household_if_needed() {
  local household_id="$1"
  load_guardians
  load_students "$household_id"
  local pending_guardians pending_students
  pending_guardians="$(jq --argjson householdId "$household_id" \
    '[.[] | select(.householdId == $householdId and ((.status // "") | ascii_upcase) != "APPROVED")] | length' \
    <<<"$GUARDIANS_JSON")"
  pending_students="$(jq \
    '[.[] | select((((.status // "") | ascii_upcase) != "ACTIVE") and (((.status // "") | ascii_upcase) != "APPROVED"))] | length' \
    <<<"$STUDENTS_JSON")"
  if (( pending_guardians > 0 || pending_students > 0 )); then
    request PUT "/api/v1/guardians/schools/$SCHOOL_ID/households/$household_id/status" \
      '{"status":"APPROVED","reason":"Household dashboard acceptance dataset"}'
    expect "approve household $household_id" 200
  fi
}

record_payment_if_needed() {
  local household_id="$1" student_id="$2" requested_amount="$3" reference="$4" payer="$5"
  request GET "/api/payments/student/$student_id/term/$TERM_ID"
  expect "load payments for $student_id" 200
  if jq -e --arg payer "$payer" \
    '.[] | select(.description == "Household dashboard acceptance dataset" and .payerName == $payer and .status != "REVERSED" and .status != "CANCELLED")' \
    >/dev/null <<<"$RESPONSE_BODY"; then
    return
  fi

  request GET "/api/payments/schools/$SCHOOL_ID/households/$household_id/allocation-options?termId=$TERM_ID"
  expect "load payment options for household $household_id" 200
  local balance amount
  balance="$(jq -r --arg studentId "$student_id" \
    '[.students[] | select(.customStudentId == $studentId)][0].balance // 0' <<<"$RESPONSE_BODY")"
  if ! awk -v balance="$balance" 'BEGIN { exit !(balance > 0) }'; then
    return
  fi
  if [[ "$requested_amount" == 'full' ]]; then
    amount="$balance"
  else
    amount="$(awk -v requested="$requested_amount" -v balance="$balance" \
      'BEGIN { value = requested < balance ? requested : balance; printf "%.2f", value }')"
  fi

  local response
  response="$(curl -sS -w $'\n%{http_code}' -X POST "$BASE_URL/api/payments" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -F "customStudentId=$student_id" \
    -F "customSchoolId=$SCHOOL_ID" \
    -F "payerName=$payer" \
    -F "amount=$amount" \
    -F 'paymentDate=2026-08-30T12:00:00' \
    -F 'paymentMethodId=1' \
    -F "referenceNumber=$reference" \
    -F "receivedBy=$USERNAME" \
    -F 'description=Household dashboard acceptance dataset' \
    -F "termId=$TERM_ID" \
    -F "idempotencyKey=$reference" \
    -F 'overpaymentConfirmed=false')"
  HTTP_CODE="${response##*$'\n'}"
  RESPONSE_BODY="${response%$'\n'*}"
  expect "record payment for $student_id" 200
  CREATED_PAYMENTS=$((CREATED_PAYMENTS + 1))
}

# Student specs are: first|last|date of birth|gender ID|grade-level business ID|stream ID.
ensure_primary_guardian Adwoa Mensah 1987-03-14 2 0200002101 adwoa.mensah.household@example.com
mensah_household="$HOUSEHOLD_ID"
ensure_student "$mensah_household" Kwaku Mensah 2018-06-11 1 3 3
mensah_first_student="$STUDENT_ID"
ensure_student "$mensah_household" Afia Mensah 2020-02-09 2 2 9
approve_household_if_needed "$mensah_household"
record_payment_if_needed "$mensah_household" "$mensah_first_student" 50 HDASH-MENSAH-01 'Adwoa Mensah'

ensure_primary_guardian Yaa Owusu 1991-11-05 2 0200002102 yaa.owusu.household@example.com
owusu_household="$HOUSEHOLD_ID"
ensure_student "$owusu_household" Sena Owusu 2022-01-18 2 254193 2
owusu_student="$STUDENT_ID"
approve_household_if_needed "$owusu_household"
record_payment_if_needed "$owusu_household" "$owusu_student" full HDASH-OWUSU-01 'Yaa Owusu'

ensure_primary_guardian Kwame Asare 1984-08-23 1 0200002103 kwame.asare.household@example.com
asare_household="$HOUSEHOLD_ID"
ensure_student "$asare_household" Nhyira Asare 2017-04-02 2 4 10
asare_first_student="$STUDENT_ID"
ensure_student "$asare_household" Kobby Asare 2021-07-19 1 1 8
ensure_student "$asare_household" Maame Asare 2016-12-01 2 5 11
approve_household_if_needed "$asare_household"
record_payment_if_needed "$asare_household" "$asare_first_student" 100 HDASH-ASARE-01 'Kwame Asare'

ensure_primary_guardian Akua Osei 1989-06-17 2 0200002104 akua.osei.household@example.com
osei_household="$HOUSEHOLD_ID"
ensure_student "$osei_household" Nana Osei 2014-03-30 1 9 4
approve_household_if_needed "$osei_household"

ensure_primary_guardian Abena Agyeman 1990-09-12 2 0200002105 abena.agyeman.household@example.com
agyeman_household="$HOUSEHOLD_ID"
ensure_student "$agyeman_household" Kojo Agyeman 2015-05-16 1 6 12
ensure_student "$agyeman_household" Efua Agyeman 2018-10-24 2 3 5
approve_household_if_needed "$agyeman_household"

ensure_primary_guardian Kofi Addo 1983-02-27 1 0200002106 kofi.addo.household@example.com
addo_household="$HOUSEHOLD_ID"
approve_household_if_needed "$addo_household"

ensure_primary_guardian Esi Gyasi 1988-07-08 2 0200002107 esi.gyasi.household@example.com
gyasi_household="$HOUSEHOLD_ID"
ensure_additional_guardian "$gyasi_household" Yaw Gyasi 1985-04-21 1 0200002207 yaw.gyasi.household@example.com
ensure_student "$gyasi_household" Ama Gyasi 2020-11-13 2 2 9
approve_household_if_needed "$gyasi_household"

ensure_primary_guardian Mavis Opoku 1992-01-31 2 0200002108 mavis.opoku.household@example.com
opoku_household="$HOUSEHOLD_ID"
ensure_student "$opoku_household" Selina Opoku 2022-03-04 2 254193 6
ensure_student "$opoku_household" Joel Opoku 2017-09-18 1 4 10
ensure_student "$opoku_household" Kweku Opoku 2015-02-22 1 6 12
approve_household_if_needed "$opoku_household"

ensure_primary_guardian Josephine Appiah 1986-12-10 2 0200002109 josephine.appiah.household@example.com
appiah_household="$HOUSEHOLD_ID"
ensure_student "$appiah_household" Emmanuel Appiah 2016-08-29 1 5 11
approve_household_if_needed "$appiah_household"

ensure_primary_guardian Agnes Boadu 1993-05-06 2 0200002110 agnes.boadu.household@example.com
boadu_household="$HOUSEHOLD_ID"
ensure_student "$boadu_household" Gideon Boadu 2021-04-14 1 1 8
ensure_student "$boadu_household" Naomi Boadu 2014-10-05 2 9 4
approve_household_if_needed "$boadu_household"

load_guardians
request POST "/api/students/schools/$SCHOOL_ID/students/filter" \
  '{"page":0,"size":500}'
expect 'load final students' 200
total_students="$(jq '(.students // .content // .data // []) | length' <<<"$RESPONSE_BODY")"
total_households="$(jq '[.[].householdId] | unique | length' <<<"$GUARDIANS_JSON")"

printf 'Household dashboard dataset ready.\n'
printf 'Created this run: %d households, %d guardians, %d students, %d payments.\n' \
  "$CREATED_HOUSEHOLDS" "$CREATED_GUARDIANS" "$CREATED_STUDENTS" "$CREATED_PAYMENTS"
printf 'Local school totals: %s households, %s students.\n' "$total_households" "$total_students"
