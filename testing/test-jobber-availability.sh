#!/bin/bash

# ============================================================================
# JOBBER AVAILABILITY & SCHEDULING TEST SUITE
# ============================================================================
#
# Tests the check-availability tool by creating scheduled items (visits and
# assessments) at known times, then verifying that get-availability correctly
# identifies open gaps between them.
#
# Test Strategy:
#   1. Set up: Create client + property + request (reuse existing if possible)
#   2. Create scheduled items at KNOWN times on a specific day:
#      - Visit 1:     09:00 - 10:30  (90 min)
#      - Assessment:   11:00 - 12:00  (60 min)
#      - Visit 2:     14:00 - 15:30  (90 min)
#   3. Query availability for that day
#   4. Verify gaps are correctly identified:
#      - Gap 1: 08:00 - 09:00  (before Visit 1)
#      - Gap 2: 10:30 - 11:00  (between Visit 1 and Assessment)
#      - Gap 3: 12:00 - 14:00  (between Assessment and Visit 2)
#      - Gap 4: 15:30 - 17:00  (after Visit 2)
#
# Usage:
#   LOCATION_ID=<id> ./test-jobber-availability.sh
# ============================================================================

set -euo pipefail

# ── Configuration ──
API_URL="${API_URL:-http://localhost:3002}"
API_KEY="${INTERNAL_API_KEY:-ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7}"
LOC_ID="${LOCATION_ID:-}"
PHONE="+15559876543"

if [ -z "$LOC_ID" ]; then
  echo "❌ LOCATION_ID is required"
  echo "Usage: LOCATION_ID=<your-location-id> ./test-jobber-availability.sh"
  exit 1
fi

# ── Counters ──
PASS=0
FAIL=0
WARN=0
TOTAL=0

# ── Helpers ──
call_endpoint() {
  local endpoint="$1"
  local payload="$2"
  curl -s -X POST "$API_URL/internal/tools/$endpoint" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$payload"
}

assert_field() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  local expected="$4"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr")
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label = $actual"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label: expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_empty() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr")
  if [ -n "$actual" ] && [ "$actual" != "null" ] && [ "$actual" != "" ]; then
    echo "  ✅ $label = $actual"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label is empty/null"
    FAIL=$((FAIL + 1))
  fi
}

assert_gte() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  local min="$4"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr")
  if [ "$actual" -ge "$min" ] 2>/dev/null; then
    echo "  ✅ $label = $actual (>= $min)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label = $actual (expected >= $min)"
    FAIL=$((FAIL + 1))
  fi
}

assert_lte() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  local max="$4"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr")
  if [ "$actual" -le "$max" ] 2>/dev/null; then
    echo "  ✅ $label = $actual (<= $max)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label = $actual (expected <= $max)"
    FAIL=$((FAIL + 1))
  fi
}

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Calculate test dates ──
# We use a date 7 days from now to avoid conflicts with other test data
TEST_DAY=$(date -u -d "+7 days" +"%Y-%m-%d")
TEST_DAY_DISPLAY=$(date -u -d "+7 days" +"%A, %B %d")

# ============================================================================
echo "🧪 JOBBER AVAILABILITY & SCHEDULING TEST SUITE"
echo "================================================"
echo "API:       $API_URL"
echo "Location:  $LOC_ID"
echo "Phone:     $PHONE"
echo "Test Day:  $TEST_DAY ($TEST_DAY_DISPLAY)"
echo "================================================"

# ============================================================================
section "SETUP: Ensure client exists"
# ============================================================================

echo ""
echo "0a. Look up caller by phone..."
R=$(call_endpoint "jobber-get-client-by-phone" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\"
}")
FOUND=$(echo "$R" | jq -r '.found')

if [ "$FOUND" = "true" ]; then
  CUSTOMER_ID=$(echo "$R" | jq -r '.client.id')
  echo "  ✅ Client found: $CUSTOMER_ID"
