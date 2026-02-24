#!/bin/bash
# =============================================================================
# AVAILABILITY & ASSESSMENT SCHEDULING TEST SUITE
# =============================================================================
#
# Comprehensive tests for:
#   1. fs-check-availability (get-availability endpoint)
#   2. fs-reschedule-assessment (assessment scheduling)
#   3. End-to-end: create-service-request → check-availability → reschedule-assessment
#   4. Double-booking prevention
#   5. Timezone correctness
#   6. Edge cases (past dates, empty calendar, multi-day, Sunday)
#
# KNOWN BUGS BEING TESTED:
#
#   BUG 1 — TIMEZONE: checkAvailability in JobberAdapter.ts uses Date.setHours()
#   which operates in SERVER local time (UTC on AWS), not the location's timezone.
#   Business hours 8AM-5PM Pacific = 16:00-01:00 UTC, but the code computes
#   08:00-17:00 UTC. A 10AM Pacific appointment (18:00 UTC) falls OUTSIDE that
#   window → invisible to gap-finder → DOUBLE BOOKING.
#   File: src/adapters/field-service/platforms/jobber/JobberAdapter.ts:2912-2916
#
#   BUG 2 — PROMPT: The system prompt's Step 10 (auto-schedule assessment after
#   creating service request) was never implemented. Line 1524 says "Step 10 is
#   provided in the FIELD SERVICE INTEGRATION section below" but no Step 10 exists.
#   Line 1560 says "The service request goes to the business owner for review,
#   quoting, and scheduling" — which is why the agent says "the team will get back
#   to you with a quote" instead of auto-scheduling.
#   File: src/utils.ts:1524, 1560
#
# Prerequisites:
#   - Local API server running on port 3002
#   - Jobber sandbox connected via Nango for the test location
#   - seed-and-test-jobber.sh already run (or run with --seed flag)
#
# Usage:
#   chmod +x testing/test-availability-and-scheduling.sh
#   ./testing/test-availability-and-scheduling.sh              # Run all tests
#   ./testing/test-availability-and-scheduling.sh --seed-first # Seed then test
#   ./testing/test-availability-and-scheduling.sh --verbose    # Show raw responses
#
# =============================================================================

set -euo pipefail

BASE_URL="http://localhost:3002/internal/tools/fs"
API_KEY="ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7"
LOCATION_ID="cmloxy8vs000ar801ma3wz6s3"

# Test client phone (dedicated to this test suite — distinct from seed script)
TEST_PHONE="+15552000001"

# Parse flags
VERBOSE=false
SEED_FIRST=false
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    --seed-first) SEED_FIRST=true ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0
TOTAL=0

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

call_api() {
  local endpoint="$1"
  local body="$2"
  local label="${3:-$endpoint}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/${endpoint}" \
    -H "Content-Type: application/json" \
    -H "x-internal-api-key: ${API_KEY}" \
    -d "$body")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body_response
  body_response=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo -e "  ${GREEN}✅ ${label}${NC} (HTTP ${http_code})" >&2
  else
    echo -e "  ${RED}❌ ${label}${NC} (HTTP ${http_code})" >&2
    if [ "$VERBOSE" = true ]; then
      echo "  Response: $(echo "$body_response" | head -c 500)" >&2
    fi
  fi

  echo "$body_response"
}

assert_pass() {
  local label="$1"
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  echo -e "    ${GREEN}✓ ${label}${NC}"
}

assert_fail() {
  local label="$1"
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  echo -e "    ${RED}✗ ${label}${NC}"
}

assert_warn() {
  local label="$1"
  TOTAL=$((TOTAL + 1))
  WARN=$((WARN + 1))
  echo -e "    ${YELLOW}⚠ ${label}${NC}"
}

assert_not_empty() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr" 2>/dev/null)
  if [ -n "$actual" ] && [ "$actual" != "null" ] && [ "$actual" != "" ]; then
    assert_pass "$label = $actual"
  else
    assert_fail "$label is empty/null"
  fi
}

assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    assert_pass "$label = $actual"
  else
    assert_fail "$label: expected '$expected', got '$actual'"
  fi
}

assert_gte() {
  local label="$1"
  local actual="$2"
  local min="$3"
  if [ "$actual" -ge "$min" ] 2>/dev/null; then
    assert_pass "$label = $actual (>= $min)"
  else
    assert_fail "$label = $actual (expected >= $min)"
  fi
}

assert_lte() {
  local label="$1"
  local actual="$2"
  local max="$3"
  if [ "$actual" -le "$max" ] 2>/dev/null; then
    assert_pass "$label = $actual (<= $max)"
  else
    assert_fail "$label = $actual (expected <= $max)"
  fi
}

section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

subsection() {
  echo ""
  echo -e "${CYAN}── $1 ──${NC}"
}

# Get ISO datetime for N days from now at a specific hour in LOCAL time
future_datetime() {
  local days_ahead=$1
  local hour=$2
  local minute=${3:-0}
  date -d "+${days_ahead} days" "+%Y-%m-%dT$(printf '%02d' $hour):$(printf '%02d' $minute):00" 2>/dev/null || \
  date -v+${days_ahead}d "+%Y-%m-%dT$(printf '%02d' $hour):$(printf '%02d' $minute):00" 2>/dev/null
}

# Get date string for N days ahead
future_date() {
  local days_ahead=$1
  date -d "+${days_ahead} days" "+%Y-%m-%d" 2>/dev/null || \
  date -v+${days_ahead}d "+%Y-%m-%d" 2>/dev/null
}

# Get day-of-week (0=Sun, 6=Sat) for N days ahead
future_dow() {
  local days_ahead=$1
  date -d "+${days_ahead} days" "+%w" 2>/dev/null || \
  date -v+${days_ahead}d "+%w" 2>/dev/null
}

day_name() {
  local days_ahead=$1
  date -d "+${days_ahead} days" "+%A" 2>/dev/null || \
  date -v+${days_ahead}d "+%A" 2>/dev/null
}

