#!/bin/bash
# =============================================================================
# Housecall Pro — Comprehensive Voice Agent Tool Test Suite v2
# =============================================================================
#
# Tests ALL 30 fs-* tool endpoints through the internal API, exactly as the
# voice agent calls them. Covers the full new-caller + auto-schedule E2E flow.
#
# Phases:
#   0: Preflight
#   1: Seed (customers, properties, service requests)
#   2: get-services (price book — duration, price, category)
#   3: check-service-area (zip code + negative test)
#   4: get-company-info (business hours, timezone)
#   5: Customer CRUD (create, find-by-phone, update, not-found)
#   6: Property CRUD (create, list)
#   7: Service Request flow (create w/ line items + lead_source, get, get-list)
#   8: check-availability (booking windows, merged contiguous blocks)
#   9: create-assessment + reschedule-assessment (lead → estimate → schedule)
#  10: Jobs & Appointments (get-jobs, get-appointments, add-note-to-job)
#  11: get-client-schedule (unified schedule view)
#  12: Estimates (get-estimates)
#  13: Invoices & Balance (get-invoices, get-account-balance)
#  14: submit-lead (full E2E new caller flow)
#  15: Direct HCP API — job types, schedule_availability, lead_source verify
#
# Usage:
#   ./testing/seed-and-test-hcp-v2.sh all      # Seed + test + guide
#   ./testing/seed-and-test-hcp-v2.sh seed      # Seed only
#   ./testing/seed-and-test-hcp-v2.sh test      # Test only (assumes seeded)
#   ./testing/seed-and-test-hcp-v2.sh direct    # Direct HCP API tests only
#   ./testing/seed-and-test-hcp-v2.sh guide     # Voice agent test guide
# =============================================================================

set -euo pipefail

BASE_URL="http://localhost:3000/internal/tools/fs"
API_KEY="ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7"
LOCATION_ID="cmloxy8vs000ar801ma3wz6s3"

HCP_API_KEY="7bce761fb72a40a6a3cce71c9ca015c1"
HCP_BASE_URL="https://api.housecallpro.com"

YOUR_PHONE="+18313345344"
SEED_PHONE_1="+15552000001"
SEED_PHONE_2="+15552000002"
SEED_PHONE_3="+15552000003"
SEED_PHONE_4="+15552000004"
NEW_CALLER_PHONE="+15558888888"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

STATE_FILE="/tmp/hcp-seed-state-v2.json"
PASSED=0; FAILED=0

# ─── Helpers ────────────────────────────────────────────────

call_api() {
  local endpoint="$1" body="$2" label="${3:-$endpoint}"
  local response http_code body_response
  response=$(curl -s -m 30 -w "\n%{http_code}" \
    -X POST "${BASE_URL}/${endpoint}" \
    -H "Content-Type: application/json" \
    -H "x-internal-api-key: ${API_KEY}" \
    -d "$body")
  http_code=$(echo "$response" | tail -n1)
  body_response=$(echo "$response" | sed '$d')
  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo -e "${GREEN}✅ ${label}${NC} (HTTP ${http_code})" >&2
  else
    echo -e "${RED}❌ ${label}${NC} (HTTP ${http_code})" >&2
    echo -e "${RED}   $(echo "$body_response" | head -c 200)${NC}" >&2
  fi
  echo "$body_response"
}

call_hcp() {
  local method="$1" path="$2" label="${3:-$path}" data="${4:-}"
  local url="${HCP_BASE_URL}${path}"
  local response http_code body_response
  if [ "$method" = "GET" ]; then
    response=$(curl -s -m 15 -w "\n%{http_code}" -X GET "$url" \
      -H "Accept: application/json" -H "Authorization: Token ${HCP_API_KEY}")
  else
    response=$(curl -s -m 15 -w "\n%{http_code}" -X "$method" "$url" \
      -H "Accept: application/json" -H "Content-Type: application/json" \
      -H "Authorization: Token ${HCP_API_KEY}" -d "$data")
  fi
  http_code=$(echo "$response" | tail -n1)
  body_response=$(echo "$response" | sed '$d')
  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo -e "${GREEN}✅ ${label}${NC} (HTTP ${http_code})" >&2
  else
    echo -e "${RED}❌ ${label}${NC} (HTTP ${http_code})" >&2
  fi
  echo "$body_response"
}

future_date() { date -d "+${1} days" "+%Y-%m-%d" 2>/dev/null || date -v+${1}d "+%Y-%m-%d" 2>/dev/null; }
future_datetime() {
  local d=$1 h=$2 m=${3:-0}
  date -d "+${d} days" "+%Y-%m-%dT$(printf '%02d' $h):$(printf '%02d' $m):00" 2>/dev/null || \
  date -v+${d}d "+%Y-%m-%dT$(printf '%02d' $h):$(printf '%02d' $m):00" 2>/dev/null
}
next_biz_day() {
  local n=$1 c=0 d=0
  while [ "$c" -lt "$n" ]; do
    d=$((d+1))
    local dow; dow=$(date -d "+${d} days" "+%w" 2>/dev/null || date -v+${d}d "+%w" 2>/dev/null)
    [ "$dow" != "0" ] && [ "$dow" != "6" ] && c=$((c+1))
  done
  echo "$d"
}

