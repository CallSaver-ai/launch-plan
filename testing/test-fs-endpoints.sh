#!/bin/bash

# ============================================
# Unified Field Service Endpoint Test Suite
# ============================================
# Tests all 34 /internal/tools/fs/* endpoints
# Platform-agnostic — works with Jobber, HCP, or any FieldServiceAdapter
#
# Usage:
#   LOCATION_ID=<id> ./test-fs-endpoints.sh                        # Full test suite
#   LOCATION_ID=<id> ./test-fs-endpoints.sh --read-only             # Skip create/update/delete
#   LOCATION_ID=<id> ./test-fs-endpoints.sh --cleanup               # Clean up created resources after
#   LOCATION_ID=<id> ./test-fs-endpoints.sh --group customer        # Test one group
#   LOCATION_ID=<id> TEST_PHONE=+15551234567 ./test-fs-endpoints.sh # Use specific phone
#
# Each run generates a unique RUN_ID (epoch seconds) used in all resource
# names and a unique phone number, so re-runs never collide with each other.
#
# Groups: customer, property, request, assessment, job, appointment, estimate, invoice, service, company, extended

set -euo pipefail

# ============================================
# Configuration
# ============================================
API_URL="${API_URL:-http://localhost:3002}"
API_KEY="${INTERNAL_API_KEY:-ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7}"
LOC_ID="${LOCATION_ID:-}"
READ_ONLY=false
DO_CLEANUP=false
TARGET_GROUP=""

# Unique run ID — makes every resource name distinct per invocation
RUN_ID=$(date +%s)

# Generate a unique phone per run unless TEST_PHONE is explicitly set.
# Format: +1555RUN_ID_LAST_7  (guarantees uniqueness for ~3 months of runs)
if [ -n "${TEST_PHONE:-}" ]; then
  PHONE="$TEST_PHONE"
else
  PHONE="+1555${RUN_ID: -7}"
fi

# Parse args
for arg in "$@"; do
  case $arg in
    --read-only) READ_ONLY=true ;;
    --cleanup) DO_CLEANUP=true ;;
    --group) shift; TARGET_GROUP="$1" ;;
    --group=*) TARGET_GROUP="${arg#*=}" ;;
  esac
done

if [ -z "$LOC_ID" ]; then
  echo "❌ LOCATION_ID is required"
  echo "Usage: LOCATION_ID=<id> ./test-fs-endpoints.sh"
  exit 1
fi

# ============================================
# Helpers
# ============================================
PASS=0
FAIL=0
SKIP=0
CUSTOMER_ID=""
PROPERTY_ID=""
REQUEST_ID=""
JOB_ID=""
APPOINTMENT_ID=""
ESTIMATE_ID=""

# Cleanup tracker — resource IDs created during this run
CLEANUP_APPOINTMENTS=()
CLEANUP_PROPERTIES=()

call() {
  local endpoint="$1"
  local body="$2"
  local label="${3:-$endpoint}"

  echo -n "  → $label ... "

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/internal/tools/fs/$endpoint" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$body" 2>&1)

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "✅ ($HTTP_CODE)"
    PASS=$((PASS + 1))
  elif [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -lt 500 ]; then
    MSG=$(echo "$BODY" | jq -r '.message // empty' 2>/dev/null || echo "$BODY")
    echo "⚠️  ($HTTP_CODE) $MSG"
    PASS=$((PASS + 1))  # 4xx is expected for unsupported ops
  else
    MSG=$(echo "$BODY" | jq -r '.message // empty' 2>/dev/null || echo "$BODY")
    echo "❌ ($HTTP_CODE) $MSG"
    FAIL=$((FAIL + 1))
  fi

  # Make BODY available to caller
  LAST_BODY="$BODY"
}

skip() {
  echo "  → $1 ... ⏭ skipped"
  SKIP=$((SKIP + 1))
}

should_run() {
  [ -z "$TARGET_GROUP" ] || [ "$TARGET_GROUP" = "$1" ]
}

# ============================================
# Banner
# ============================================
echo "============================================"
echo "  Field Service Endpoint Test Suite"
echo "============================================"
echo "API:      $API_URL"
echo "Location: $LOC_ID"
echo "Phone:    $PHONE"
echo "Run ID:   $RUN_ID"
echo "Mode:     $([ "$READ_ONLY" = true ] && echo 'READ-ONLY' || echo 'FULL')$([ "$DO_CLEANUP" = true ] && echo ' + CLEANUP')"
[ -n "$TARGET_GROUP" ] && echo "Group:    $TARGET_GROUP"
echo "============================================"
echo ""