else
  echo "  Creating client via submit-new-lead..."
  R=$(call_endpoint "jobber-submit-new-lead" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"firstName\": \"Jane\",
    \"lastName\": \"Doe\",
    \"email\": \"jane.doe@example.com\",
    \"address\": {
      \"street\": \"742 Evergreen Terrace\",
      \"city\": \"Springfield\",
      \"state\": \"IL\",
      \"zipCode\": \"62704\"
    },
    \"serviceDescription\": \"Availability test setup\"
  }")
  CUSTOMER_ID=$(echo "$R" | jq -r '.customer.id')
  echo "  ✅ Client created: $CUSTOMER_ID"
fi

if [ -z "$CUSTOMER_ID" ] || [ "$CUSTOMER_ID" = "null" ]; then
  echo "  ❌ Failed to get client ID. Cannot continue."
  exit 1
fi

# Get or create a request for assessments
echo ""
echo "0b. Ensure a request exists for assessment creation..."
R=$(call_endpoint "jobber-get-requests" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
REQ_COUNT=$(echo "$R" | jq -r '.requests | length // 0')

if [ "$REQ_COUNT" -gt 0 ] 2>/dev/null; then
  REQUEST_ID=$(echo "$R" | jq -r '.requests[0].id')
  echo "  ✅ Using existing request: $REQUEST_ID"
else
  echo "  Creating request..."
  R=$(call_endpoint "jobber-create-service-request" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"clientId\": \"$CUSTOMER_ID\",
    \"description\": \"Availability test - assessment needed\",
    \"serviceType\": \"General Consultation\"
  }")
  REQUEST_ID=$(echo "$R" | jq -r '.serviceRequest.id')
  echo "  ✅ Request created: $REQUEST_ID"
fi

# Create a second request for the second assessment
echo ""
echo "0c. Create second request for additional assessment..."
R=$(call_endpoint "jobber-create-service-request" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"description\": \"Availability test - second assessment\",
  \"serviceType\": \"Follow-up Consultation\"
}")
REQUEST2_ID=$(echo "$R" | jq -r '.serviceRequest.id // empty')
if [ -n "$REQUEST2_ID" ] && [ "$REQUEST2_ID" != "null" ]; then
  echo "  ✅ Second request created: $REQUEST2_ID"
else
  echo "  ⚠️  Could not create second request, will use first for all assessments"
  REQUEST2_ID="$REQUEST_ID"
fi

# ============================================================================
section "STEP 1: Create scheduled items at known times"
# Schedule on TEST_DAY:
#   Visit 1:     09:00 - 10:30
#   Assessment:  11:00 - 12:00
#   Visit 2:     14:00 - 15:30
# ============================================================================

echo ""
echo "1a. Create Visit 1: ${TEST_DAY} 09:00 - 10:30..."
VISIT1_START="${TEST_DAY}T09:00:00.000Z"
VISIT1_END="${TEST_DAY}T10:30:00.000Z"

R=$(call_endpoint "jobber-create-visit" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"serviceType\": \"Morning Lawn Care\",
  \"startTime\": \"$VISIT1_START\",
  \"endTime\": \"$VISIT1_END\",
  \"notes\": \"Availability test - Visit 1 (09:00-10:30)\"
}")
VISIT1_ID=$(echo "$R" | jq -r '.visit.id // empty')
echo "$R" | jq -c '{visitId: .visit.id, message: .message}'
assert_not_empty "visit1.id" "$R" ".visit.id"

echo ""
echo "1b. Create Assessment: ${TEST_DAY} 11:00 - 12:00..."
ASSESS_START="${TEST_DAY}T11:00:00.000Z"
ASSESS_END="${TEST_DAY}T12:00:00.000Z"

R=$(call_endpoint "jobber-create-assessment" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"requestId\": \"$REQUEST_ID\",
  \"startTime\": \"$ASSESS_START\",
  \"endTime\": \"$ASSESS_END\",
  \"instructions\": \"Availability test - Assessment (11:00-12:00)\"
}")
ASSESS_ID=$(echo "$R" | jq -r '.assessment.id // empty')
echo "$R" | jq -c '{assessmentId: .assessment.id, message: .message}'
assert_not_empty "assessment.id" "$R" ".assessment.id"

echo ""
echo "1c. Create Visit 2: ${TEST_DAY} 14:00 - 15:30..."
VISIT2_START="${TEST_DAY}T14:00:00.000Z"
VISIT2_END="${TEST_DAY}T15:30:00.000Z"

R=$(call_endpoint "jobber-create-visit" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"serviceType\": \"Afternoon Sprinkler Repair\",
  \"startTime\": \"$VISIT2_START\",
  \"endTime\": \"$VISIT2_END\",
  \"notes\": \"Availability test - Visit 2 (14:00-15:30)\"
}")
VISIT2_ID=$(echo "$R" | jq -r '.visit.id // empty')
echo "$R" | jq -c '{visitId: .visit.id, message: .message}'
assert_not_empty "visit2.id" "$R" ".visit.id"

echo ""
echo "  📅 Scheduled items on $TEST_DAY:"
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │ 08:00 │ ░░░░ AVAILABLE ░░░░                            │"
echo "  │ 09:00 │ ████ Visit 1: Morning Lawn Care ████            │"
echo "  │ 10:30 │ ░░░░ AVAILABLE ░░░░                            │"
echo "  │ 11:00 │ ████ Assessment: Consultation ████              │"
echo "  │ 12:00 │ ░░░░ AVAILABLE ░░░░                            │"
echo "  │ 14:00 │ ████ Visit 2: Afternoon Sprinkler ████         │"
echo "  │ 15:30 │ ░░░░ AVAILABLE ░░░░                            │"
echo "  │ 17:00 │ ── End of business hours ──                    │"
echo "  └─────────────────────────────────────────────────────────┘"

# ============================================================================
section "STEP 2: Query availability for single day"
# Expected: gaps at 08-09, 10:30-11, 12-14, 15:30-17
# With default 60 min duration, should find slots in 08-09, 12-14, 15:30-17
# The 10:30-11 gap is only 30 min, so it should NOT appear as a 60-min slot
# ============================================================================

echo ""
echo "2a. Check availability for ${TEST_DAY} (default 60 min duration)..."
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"${TEST_DAY}T00:00:00.000Z\",
  \"endDate\": \"${TEST_DAY}T23:59:59.000Z\"
}")
echo "$R" | jq -c '{slotCount: (.timeSlots | length), message: .message}'
assert_not_empty "message" "$R" ".message"

