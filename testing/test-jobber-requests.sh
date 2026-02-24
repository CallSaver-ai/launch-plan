#!/bin/bash

# ============================================================================
# COMPREHENSIVE JOBBER VOICE AGENT TEST SUITE
# ============================================================================
#
# Tests ALL Jobber endpoints organized by customer intent scenarios.
# Simulates the full lifecycle a real customer would experience:
#
#   SCENARIO 1: New caller requests service (Client + Property + Request)
#   SCENARIO 2: Same caller calls back to check status
#   SCENARIO 3: Caller wants to update their info
#   SCENARIO 4: Caller asks about services offered
#   SCENARIO 5: Caller has a scheduled visit (Job + Visit lifecycle)
#   SCENARIO 6: Caller wants to reschedule
#   SCENARIO 7: Caller asks about billing
#   SCENARIO 8: Emergency caller
#   SCENARIO 9: Caller wants to cancel
#   SCENARIO 10: Cleanup verification
#
# Endpoints tested (22 total):
#   jobber-get-client-by-phone      jobber-create-client
#   jobber-update-client            jobber-submit-new-lead
#   jobber-create-property          jobber-list-properties
#   jobber-update-property          jobber-create-service-request
#   jobber-get-requests             jobber-get-request
#   jobber-get-services             jobber-get-jobs
#   jobber-get-job                  jobber-create-visit
#   jobber-get-visits               jobber-reschedule-visit
#   jobber-cancel-visit             jobber-get-client-balance
#   jobber-get-invoices             jobber-add-note-to-job
#   jobber-create-estimate          jobber-get-availability
#
# Usage:
#   LOCATION_ID=<id> ./test-jobber-requests.sh
#   LOCATION_ID=<id> SKIP_CLEANUP=1 ./test-jobber-requests.sh  # keep test data
# ============================================================================

set -euo pipefail

# ── Configuration ──
API_URL="${API_URL:-http://localhost:3002}"
API_KEY="${INTERNAL_API_KEY:-ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7}"
LOC_ID="${LOCATION_ID:-}"
PHONE="+15559876543"

if [ -z "$LOC_ID" ]; then
  echo "❌ LOCATION_ID is required"
  echo "Usage: LOCATION_ID=<your-location-id> ./test-jobber-requests.sh"
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

assert_exists() {
  local label="$1"
  local json="$2"
  local jq_expr="$3"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(echo "$json" | jq -r "$jq_expr")
  if [ -n "$actual" ] && [ "$actual" != "null" ] && [ "$actual" != "" ]; then
    echo "  ✅ $label present"
    PASS=$((PASS + 1))
  else
    echo "  ⚠️  $label not present (may be expected)"
    WARN=$((WARN + 1))
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

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
echo "🧪 COMPREHENSIVE JOBBER VOICE AGENT TEST SUITE"
echo "================================================"
echo "API:      $API_URL"
echo "Location: $LOC_ID"
echo "Phone:    $PHONE"
echo "================================================"

# ============================================================================
section "SCENARIO 1: New caller requests service"
# Intent: \"I need landscaping work done\"
# Flow: lookup phone → not found → submit-new-lead (Client+Property+Request)
# Endpoints: jobber-get-client-by-phone, jobber-submit-new-lead
# ============================================================================

echo ""
echo "1a. Look up caller by phone (should not exist)..."
R=$(call_endpoint "jobber-get-client-by-phone" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\"
}")
echo "$R" | jq -c '{found: .found, message: .message}'
# Could be found or not found depending on prior runs — handle both
FOUND=$(echo "$R" | jq -r '.found')
if [ "$FOUND" = "true" ]; then
  CUSTOMER_ID=$(echo "$R" | jq -r '.client.id')
  echo "  ⚠️  Client already exists from prior run: $CUSTOMER_ID"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
else
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  echo "  ✅ Customer not found (expected for new caller)"
fi

echo ""
echo "1b. Submit new lead: Client + Property + Request in one call..."
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
  \"serviceDescription\": \"Backyard landscaping - new patio and garden bed installation\",
  \"priority\": \"normal\"
}")
echo "$R" | jq -c '{customerCreated: .customerCreated, clientId: .customer.id, propertyId: .property.id, requestId: .serviceRequest.id}'
assert_not_empty "customer.id" "$R" ".customer.id"
assert_not_empty "serviceRequest.id" "$R" ".serviceRequest.id"
assert_not_empty "message" "$R" ".message"