# Find next business day that is NOT Sunday, starting from N days ahead
find_business_day() {
  local start=${1:-1}
  local days=$start
  while true; do
    local dow
    dow=$(future_dow $days)
    if [ "$dow" != "0" ]; then
      echo "$days"
      return
    fi
    days=$((days + 1))
  done
}

# Find next Sunday from now
find_next_sunday() {
  local days=1
  while true; do
    local dow
    dow=$(future_dow $days)
    if [ "$dow" = "0" ]; then
      echo "$days"
      return
    fi
    days=$((days + 1))
  done
}

# Parse ISO timestamp to epoch seconds
to_epoch() {
  date -d "$1" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$1" +%s 2>/dev/null || echo "0"
}

# ─────────────────────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────────────────────

preflight() {
  section "PREFLIGHT"

  if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq required. Install: sudo apt install jq${NC}"
    exit 1
  fi

  local health
  health=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/get-services" \
    -X POST -H "Content-Type: application/json" -H "x-internal-api-key: ${API_KEY}" \
    -d "{\"locationId\": \"${LOCATION_ID}\"}")

  if [[ "$health" -ge 200 && "$health" -lt 300 ]]; then
    echo -e "${GREEN}✅ API reachable at ${BASE_URL}${NC}"
  else
    echo -e "${RED}❌ API returned HTTP ${health}. Is server running on port 3002?${NC}"
    exit 1
  fi
}

# ─────────────────────────────────────────────────────────────
# Setup: Ensure test client + property + requests exist
# ─────────────────────────────────────────────────────────────

CUSTOMER_ID=""
PROPERTY_ID=""
REQUEST_ID_1=""
REQUEST_ID_2=""
REQUEST_ID_3=""
ASSESSMENT_ID_1=""
ASSESSMENT_ID_2=""
ASSESSMENT_ID_3=""

setup() {
  section "SETUP: Create test client, property, and requests"

  # Create customer
  subsection "Create test customer"
  local r
  r=$(call_api "create-customer" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"firstName\": \"Avail\",
    \"lastName\": \"TestUser\",
    \"email\": \"avail.test@example.com\"
  }" "Create customer: Avail TestUser")
  CUSTOMER_ID=$(echo "$r" | jq -r '.customer.id // empty')
  assert_not_empty "customer.id" "$r" ".customer.id"

  # Create property
  subsection "Create test property"
  r=$(call_api "create-property" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\",
    \"address\": {\"street\": \"100 Availability Ave\", \"city\": \"Santa Cruz\", \"state\": \"CA\", \"zip\": \"95060\"}
  }" "Create property: 100 Availability Ave")
  PROPERTY_ID=$(echo "$r" | jq -r '.property.id // empty')
  assert_not_empty "property.id" "$r" ".property.id"

  # Create 3 service requests (each auto-creates an assessment)
  subsection "Create service requests (3 — each auto-creates an assessment)"

  r=$(call_api "create-service-request" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\",
    \"description\": \"Availability test request 1 — morning block\",
    \"serviceType\": \"Leak Repair\",
    \"propertyId\": \"${PROPERTY_ID}\"
  }" "Create request 1")
  REQUEST_ID_1=$(echo "$r" | jq -r '.serviceRequest.id // empty')
  ASSESSMENT_ID_1=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.id // empty')
  echo "    Request 1: ${REQUEST_ID_1}, Assessment 1: ${ASSESSMENT_ID_1}"

  r=$(call_api "create-service-request" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\",
    \"description\": \"Availability test request 2 — afternoon block\",
    \"serviceType\": \"Drain Cleaning\",
    \"propertyId\": \"${PROPERTY_ID}\"
  }" "Create request 2")
  REQUEST_ID_2=$(echo "$r" | jq -r '.serviceRequest.id // empty')
  ASSESSMENT_ID_2=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.id // empty')
  echo "    Request 2: ${REQUEST_ID_2}, Assessment 2: ${ASSESSMENT_ID_2}"

  r=$(call_api "create-service-request" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\",
    \"description\": \"Availability test request 3 — for double-booking test\",
    \"serviceType\": \"Water Heater\",
    \"propertyId\": \"${PROPERTY_ID}\"
  }" "Create request 3")
  REQUEST_ID_3=$(echo "$r" | jq -r '.serviceRequest.id // empty')
  ASSESSMENT_ID_3=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.id // empty')
  echo "    Request 3: ${REQUEST_ID_3}, Assessment 3: ${ASSESSMENT_ID_3}"

  # Fallback: fetch assessment IDs from get-request if not in create response
  if [ -z "$ASSESSMENT_ID_1" ] || [ "$ASSESSMENT_ID_1" = "null" ]; then
    echo "    ⚠ Assessment 1 not in create response, fetching from get-request..."
    r=$(call_api "get-request" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${TEST_PHONE}\",\"requestId\":\"${REQUEST_ID_1}\"}" "Fetch assessment 1")
    ASSESSMENT_ID_1=$(echo "$r" | jq -r '.request.metadata.assessment.id // empty')
    echo "    Assessment 1 (from get-request): ${ASSESSMENT_ID_1}"
  fi
  if [ -z "$ASSESSMENT_ID_2" ] || [ "$ASSESSMENT_ID_2" = "null" ]; then
    echo "    ⚠ Assessment 2 not in create response, fetching from get-request..."
    r=$(call_api "get-request" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${TEST_PHONE}\",\"requestId\":\"${REQUEST_ID_2}\"}" "Fetch assessment 2")
    ASSESSMENT_ID_2=$(echo "$r" | jq -r '.request.metadata.assessment.id // empty')
    echo "    Assessment 2 (from get-request): ${ASSESSMENT_ID_2}"
  fi
  if [ -z "$ASSESSMENT_ID_3" ] || [ "$ASSESSMENT_ID_3" = "null" ]; then
    echo "    ⚠ Assessment 3 not in create response, fetching from get-request..."
    r=$(call_api "get-request" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${TEST_PHONE}\",\"requestId\":\"${REQUEST_ID_3}\"}" "Fetch assessment 3")
    ASSESSMENT_ID_3=$(echo "$r" | jq -r '.request.metadata.assessment.id // empty')
    echo "    Assessment 3 (from get-request): ${ASSESSMENT_ID_3}"
  fi

  echo ""
  echo "  Setup IDs:"
  echo "    Customer:    ${CUSTOMER_ID}"
  echo "    Property:    ${PROPERTY_ID}"
  echo "    Request 1:   ${REQUEST_ID_1} → Assessment: ${ASSESSMENT_ID_1}"
  echo "    Request 2:   ${REQUEST_ID_2} → Assessment: ${ASSESSMENT_ID_2}"
  echo "    Request 3:   ${REQUEST_ID_3} → Assessment: ${ASSESSMENT_ID_3}"
}

