#!/bin/bash

# ============================================
# Voice Agent Scenario Setup Script
# ============================================
# Sets up Jobber state for live voice testing from a fixed phone number.
# Run a scenario before calling the voice agent to test that conversation path.
#
# Usage:
#   LOCATION_ID=<id> ./testing/setup-voice-scenario.sh <scenario>
#
# Scenarios:
#   new-caller       — Delete all data for the test phone. Agent should create customer + request.
#   returning-caller  — Create customer + property + request. Agent should greet by name.
#   has-appointment   — Create customer + property + job + visit. Agent can report/reschedule.
#   has-estimate      — Create customer + property + estimate. Agent can report quote details.
#   has-invoice       — Create customer + property + job + invoice. Agent can report balance.
#   clean             — Delete the test customer (if API supports it). Reset to blank state.

set -euo pipefail

API_URL="${API_URL:-http://localhost:3002}"
API_KEY="${INTERNAL_API_KEY:-ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7}"
LOC_ID="${LOCATION_ID:-}"
PHONE="${TEST_PHONE:-+18313345344}"
SCENARIO="${1:-}"

if [ -z "$LOC_ID" ]; then
  echo "❌ LOCATION_ID is required"
  echo "Usage: LOCATION_ID=<id> ./testing/setup-voice-scenario.sh <scenario>"
  exit 1
fi

if [ -z "$SCENARIO" ]; then
  echo "❌ Scenario is required"
  echo ""
  echo "Available scenarios:"
  echo "  new-caller          — Blank slate, no customer in Jobber"
  echo "  returning-caller    — Customer + property + open request"
  echo "  has-appointment     — Customer + upcoming appointment/visit"
  echo "  has-estimate        — Customer + pending estimate"
  echo "  has-invoice         — Customer + invoice/balance"
  echo "  seed-busy-schedule  — Fill calendar with dummy appointments (for test 1.3)"
  echo "  clean               — Reset: show current customer ID for manual deletion"
  exit 1
fi

# ============================================
# Helpers
# ============================================
LAST_BODY=""

call() {
  local endpoint="$1"
  local body="$2"
  local label="${3:-$endpoint}"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/internal/tools/fs/$endpoint" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$body" 2>&1)

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  LAST_BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "  ✅ $label (${HTTP_CODE})"
  elif [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -lt 500 ]; then
    MSG=$(echo "$LAST_BODY" | jq -r '.message // empty' 2>/dev/null || echo "$LAST_BODY")
    echo "  ⚠️  $label (${HTTP_CODE}) $MSG"
  else
    MSG=$(echo "$LAST_BODY" | jq -r '.message // empty' 2>/dev/null || echo "$LAST_BODY")
    echo "  ❌ $label (${HTTP_CODE}) $MSG"
  fi
}

lookup_customer() {
  call "get-customer-by-phone" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\"}" \
    "lookup customer"
  FOUND=$(echo "$LAST_BODY" | jq -r '.found // false' 2>/dev/null)
  CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id // empty' 2>/dev/null)
}

ensure_customer() {
  lookup_customer
  if [ "$FOUND" != "true" ]; then
    echo "  → Creating customer..."
    call "create-customer" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"firstName\":\"Alex\",\"lastName\":\"TestCaller\",\"email\":\"alex-test@callsaver.ai\"}" \
      "create customer"
    CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id // empty' 2>/dev/null)
  fi
  echo "  → Customer ID: $CUSTOMER_ID"
}

ensure_property() {
  call "list-properties" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
    "list properties"
  PROPERTY_ID=$(echo "$LAST_BODY" | jq -r '.properties[0].id // empty' 2>/dev/null)

  if [ -z "$PROPERTY_ID" ]; then
    echo "  → Creating property..."
    call "create-property" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"address\":{\"street\":\"742 Evergreen Terrace\",\"city\":\"Santa Cruz\",\"state\":\"CA\",\"zipCode\":\"95060\"}}" \
      "create property"
    PROPERTY_ID=$(echo "$LAST_BODY" | jq -r '.property.id // empty' 2>/dev/null)
  fi
  echo "  → Property ID: $PROPERTY_ID"
}

# ============================================
# Scenarios
# ============================================

echo "============================================"
echo "  Voice Scenario Setup: $SCENARIO"
echo "============================================"
echo "  Phone:    $PHONE"
echo "  Location: $LOC_ID"
echo "  API:      $API_URL"
echo "============================================"
echo ""