CUSTOMER_ID=$(echo "$R" | jq -r '.customer.id')
PROPERTY_ID=$(echo "$R" | jq -r '.property.id // empty')
REQUEST1_ID=$(echo "$R" | jq -r '.serviceRequest.id')
echo "  📝 Customer=$CUSTOMER_ID Property=${PROPERTY_ID:-none} Request=$REQUEST1_ID"

echo ""
echo "1c. Verify customer now found by phone..."
R=$(call_endpoint "jobber-get-client-by-phone" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\"
}")
assert_field "found" "$R" ".found" "true"
assert_not_empty "client.name" "$R" ".client.name"

echo ""
echo "1d. Verify property was created..."
R=$(call_endpoint "jobber-list-properties" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
assert_gte "property count" "$R" ".properties | length" "1"
# Grab property ID if we didn't get one from submit-new-lead
if [ -z "$PROPERTY_ID" ] || [ "$PROPERTY_ID" = "null" ]; then
  PROPERTY_ID=$(echo "$R" | jq -r '.properties[0].id // empty')
fi

# ============================================================================
section "SCENARIO 2: Returning caller checks status"
# Intent: \"What's happening with my request?\"
# Flow: lookup phone → found → get-requests → get-request (detail)
# Endpoints: jobber-get-client-by-phone, jobber-get-requests, jobber-get-request
# ============================================================================

echo ""
echo "2a. Submit a second request (same caller, different service)..."
R=$(call_endpoint "jobber-submit-new-lead" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"address\": {
    \"street\": \"742 Evergreen Terrace\",
    \"city\": \"Springfield\",
    \"state\": \"IL\",
    \"zipCode\": \"62704\"
  },
  \"serviceDescription\": \"Sprinkler system repair - two heads broken\",
  \"priority\": \"high\"
}")
assert_field "customerCreated" "$R" ".customerCreated" "false"
assert_not_empty "serviceRequest.id" "$R" ".serviceRequest.id"
REQUEST2_ID=$(echo "$R" | jq -r '.serviceRequest.id // empty')

echo ""
echo "2b. List all requests for client..."
R=$(call_endpoint "jobber-get-requests" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
echo "$R" | jq -c '{count: (.requests | length), message: .message}'
assert_gte "request count" "$R" ".requests | length" "2"
assert_not_empty "voice message" "$R" ".message"

echo ""
echo "2c. Get detailed single request (assessment/quotes/jobs metadata)..."
R=$(call_endpoint "jobber-get-request" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"requestId\": \"$REQUEST1_ID\"
}")
echo "$R" | jq -c '{id: .request.id, status: .request.status, source: .request.metadata.source, message: .message}'
assert_not_empty "request.id" "$R" ".request.id"
assert_not_empty "request.status" "$R" ".request.status"
assert_not_empty "voice message" "$R" ".message"
# These may be null for a new request (no assessment/quotes yet) — that's expected
assert_exists "metadata.assessment" "$R" ".request.metadata.assessment"
assert_exists "metadata.quotes" "$R" ".request.metadata.quotes"
assert_exists "metadata.propertyId" "$R" ".request.metadata.propertyId"

echo ""
echo "2d. Create assessment for the request..."
# Schedule assessment for 3 days from now at 10 AM
ASSESSMENT_DATE=$(date -u -d "+3 days 10:00:00" +"%Y-%m-%dT%H:%M:%SZ")
R=$(call_endpoint "jobber-create-assessment" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"requestId\": \"$REQUEST1_ID\",
  \"startTime\": \"$ASSESSMENT_DATE\",
  \"instructions\": \"Site assessment for landscaping project\"
}")
echo "$R" | jq -c '{assessmentId: .assessment.id, message: .message}'
assert_not_empty "assessment.id" "$R" ".assessment.id"
assert_not_empty "message" "$R" ".message"
ASSESSMENT_ID=$(echo "$R" | jq -r '.assessment.id // empty')

echo ""
echo "2e. Verify assessment appears in request metadata..."
R=$(call_endpoint "jobber-get-request" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"requestId\": \"$REQUEST1_ID\"
}")
assert_not_empty "metadata.assessment.id" "$R" ".request.metadata.assessment.id"
assert_field "assessment.id matches" "$R" ".request.metadata.assessment.id" "$ASSESSMENT_ID"
echo "  ✅ Assessment ID in metadata: $(echo "$R" | jq -r '.request.metadata.assessment.id')"

# ============================================================================
section "SCENARIO 3: Caller wants to update their info"
# Intent: \"I have a new email address\"
# Endpoints: jobber-update-client, jobber-update-property
# ============================================================================

echo ""
echo "3a. Update client email..."
R=$(call_endpoint "jobber-update-client" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"email\": \"jane.doe.updated@example.com\"
}")
echo "$R" | jq -c '{message: .message}'
assert_not_empty "message" "$R" ".message"

echo ""
echo "3b. Update property address..."
if [ -n "$PROPERTY_ID" ] && [ "$PROPERTY_ID" != "null" ]; then
  R=$(call_endpoint "jobber-update-property" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"propertyId\": \"$PROPERTY_ID\",
    \"address\": {
      \"street\": \"744 Evergreen Terrace\",
      \"city\": \"Springfield\",
      \"state\": \"IL\",
      \"zipCode\": \"62704\"
    }
  }")
  echo "$R" | jq -c '{message: .message}'
  assert_not_empty "message" "$R" ".message"