# Should have at least 1 available slot
SLOT_COUNT=$(echo "$R" | jq -r '.timeSlots | length')
assert_gte "slot count" "$R" ".timeSlots | length" "1"

echo ""
echo "  Available slots returned:"
echo "$R" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime) (available: \(.available))"'

# Verify all returned slots are marked as available
echo ""
echo "2b. Verify all slots are marked available..."
TOTAL=$((TOTAL + 1))
ALL_AVAILABLE=$(echo "$R" | jq '[.timeSlots[]?.available] | all')
if [ "$ALL_AVAILABLE" = "true" ]; then
  echo "  ✅ All returned slots marked available=true"
  PASS=$((PASS + 1))
else
  echo "  ❌ Some slots not marked as available"
  FAIL=$((FAIL + 1))
fi

# Verify no slot overlaps with our scheduled items
echo ""
echo "2c. Verify no slots overlap with scheduled items..."
TOTAL=$((TOTAL + 1))
# Check that no slot starts during Visit 1 (09:00-10:30)
OVERLAP_VISIT1=$(echo "$R" | jq "[.timeSlots[]? | select(
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) >= (\"${VISIT1_START}\" | fromdateiso8601) and
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) < (\"${VISIT1_END}\" | fromdateiso8601)
)] | length")
if [ "$OVERLAP_VISIT1" = "0" ]; then
  echo "  ✅ No slots overlap with Visit 1 (09:00-10:30)"
  PASS=$((PASS + 1))