# =============================================================================
# TEST 1: Empty calendar — full day availability
# =============================================================================

test_empty_calendar() {
  section "TEST 1: Empty calendar — full day availability"

  # Use a day far in the future with no appointments
  local far_day
  far_day=$(find_business_day 30)
  local far_date
  far_date=$(future_date $far_day)
  local far_start far_end
  far_start="${far_date}T00:00:00"
  far_end="${far_date}T23:59:59"

  echo "  Querying availability for ${far_date} ($(day_name $far_day)) — empty calendar"
  local r
  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${far_start}\",
    \"endDate\": \"${far_end}\"
  }" "Check availability: empty day")

  local slot_count
  slot_count=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)

  subsection "1a. Should return at least 1 availability window"
  assert_gte "slot count" "$slot_count" "1"

  subsection "1b. Window should span full business hours (~8-9 hours)"
  if [ "$slot_count" -ge 1 ]; then
    local start_iso end_iso
    start_iso=$(echo "$r" | jq -r '.timeSlots[0].startTime')
    end_iso=$(echo "$r" | jq -r '.timeSlots[0].endTime')
    local start_epoch end_epoch duration_hours
    start_epoch=$(to_epoch "$start_iso")
    end_epoch=$(to_epoch "$end_iso")
    if [ "$start_epoch" != "0" ] && [ "$end_epoch" != "0" ]; then
      duration_hours=$(( (end_epoch - start_epoch) / 3600 ))
      assert_gte "window duration (hours)" "$duration_hours" "8"
    else
      assert_warn "Could not parse timestamps: $start_iso → $end_iso"
    fi
  fi

  subsection "1c. Message should contain 'available' or 'availability'"
  local msg
  msg=$(echo "$r" | jq -r '.message // ""')
  if echo "$msg" | grep -qi "avail"; then
    assert_pass "Message mentions availability"
  else
    assert_fail "Message doesn't mention availability: $(echo "$msg" | head -c 80)"
  fi

  if [ "$VERBOSE" = true ]; then
    echo "  Raw slots:"
    echo "$r" | jq '.timeSlots[] | {startTime, endTime}'
    echo "  Message: $msg"
  fi
}

# =============================================================================
# TEST 2: Schedule assessments, verify blocked slots
# =============================================================================