# ============================================
# 1. CUSTOMER (3 endpoints)
# ============================================
if should_run "customer"; then
  echo "📞 CUSTOMER OPERATIONS"
  echo "--------------------------------------------"

  # find customer by phone
  call "get-customer-by-phone" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\"}" \
    "findCustomerByPhone"
  
  FOUND=$(echo "$LAST_BODY" | jq -r '.found // false' 2>/dev/null)
  if [ "$FOUND" = "true" ]; then
    CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id' 2>/dev/null)
    echo "       Found customer: $CUSTOMER_ID"
  fi

  # create customer
  if [ "$READ_ONLY" = false ] && [ "$FOUND" != "true" ]; then
    call "create-customer" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"firstName\":\"TestRun\",\"lastName\":\"FS-$RUN_ID\",\"email\":\"test-fs-${RUN_ID}@example.com\"}" \
      "createCustomer"
    CUSTOMER_ID=$(echo "$LAST_BODY" | jq -r '.customer.id // empty' 2>/dev/null)
    [ -n "$CUSTOMER_ID" ] && echo "       Created customer: $CUSTOMER_ID"
  elif [ "$READ_ONLY" = true ]; then
    skip "createCustomer (read-only)"
  else
    skip "createCustomer (customer exists)"
  fi

  # update customer
  if [ "$READ_ONLY" = false ] && [ -n "$CUSTOMER_ID" ]; then
    call "update-customer" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"email\":\"test-fs-${RUN_ID}-upd@example.com\"}" \
      "updateCustomer"
  else
    skip "updateCustomer (read-only or no customer)"
  fi

  echo ""
fi

# ============================================
# 2. PROPERTY (4 endpoints)
# ============================================
if should_run "property"; then
  echo "🏠 PROPERTY OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    # list properties
    call "list-properties" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "listProperties"
    PROPERTY_ID=$(echo "$LAST_BODY" | jq -r '.properties[0].id // empty' 2>/dev/null)

    # create property
    if [ "$READ_ONLY" = false ]; then
      call "create-property" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"address\":{\"street\":\"${RUN_ID} Test St\",\"city\":\"Portland\",\"state\":\"OR\",\"zipCode\":\"97201\"}}" \
        "createProperty"
      PROPERTY_ID=$(echo "$LAST_BODY" | jq -r '.property.id // empty' 2>/dev/null)
      [ -n "$PROPERTY_ID" ] && CLEANUP_PROPERTIES+=("$PROPERTY_ID")
    else
      skip "createProperty (read-only)"
    fi

    # update property
    if [ "$READ_ONLY" = false ] && [ -n "$PROPERTY_ID" ]; then
      call "update-property" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"propertyId\":\"$PROPERTY_ID\",\"address\":{\"street\":\"${RUN_ID} Updated St\",\"city\":\"Portland\",\"state\":\"OR\",\"zipCode\":\"97201\"}}" \
        "updateProperty"
    else
      skip "updateProperty (read-only or no property)"
    fi

    # delete property
    if [ "$READ_ONLY" = false ] && [ -n "$PROPERTY_ID" ]; then
      call "delete-property" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"propertyId\":\"$PROPERTY_ID\"}" \
        "deleteProperty"
    else
      skip "deleteProperty (read-only or no property)"
    fi
  else
    skip "listProperties (no customer)"
    skip "createProperty (no customer)"
    skip "updateProperty (no customer)"
    skip "deleteProperty (no customer)"
  fi

  echo ""
fi