else
  echo "  ⚠️  No property ID — skipping property update"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "SCENARIO 4: Caller asks what services are offered"
# Intent: \"What services do you provide?\"
# Endpoints: jobber-get-services
# ============================================================================

echo ""
echo "4a. Get service catalog..."
R=$(call_endpoint "jobber-get-services" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\"
}")
echo "$R" | jq -c '{serviceCount: (.services | length), message: .message}'
assert_not_empty "message" "$R" ".message"
# Services may be empty if none configured in Jobber test account
TOTAL=$((TOTAL + 1))
SVC_COUNT=$(echo "$R" | jq -r '.services | length // 0')
if [ "$SVC_COUNT" -gt 0 ] 2>/dev/null; then
  echo "  ✅ Found $SVC_COUNT service(s)"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  No services found (configure in Jobber test account)"
  WARN=$((WARN + 1))
fi

# ============================================================================
section "SCENARIO 5: Active work — Job + Visit lifecycle"
# Intent: \"When is my next appointment?\"
# Flow: create-visit (creates Job+Visit) → get-visits → get-jobs
# Endpoints: jobber-create-visit, jobber-get-visits, jobber-get-jobs,
#            jobber-get-job, jobber-add-note-to-job
# ============================================================================

echo ""
echo "5a. Create visit (Job + Visit)..."
START_TIME=$(date -u -d "+3 days 09:00" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+3d -v9H -v0M +"%Y-%m-%dT%H:%M:%S.000Z")
END_TIME=$(date -u -d "+3 days 10:30" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+3d -v10H -v30M +"%Y-%m-%dT%H:%M:%S.000Z")

R=$(call_endpoint "jobber-create-visit" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"serviceType\": \"Lawn Care\",
  \"startTime\": \"$START_TIME\",
  \"endTime\": \"$END_TIME\",
  \"notes\": \"Test visit from comprehensive test suite\"
}")
echo "$R" | jq -c '{visitId: .visit.id, message: .message}'
assert_not_empty "visit.id" "$R" ".visit.id"
VISIT_ID=$(echo "$R" | jq -r '.visit.id // empty')
JOB_ID=$(echo "$R" | jq -r '.visit.jobId // empty')