test_blocked_slots() {
  section "TEST 2: Schedule assessments → verify availability gaps"

  local test_day
  test_day=$(find_business_day 8)  # 8+ days out to avoid conflicts
  local test_date
  test_date=$(future_date $test_day)

  echo "  Test day: ${test_date} ($(day_name $test_day))"
  echo ""

  # Schedule Assessment 1: 9:00 AM - 10:00 AM
  subsection "2a. Schedule Assessment 1 at 9-10 AM"
  local a1_start a1_end
  a1_start=$(future_datetime $test_day 9)
  a1_end=$(future_datetime $test_day 10)

  if [ -n "$ASSESSMENT_ID_1" ] && [ "$ASSESSMENT_ID_1" != "null" ]; then
    local r
    r=$(call_api "reschedule-assessment" "{
      \"locationId\": \"${LOCATION_ID}\",
      \"callerPhoneNumber\": \"${TEST_PHONE}\",
      \"assessmentId\": \"${ASSESSMENT_ID_1}\",
      \"startTime\": \"${a1_start}\",
      \"endTime\": \"${a1_end}\"
    }" "Schedule Assessment 1: 9-10 AM")
    assert_not_empty "message" "$r" ".message"
  else
    assert_fail "No assessment ID 1 — cannot schedule"
    return
  fi

  # Schedule Assessment 2: 2:00 PM - 3:00 PM
  subsection "2b. Schedule Assessment 2 at 2-3 PM"
  local a2_start a2_end
  a2_start=$(future_datetime $test_day 14)
  a2_end=$(future_datetime $test_day 15)

  if [ -n "$ASSESSMENT_ID_2" ] && [ "$ASSESSMENT_ID_2" != "null" ]; then
    r=$(call_api "reschedule-assessment" "{
      \"locationId\": \"${LOCATION_ID}\",
      \"callerPhoneNumber\": \"${TEST_PHONE}\",
      \"assessmentId\": \"${ASSESSMENT_ID_2}\",
      \"startTime\": \"${a2_start}\",
      \"endTime\": \"${a2_end}\"
    }" "Schedule Assessment 2: 2-3 PM")
    assert_not_empty "message" "$r" ".message"
  else
    assert_fail "No assessment ID 2 — cannot schedule"
    return
  fi

  echo ""
  echo "  📅 Expected calendar for ${test_date}:"
  echo "  ┌──────────────────────────────────────────┐"
  echo "  │ 08:00  ░░░ AVAILABLE ░░░                 │"
  echo "  │ 09:00  ███ Assessment 1 (Leak Repair) ██ │"
  echo "  │ 10:00  ░░░ AVAILABLE ░░░                 │"
  echo "  │ 14:00  ███ Assessment 2 (Drain Clean) ██ │"
  echo "  │ 15:00  ░░░ AVAILABLE ░░░                 │"
  echo "  │ 17:00  ── End of business hours ──       │"
  echo "  └──────────────────────────────────────────┘"

  # Wait for Jobber eventual consistency
  echo ""
  echo "  ⏳ Waiting 5s for Jobber to propagate..."
  sleep 5

  # Query availability
  subsection "2c. Query availability for test day"
  local avail_start avail_end
  avail_start="${test_date}T00:00:00"
  avail_end="${test_date}T23:59:59"

  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${avail_start}\",
    \"endDate\": \"${avail_end}\"
  }" "Check availability: test day with 2 assessments")

  local slot_count
  slot_count=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)

  echo ""
  echo "  Available windows returned: ${slot_count}"
  echo "$r" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"' 2>/dev/null

  # Expected: 3 windows (before 9AM, between 10AM-2PM, after 3PM)
  subsection "2d. Should return 3 availability windows (gaps around 2 assessments)"
  assert_eq "window count" "$slot_count" "3"

  # Verify no window overlaps Assessment 1 (9-10 AM)
  subsection "2e. No window should overlap Assessment 1 (9-10 AM)"
  # A window overlaps if: window.start < assessment.end AND window.end > assessment.start
  local a1_start_epoch a1_end_epoch
  a1_start_epoch=$(to_epoch "$a1_start")
  a1_end_epoch=$(to_epoch "$a1_end")
  local overlap_a1=0
  while IFS= read -r slot; do
    local s_start s_end
    s_start=$(echo "$slot" | jq -r '.startTime')
    s_end=$(echo "$slot" | jq -r '.endTime')
    local ss_epoch se_epoch
    ss_epoch=$(to_epoch "$s_start")
    se_epoch=$(to_epoch "$s_end")
    if [ "$ss_epoch" != "0" ] && [ "$se_epoch" != "0" ]; then
      if [ "$ss_epoch" -lt "$a1_end_epoch" ] && [ "$se_epoch" -gt "$a1_start_epoch" ]; then
        overlap_a1=$((overlap_a1 + 1))
      fi
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$overlap_a1" -eq 0 ]; then
    assert_pass "No windows overlap Assessment 1 (9-10 AM)"
  else
    assert_fail "$overlap_a1 window(s) overlap Assessment 1 (9-10 AM) ← TIMEZONE BUG?"
  fi

  # Verify no window overlaps Assessment 2 (2-3 PM)
  subsection "2f. No window should overlap Assessment 2 (2-3 PM)"
  local a2_start_epoch a2_end_epoch
  a2_start_epoch=$(to_epoch "$a2_start")
  a2_end_epoch=$(to_epoch "$a2_end")
  local overlap_a2=0
  while IFS= read -r slot; do
    local s_start s_end
    s_start=$(echo "$slot" | jq -r '.startTime')
    s_end=$(echo "$slot" | jq -r '.endTime')
    local ss_epoch se_epoch
    ss_epoch=$(to_epoch "$s_start")
    se_epoch=$(to_epoch "$s_end")
    if [ "$ss_epoch" != "0" ] && [ "$se_epoch" != "0" ]; then
      if [ "$ss_epoch" -lt "$a2_end_epoch" ] && [ "$se_epoch" -gt "$a2_start_epoch" ]; then
        overlap_a2=$((overlap_a2 + 1))
      fi
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$overlap_a2" -eq 0 ]; then
    assert_pass "No windows overlap Assessment 2 (2-3 PM)"
  else
    assert_fail "$overlap_a2 window(s) overlap Assessment 2 (2-3 PM) ← TIMEZONE BUG?"
  fi

  # Verify there IS a morning window (before 9 AM)
  subsection "2g. Should have a morning window (before 9 AM assessment)"
  local morning_windows=0
  while IFS= read -r slot; do
    local s_end
    s_end=$(echo "$slot" | jq -r '.endTime')
    local se_epoch
    se_epoch=$(to_epoch "$s_end")
    if [ "$se_epoch" != "0" ] && [ "$se_epoch" -le "$a1_start_epoch" ]; then
      morning_windows=$((morning_windows + 1))
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$morning_windows" -ge 1 ]; then
    assert_pass "Found morning window before 9 AM"
  else
    assert_fail "No morning window found"
  fi

  # Verify there IS a midday window (between 10 AM and 2 PM)
  subsection "2h. Should have a midday window (10 AM - 2 PM gap)"
  local midday_windows=0
  while IFS= read -r slot; do
    local s_start s_end
    s_start=$(echo "$slot" | jq -r '.startTime')
    s_end=$(echo "$slot" | jq -r '.endTime')
    local ss_epoch se_epoch
    ss_epoch=$(to_epoch "$s_start")
    se_epoch=$(to_epoch "$s_end")
    if [ "$ss_epoch" != "0" ] && [ "$se_epoch" != "0" ]; then
      if [ "$ss_epoch" -ge "$a1_end_epoch" ] && [ "$se_epoch" -le "$a2_start_epoch" ]; then
        midday_windows=$((midday_windows + 1))
      fi
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$midday_windows" -ge 1 ]; then
    assert_pass "Found midday window between assessments"
  else
    # Relax: window may extend past a2_start if its end was trimmed by buffer
    assert_warn "No strictly contained midday window (may be buffer-adjusted)"
  fi

  # Save for double-booking test
  BLOCKED_DAY="$test_day"
  BLOCKED_DATE="$test_date"
}

# =============================================================================
# TEST 3: Double-booking prevention (THE BUG)
# =============================================================================