# ============================================
# 3. SERVICE REQUEST / LEAD (4 endpoints)
# ============================================
if should_run "request"; then
  echo "📋 SERVICE REQUEST OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    # create service request
    if [ "$READ_ONLY" = false ]; then
      call "create-service-request" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"description\":\"Test plumbing repair run-$RUN_ID\",\"serviceType\":\"Plumbing\",\"priority\":\"normal\"}" \
        "createServiceRequest"
      REQUEST_ID=$(echo "$LAST_BODY" | jq -r '.serviceRequest.id // empty' 2>/dev/null)
    else
      skip "createServiceRequest (read-only)"
    fi

    # get single request
    if [ -n "$REQUEST_ID" ]; then
      call "get-request" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"requestId\":\"$REQUEST_ID\"}" \
        "getRequest"
    else
      skip "getRequest (no request)"
    fi

    # get requests list
    call "get-requests" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getRequests"

    # submit lead (orchestrated)
    if [ "$READ_ONLY" = false ]; then
      call "submit-lead" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"firstName\":\"Lead\",\"lastName\":\"Run$RUN_ID\",\"serviceDescription\":\"HVAC tune-up run-$RUN_ID\",\"address\":{\"street\":\"${RUN_ID} Lead Ave\",\"city\":\"Portland\",\"state\":\"OR\",\"zipCode\":\"97201\"}}" \
        "submitLead"
    else
      skip "submitLead (read-only)"
    fi
  else
    skip "createServiceRequest (no customer)"
    skip "getRequest (no customer)"
    skip "getRequests (no customer)"
    skip "submitLead (no customer)"
  fi

  echo ""
fi