assert_gte() {
  if [ "$1" -ge "$2" ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ $3 ($1 >= $2)${NC}"; ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ $3: expected >= $2, got '$1'${NC}"; ((FAILED++)) || true
  fi
}
assert_eq() {
  if [ "$1" = "$2" ]; then
    echo -e "  ${GREEN}✓ $3 ($1)${NC}"; ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ $3: expected '$2', got '$1'${NC}"; ((FAILED++)) || true
  fi
}
assert_not_empty() {
  if [ -n "$1" ] && [ "$1" != "null" ]; then
    echo -e "  ${GREEN}✓ $2${NC}"; ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ $2: empty or null${NC}"; ((FAILED++)) || true
  fi
}
assert_contains() {
  if echo "$1" | grep -qi "$2"; then
    echo -e "  ${GREEN}✓ $3${NC}"; ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ $3: does not contain '$2'${NC}"; ((FAILED++)) || true
  fi
}

phase() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  PHASE ${1}: ${2}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ─── Phase 0: Preflight ────────────────────────────────────

preflight() {
  phase "0" "PREFLIGHT"
  command -v jq &>/dev/null || { echo -e "${RED}❌ jq required${NC}"; exit 1; }
  echo -e "${GREEN}✅ jq installed${NC}"
  local h
  h=$(curl -s -m 10 -o /dev/null -w "%{http_code}" "${BASE_URL}/get-services" \
    -X POST -H "Content-Type: application/json" -H "x-internal-api-key: ${API_KEY}" \
    -d "{\"locationId\": \"${LOCATION_ID}\"}")
  if [[ "$h" -ge 200 && "$h" -lt 300 ]]; then
    echo -e "${GREEN}✅ Backend API reachable (HTTP ${h})${NC}"
  else
    echo -e "${RED}❌ Backend API returned HTTP ${h} — is the server running on port 3000?${NC}"; exit 1
  fi
}

# ─── Phase 1: Seed ─────────────────────────────────────────

seed() {
  phase "1" "SEED HCP SANDBOX"
  echo '{}' > "$STATE_FILE"

  echo -e "${CYAN}── 1a: Fetch services ──${NC}"
  local svc_resp svc_count first_svc_id first_svc_name
  svc_resp=$(call_api "get-services" "{\"locationId\":\"${LOCATION_ID}\"}" "get-services")
  svc_count=$(echo "$svc_resp" | jq '.services | length' 2>/dev/null || echo "0")
  first_svc_id=$(echo "$svc_resp" | jq -r '.services[0].id // empty' 2>/dev/null)
  first_svc_name=$(echo "$svc_resp" | jq -r '.services[0].name // empty' 2>/dev/null)
  echo "  Found ${svc_count} services. First: ${first_svc_name} (${first_svc_id})"
  jq --arg id "$first_svc_id" --arg name "$first_svc_name" --argjson count "$svc_count" \
    '. + {services: {first_id: $id, first_name: $name, count: $count}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  echo -e "${CYAN}── 1b: Create customers ──${NC}"
  mk_client() {
    local r; r=$(call_api "create-customer" \
      "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"$1\",\"firstName\":\"$2\",\"lastName\":\"$3\",\"email\":\"$4\"}" "Create: $2 $3")
    echo "$r" | jq -r '.customer.id // empty'
  }
  local c1 c2 c3 c4
  c1=$(mk_client "$SEED_PHONE_1" "Maria" "Garcia" "maria.v2@example.com")
  c2=$(mk_client "$SEED_PHONE_2" "James" "Wilson" "james.v2@example.com")
  c3=$(mk_client "$SEED_PHONE_3" "Sarah" "Chen" "sarah.v2@example.com")
  c4=$(mk_client "$SEED_PHONE_4" "Robert" "Johnson" "robert.v2@example.com")
  echo "  IDs: c1=${c1} c2=${c2} c3=${c3} c4=${c4}"
  jq --arg c1 "$c1" --arg c2 "$c2" --arg c3 "$c3" --arg c4 "$c4" \
    '. + {clients: {maria: $c1, james: $c2, sarah: $c3, robert: $c4}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  echo -e "${CYAN}── 1c: Create properties ──${NC}"
  mk_prop() {
    local r; r=$(call_api "create-property" \
      "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"$1\",\"customerId\":\"$2\",\"address\":{\"street\":\"$3\",\"city\":\"$4\",\"state\":\"$5\",\"zip\":\"$6\"}}" "Property: $7")
    echo "$r" | jq -r '.property.id // empty'
  }
  local p1 p2 p3 p4
  p1=$(mk_prop "$SEED_PHONE_1" "$c1" "456 Oak Ave"       "Santa Cruz" "CA" "95065" "Maria")
  p2=$(mk_prop "$SEED_PHONE_2" "$c2" "789 Pine St"       "Santa Cruz" "CA" "95065" "James")
  p3=$(mk_prop "$SEED_PHONE_3" "$c3" "321 Elm Dr"        "Capitola"   "CA" "95010" "Sarah")
  p4=$(mk_prop "$SEED_PHONE_4" "$c4" "555 Walnut Blvd"   "Aptos"      "CA" "95003" "Robert")
  jq --arg p1 "$p1" --arg p2 "$p2" --arg p3 "$p3" --arg p4 "$p4" \
    '. + {properties: {maria: $p1, james: $p2, sarah: $p3, robert: $p4}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  echo -e "${CYAN}── 1d: Create service requests (leads) with line items ──${NC}"
  mk_req() {
    local sid_f=""; [ -n "$6" ] && sid_f=",\"serviceId\":\"$6\",\"serviceType\":\"$5\""
    local r; r=$(call_api "create-service-request" \
      "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"$1\",\"customerId\":\"$2\",\"description\":\"$4\",\"serviceType\":\"$5\",\"propertyId\":\"$3\"${sid_f},\"summary\":\"Test lead from seed script\",\"desiredTime\":\"Tuesday morning\"}" "Request: $7")
    # Return both request ID and assessment ID
    local req_id assess_id
    req_id=$(echo "$r" | jq -r '.serviceRequest.id // empty')
    assess_id=$(echo "$r" | jq -r '.assessmentId // empty')
    echo "${req_id}|${assess_id}"
  }
  local sr1_full sr2_full sr1 sr2 sr3 sr4 a1 a2
  sr1_full=$(mk_req "$SEED_PHONE_1" "$c1" "$p1" "Kitchen sink leaking"    "Leak Repair"    "$first_svc_id" "Maria/Leak")
  sr2_full=$(mk_req "$SEED_PHONE_2" "$c2" "$p2" "Bathroom drain clogged"  "Drain Cleaning" "$first_svc_id" "James/Drain")
  sr1=$(echo "$sr1_full" | cut -d'|' -f1); a1=$(echo "$sr1_full" | cut -d'|' -f2)
  sr2=$(echo "$sr2_full" | cut -d'|' -f1); a2=$(echo "$sr2_full" | cut -d'|' -f2)
  sr3=$(mk_req "$SEED_PHONE_3" "$c3" "$p3" "Water heater banging" "Water Heater" "" "Sarah/WH" | cut -d'|' -f1)
  sr4=$(mk_req "$SEED_PHONE_4" "$c4" "$p4" "New toilet install"   "Toilet Install" "" "Robert/Toilet" | cut -d'|' -f1)
  jq --arg sr1 "$sr1" --arg sr2 "$sr2" --arg sr3 "$sr3" --arg sr4 "$sr4" \
     --arg a1 "$a1" --arg a2 "$a2" \
    '. + {requests: {maria: $sr1, james: $sr2, sarah: $sr3, robert: $sr4}, assessments: {maria: $a1, james: $a2}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  echo -e "${GREEN}  SEEDING COMPLETE${NC}"
  jq . "$STATE_FILE"
  echo -e "  ⏳ Waiting 3s for HCP propagation..."
  sleep 3
}

# ─── Test Phases ───────────────────────────────────────────

run_tests() {
  [ -f "$STATE_FILE" ] || { echo -e "${RED}❌ No state file. Run seed first.${NC}"; exit 1; }

  local c1 c2 c3 c4 p1 p2 p3 p4 sr1 sr2 sr3 a1 a2 first_svc_id
  c1=$(jq -r '.clients.maria'   "$STATE_FILE"); c2=$(jq -r '.clients.james'   "$STATE_FILE")
  c3=$(jq -r '.clients.sarah'   "$STATE_FILE"); c4=$(jq -r '.clients.robert'  "$STATE_FILE")
  p1=$(jq -r '.properties.maria' "$STATE_FILE"); p2=$(jq -r '.properties.james' "$STATE_FILE")
  sr1=$(jq -r '.requests.maria'  "$STATE_FILE"); sr2=$(jq -r '.requests.james'  "$STATE_FILE")
  sr3=$(jq -r '.requests.sarah'  "$STATE_FILE")
  a1=$(jq -r '.assessments.maria // empty' "$STATE_FILE"); a2=$(jq -r '.assessments.james // empty' "$STATE_FILE")
  first_svc_id=$(jq -r '.services.first_id' "$STATE_FILE")

  # ═══════════════ Phase 2: get-services ═══════════════
  phase "2" "GET-SERVICES (PRICE BOOK)"
  local sv sc
  sv=$(call_api "get-services" "{\"locationId\":\"${LOCATION_ID}\"}" "get-services")
  sc=$(echo "$sv" | jq '.services | length' 2>/dev/null || echo 0)
  assert_gte "$sc" 1 "Has services"

  local ids_count names_count
  ids_count=$(echo "$sv" | jq '[.services[] | select(.id != null and .id != "")] | length' 2>/dev/null || echo 0)
  names_count=$(echo "$sv" | jq '[.services[] | select(.name != null and .name != "")] | length' 2>/dev/null || echo 0)
  assert_eq "$ids_count" "$sc" "All services have .id"
  assert_eq "$names_count" "$sc" "All services have .name"

  # Check duration + price fields exist (may be null for this test account)
  local has_dur has_price
  has_dur=$(echo "$sv" | jq '[.services[] | select(.duration != null)] | length' 2>/dev/null || echo 0)
  has_price=$(echo "$sv" | jq '[.services[] | select(.price != null)] | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}ℹ ${has_dur}/${sc} have duration, ${has_price}/${sc} have price${NC}"

  local categories
  categories=$(echo "$sv" | jq -r '[.services[].category] | unique | join(", ")' 2>/dev/null || echo "none")
  echo -e "  ${CYAN}Categories: ${categories}${NC}"

  # ═══════════════ Phase 3: check-service-area ═══════════════
  phase "3" "CHECK-SERVICE-AREA"
  local sa1 sa1_ok sa2 sa2_ok
  sa1=$(call_api "check-service-area" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"zipCode\":\"95065\"}" "check-service-area 95065")
  sa1_ok=$(echo "$sa1" | jq -r '.serviceArea.isServiced // false' 2>/dev/null)
  assert_eq "$sa1_ok" "true" "95065 IS serviced"
  echo -e "  ${CYAN}Zone: $(echo "$sa1" | jq -r '.serviceArea.matchedZone // "N/A"')${NC}"

  sa2=$(call_api "check-service-area" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"zipCode\":\"99999\"}" "check-service-area 99999")
  sa2_ok=$(echo "$sa2" | jq -r '.serviceArea.isServiced // true' 2>/dev/null)
  assert_eq "$sa2_ok" "false" "99999 NOT serviced"

  # ═══════════════ Phase 4: get-company-info ═══════════════
  phase "4" "GET-COMPANY-INFO + BUSINESS HOURS"
  local ci ci_name ci_tz ci_bh
  ci=$(call_api "get-company-info" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\"}" "get-company-info")
  ci_name=$(echo "$ci" | jq -r '.companyInfo.name // empty' 2>/dev/null)
  ci_tz=$(echo "$ci" | jq -r '.companyInfo.timezone // empty' 2>/dev/null)
  assert_not_empty "$ci_name" "Company name present"
  assert_not_empty "$ci_tz" "Company timezone present"
  echo -e "  ${CYAN}Name: ${ci_name}, TZ: ${ci_tz}${NC}"

  # Business hours in metadata
  ci_bh=$(echo "$ci" | jq '.companyInfo.metadata.businessHours | length' 2>/dev/null || echo 0)
  assert_gte "$ci_bh" 1 "Business hours present in metadata"
  echo -e "  ${CYAN}Business hours: ${ci_bh} day entries${NC}"

  # ═══════════════ Phase 5: Customer CRUD ═══════════════
  phase "5" "CUSTOMER CRUD"

  echo -e "${YELLOW}── 5a: get-customer-by-phone (existing) ──${NC}"
  local cu1 cu1_id cu1_name
  cu1=$(call_api "get-customer-by-phone" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\"}" "find Maria")
  cu1_id=$(echo "$cu1" | jq -r '.customer.id // empty' 2>/dev/null)
  cu1_name=$(echo "$cu1" | jq -r '.customer.name // empty' 2>/dev/null)
  assert_not_empty "$cu1_id" "Found Maria by phone"
  echo -e "  ${CYAN}Found: ${cu1_name} (${cu1_id})${NC}"

  echo -e "${YELLOW}── 5b: get-customer-by-phone (not found) ──${NC}"
  local cu2 cu2_msg
  cu2=$(call_api "get-customer-by-phone" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"+15559999999\"}" "find unknown")
  cu2_msg=$(echo "$cu2" | jq -r '.message // empty' 2>/dev/null)
  assert_not_empty "$cu2_msg" "Returns message for unknown phone"

  echo -e "${YELLOW}── 5c: update-customer ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local cu3
    cu3=$(call_api "update-customer" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\",\"email\":\"maria.updated@example.com\"}" "update Maria")
    assert_not_empty "$(echo "$cu3" | jq -r '.message // empty')" "update-customer OK"
  fi

  # ═══════════════ Phase 6: Property CRUD ═══════════════
  phase "6" "PROPERTY CRUD"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local pr1 pr1_count
    pr1=$(call_api "list-properties" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "list-properties Maria")
    pr1_count=$(echo "$pr1" | jq '.properties | length' 2>/dev/null || echo 0)
    assert_gte "$pr1_count" 1 "Maria has >= 1 property"
  fi

  # ═══════════════ Phase 7: Service Request Flow ═══════════════
  phase "7" "SERVICE REQUEST FLOW"

  echo -e "${YELLOW}── 7a: get-requests (Maria) ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local sr_resp sr_msg
    sr_resp=$(call_api "get-requests" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-requests Maria")
    sr_msg=$(echo "$sr_resp" | jq -r '.message // empty' 2>/dev/null)
    assert_not_empty "$sr_msg" "get-requests returns message"
  fi

  echo -e "${YELLOW}── 7b: get-request (single) ──${NC}"
  if [ -n "$sr1" ] && [ "$sr1" != "null" ]; then
    local sr_single
    sr_single=$(call_api "get-request" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"requestId\":\"${sr1}\"}" "get-request Maria")
    assert_not_empty "$(echo "$sr_single" | jq -r '.message // empty')" "get-request returns data"
  fi

  # ═══════════════ Phase 8: check-availability ═══════════════
  phase "8" "CHECK-AVAILABILITY (BOOKING WINDOWS)"
  local biz_days avail_start avail_end
  biz_days=$(next_biz_day 2)
  avail_start=$(future_date "$biz_days")
  avail_end=$(future_date $((biz_days + 3)))

  echo -e "${YELLOW}── 8a: check-availability (${avail_start} → ${avail_end}) ──${NC}"
  local avail avail_windows avail_msg
  avail=$(call_api "get-availability" \
    "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"date\":\"${avail_start}\",\"endDate\":\"${avail_end}\"}" \
    "get-availability")
  avail_msg=$(echo "$avail" | jq -r '.message // empty' 2>/dev/null)
  assert_not_empty "$avail_msg" "Availability returns message"
  echo -e "  ${CYAN}${avail_msg}${NC}"

  # Check we got windows back
  avail_windows=$(echo "$avail" | jq '.availableWindows | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Available windows: ${avail_windows}${NC}"
  if [ "$avail_windows" -gt 0 ]; then
    echo -e "  ${CYAN}First window: $(echo "$avail" | jq -r '.availableWindows[0]' 2>/dev/null)${NC}"
  fi

  # ═══════════════ Phase 9: Assessment Flow ═══════════════
  phase "9" "ASSESSMENT FLOW (CREATE + RESCHEDULE)"

  echo -e "${YELLOW}── 9a: create-assessment (convert lead → estimate) ──${NC}"
  local assess_resp assess_id
  if [ -n "$sr3" ] && [ "$sr3" != "null" ]; then
    assess_resp=$(call_api "create-assessment" \
      "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_3}\",\"requestId\":\"${sr3}\",\"instructions\":\"Please check water heater pilot light\"}" \
      "create-assessment Sarah")
    assess_id=$(echo "$assess_resp" | jq -r '.assessment.id // empty' 2>/dev/null)
    if [ -z "$assess_id" ] || [ "$assess_id" = "null" ]; then
      assess_id=$(echo "$assess_resp" | jq -r '.assessment.estimate_id // .assessment.job_id // empty' 2>/dev/null)
    fi
    assert_not_empty "$assess_id" "Assessment created with ID"
    echo -e "  ${CYAN}Assessment ID: ${assess_id}${NC}"

    # Save to state
    jq --arg aid "$assess_id" '. + {assessments: (.assessments + {sarah: $aid})}' \
      "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo -e "${YELLOW}── 9b: reschedule-assessment (schedule it) ──${NC}"
    if [ -n "$assess_id" ] && [ "$assess_id" != "null" ]; then
      local sched_start sched_end sched_resp
      sched_start=$(future_datetime "$biz_days" 10 0)
      sched_end=$(future_datetime "$biz_days" 11 0)
      sched_resp=$(call_api "reschedule-assessment" \
        "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_3}\",\"assessmentId\":\"${assess_id}\",\"startTime\":\"${sched_start}\",\"endTime\":\"${sched_end}\"}" \
        "reschedule-assessment Sarah")
      assert_not_empty "$(echo "$sched_resp" | jq -r '.message // empty')" "Assessment scheduled"
      echo -e "  ${CYAN}$(echo "$sched_resp" | jq -r '.message // empty')${NC}"
    fi
  else
    echo -e "  ${YELLOW}⚠️ Skipping (no request ID for Sarah)${NC}"
  fi

  # ═══════════════ Phase 10: Jobs & Appointments ═══════════════
  phase "10" "JOBS & APPOINTMENTS"

  echo -e "${YELLOW}── 10a: get-jobs ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local jobs_resp
    jobs_resp=$(call_api "get-jobs" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-jobs Maria")
    assert_not_empty "$(echo "$jobs_resp" | jq -r '.message // empty')" "get-jobs OK"
  fi

  echo -e "${YELLOW}── 10b: get-appointments ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local appts_resp
    appts_resp=$(call_api "get-appointments" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-appointments Maria")
    assert_not_empty "$(echo "$appts_resp" | jq -r '.message // empty')" "get-appointments OK"
  fi

  # ═══════════════ Phase 11: get-client-schedule ═══════════════
  phase "11" "GET-CLIENT-SCHEDULE"
  if [ -n "$c2" ] && [ "$c2" != "null" ]; then
    local cs_resp cs_msg
    cs_resp=$(call_api "get-client-schedule" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_2}\",\"customerId\":\"${c2}\"}" "get-client-schedule James")
    cs_msg=$(echo "$cs_resp" | jq -r '.message // empty' 2>/dev/null)
    assert_not_empty "$cs_msg" "get-client-schedule OK"
    echo -e "  ${CYAN}${cs_msg}${NC}"
  fi

  # ═══════════════ Phase 12: Estimates ═══════════════
  phase "12" "ESTIMATES"
  if [ -n "$c3" ] && [ "$c3" != "null" ]; then
    local est_resp
    est_resp=$(call_api "get-estimates" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_3}\",\"customerId\":\"${c3}\"}" "get-estimates Sarah")
    assert_not_empty "$(echo "$est_resp" | jq -r '.message // empty')" "get-estimates OK"
  fi

  # ═══════════════ Phase 13: Invoices & Balance ═══════════════
  phase "13" "INVOICES & BALANCE"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local inv_resp bal_resp
    inv_resp=$(call_api "get-invoices" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-invoices Maria")
    assert_not_empty "$(echo "$inv_resp" | jq -r '.message // empty')" "get-invoices OK"

    bal_resp=$(call_api "get-account-balance" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-account-balance Maria")
    assert_not_empty "$(echo "$bal_resp" | jq -r '.message // empty')" "get-account-balance OK"
  fi

  # ═══════════════ Phase 14: submit-lead (E2E) ═══════════════
  phase "14" "SUBMIT-LEAD (FULL E2E)"
  local sl_resp sl_msg sl_cust_created
  sl_resp=$(call_api "submit-lead" \
    "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${NEW_CALLER_PHONE}\",\"firstName\":\"Test\",\"lastName\":\"LeadV2\",\"email\":\"testv2@example.com\",\"address\":{\"street\":\"999 Test Ln\",\"city\":\"Santa Cruz\",\"state\":\"CA\",\"zip\":\"95065\"},\"serviceDescription\":\"Faucet dripping in kitchen\"}" \
    "submit-lead E2E")
  sl_msg=$(echo "$sl_resp" | jq -r '.message // empty' 2>/dev/null)
  sl_cust_created=$(echo "$sl_resp" | jq -r '.customerCreated // false' 2>/dev/null)
  assert_not_empty "$sl_msg" "submit-lead returns message"
  assert_not_empty "$(echo "$sl_resp" | jq -r '.customer.id // empty')" "submit-lead returns customer.id"
  assert_not_empty "$(echo "$sl_resp" | jq -r '.serviceRequest.id // empty')" "submit-lead returns serviceRequest.id"
  echo -e "  ${CYAN}${sl_msg}${NC}"
  echo -e "  ${CYAN}Customer created: ${sl_cust_created}${NC}"

  # ═══════════════ Phase 15: Direct HCP API checks ═══════════════
  phase "15" "DIRECT HCP API — JOB TYPES + SCHEDULE + LEAD SOURCE"

  echo -e "${YELLOW}── 15a: Job Types ──${NC}"
  local jt_resp jt_count
  jt_resp=$(call_hcp "GET" "/job_fields/job_types?page_size=50" "GET /job_fields/job_types")
  jt_count=$(echo "$jt_resp" | jq '.job_types | length' 2>/dev/null || echo 0)
  assert_gte "$jt_count" 1 "Has job types"
  echo -e "  ${CYAN}Job types:${NC}"
  echo "$jt_resp" | jq -r '.job_types[] | "    - \(.name) (\(.id))"' 2>/dev/null

  echo -e "${YELLOW}── 15b: Schedule Availability (business hours) ──${NC}"
  local sa_resp sa_days
  sa_resp=$(call_hcp "GET" "/company/schedule_availability" "GET /company/schedule_availability")
  sa_days=$(echo "$sa_resp" | jq '.daily_availabilities.data | length' 2>/dev/null || echo 0)
  assert_eq "$sa_days" "7" "Has 7 days of availability"
  echo -e "  ${CYAN}Buffer days: $(echo "$sa_resp" | jq '.availability_buffer_in_days' 2>/dev/null)${NC}"
  echo "$sa_resp" | jq -r '.daily_availabilities.data[] | "    - \(.day_name): \(.schedule_windows.data | map("\(.start_time)-\(.end_time)") | join(", ") // "closed")"' 2>/dev/null

  echo -e "${YELLOW}── 15c: Verify lead_source attribution ──${NC}"
  local leads_resp cs_lead_count
  leads_resp=$(call_hcp "GET" "/leads?page_size=10" "GET /leads (recent)")
  cs_lead_count=$(echo "$leads_resp" | jq '[.leads[] | select(.lead_source == "CallSaver")] | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Leads with lead_source=CallSaver: ${cs_lead_count}${NC}"
  assert_gte "$cs_lead_count" 1 "At least 1 lead has CallSaver attribution"

  echo -e "${YELLOW}── 15d: Verify customer lead_source ──${NC}"
  local custs_resp cs_cust_count
  custs_resp=$(call_hcp "GET" "/customers?page_size=20&sort_direction=desc" "GET /customers (recent)")
  cs_cust_count=$(echo "$custs_resp" | jq '[.customers[] | select(.lead_source == "CallSaver")] | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Customers with lead_source=CallSaver: ${cs_cust_count}${NC}"
  assert_gte "$cs_cust_count" 1 "At least 1 customer has CallSaver attribution"

  # ═══════════════ Results ═══════════════
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  RESULTS${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
  echo -e "  ${RED}Failed: ${FAILED}${NC}"
  echo -e "  Total:  $((PASSED + FAILED))"
  echo ""
  if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}⚠️  Some tests failed.${NC}"; exit 1
  else
    echo -e "${GREEN}🎉 All tests passed!${NC}"
  fi
}

# ─── Direct-only tests ─────────────────────────────────────

direct_tests() {
  phase "D1" "DIRECT HCP API — COMPANY"
  local comp comp_name comp_tz
  comp=$(call_hcp "GET" "/company" "GET /company")
  comp_name=$(echo "$comp" | jq -r '.name // empty' 2>/dev/null)
  comp_tz=$(echo "$comp" | jq -r '.time_zone // empty' 2>/dev/null)
  assert_not_empty "$comp_name" "Company name"; assert_not_empty "$comp_tz" "Timezone"
  echo -e "  ${CYAN}${comp_name} (${comp_tz})${NC}"

  phase "D2" "DIRECT HCP API — SERVICES + ZONES + JOB TYPES"
  local svcs svc_count zones zone_count jt jt_count
  svcs=$(call_hcp "GET" "/api/price_book/services?page_size=5" "GET price_book/services")
  svc_count=$(echo "$svcs" | jq '.data | length' 2>/dev/null || echo 0)
  assert_gte "$svc_count" 1 "Has services"

  zones=$(call_hcp "GET" "/service_zones?page_size=50" "GET service_zones")
  zone_count=$(echo "$zones" | jq '.service_zones | length' 2>/dev/null || echo 0)
  assert_gte "$zone_count" 0 "Zones array exists"

  jt=$(call_hcp "GET" "/job_fields/job_types?page_size=50" "GET job_types")
  jt_count=$(echo "$jt" | jq '.job_types | length' 2>/dev/null || echo 0)
  assert_gte "$jt_count" 1 "Has job types"

  phase "D3" "DIRECT HCP API — BOOKING WINDOWS"
  local bw bw_count
  bw=$(call_hcp "GET" "/company/schedule_availability/booking_windows?show_for_days=3&service_duration=60" "GET booking_windows")
  bw_count=$(echo "$bw" | jq '.booking_windows | length' 2>/dev/null || echo 0)
  assert_gte "$bw_count" 1 "Has booking windows"
  echo -e "  ${CYAN}Windows: ${bw_count} (3-day range, 60min duration)${NC}"

  phase "D4" "DIRECT HCP API — SCHEDULE AVAILABILITY"
  local sa sa_days
  sa=$(call_hcp "GET" "/company/schedule_availability" "GET schedule_availability")
  sa_days=$(echo "$sa" | jq '.daily_availabilities.data | length' 2>/dev/null || echo 0)
  assert_eq "$sa_days" "7" "Has 7 days"

  echo ""
  echo -e "${BLUE}  Direct: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
}

# ─── Voice Agent Test Guide ────────────────────────────────

guide() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  VOICE AGENT TEST GUIDE (HOUSECALL PRO)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  cat <<'EOF'

Start voice agent in console mode:
  cd ~/callsaver-api/livekit-python && source .venv/bin/activate
  API_URL=http://localhost:3000 CONSOLE_TEST_LOCATION_ID=cmloxy8vs000ar801ma3wz6s3 python server.py console

Scenario A: NEW CALLER — full flow
  - Call from unknown number, give name + Santa Cruz address (95065)
  - Agent: create customer → create property → check service area → match service → create request
  - If autoScheduleAssessment=true: check availability → offer times → schedule

Scenario B: RETURNING CALLER — check status
  - Use +15552000001 (Maria Garcia)
  - "I'd like to check on my service request" → agent: get-requests

Scenario C: OUT OF SERVICE AREA
  - Give NYC address (zip 10001)
  - Agent: check service area → politely decline

Scenario D: ASK ABOUT SERVICES
  - "What services do you offer?"
  - Agent should give brief summary, NOT read all 57+ services

Scenario E: RETURNING CALLER — schedule check
  - Use +15552000002 (James Wilson)
  - "What do I have coming up?" → agent: get-client-schedule

Scenario F: RETURNING CALLER — reschedule
  - Use +15552000003 (Sarah Chen) — has assessment
  - "Can I reschedule?" → check-availability → reschedule-assessment
EOF
}

# ─── Cleanup ──────────────────────────────────────────────

cleanup() {
  phase "CLEANUP" "DELETE SEEDED RESOURCES FROM HCP"

  # Delete seeded customers by phone number lookup
  # Deleting a customer in HCP cascades to their addresses and leads
  local phones=("$SEED_PHONE_1" "$SEED_PHONE_2" "$SEED_PHONE_3" "$SEED_PHONE_4" "$NEW_CALLER_PHONE")
  local labels=("Maria Garcia" "James Wilson" "Sarah Chen" "Robert Johnson" "Test LeadV2")
  local deleted=0 skipped=0 failed=0

  for i in "${!phones[@]}"; do
    local phone="${phones[$i]}" label="${labels[$i]}"
    echo -e "${YELLOW}── Cleaning up: ${label} (${phone}) ──${NC}"

    # Look up customer by phone
    local search_resp cust_id
    search_resp=$(curl -s -m 15 "${HCP_BASE_URL}/customers?phone=${phone}&page_size=5" \
      -H "Accept: application/json" -H "Authorization: Token ${HCP_API_KEY}")
    
    # Iterate all matching customers (there may be duplicates from previous runs)
    local cust_ids
    cust_ids=$(echo "$search_resp" | jq -r '.customers[]?.id // empty' 2>/dev/null)
    
    if [ -z "$cust_ids" ]; then
      echo -e "  ${CYAN}⏭️  No customer found for ${phone}${NC}"
      ((skipped++)) || true
      continue
    fi

    for cust_id in $cust_ids; do
      # Delete any leads associated with this customer first
      local leads_resp lead_ids
      leads_resp=$(curl -s -m 15 "${HCP_BASE_URL}/leads?customer_id=${cust_id}&page_size=50" \
        -H "Accept: application/json" -H "Authorization: Token ${HCP_API_KEY}")
      lead_ids=$(echo "$leads_resp" | jq -r '.leads[]?.id // empty' 2>/dev/null)
      for lid in $lead_ids; do
        local del_lead_code
        del_lead_code=$(curl -s -o /dev/null -w "%{http_code}" -m 15 -X DELETE \
          "${HCP_BASE_URL}/leads/${lid}" \
          -H "Authorization: Token ${HCP_API_KEY}")
        if [[ "$del_lead_code" -ge 200 && "$del_lead_code" -lt 300 ]]; then
          echo -e "  ${GREEN}✅ Deleted lead ${lid}${NC}"
        else
          echo -e "  ${YELLOW}⚠️  Lead ${lid} delete returned HTTP ${del_lead_code} (may not support DELETE)${NC}"
        fi
      done

      # Delete the customer
      local del_code
      del_code=$(curl -s -o /dev/null -w "%{http_code}" -m 15 -X DELETE \
        "${HCP_BASE_URL}/customers/${cust_id}" \
        -H "Authorization: Token ${HCP_API_KEY}")
      if [[ "$del_code" -ge 200 && "$del_code" -lt 300 ]]; then
        echo -e "  ${GREEN}✅ Deleted customer ${cust_id} (${label})${NC}"
        ((deleted++)) || true
      else
        echo -e "  ${RED}❌ Failed to delete customer ${cust_id} (HTTP ${del_code})${NC}"
        ((failed++)) || true
      fi
    done
  done

  # Clean up state file
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    echo -e "  ${GREEN}✅ Removed state file${NC}"
  fi

  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Deleted: ${deleted}${NC} | ${CYAN}Skipped: ${skipped}${NC} | ${RED}Failed: ${failed}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ─── Main ──────────────────────────────────────────────────

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    seed)    preflight; seed ;;
    test)    run_tests ;;
    all)     preflight; seed; run_tests; guide ;;
    direct)  direct_tests ;;
    guide)   guide ;;
    cleanup) cleanup ;;
    *)       echo "Usage: $0 {seed|test|all|direct|guide|cleanup}"; exit 1 ;;
  esac
}

main "$@"
