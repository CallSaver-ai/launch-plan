#!/bin/bash

# Test script for Jobber endpoints
# Run locally against localhost:3002

set -e

# Configuration - UPDATE THESE
export API_URL="http://localhost:3002"
export API_KEY="${INTERNAL_API_KEY:-ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7}"
export LOC_ID="${LOCATION_ID:-}"  # Set your test location ID
export PHONE="+15551234567"  # Use a test number

if [ -z "$LOC_ID" ]; then
  echo "❌ Error: LOCATION_ID environment variable not set"
  echo "Usage: LOCATION_ID=<your-location-id> ./test-jobber-endpoints.sh"
  exit 1
fi

echo "🧪 Testing Jobber Endpoints"
echo "================================"
echo "API URL: $API_URL"
echo "Location ID: $LOC_ID"
echo "Test Phone: $PHONE"
echo ""

# Step 1: Look up caller (should return found: false)
echo "📞 Step 1: Looking up caller (should not exist yet)..."
LOOKUP_RESULT=$(curl -s -X POST "$API_URL/internal/tools/jobber-get-customer-by-phone" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\"}")

echo "$LOOKUP_RESULT" | jq .
FOUND=$(echo "$LOOKUP_RESULT" | jq -r '.found')

if [ "$FOUND" = "false" ]; then
  echo "✅ Caller not found (expected)"
else
  echo "⚠️  Caller already exists - will skip creation"
  CUSTOMER_ID=$(echo "$LOOKUP_RESULT" | jq -r '.customer.id')
fi

echo ""

# Step 2: Create the client (only if not found)
if [ "$FOUND" = "false" ]; then
  echo "👤 Step 2: Creating new client..."
  CREATE_RESULT=$(curl -s -X POST "$API_URL/internal/tools/jobber-create-customer" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\", \"firstName\": \"Test\", \"lastName\": \"Caller\", \"email\": \"test@example.com\"}")

  echo "$CREATE_RESULT" | jq .
  CUSTOMER_ID=$(echo "$CREATE_RESULT" | jq -r '.customer.id')
  
  if [ -z "$CUSTOMER_ID" ] || [ "$CUSTOMER_ID" = "null" ]; then
    echo "❌ Failed to create customer"
    exit 1
  fi
  
  echo "✅ Customer created: $CUSTOMER_ID"
  echo ""
fi

# Step 3: Schedule a visit (creates Job + Visit)
echo "📅 Step 3: Scheduling a visit..."
START_TIME=$(date -u -d "+3 days 09:00" +"%Y-%m-%dT%H:%M:%S-08:00")
END_TIME=$(date -u -d "+3 days 10:30" +"%Y-%m-%dT%H:%M:%S-08:00")

APPOINTMENT_RESULT=$(curl -s -X POST "$API_URL/internal/tools/jobber-create-appointment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"customerId\": \"$CUSTOMER_ID\",
    \"serviceType\": \"Lawn Care\",
    \"startTime\": \"$START_TIME\",
    \"endTime\": \"$END_TIME\",
    \"notes\": \"Test visit created by API test script\"
  }")

echo "$APPOINTMENT_RESULT" | jq .
APPOINTMENT_ID=$(echo "$APPOINTMENT_RESULT" | jq -r '.appointment.id')

if [ -z "$APPOINTMENT_ID" ] || [ "$APPOINTMENT_ID" = "null" ]; then
  echo "❌ Failed to create appointment"
  exit 1
fi

echo "✅ Appointment created: $APPOINTMENT_ID"
echo ""

# Step 4: Look up caller again (should now return found: true)
echo "🔍 Step 4: Looking up caller again (should now exist)..."
LOOKUP2_RESULT=$(curl -s -X POST "$API_URL/internal/tools/jobber-get-customer-by-phone" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\"}")

echo "$LOOKUP2_RESULT" | jq .
FOUND2=$(echo "$LOOKUP2_RESULT" | jq -r '.found')

if [ "$FOUND2" = "true" ]; then
  echo "✅ Caller found (expected)"
else
  echo "❌ Caller not found (unexpected)"
  exit 1
fi

echo ""

# Step 5: Get appointments (should return the visit we just created)
echo "📋 Step 5: Getting appointments..."
APPOINTMENTS_RESULT=$(curl -s -X POST "$API_URL/internal/tools/jobber-get-appointments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{
    \"locationId\": \"$LOC_ID\",
    \"callerPhoneNumber\": \"$PHONE\",
    \"customerId\": \"$CUSTOMER_ID\"
  }")

echo "$APPOINTMENTS_RESULT" | jq .
APPOINTMENT_COUNT=$(echo "$APPOINTMENTS_RESULT" | jq -r '.appointments | length')

if [ "$APPOINTMENT_COUNT" -gt 0 ]; then
  echo "✅ Found $APPOINTMENT_COUNT appointment(s)"
else
  echo "❌ No appointments found (unexpected)"
  exit 1
fi

echo ""
echo "================================"
echo "🎉 All tests passed!"
echo ""
echo "Next steps:"
echo "1. Log into https://app.getjobber.com"
echo "2. Check Clients → 'Test Caller' should appear"
echo "3. Check Schedule → Visit on $(date -d "+3 days" +"%B %d") should appear"
echo ""
echo "Customer ID: $CUSTOMER_ID"
echo "Appointment ID: $APPOINTMENT_ID"