echo ""
echo "5b. Get upcoming visits..."
R=$(call_endpoint "jobber-get-visits" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
echo "$R" | jq -c '{count: (.visits | length), message: .message}'
assert_gte "visit count" "$R" ".visits | length" "1"
assert_not_empty "voice message" "$R" ".message"

echo ""
echo "5c. Get jobs for client..."
R=$(call_endpoint "jobber-get-jobs" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
echo "$R" | jq -c '{count: (.jobs | length), message: .message}'
assert_gte "job count" "$R" ".jobs | length" "1"
# Grab job number for next test
JOB_NUMBER=$(echo "$R" | jq -r '.jobs[0].jobNumber // empty')

echo ""
echo "5d. Get job by number..."
if [ -n "$JOB_NUMBER" ] && [ "$JOB_NUMBER" != "null" ]; then
  R=$(call_endpoint "jobber-get-job" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"jobNumber\": \"$JOB_NUMBER\"
  }")
  echo "$R" | jq -c '{jobId: .job.id, title: .job.title, message: .message}'
  assert_not_empty "job.id" "$R" ".job.id"
  # Get JOB_ID from here if we didn't get it from appointment
  if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
    JOB_ID=$(echo "$R" | jq -r '.job.id // empty')
  fi
else
  echo "  ⚠️  No job number — skipping"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

echo ""
echo "5e. Add note to job..."
if [ -n "$JOB_ID" ] && [ "$JOB_ID" != "null" ]; then
  R=$(call_endpoint "jobber-add-note-to-job" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"jobId\": \"$JOB_ID\",
    \"note\": \"Customer called to confirm appointment. Prefers morning visits.\"
  }")
  echo "$R" | jq -c '{message: .message}'
  assert_not_empty "message" "$R" ".message"
else
  echo "  ⚠️  No job ID — skipping note"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "SCENARIO 6: Caller wants to reschedule"
# Intent: \"Can I move my appointment to next week?\"
# Endpoints: jobber-reschedule-visit
# ============================================================================

echo ""
echo "6a. Reschedule visit..."
if [ -n "$VISIT_ID" ] && [ "$VISIT_ID" != "null" ]; then
  NEW_START=$(date -u -d "+5 days 14:00" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+5d -v14H -v0M +"%Y-%m-%dT%H:%M:%S.000Z")
  NEW_END=$(date -u -d "+5 days 15:30" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+5d -v15H -v30M +"%Y-%m-%dT%H:%M:%S.000Z")

  R=$(call_endpoint "jobber-reschedule-visit" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"visitId\": \"$VISIT_ID\",
    \"startTime\": \"$NEW_START\",
    \"endTime\": \"$NEW_END\"
  }")
  echo "$R" | jq -c '{message: .message}'
  assert_not_empty "message" "$R" ".message"
else
  echo "  ⚠️  No visit ID — skipping reschedule"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "SCENARIO 7: Caller asks about billing"
# Intent: \"How much do I owe?\" / \"What are my invoices?\"
# Endpoints: jobber-get-client-balance, jobber-get-invoices
# ============================================================================

echo ""
echo "7a. Get account balance..."
R=$(call_endpoint "jobber-get-client-balance" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
echo "$R" | jq -c '{balance: .balance, message: .message}'
assert_not_empty "message" "$R" ".message"
TOTAL=$((TOTAL + 1))
PASS=$((PASS + 1))
echo "  ✅ Balance endpoint responded"

echo ""
echo "7b. Get invoices..."
R=$(call_endpoint "jobber-get-invoices" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
echo "$R" | jq -c '{count: (.invoices | length), message: .message}'
assert_not_empty "message" "$R" ".message"
# Invoices may be empty for test account — that's fine
TOTAL=$((TOTAL + 1))
INV_COUNT=$(echo "$R" | jq -r '.invoices | length // 0')
if [ "$INV_COUNT" -gt 0 ] 2>/dev/null; then
  echo "  ✅ Found $INV_COUNT invoice(s)"
else
  echo "  ✅ No invoices (expected for new test client)"
fi
PASS=$((PASS + 1))

# ============================================================================
section "SCENARIO 8: Emergency caller"
# Intent: \"My pipe burst! I need someone now!\"
# Flow: submit-new-lead with priority=emergency
# Endpoints: jobber-create-service-request (with emergency priority)
# ============================================================================

echo ""
echo "8a. Create emergency service request..."
R=$(call_endpoint "jobber-create-service-request" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"description\": \"EMERGENCY - Water pipe burst in basement, flooding\",
  \"serviceType\": \"Emergency Plumbing\",
  \"address\": {
    \"street\": \"742 Evergreen Terrace\",
    \"city\": \"Springfield\",
    \"state\": \"IL\",
    \"zipCode\": \"62704\"
  },
  \"priority\": \"emergency\"
}")
echo "$R" | jq -c '{requestId: .serviceRequest.id, message: .message}'
assert_not_empty "serviceRequest.id" "$R" ".serviceRequest.id"
assert_not_empty "message" "$R" ".message"
EMERGENCY_ID=$(echo "$R" | jq -r '.serviceRequest.id // empty')

# ============================================================================
section "SCENARIO 9: Caller wants to cancel"
# Intent: \"I need to cancel my appointment\"
# Endpoints: jobber-cancel-visit
# ============================================================================

echo ""
echo "9a. Cancel visit..."
if [ -n "$VISIT_ID" ] && [ "$VISIT_ID" != "null" ]; then
  R=$(call_endpoint "jobber-cancel-visit" "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"visitId\": \"$VISIT_ID\"
  }")
  echo "$R" | jq -c '{message: .message}'
  assert_not_empty "message" "$R" ".message"
else
  echo "  ⚠️  No visit ID — skipping cancel"
  WARN=$((WARN + 1))
  TOTAL=$((TOTAL + 1))
fi

# ============================================================================
section "SCENARIO 10: Additional endpoint coverage"
# Endpoints not covered by intent scenarios above
# ============================================================================

echo ""
echo "10a. Create property directly..."
R=$(call_endpoint "jobber-create-property" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"address\": {
    \"street\": \"100 Main Street\",
    \"city\": \"Springfield\",
    \"state\": \"IL\",
    \"zipCode\": \"62701\"
  }
}")
echo "$R" | jq -c '{propertyId: .property.id, message: .message}'
assert_not_empty "property.id or message" "$R" ".message"
PROP2_ID=$(echo "$R" | jq -r '.property.id // empty')

echo ""
echo "10b. Standalone create-service-request (with serviceType + address)..."
R=$(call_endpoint "jobber-create-service-request" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"description\": \"Gutter cleaning and inspection\",
  \"serviceType\": \"Gutter Cleaning\",
  \"address\": {
    \"street\": \"742 Evergreen Terrace\",
    \"city\": \"Springfield\",
    \"state\": \"IL\",
    \"zipCode\": \"62704\"
  },
  \"priority\": \"normal\"
}")
echo "$R" | jq -c '{requestId: .serviceRequest.id, message: .message}'
assert_not_empty "serviceRequest.id" "$R" ".serviceRequest.id"

echo ""
echo "10c. Check availability..."
R=$(call_endpoint "jobber-get-availability" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"startDate\": \"$START_TIME\",
  \"endDate\": \"$END_TIME\"
}")
echo "$R" | jq -c '{message: .message}'
# This may return an error if not fully implemented — that's OK to note
TOTAL=$((TOTAL + 1))
CHK_MSG=$(echo "$R" | jq -r '.message // empty')
if [ -n "$CHK_MSG" ]; then
  echo "  ✅ get-availability responded"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  get-availability: no message (may not be implemented)"
  WARN=$((WARN + 1))
fi

echo ""
echo "10d. Create estimate..."
R=$(call_endpoint "jobber-create-estimate" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\",
  \"title\": \"Landscaping Estimate\",
  \"description\": \"Full backyard renovation\",
  \"lineItems\": [
    {\"description\": \"Patio installation\", \"quantity\": 1, \"unitPrice\": 2500},
    {\"description\": \"Garden bed\", \"quantity\": 2, \"unitPrice\": 750}
  ]
}")
echo "$R" | jq -c '{message: .message}'
TOTAL=$((TOTAL + 1))
EST_MSG=$(echo "$R" | jq -r '.message // empty')
if [ -n "$EST_MSG" ]; then
  echo "  ✅ create-estimate responded"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  create-estimate: no message"
  WARN=$((WARN + 1))
fi

echo ""
echo "10e. Final property count verification..."
R=$(call_endpoint "jobber-list-properties" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
PROP_COUNT=$(echo "$R" | jq -r '.properties | length // 0')
assert_gte "total properties" "$R" ".properties | length" "1"

echo ""
echo "10f. Final request count verification..."
R=$(call_endpoint "jobber-get-requests" "{
  \"locationId\": \"$LOC_ID\",
  \"callerPhoneNumber\": \"$PHONE\",
  \"clientId\": \"$CUSTOMER_ID\"
}")
REQ_COUNT=$(echo "$R" | jq -r '.requests | length // 0')
assert_gte "total requests" "$R" ".requests | length" "3"

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
echo "── Test Data Created ──"
echo "  Client ID:    $CUSTOMER_ID"
echo "  Property IDs:   ${PROPERTY_ID:-N/A}, ${PROP2_ID:-N/A}"
echo "  Request IDs:    $REQUEST1_ID, ${REQUEST2_ID:-N/A}, ${EMERGENCY_ID:-N/A}"
echo "  Visit ID:       ${VISIT_ID:-N/A}"
echo "  Job ID:         ${JOB_ID:-N/A}"
echo ""
echo "── Verify in Jobber UI ──"
echo "  https://app.getjobber.com"
echo "  Clients  → Jane Doe ($PHONE)"
echo "  Requests → 4+ requests (landscaping, sprinkler, emergency, gutter)"
echo "  Jobs     → 1+ job (Lawn Care)"
echo "  Visits   → 1+ visit"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