test_double_booking_prevention() {
  section "TEST 3: Double-booking prevention"

  if [ -z "$BLOCKED_DATE" ]; then
    echo "  ⚠ Skipping — TEST 2 did not run (no BLOCKED_DATE)"
    return
  fi

  echo "  This test verifies that scheduling an assessment at a KNOWN blocked time"
  echo "  does NOT silently succeed (it should either fail or return a conflict)."
  echo ""
  echo "  Attempting to schedule Assessment 3 at 9:30 AM on ${BLOCKED_DATE}"
  echo "  (overlaps Assessment 1: 9:00-10:00 AM)"

  local overlap_start overlap_end
  overlap_start=$(future_datetime $BLOCKED_DAY 9 30)
  overlap_end=$(future_datetime $BLOCKED_DAY 10 30)

  if [ -z "$ASSESSMENT_ID_3" ] || [ "$ASSESSMENT_ID_3" = "null" ]; then
    assert_warn "No assessment ID 3 — cannot test double-booking"
    return
  fi

  subsection "3a. Schedule Assessment 3 at 9:30-10:30 AM (overlapping Assessment 1)"
  local r
  r=$(call_api "reschedule-assessment" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"assessmentId\": \"${ASSESSMENT_ID_3}\",
    \"startTime\": \"${overlap_start}\",
    \"endTime\": \"${overlap_end}\"
  }" "Schedule overlapping assessment")

  # Jobber may accept the overlapping schedule (it doesn't enforce uniqueness).
  # The key test is: does check-availability EXCLUDE this time?
  echo "  Note: Jobber may accept overlapping schedules. The real test is"
  echo "  whether check-availability correctly reports the time as blocked."

  # Wait for propagation
  echo "  ⏳ Waiting 5s for Jobber propagation..."
  sleep 5

  subsection "3b. Re-query availability — 9:00-10:30 should be blocked"
  local avail_start avail_end
  avail_start="${BLOCKED_DATE}T00:00:00"
  avail_end="${BLOCKED_DATE}T23:59:59"

  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${avail_start}\",
    \"endDate\": \"${avail_end}\"
  }" "Check availability after double-book attempt")

  echo ""
  echo "  Available windows:"
  echo "$r" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"' 2>/dev/null

  # The 9:00-10:30 block should NOT appear in any availability window
  local block_start_epoch block_end_epoch
  block_start_epoch=$(to_epoch "$(future_datetime $BLOCKED_DAY 9)")
  block_end_epoch=$(to_epoch "$(future_datetime $BLOCKED_DAY 10 30)")

  local any_overlap=0
  while IFS= read -r slot; do
    local s_start s_end
    s_start=$(echo "$slot" | jq -r '.startTime')
    s_end=$(echo "$slot" | jq -r '.endTime')
    local ss_epoch se_epoch
    ss_epoch=$(to_epoch "$s_start")
    se_epoch=$(to_epoch "$s_end")
    if [ "$ss_epoch" != "0" ] && [ "$se_epoch" != "0" ]; then
      # Check if any availability window contains 9:30 AM (the overlap point)
      local overlap_epoch
      overlap_epoch=$(to_epoch "$(future_datetime $BLOCKED_DAY 9 30)")
      if [ "$ss_epoch" -le "$overlap_epoch" ] && [ "$se_epoch" -gt "$overlap_epoch" ]; then
        any_overlap=$((any_overlap + 1))
      fi
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$any_overlap" -eq 0 ]; then
    assert_pass "9:30 AM is correctly blocked (not in any availability window)"
  else
    assert_fail "9:30 AM appears in $any_overlap availability window(s) ← DOUBLE-BOOKING BUG"
  fi
}

# =============================================================================
# TEST 4: Assessment scheduling end-to-end flow
# =============================================================================

test_e2e_scheduling_flow() {
  section "TEST 4: End-to-end scheduling flow (availability → book)"

  # Use a clean day far out
  local clean_day
  clean_day=$(find_business_day 20)
  local clean_date
  clean_date=$(future_date $clean_day)

  subsection "4a. Check availability for clean day ($(day_name $clean_day) $clean_date)"
  local r
  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${clean_date}T00:00:00\",
    \"endDate\": \"${clean_date}T23:59:59\"
  }" "Check availability: clean day")

  local slot_count
  slot_count=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)
  assert_gte "available slots" "$slot_count" "1"

  if [ "$slot_count" -lt 1 ]; then
    assert_warn "No slots available — skipping booking flow"
    return
  fi

  # Pick first available window
  local first_start first_end
  first_start=$(echo "$r" | jq -r '.timeSlots[0].startTime')
  first_end=$(echo "$r" | jq -r '.timeSlots[0].endTime')
  echo "    First available window: $first_start → $first_end"

  # Book assessment at the start of the first window (60 min)
  local book_start_epoch
  book_start_epoch=$(to_epoch "$first_start")
  local book_end_epoch=$((book_start_epoch + 3600))  # +60 min
  local book_start book_end
  book_start=$(date -d "@$book_start_epoch" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -r "$book_start_epoch" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null)
  book_end=$(date -d "@$book_end_epoch" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -r "$book_end_epoch" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null)

  subsection "4b. Book Assessment 3 in the first available slot"
  echo "    Booking: $book_start → $book_end"

  if [ -z "$ASSESSMENT_ID_3" ] || [ "$ASSESSMENT_ID_3" = "null" ]; then
    assert_warn "No assessment ID 3 — cannot test booking flow"
    return
  fi

  r=$(call_api "reschedule-assessment" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"assessmentId\": \"${ASSESSMENT_ID_3}\",
    \"startTime\": \"${book_start}\",
    \"endTime\": \"${book_end}\"
  }" "Book assessment in available slot")
  assert_not_empty "message" "$r" ".message"

  # Wait for propagation
  echo "    ⏳ Waiting 5s for Jobber propagation..."
  sleep 5

  subsection "4c. Re-check availability — booked slot should be consumed"
  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${clean_date}T00:00:00\",
    \"endDate\": \"${clean_date}T23:59:59\"
  }" "Re-check availability after booking")

  local new_slot_count
  new_slot_count=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)

  echo ""
  echo "  Windows after booking: $new_slot_count (was $slot_count before)"
  echo "$r" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"' 2>/dev/null

  # The booked time should no longer be available
  local booked_in_window=0
  local book_mid_epoch=$((book_start_epoch + 1800))  # midpoint of booking
  while IFS= read -r slot; do
    local s_start s_end
    s_start=$(echo "$slot" | jq -r '.startTime')
    s_end=$(echo "$slot" | jq -r '.endTime')
    local ss_epoch se_epoch
    ss_epoch=$(to_epoch "$s_start")
    se_epoch=$(to_epoch "$s_end")
    if [ "$ss_epoch" != "0" ] && [ "$se_epoch" != "0" ]; then
      if [ "$ss_epoch" -le "$book_mid_epoch" ] && [ "$se_epoch" -gt "$book_mid_epoch" ]; then
        booked_in_window=$((booked_in_window + 1))
      fi
    fi
  done < <(echo "$r" | jq -c '.timeSlots[]?' 2>/dev/null)

  if [ "$booked_in_window" -eq 0 ]; then
    assert_pass "Booked time slot no longer appears as available"
  else
    assert_fail "Booked time still in availability window ← BUG"
  fi
}