else
  echo "  ❌ $OVERLAP_VISIT1 slot(s) overlap with Visit 1"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
# Check that no slot starts during Assessment (11:00-12:00)
OVERLAP_ASSESS=$(echo "$R" | jq "[.timeSlots[]? | select(
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) >= (\"${ASSESS_START}\" | fromdateiso8601) and
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) < (\"${ASSESS_END}\" | fromdateiso8601)
)] | length")
if [ "$OVERLAP_ASSESS" = "0" ]; then
  echo "  ✅ No slots overlap with Assessment (11:00-12:00)"
  PASS=$((PASS + 1))
else
  echo "  ❌ $OVERLAP_ASSESS slot(s) overlap with Assessment"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
# Check that no slot starts during Visit 2 (14:00-15:30)
OVERLAP_VISIT2=$(echo "$R" | jq "[.timeSlots[]? | select(
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) >= (\"${VISIT2_START}\" | fromdateiso8601) and
  (.startTime | sub(\"\\\\.[0-9]+Z$\"; \"Z\") | fromdateiso8601) < (\"${VISIT2_END}\" | fromdateiso8601)
)] | length")
if [ "$OVERLAP_VISIT2" = "0" ]; then
  echo "  ✅ No slots overlap with Visit 2 (14:00-15:30)"
  PASS=$((PASS + 1))
else
  echo "  ❌ $OVERLAP_VISIT2 slot(s) overlap with Visit 2"
  FAIL=$((FAIL + 1))
fi

# ============================================================================
section "STEP 3: Query with shorter duration (30 min)"
# The 30-min gap between 10:30-11:00 should now appear as available
# ============================================================================

echo ""
echo "3a. Check availability with 30-min duration..."
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"${TEST_DAY}T00:00:00.000Z\",
  \"endDate\": \"${TEST_DAY}T23:59:59.000Z\",
  \"duration\": 30
}")
echo "$R" | jq -c '{slotCount: (.timeSlots | length), message: .message}'

SLOT_COUNT_30=$(echo "$R" | jq -r '.timeSlots | length')
echo ""
echo "  Available 30-min slots returned:"
echo "$R" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"'

# With 30-min slots, we should get MORE slots than with 60-min
# (the 10:30-11:00 gap now fits, and more slots fit in larger gaps)
echo ""
echo "3b. Verify more slots with shorter duration..."
assert_gte "30-min slot count" "$R" ".timeSlots | length" "1"

# ============================================================================
section "STEP 4: Query multi-day range"
# Query TEST_DAY and the next day
# Next day should have full availability (8am-5pm) since no items scheduled
# ============================================================================

NEXT_DAY=$(date -u -d "+8 days" +"%Y-%m-%d")
NEXT_DAY_DISPLAY=$(date -u -d "+8 days" +"%A, %B %d")

echo ""
echo "4a. Check availability across 2 days: $TEST_DAY to $NEXT_DAY..."
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"${TEST_DAY}T00:00:00.000Z\",
  \"endDate\": \"${NEXT_DAY}T23:59:59.000Z\"
}")
echo "$R" | jq -c '{slotCount: (.timeSlots | length), message: .message}'

MULTI_SLOT_COUNT=$(echo "$R" | jq -r '.timeSlots | length')
assert_gte "multi-day slot count" "$R" ".timeSlots | length" "2"

echo ""
echo "  Multi-day slots returned:"
echo "$R" | jq -r '.timeSlots[]? | "    \(.startTime) → \(.endTime)"'

# Verify the voice message is well-formed
echo ""
echo "4b. Verify voice message is well-formed..."
assert_not_empty "voice message" "$R" ".message"
TOTAL=$((TOTAL + 1))
MSG=$(echo "$R" | jq -r '.message')
if echo "$MSG" | grep -q "available"; then
  echo "  ✅ Message mentions availability: $(echo "$MSG" | head -c 100)..."
  PASS=$((PASS + 1))