case "$SCENARIO" in

  new-caller)
    echo "🆕 SCENARIO: New Caller"
    echo "  The agent should NOT find a customer and should collect info + create a request."
    echo ""
    lookup_customer
    if [ "$FOUND" = "true" ]; then
      echo ""
      echo "  ⚠️  Customer already exists: $CUSTOMER_ID"
      echo "  → You need to delete this client manually in Jobber to test new-caller flow."
      echo "  → Jobber > Clients > search '$PHONE' > delete"
    else
      echo ""
      echo "  ✅ No customer found for $PHONE — ready for new-caller test!"
    fi
    ;;

  returning-caller)
    echo "🔄 SCENARIO: Returning Caller"
    echo "  Customer exists with property and an open service request."
    echo ""
    ensure_customer
    ensure_property

    echo "  → Creating service request..."
    call "create-service-request" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"description\":\"Water heater making strange noises\",\"serviceType\":\"Plumbing\",\"priority\":\"normal\"}" \
      "create service request"
    REQUEST_ID=$(echo "$LAST_BODY" | jq -r '.serviceRequest.id // empty' 2>/dev/null)
    echo "  → Request ID: $REQUEST_ID"

    echo ""
    echo "  ✅ Ready! Call the agent and say things like:"
    echo "     - 'I'm calling about my water heater'"
    echo "     - 'What's the status of my request?'"
    echo "     - 'I need to schedule a visit'"
    ;;

  has-appointment)
    echo "📅 SCENARIO: Has Appointment"
    echo "  Customer exists with an upcoming appointment/visit."
    echo ""
    ensure_customer
    ensure_property

    # Schedule appointment 3 days from now
    APT_START=$(date -u -d "+3 days 10:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+3d -v10H -v0M +"%Y-%m-%dT%H:%M:%S")
    APT_END=$(date -u -d "+3 days 11:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+3d -v11H -v0M +"%Y-%m-%dT%H:%M:%S")
    APT_DATE=$(date -u -d "+3 days" +"%A, %B %d" 2>/dev/null || date -v+3d +"%A, %B %d")

    echo "  → Creating appointment for $APT_DATE at 10:00 AM..."
    call "create-appointment" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"serviceType\":\"Plumbing\",\"startTime\":\"$APT_START\",\"endTime\":\"$APT_END\",\"notes\":\"Water heater inspection\"}" \
      "create appointment"
    APPOINTMENT_ID=$(echo "$LAST_BODY" | jq -r '.appointment.id // empty' 2>/dev/null)
    echo "  → Appointment ID: $APPOINTMENT_ID"

    echo ""
    echo "  ✅ Ready! Call the agent and say things like:"
    echo "     - 'When is my appointment?'"
    echo "     - 'I need to reschedule my visit'"
    echo "     - 'Can we move it to Friday afternoon?'"
    echo "     - 'I need to cancel my appointment'"
    ;;

  has-estimate)
    echo "💰 SCENARIO: Has Estimate"
    echo "  Customer exists with a pending estimate/quote."
    echo ""
    ensure_customer
    ensure_property

    # Need a job first (create via appointment)
    APT_START=$(date -u -d "+5 days 09:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+5d -v9H -v0M +"%Y-%m-%dT%H:%M:%S")
    APT_END=$(date -u -d "+5 days 10:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+5d -v10H -v0M +"%Y-%m-%dT%H:%M:%S")

    echo "  → Creating appointment (to generate a job)..."
    call "create-appointment" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"serviceType\":\"Plumbing\",\"startTime\":\"$APT_START\",\"endTime\":\"$APT_END\"}" \
      "create appointment"

    # Get the auto-created job
    call "get-jobs" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "get jobs"
    JOB_ID=$(echo "$LAST_BODY" | jq -r '.jobs[0].id // empty' 2>/dev/null)

    if [ -n "$JOB_ID" ]; then
      echo "  → Creating estimate on job $JOB_ID..."
      call "create-estimate" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"jobId\":\"$JOB_ID\",\"lineItems\":[{\"description\":\"Water heater replacement - 50 gallon\",\"quantity\":1,\"unitPrice\":1200},{\"description\":\"Labor - installation\",\"quantity\":3,\"unitPrice\":150}]}" \
        "create estimate"
    else
      echo "  ⚠️  No job found — estimate not created"
    fi

    echo ""
    echo "  ✅ Ready! Call the agent and say things like:"
    echo "     - 'Did you send me a quote?'"
    echo "     - 'How much is the estimate?'"
    echo "     - 'What's included in the quote?'"
    ;;

  has-invoice)
    echo "🧾 SCENARIO: Has Invoice"
    echo "  Customer exists with invoice/balance history."
    echo ""
    ensure_customer
    ensure_property

    echo "  → Note: Invoices are created in Jobber when jobs are completed."
    echo "  → You may need to manually create an invoice in Jobber for this customer."
    echo "  → Customer ID: $CUSTOMER_ID"
    echo ""
    echo "  Checking existing invoices..."
    call "get-invoices" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "get invoices"

    call "get-account-balance" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "get account balance"

    echo ""
    echo "  ✅ Ready! Call the agent and say things like:"
    echo "     - 'What do I owe?'"
    echo "     - 'Do I have any outstanding invoices?'"
    echo "     - 'What's my account balance?'"
    ;;

  seed-busy-schedule)
    echo "📅 SCENARIO: Seed Busy Schedule"
    echo "  Creates a dummy client with visits/assessments to fill up the calendar."
    echo "  Run this BEFORE test 1.3 so checkAvailability returns realistic results."
    echo ""

    DUMMY_PHONE="+15550001234"

    # Create dummy customer
    call "create-customer" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\",\"firstName\":\"Busy\",\"lastName\":\"Schedule\",\"email\":\"busy@test.local\"}" \
      "create dummy customer"
    DUMMY_CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id // empty' 2>/dev/null)

    if [ -z "$DUMMY_CUSTOMER_ID" ]; then
      # Maybe already exists
      call "get-customer-by-phone" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\"}" \
        "lookup dummy customer"
      DUMMY_CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id // empty' 2>/dev/null)
    fi
    echo "  → Dummy Customer ID: $DUMMY_CUSTOMER_ID"

    # Create dummy property
    call "create-property" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\",\"customerId\":\"$DUMMY_CUSTOMER_ID\",\"address\":{\"street\":\"999 Busy Lane\",\"city\":\"Santa Cruz\",\"state\":\"CA\",\"zipCode\":\"95060\"}}" \
      "create dummy property"

    # Create appointments across the next 3 days to fill up the schedule
    # Day +1: 8-10 AM, 11-12 PM, 2-4 PM (leaves 10-11, 12-2, 4-5 open)
    # Day +2: 8-9 AM, 9-11 AM, 1-3 PM, 3-5 PM (leaves 11-1 open)
    # Day +3: 8-12 PM, 1-5 PM (almost fully booked, only 12-1 open)

    for DAY_OFFSET in 1 2 3; do
      DAY_LABEL=$(date -d "+${DAY_OFFSET} days" +"%A %b %d" 2>/dev/null || date -v+${DAY_OFFSET}d +"%A %b %d")
      echo ""
      echo "  📆 Day +${DAY_OFFSET} ($DAY_LABEL):"
    done

    # Day +1 appointments
    D1=$(date -d "+1 day" +"%Y-%m-%d" 2>/dev/null || date -v+1d +"%Y-%m-%d")
    for SLOT in "08:00:00,10:00:00,Morning inspection" "11:00:00,12:00:00,Midday checkup" "14:00:00,16:00:00,Afternoon repair"; do
      IFS=',' read -r S E NOTE <<< "$SLOT"
      call "create-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\",\"customerId\":\"$DUMMY_CUSTOMER_ID\",\"serviceType\":\"General\",\"startTime\":\"${D1}T${S}\",\"endTime\":\"${D1}T${E}\",\"notes\":\"$NOTE\"}" \
        "day+1 ${S}-${E}"
    done

    # Day +2 appointments
    D2=$(date -d "+2 days" +"%Y-%m-%d" 2>/dev/null || date -v+2d +"%Y-%m-%d")
    for SLOT in "08:00:00,09:00:00,Early call" "09:00:00,11:00:00,Long assessment" "13:00:00,15:00:00,Afternoon job" "15:00:00,17:00:00,Late repair"; do
      IFS=',' read -r S E NOTE <<< "$SLOT"
      call "create-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\",\"customerId\":\"$DUMMY_CUSTOMER_ID\",\"serviceType\":\"General\",\"startTime\":\"${D2}T${S}\",\"endTime\":\"${D2}T${E}\",\"notes\":\"$NOTE\"}" \
        "day+2 ${S}-${E}"
    done

    # Day +3 appointments (almost full)
    D3=$(date -d "+3 days" +"%Y-%m-%d" 2>/dev/null || date -v+3d +"%Y-%m-%d")
    for SLOT in "08:00:00,12:00:00,Full morning block" "13:00:00,17:00:00,Full afternoon block"; do
      IFS=',' read -r S E NOTE <<< "$SLOT"
      call "create-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$DUMMY_PHONE\",\"customerId\":\"$DUMMY_CUSTOMER_ID\",\"serviceType\":\"General\",\"startTime\":\"${D3}T${S}\",\"endTime\":\"${D3}T${E}\",\"notes\":\"$NOTE\"}" \
        "day+3 ${S}-${E}"
    done

    echo ""
    echo "  ✅ Schedule seeded! Expected availability gaps:"
    echo "     Day +1: 10-11 AM, 12-2 PM, 4-5 PM"
    echo "     Day +2: 11 AM-1 PM only"
    echo "     Day +3: 12-1 PM only (lunch gap)"
    echo ""
    echo "  ⚠️  Dummy customer phone: $DUMMY_PHONE"
    echo "  ⚠️  Delete dummy client in Jobber after testing."
    ;;

  clean)
    echo "🧹 SCENARIO: Clean / Reset"
    echo ""
    lookup_customer
    if [ "$FOUND" = "true" ]; then
      echo "  → Customer found: $CUSTOMER_ID"
      echo "  → Jobber API does not support deleting customers."
      echo "  → Delete manually: Jobber > Clients > search '$PHONE' > Archive/Delete"
    else
      echo "  ✅ No customer found for $PHONE — already clean."
    fi
    ;;

  *)
    echo "❌ Unknown scenario: $SCENARIO"
    echo "Available: new-caller, returning-caller, has-appointment, has-estimate, has-invoice, seed-busy-schedule, clean"
    exit 1
    ;;
esac

echo ""
echo "============================================"
echo "  Now call the voice agent from $PHONE"
echo "============================================"