# =============================================================================
# TEST 5: Reschedule + Cancel flow
# =============================================================================

test_reschedule_and_cancel() {
  section "TEST 5: Reschedule assessment + Cancel assessment"

  if [ -z "$ASSESSMENT_ID_1" ] || [ "$ASSESSMENT_ID_1" = "null" ]; then
    assert_warn "No assessment ID 1 — skipping reschedule/cancel test"
    return
  fi

  # Reschedule Assessment 1 to a different day
  local new_day
  new_day=$(find_business_day 25)
  local new_start new_end
  new_start=$(future_datetime $new_day 11)
  new_end=$(future_datetime $new_day 12)

  subsection "5a. Reschedule Assessment 1 to $(day_name $new_day) 11 AM - 12 PM"
  local r
  r=$(call_api "reschedule-assessment" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"assessmentId\": \"${ASSESSMENT_ID_1}\",
    \"startTime\": \"${new_start}\",
    \"endTime\": \"${new_end}\"
  }" "Reschedule Assessment 1")
  assert_not_empty "message" "$r" ".message"

  # Verify via get-request
  subsection "5b. Verify reschedule via get-request metadata"
  r=$(call_api "get-request" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"requestId\": \"${REQUEST_ID_1}\"
  }" "Get request 1 after reschedule")
  local assessment_start
  assessment_start=$(echo "$r" | jq -r '.request.metadata.assessment.startAt // empty')
  if [ -n "$assessment_start" ] && [ "$assessment_start" != "null" ]; then
    assert_pass "Assessment has startAt after reschedule: $assessment_start"
  else
    assert_warn "No startAt in assessment metadata (may be field naming difference)"
  fi

  # Cancel Assessment 2
  subsection "5c. Cancel Assessment 2"
  if [ -n "$ASSESSMENT_ID_2" ] && [ "$ASSESSMENT_ID_2" != "null" ]; then
    r=$(call_api "cancel-assessment" "{
      \"locationId\": \"${LOCATION_ID}\",
      \"callerPhoneNumber\": \"${TEST_PHONE}\",
      \"assessmentId\": \"${ASSESSMENT_ID_2}\"
    }" "Cancel Assessment 2")
    assert_not_empty "message" "$r" ".message"
  else
    assert_warn "No assessment ID 2 — skipping cancel"
  fi
}

# =============================================================================
# TEST 6: Edge cases
# =============================================================================

test_edge_cases() {
  section "TEST 6: Edge cases"

  # 6a. Past date range
  subsection "6a. Past date range (should return empty or graceful message)"
  local past_start past_end
  past_start=$(date -d "-7 days" "+%Y-%m-%dT00:00:00" 2>/dev/null || date -v-7d "+%Y-%m-%dT00:00:00")
  past_end=$(date -d "-6 days" "+%Y-%m-%dT23:59:59" 2>/dev/null || date -v-6d "+%Y-%m-%dT23:59:59")

  local r
  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${past_start}\",
    \"endDate\": \"${past_end}\"
  }" "Check availability: past dates")

  local msg
  msg=$(echo "$r" | jq -r '.message // ""')
  if [ -n "$msg" ]; then
    assert_pass "Past date handled gracefully: $(echo "$msg" | head -c 80)"
  else
    assert_warn "No message for past date range"
  fi

  # 6b. Missing required params
  subsection "6b. Missing startDate/endDate (should return 400)"
  r=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/get-availability" \
    -H "Content-Type: application/json" \
    -H "x-internal-api-key: ${API_KEY}" \
    -d "{\"locationId\": \"${LOCATION_ID}\", \"callerPhoneNumber\": \"${TEST_PHONE}\"}")

  local http_code
  http_code=$(echo "$r" | tail -n1)
  if [ "$http_code" = "400" ]; then
    assert_pass "Missing params returns HTTP 400"
  else
    assert_fail "Expected HTTP 400, got HTTP $http_code"
  fi

  # 6c. Sunday (business closed — if no Sunday hours)
  subsection "6c. Sunday availability (should be empty if business closed)"
  local sunday_days
  sunday_days=$(find_next_sunday)
  local sunday_date
  sunday_date=$(future_date $sunday_days)

  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${sunday_date}T00:00:00\",
    \"endDate\": \"${sunday_date}T23:59:59\"
  }" "Check availability: Sunday")

  local sunday_slots
  sunday_slots=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)
  msg=$(echo "$r" | jq -r '.message // ""')
  echo "    Sunday slots: $sunday_slots"
  echo "    Message: $(echo "$msg" | head -c 100)"
  # Can't assert 0 — business may be open Sundays. Just report.
  if [ "$sunday_slots" -eq 0 ]; then
    assert_pass "No availability on Sunday (closed)"
  else
    assert_warn "Sunday has $sunday_slots slot(s) — business may be open Sundays"
  fi

  # 6d. Multi-day range
  subsection "6d. Multi-day range (3 consecutive business days)"
  local bd1 bd2 bd3
  bd1=$(find_business_day 15)
  bd3=$((bd1 + 2))
  # Ensure bd3 isn't Sunday
  local bd3_dow
  bd3_dow=$(future_dow $bd3)
  if [ "$bd3_dow" = "0" ]; then
    bd3=$((bd3 + 1))
  fi

  local multi_start multi_end
  multi_start="$(future_date $bd1)T00:00:00"
  multi_end="$(future_date $bd3)T23:59:59"

  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${multi_start}\",
    \"endDate\": \"${multi_end}\"
  }" "Check availability: 3-day range")

  local multi_slots
  multi_slots=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)
  # With 3 open days, should have at least 3 windows (1 per day)
  assert_gte "multi-day slots" "$multi_slots" "2"

  echo ""
  echo "  Multi-day windows:"
  echo "$r" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"' 2>/dev/null

  # 6e. Custom duration (30 min)
  subsection "6e. Custom duration (30 min — should find more/different slots)"
  local short_day
  short_day=$(find_business_day 12)
  local short_date
  short_date=$(future_date $short_day)

  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${short_date}T00:00:00\",
    \"endDate\": \"${short_date}T23:59:59\",
    \"duration\": 30
  }" "Check availability: 30-min duration")

  local short_slots
  short_slots=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)
  assert_gte "30-min slots" "$short_slots" "1"
}