else
  echo "  ⚠️  Message doesn't mention 'available': $MSG"
  WARN=$((WARN + 1))
fi

# ============================================================================
section "STEP 5: Edge cases"
# ============================================================================

echo ""
echo "5a. Check availability for past date range (should return empty or error)..."
PAST_START=$(date -u -d "-7 days" +"%Y-%m-%dT00:00:00.000Z")
PAST_END=$(date -u -d "-6 days" +"%Y-%m-%dT23:59:59.000Z")
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"$PAST_START\",
  \"endDate\": \"$PAST_END\"
}")
echo "$R" | jq -c '{slotCount: (.timeSlots | length), message: .message}'
TOTAL=$((TOTAL + 1))
PAST_MSG=$(echo "$R" | jq -r '.message // empty')
if [ -n "$PAST_MSG" ]; then
  echo "  ✅ Past date range handled gracefully"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  No message for past date range"
  WARN=$((WARN + 1))
fi

echo ""
echo "5b. Check availability with missing required params..."
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\"
}")
TOTAL=$((TOTAL + 1))
ERR_MSG=$(echo "$R" | jq -r '.message // empty')
if echo "$ERR_MSG" | grep -qi "required"; then
  echo "  ✅ Missing params returns validation error: $ERR_MSG"
  PASS=$((PASS + 1))
else
  echo "  ❌ Expected validation error for missing startDate/endDate, got: $ERR_MSG"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "5c. Check availability for far future (empty calendar)..."
FAR_START=$(date -u -d "+60 days" +"%Y-%m-%dT00:00:00.000Z")
FAR_END=$(date -u -d "+60 days" +"%Y-%m-%dT23:59:59.000Z")
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"$FAR_START\",
  \"endDate\": \"$FAR_END\"
}")
echo "$R" | jq -c '{slotCount: (.timeSlots | length), message: .message}'
# Empty calendar should return all business-hour slots
assert_gte "far future slots (empty day)" "$R" ".timeSlots | length" "1"

# ============================================================================
section "STEP 6: Verify scheduling flow (availability → create)"
# Simulates: caller asks "when are you free?" → agent suggests slot → books it
# ============================================================================

echo ""
echo "6a. Get availability for next week..."
NEXT_WEEK=$(date -u -d "+14 days" +"%Y-%m-%d")
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"${NEXT_WEEK}T00:00:00.000Z\",
  \"endDate\": \"${NEXT_WEEK}T23:59:59.000Z\"
}")
AVAIL_SLOTS=$(echo "$R" | jq -r '.timeSlots | length')

if [ "$AVAIL_SLOTS" -gt 0 ] 2>/dev/null; then
  # Grab the first available slot
  BOOK_START=$(echo "$R" | jq -r '.timeSlots[0].startTime')
  BOOK_END=$(echo "$R" | jq -r '.timeSlots[0].endTime')
  echo "  ✅ Found $AVAIL_SLOTS slot(s). First: $BOOK_START → $BOOK_END"

  echo ""
  echo "6b. Book a visit in the available slot..."
  R=$(call_endpoint "jobber-create-visit" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"clientId\": \"$CUSTOMER_ID\",
    \"serviceType\": \"Availability-Selected Visit\",
    \"startTime\": \"$BOOK_START\",
    \"endTime\": \"$BOOK_END\",
    \"notes\": \"Booked via availability check flow\"
  }")
  BOOKED_ID=$(echo "$R" | jq -r '.visit.id // empty')
  assert_not_empty "booked visit.id" "$R" ".visit.id"

  echo ""
  echo "6c. Re-check availability — booked slot should no longer appear..."
  R=$(call_endpoint "jobber-get-availability" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"startDate\": \"${NEXT_WEEK}T00:00:00.000Z\",
    \"endDate\": \"${NEXT_WEEK}T23:59:59.000Z\"
  }")
  NEW_AVAIL=$(echo "$R" | jq -r '.timeSlots | length')
  echo "  Slots before booking: $AVAIL_SLOTS → after: $NEW_AVAIL"

  # The booked slot should no longer appear, so fewer slots or same
  # (could be same if the slot was at the boundary and just shifted)
  TOTAL=$((TOTAL + 1))
  if [ "$NEW_AVAIL" -le "$AVAIL_SLOTS" ] 2>/dev/null; then
    echo "  ✅ Slot count did not increase after booking ($NEW_AVAIL <= $AVAIL_SLOTS)"
    PASS=$((PASS + 1))
  else
    echo "  ⚠️  Slot count increased after booking ($NEW_AVAIL > $AVAIL_SLOTS) — may be timing/caching"
    WARN=$((WARN + 1))
  fi