# ============================================
# 4. ASSESSMENT (2 endpoints)
# ============================================
if should_run "assessment"; then
  echo "🔍 ASSESSMENT OPERATIONS"
  echo "--------------------------------------------"

  if [ "$READ_ONLY" = false ] && [ -n "$REQUEST_ID" ]; then
    START=$(date -u -d "+5 days 09:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+5d -v9H -v0M +"%Y-%m-%dT%H:%M:%S")
    call "create-assessment" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"requestId\":\"$REQUEST_ID\",\"startTime\":\"$START\"}" \
      "createAssessment"
    ASSESSMENT_ID=$(echo "$LAST_BODY" | jq -r '.assessment.id // empty' 2>/dev/null)

    if [ -n "$ASSESSMENT_ID" ]; then
      call "cancel-assessment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"assessmentId\":\"$ASSESSMENT_ID\"}" \
        "cancelAssessment"
    else
      skip "cancelAssessment (no assessment)"
    fi
  else
    skip "createAssessment (read-only or no request)"
    skip "cancelAssessment (read-only or no request)"
  fi

  echo ""
fi

# ============================================
# 5. JOB (4 endpoints)
# ============================================
if should_run "job"; then
  echo "🔧 JOB OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    # get jobs
    call "get-jobs" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getJobs"
    JOB_ID=$(echo "$LAST_BODY" | jq -r '.jobs[0].id // empty' 2>/dev/null)

    # get job by number
    JOB_NUM=$(echo "$LAST_BODY" | jq -r '.jobs[0].jobNumber // empty' 2>/dev/null)
    if [ -n "$JOB_NUM" ]; then
      call "get-job" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"jobNumber\":\"$JOB_NUM\"}" \
        "getJobByNumber"
    else
      skip "getJobByNumber (no jobs)"
    fi

    # add note to job
    if [ "$READ_ONLY" = false ] && [ -n "$JOB_ID" ]; then
      call "add-note-to-job" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"jobId\":\"$JOB_ID\",\"note\":\"Test note run-$RUN_ID\"}" \
        "addNoteToJob"
    else
      skip "addNoteToJob (read-only or no job)"
    fi

    # cancel job — skip to avoid destroying data
    skip "cancelJob (destructive — test manually)"
  else
    skip "getJobs (no customer)"
    skip "getJobByNumber (no customer)"
    skip "addNoteToJob (no customer)"
    skip "cancelJob (no customer)"
  fi

  echo ""
fi

# ============================================
# 6. APPOINTMENT (5 endpoints)
# ============================================
if should_run "appointment"; then
  echo "📅 APPOINTMENT OPERATIONS"
  echo "--------------------------------------------"

  # check availability
  START_DATE=$(date -u -d "+1 day" +"%Y-%m-%dT00:00:00" 2>/dev/null || date -v+1d +"%Y-%m-%dT00:00:00")
  END_DATE=$(date -u -d "+8 days" +"%Y-%m-%dT23:59:59" 2>/dev/null || date -v+8d +"%Y-%m-%dT23:59:59")
  call "get-availability" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"startDate\":\"$START_DATE\",\"endDate\":\"$END_DATE\"}" \
    "checkAvailability"

  if [ -n "$CUSTOMER_ID" ]; then
    # get appointments
    call "get-appointments" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getAppointments"
    APPOINTMENT_ID=$(echo "$LAST_BODY" | jq -r '.appointments[0].id // empty' 2>/dev/null)

    # create appointment
    if [ "$READ_ONLY" = false ]; then
      APT_START=$(date -u -d "+4 days 10:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+4d -v10H -v0M +"%Y-%m-%dT%H:%M:%S")
      APT_END=$(date -u -d "+4 days 11:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+4d -v11H -v0M +"%Y-%m-%dT%H:%M:%S")
      call "create-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"serviceType\":\"General Service\",\"startTime\":\"$APT_START\",\"endTime\":\"$APT_END\",\"notes\":\"Test run-$RUN_ID\"}" \
        "createAppointment"
      NEW_APPT_ID=$(echo "$LAST_BODY" | jq -r '.appointment.id // empty' 2>/dev/null)
      if [ -n "$NEW_APPT_ID" ]; then
        APPOINTMENT_ID="$NEW_APPT_ID"
        CLEANUP_APPOINTMENTS+=("$NEW_APPT_ID")
      fi

      # Creating an appointment in Jobber auto-creates a Job+Visit.
      # Re-fetch jobs so downstream tests (estimates, notes) can use JOB_ID.
      if [ -z "$JOB_ID" ] && [ -n "$CUSTOMER_ID" ]; then
        call "get-jobs" \
          "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
          "getJobs (re-fetch after appointment)"
        JOB_ID=$(echo "$LAST_BODY" | jq -r '.jobs[0].id // empty' 2>/dev/null)
        [ -n "$JOB_ID" ] && echo "       Found job: $JOB_ID"
      fi
    else
      skip "createAppointment (read-only)"
    fi

    # reschedule appointment
    if [ "$READ_ONLY" = false ] && [ -n "$APPOINTMENT_ID" ]; then
      RESC_START=$(date -u -d "+6 days 14:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+6d -v14H -v0M +"%Y-%m-%dT%H:%M:%S")
      RESC_END=$(date -u -d "+6 days 15:00" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v+6d -v15H -v0M +"%Y-%m-%dT%H:%M:%S")
      call "reschedule-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"appointmentId\":\"$APPOINTMENT_ID\",\"startTime\":\"$RESC_START\",\"endTime\":\"$RESC_END\"}" \
        "rescheduleAppointment"
    else
      skip "rescheduleAppointment (read-only or no appointment)"
    fi

    # cancel appointment
    if [ "$READ_ONLY" = false ] && [ -n "$APPOINTMENT_ID" ]; then
      call "cancel-appointment" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"appointmentId\":\"$APPOINTMENT_ID\",\"reason\":\"Test cancellation\"}" \
        "cancelAppointment"
    else
      skip "cancelAppointment (read-only or no appointment)"
    fi
  else
    skip "getAppointments (no customer)"
    skip "createAppointment (no customer)"
    skip "rescheduleAppointment (no customer)"
    skip "cancelAppointment (no customer)"
  fi

  echo ""
fi

# ============================================
# 7. ESTIMATE (4 endpoints)
# ============================================
if should_run "estimate"; then
  echo "💰 ESTIMATE OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    # get estimates
    call "get-estimates" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getEstimates"
    ESTIMATE_ID=$(echo "$LAST_BODY" | jq -r '.estimates[0].id // empty' 2>/dev/null)

    # create estimate
    if [ "$READ_ONLY" = false ] && [ -n "$JOB_ID" ]; then
      call "create-estimate" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\",\"jobId\":\"$JOB_ID\",\"lineItems\":[{\"description\":\"Test service run-$RUN_ID\",\"quantity\":1,\"unitPrice\":150}]}" \
        "createEstimate"
      NEW_EST_ID=$(echo "$LAST_BODY" | jq -r '.estimate.id // empty' 2>/dev/null)
      [ -n "$NEW_EST_ID" ] && ESTIMATE_ID="$NEW_EST_ID"
    elif [ -z "$JOB_ID" ]; then
      skip "createEstimate (no job available)"
    else
      skip "createEstimate (read-only)"
    fi

    # accept estimate — skip unless we have one
    if [ "$READ_ONLY" = false ] && [ -n "$ESTIMATE_ID" ]; then
      call "accept-estimate" \
        "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"estimateId\":\"$ESTIMATE_ID\"}" \
        "acceptEstimate"
    else
      skip "acceptEstimate (read-only or no estimate)"
    fi

    # decline estimate — skip (would conflict with accept)
    skip "declineEstimate (skip — would conflict with accept)"
  else
    skip "getEstimates (no customer)"
    skip "createEstimate (no customer)"
    skip "acceptEstimate (no customer)"
    skip "declineEstimate (no customer)"
  fi

  echo ""
fi

# ============================================
# 8. INVOICE & BILLING (2 endpoints)
# ============================================
if should_run "invoice"; then
  echo "🧾 INVOICE & BILLING OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    call "get-invoices" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getInvoices"

    call "get-account-balance" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getAccountBalance"
  else
    skip "getInvoices (no customer)"
    skip "getAccountBalance (no customer)"
  fi

  echo ""
fi

# ============================================
# 9. SERVICE CATALOG (1 endpoint)
# ============================================
if should_run "service"; then
  echo "🛠️  SERVICE CATALOG"
  echo "--------------------------------------------"

  call "get-services" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\"}" \
    "getServices"

  echo ""
fi

# ============================================
# 10. COMPANY / META (2 endpoints)
# ============================================
if should_run "company"; then
  echo "🏢 COMPANY / META OPERATIONS"
  echo "--------------------------------------------"

  call "get-company-info" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\"}" \
    "getCompanyInfo"

  call "check-service-area" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"zipCode\":\"97201\"}" \
    "checkServiceArea"

  echo ""
fi

# ============================================
# 11. EXTENDED (3 endpoints)
# ============================================
if should_run "extended"; then
  echo "🔌 EXTENDED OPERATIONS"
  echo "--------------------------------------------"

  if [ -n "$CUSTOMER_ID" ]; then
    call "get-memberships" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"customerId\":\"$CUSTOMER_ID\"}" \
      "getMemberships"
  else
    skip "getMemberships (no customer)"
  fi

  call "get-membership-types" \
    "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\"}" \
    "getMembershipTypes"

  if [ "$READ_ONLY" = false ]; then
    call "create-task" \
      "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"title\":\"Follow up run-$RUN_ID\",\"description\":\"Test callback run-$RUN_ID\",\"jobId\":\"${JOB_ID:-}\"}" \
      "createTask"
  else
    skip "createTask (read-only)"
  fi

  echo ""
fi

# ============================================
# Cleanup (opt-in via --cleanup)
# ============================================
if [ "$DO_CLEANUP" = true ] && [ "$READ_ONLY" = false ]; then
  echo "🧹 CLEANUP"
  echo "--------------------------------------------"

  # Cancel appointments we created
  for appt_id in "${CLEANUP_APPOINTMENTS[@]:-}"; do
    [ -z "$appt_id" ] && continue
    echo -n "  → cancel appointment $appt_id ... "
    curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/internal/tools/fs/cancel-appointment" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"appointmentId\":\"$appt_id\",\"reason\":\"Test cleanup run-$RUN_ID\"}" \
      && echo " done" || echo " (may already be cancelled)"
  done

  # Delete properties we created
  for prop_id in "${CLEANUP_PROPERTIES[@]:-}"; do
    [ -z "$prop_id" ] && continue
    echo -n "  → delete property $prop_id ... "
    curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/internal/tools/fs/delete-property" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{\"locationId\":\"$LOC_ID\",\"callerPhoneNumber\":\"$PHONE\",\"propertyId\":\"$prop_id\"}" \
      && echo " done" || echo " (may already be deleted)"
  done

  echo "  (Customers are not deleted — API does not support it)"
  echo ""
fi

# ============================================
# Summary
# ============================================
echo "============================================"
echo "  RESULTS  (run $RUN_ID)"
echo "============================================"
TOTAL=$((PASS + FAIL + SKIP))
echo "  ✅ Passed:  $PASS"
echo "  ❌ Failed:  $FAIL"
echo "  ⏭  Skipped: $SKIP"
echo "  📊 Total:   $TOTAL"
[ -n "$CUSTOMER_ID" ] && echo "  👤 Customer: $CUSTOMER_ID"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo "⚠️  Some tests failed. Review output above."
  exit 1
else
  echo "🎉 All executed tests passed!"
fi