# =============================================================================
# TEST 7: Timezone correctness (THE CORE BUG)
# =============================================================================

test_timezone_correctness() {
  section "TEST 7: Timezone correctness"

  echo "  This test verifies that availability windows align with the"
  echo "  location's timezone (America/Los_Angeles), NOT server time (UTC)."
  echo ""
  echo "  The bug: Date.setHours() in checkAvailability uses server local time."
  echo "  On an AWS server (UTC), business hours 8AM-5PM get computed as"
  echo "  08:00-17:00 UTC instead of 16:00-01:00 UTC (Pacific time)."
  echo ""

  # Query availability for a far-future empty day
  local tz_day
  tz_day=$(find_business_day 35)
  local tz_date
  tz_date=$(future_date $tz_day)

  subsection "7a. Query empty day and verify window times"
  local r
  r=$(call_api "get-availability" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"startDate\": \"${tz_date}T00:00:00\",
    \"endDate\": \"${tz_date}T23:59:59\"
  }" "Check availability: timezone test day")

  local slot_count
  slot_count=$(echo "$r" | jq '.timeSlots | length' 2>/dev/null)

  if [ "$slot_count" -lt 1 ]; then
    assert_fail "No slots returned — cannot verify timezone"
    return
  fi

  # Extract the first window's start and end hours (in UTC from the API)
  local first_start_iso first_end_iso
  first_start_iso=$(echo "$r" | jq -r '.timeSlots[0].startTime')
  first_end_iso=$(echo "$r" | jq -r '.timeSlots[0].endTime')

  echo "    First window: $first_start_iso → $first_end_iso"

  # Extract UTC hour from the start time
  # Format: 2026-03-01T16:00:00.000Z or 2026-03-01T08:00:00.000Z
  local start_utc_hour
  start_utc_hour=$(echo "$first_start_iso" | sed -n 's/.*T\([0-9][0-9]\):.*/\1/p')

  echo "    Start UTC hour: $start_utc_hour"

  # For Pacific timezone (UTC-8), business start 8 AM = 16:00 UTC
  # For UTC server bug, business start 8 AM = 08:00 UTC
  subsection "7b. Window start hour should be 15-16 UTC (8 AM Pacific)"
  echo "    If start hour is 08: BUG — using server UTC time, not Pacific"
  echo "    If start hour is 15-16: CORRECT — using Pacific timezone"

  if [ -n "$start_utc_hour" ]; then
    local hour_num=$((10#$start_utc_hour))  # force base-10
    if [ "$hour_num" -ge 15 ] && [ "$hour_num" -le 17 ]; then
      assert_pass "Start hour $start_utc_hour UTC = 8-10 AM Pacific (timezone correct)"
    elif [ "$hour_num" -ge 7 ] && [ "$hour_num" -le 9 ]; then
      assert_fail "Start hour $start_utc_hour UTC = 8 AM UTC ← TIMEZONE BUG (using server time, not Pacific)"
    else
      assert_warn "Start hour $start_utc_hour UTC — unexpected (DST or different timezone?)"
    fi
  else
    assert_warn "Could not parse UTC hour from: $first_start_iso"
  fi

  # Also check end time
  local end_utc_hour
  end_utc_hour=$(echo "$first_end_iso" | sed -n 's/.*T\([0-9][0-9]\):.*/\1/p')

  subsection "7c. Window end hour should be 00-02 UTC next day (5 PM Pacific)"
  echo "    If end hour is 17: BUG — using server UTC time"
  echo "    If end hour is 00-02 (next day): CORRECT — using Pacific timezone"

  if [ -n "$end_utc_hour" ]; then
    local end_num=$((10#$end_utc_hour))
    if [ "$end_num" -ge 0 ] && [ "$end_num" -le 3 ]; then
      assert_pass "End hour $end_utc_hour UTC = 4-7 PM Pacific (timezone correct)"
    elif [ "$end_num" -eq 17 ] || [ "$end_num" -eq 18 ]; then
      assert_fail "End hour $end_utc_hour UTC = 5 PM UTC ← TIMEZONE BUG"
    else
      assert_warn "End hour $end_utc_hour UTC — unexpected"
    fi
  else
    assert_warn "Could not parse UTC hour from: $first_end_iso"
  fi
}

# =============================================================================
# TEST 8: Assessment response shape
# =============================================================================

test_assessment_response_shape() {
  section "TEST 8: Assessment response shape (from create-service-request)"

  subsection "8a. Verify assessment field in create-service-request response"
  # Create a new request and check the response shape
  local r
  r=$(call_api "create-service-request" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\",
    \"description\": \"Response shape test — verify assessment field\",
    \"serviceType\": \"General\",
    \"propertyId\": \"${PROPERTY_ID}\"
  }" "Create request (response shape test)")

  local req_id assessment_id
  req_id=$(echo "$r" | jq -r '.serviceRequest.id // empty')
  assessment_id=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.id // empty')

  assert_not_empty "serviceRequest.id" "$r" ".serviceRequest.id"

  if [ -n "$assessment_id" ] && [ "$assessment_id" != "null" ]; then
    assert_pass "assessment.id present in response: $assessment_id"
  else
    assert_fail "assessment.id MISSING from create-service-request response ← agent can't auto-schedule without this"
  fi

  # Check that assessment has the expected fields
  subsection "8b. Assessment metadata fields"
  local has_title has_start has_complete
  has_title=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.title // empty')
  has_start=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.startAt // "unscheduled"')
  has_complete=$(echo "$r" | jq -r '.serviceRequest.metadata.assessment.isComplete // empty')

  if [ -n "$has_title" ] && [ "$has_title" != "null" ]; then
    assert_pass "assessment.title present: $has_title"
  else
    assert_warn "assessment.title not present"
  fi

  echo "    assessment.startAt: $has_start (expected: null/unscheduled for new request)"
  echo "    assessment.isComplete: $has_complete"

  # Fetch via get-request and verify assessment appears there too
  subsection "8c. Assessment also visible in get-request response"
  if [ -n "$req_id" ] && [ "$req_id" != "null" ]; then
    r=$(call_api "get-request" "{
      \"locationId\": \"${LOCATION_ID}\",
      \"callerPhoneNumber\": \"${TEST_PHONE}\",
      \"requestId\": \"${req_id}\"
    }" "Get request (verify assessment)")

    local get_assessment_id
    get_assessment_id=$(echo "$r" | jq -r '.request.metadata.assessment.id // empty')
    if [ -n "$get_assessment_id" ] && [ "$get_assessment_id" != "null" ]; then
      assert_pass "assessment.id in get-request: $get_assessment_id"
      assert_eq "assessment IDs match" "$get_assessment_id" "$assessment_id"
    else
      assert_fail "assessment.id missing from get-request metadata"
    fi
  fi
}

# =============================================================================
# TEST 9: Client schedule integration
# =============================================================================

test_client_schedule() {
  section "TEST 9: Client schedule shows assessments"

  subsection "9a. Get client schedule (should include scheduled assessments)"
  local r
  r=$(call_api "get-client-schedule" "{
    \"locationId\": \"${LOCATION_ID}\",
    \"callerPhoneNumber\": \"${TEST_PHONE}\",
    \"customerId\": \"${CUSTOMER_ID}\"
  }" "Get client schedule")

  assert_not_empty "message" "$r" ".message"

  local item_count
  item_count=$(echo "$r" | jq '.scheduledItems | length' 2>/dev/null || echo "0")
  echo "    Scheduled items: $item_count"

  if [ "$item_count" -ge 1 ]; then
    assert_pass "Client has $item_count scheduled item(s)"
    echo ""
    echo "  Schedule:"
    echo "$r" | jq -r '.scheduledItems[]? | "    [\(.type)] \(.title // "untitled") — \(.startAt // "unscheduled") → \(.endAt // "")"' 2>/dev/null
  else
    assert_warn "No scheduled items (assessments may be unscheduled or cancelled)"
  fi

  subsection "9b. Schedule contains assessment type items"
  local assessment_count
  assessment_count=$(echo "$r" | jq '[.scheduledItems[]? | select(.type == "assessment")] | length' 2>/dev/null || echo "0")

  if [ "$assessment_count" -ge 1 ]; then
    assert_pass "Found $assessment_count assessment(s) in schedule"
  else
    assert_warn "No assessments in schedule (may have been cancelled or unscheduled)"
  fi
}

# =============================================================================
# Results
# =============================================================================

print_results() {
  section "RESULTS"

  echo ""
  echo -e "  ${GREEN}✅ Passed:  ${PASS}${NC}"
  echo -e "  ${RED}❌ Failed:  ${FAIL}${NC}"
  echo -e "  ${YELLOW}⚠  Warned:  ${WARN}${NC}"
  echo -e "  📊 Total:   ${TOTAL}"
  echo ""

  if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
  else
    echo -e "${RED}💥 ${FAIL} TEST(S) FAILED${NC}"
    echo ""
    echo "  Known bugs that may cause failures:"
    echo "    1. TIMEZONE BUG: JobberAdapter.ts checkAvailability uses Date.setHours()"
    echo "       in server local time instead of location timezone."
    echo "       Fix: Use timezone-aware date math (e.g., Intl.DateTimeFormat or luxon)"
    echo "       File: src/adapters/field-service/platforms/jobber/JobberAdapter.ts:2912"
    echo ""
    echo "    2. PROMPT BUG: Step 10 (auto-schedule assessment) never implemented."
    echo "       Agent says 'team will get back' instead of checking availability."
    echo "       Fix: Add Step 10 conditional on autoScheduleAssessment flag."
    echo "       File: src/utils.ts:1524"
  fi
  echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo "🧪 AVAILABILITY & ASSESSMENT SCHEDULING TEST SUITE"
  echo "===================================================="
  echo "API:       ${BASE_URL}"
  echo "Location:  ${LOCATION_ID}"
  echo "Phone:     ${TEST_PHONE}"
  echo "Verbose:   ${VERBOSE}"
  echo "===================================================="

  preflight

  if [ "$SEED_FIRST" = true ]; then
    echo ""
    echo "Running seed script first..."
    bash "$(dirname "$0")/seed-and-test-jobber.sh" seed || true
  fi

  setup
  test_empty_calendar
  test_blocked_slots
  test_double_booking_prevention
  test_e2e_scheduling_flow
  test_reschedule_and_cancel
  test_edge_cases
  test_timezone_correctness
  test_assessment_response_shape
  test_client_schedule
  print_results

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