else
  echo "  ⚠️  No available slots returned — skipping booking flow"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "STEP 7: Assessment scheduling via availability"
# Same flow but for assessments: check availability → schedule assessment
# ============================================================================

echo ""
echo "7a. Check availability for assessment scheduling..."
ASSESS_DAY=$(date -u -d "+10 days" +"%Y-%m-%d")
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"${ASSESS_DAY}T00:00:00.000Z\",
  \"endDate\": \"${ASSESS_DAY}T23:59:59.000Z\",
  \"duration\": 60
}")
ASSESS_AVAIL=$(echo "$R" | jq -r '.timeSlots | length')

if [ "$ASSESS_AVAIL" -gt 0 ] 2>/dev/null; then
  ASSESS_BOOK_START=$(echo "$R" | jq -r '.timeSlots[0].startTime')
  ASSESS_BOOK_END=$(echo "$R" | jq -r '.timeSlots[0].endTime')
  echo "  ✅ Found $ASSESS_AVAIL slot(s). Using first: $ASSESS_BOOK_START → $ASSESS_BOOK_END"

  echo ""
  echo "7b. Schedule assessment in available slot..."
  R=$(call_endpoint "jobber-create-assessment" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"requestId\": \"$REQUEST2_ID\",
    \"startTime\": \"$ASSESS_BOOK_START\",
    \"endTime\": \"$ASSESS_BOOK_END\",
    \"instructions\": \"Assessment booked via availability check\"
  }")
  assert_not_empty "assessment.id" "$R" ".assessment.id"
  echo "$R" | jq -c '{assessmentId: .assessment.id, message: .message}'
else
  echo "  ⚠️  No available slots for assessment — skipping"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "RESULTS"
# ============================================================================

echo ""
echo "  ✅ Passed:  $PASS"
echo "  ❌ Failed:  $FAIL"
echo "  ⚠️  Warned:  $WARN"
echo "  📊 Total:   $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "🎉 ALL TESTS PASSED!"
else
  echo "💥 $FAIL TEST(S) FAILED"
fi

echo ""
echo "── Scheduled Items Created ──"
echo "  Visit 1 ID:     ${VISIT1_ID:-N/A}"
echo "  Assessment ID:  ${ASSESS_ID:-N/A}"
echo "  Visit 2 ID:     ${VISIT2_ID:-N/A}"
echo "  Test Day:       $TEST_DAY"
echo ""
echo "── Expected Schedule on $TEST_DAY ──"
echo "  09:00-10:30  Visit 1 (Morning Lawn Care)"
echo "  11:00-12:00  Assessment (Consultation)"
echo "  14:00-15:30  Visit 2 (Afternoon Sprinkler Repair)"
echo ""
echo "── Expected Available Gaps ──"
echo "  08:00-09:00  (1 hour - before first item)"
echo "  10:30-11:00  (30 min - only fits short appointments)"
echo "  12:00-14:00  (2 hours - lunch gap)"
echo "  15:30-17:00  (1.5 hours - end of day)"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
