#!/bin/bash
# =============================================================================
# Housecall Pro Sandbox Seeder & Tool Tester
# =============================================================================
#
# Comprehensive test suite for the Housecall Pro field-service integration.
# Tests all endpoints through the internal tools API (same path as voice agent).
#
# Phases:
#   0: Preflight — verify API reachable, get company info, service zones
#   1: Seed — get services, create customers, properties, service requests
#   2: Test get-services (price book)
#   3: Test check-service-area (zip code based)
#   4: Test get-company-info
#   5: Test customer CRUD
#   6: Test property CRUD
#   7: Test service request flow
#   8: Test jobs & appointments
#   9: Test submit-lead (E2E new caller)
#  10: Test get-client-schedule
#
# Usage:
#   ./testing/seed-and-test-hcp.sh seed     # Seed only
#   ./testing/seed-and-test-hcp.sh test     # Test only (assumes seeded)
#   ./testing/seed-and-test-hcp.sh all      # Seed + test
#   ./testing/seed-and-test-hcp.sh direct   # Direct HCP API tests (no server needed)
#   ./testing/seed-and-test-hcp.sh guide    # Print voice agent test guide
# =============================================================================

set -euo pipefail

BASE_URL="http://localhost:3000/internal/tools/fs"
API_KEY="ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7"
LOCATION_ID="cmloxy8vs000ar801ma3wz6s3"

# Housecall Pro API key (for direct API tests)
HCP_API_KEY="7bce761fb72a40a6a3cce71c9ca015c1"
HCP_BASE_URL="https://api.housecallpro.com"

YOUR_PHONE="+18313345344"

SEED_PHONE_1="+15551000001"
SEED_PHONE_2="+15551000002"
SEED_PHONE_3="+15551000003"
SEED_PHONE_4="+15551000004"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STATE_FILE="/tmp/hcp-seed-state.json"
PASSED=0
FAILED=0

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

call_api() {
  local endpoint="$1" body="$2" label="${3:-$endpoint}"
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
    echo -e "${GREEN}✅ ${label}${NC} (HTTP ${http_code})" >&2
  else
    echo -e "${RED}❌ ${label}${NC} (HTTP ${http_code})" >&2
    echo -e "${RED}   Response: $(echo "$body_response" | head -c 200)${NC}" >&2
  fi
  echo "$body_response"
}

call_api_status() {
  local endpoint="$1" body="$2" label="${3:-$endpoint}"
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/${endpoint}" \
    -H "Content-Type: application/json" \
    -H "x-internal-api-key: ${API_KEY}" \
    -d "$body")
  local http_code
  http_code=$(echo "$response" | tail -n1)
  echo "$http_code"
}

call_hcp_direct() {
  local path="$1" label="${2:-$path}"
  local params="${3:-}"
  local url="${HCP_BASE_URL}${path}"
  if [ -n "$params" ]; then
    url="${url}?${params}"
  fi
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X GET "$url" \
    -H "Accept: application/json" \
    -H "Authorization: Token ${HCP_API_KEY}")
  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body_response
  body_response=$(echo "$response" | sed '$d')
  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo -e "${GREEN}✅ ${label}${NC} (HTTP ${http_code})" >&2
  else
    echo -e "${RED}❌ ${label}${NC} (HTTP ${http_code})" >&2
  fi
  echo "$body_response"
}

future_date() {
  date -d "+${1} days" "+%Y-%m-%d" 2>/dev/null || date -v+${1}d "+%Y-%m-%d" 2>/dev/null
}

future_datetime() {
  local days=$1 hour=$2 minute=${3:-0}
  date -d "+${days} days" "+%Y-%m-%dT$(printf '%02d' $hour):$(printf '%02d' $minute):00" 2>/dev/null || \
  date -v+${days}d "+%Y-%m-%dT$(printf '%02d' $hour):$(printf '%02d' $minute):00" 2>/dev/null
}

today_date() {
  date "+%Y-%m-%d" 2>/dev/null
}

next_business_day() {
  local nth=$1 count=0 days=0
  while [ "$count" -lt "$nth" ]; do
    days=$((days + 1))
    local dow
    dow=$(date -d "+${days} days" "+%w" 2>/dev/null || date -v+${days}d "+%w" 2>/dev/null)
    [ "$dow" != "0" ] && [ "$dow" != "6" ] && count=$((count + 1))
  done
  echo "$days"
}

day_name() {
  date -d "+${1} days" "+%A" 2>/dev/null || date -v+${1}d "+%A" 2>/dev/null
}

assert_gte() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" -ge "$expected" ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ ${label} (${actual} >= ${expected})${NC}"
    ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ ${label}: expected >= ${expected}, got '${actual}'${NC}"
    ((FAILED++)) || true
  fi
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    echo -e "  ${GREEN}✓ ${label} (${actual})${NC}"
    ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ ${label}: expected '${expected}', got '${actual}'${NC}"
    ((FAILED++)) || true
  fi
}

assert_not_empty() {
  local value="$1" label="$2"
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    echo -e "  ${GREEN}✓ ${label}${NC}"
    ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ ${label}: empty or null${NC}"
    ((FAILED++)) || true
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -qi "$needle"; then
    echo -e "  ${GREEN}✓ ${label}${NC}"
    ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ ${label}: '${haystack}' does not contain '${needle}'${NC}"
    ((FAILED++)) || true
  fi
}

assert_http_ok() {
  local status="$1" label="$2"
  if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
    echo -e "  ${GREEN}✓ ${label} (HTTP ${status})${NC}"
    ((PASSED++)) || true
  else
    echo -e "  ${RED}✗ ${label}: HTTP ${status}${NC}"
    ((FAILED++)) || true
  fi
}

phase_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  PHASE ${1}: ${2}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# ─────────────────────────────────────────────────────────────
# Phase 0: Preflight
# ─────────────────────────────────────────────────────────────

preflight() {
  phase_header "0" "PREFLIGHT"
  command -v jq &>/dev/null || { echo -e "${RED}❌ jq required${NC}"; exit 1; }
  echo -e "${GREEN}✅ jq installed${NC}"

  local h
  h=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/get-services" \
    -X POST -H "Content-Type: application/json" -H "x-internal-api-key: ${API_KEY}" \
    -d "{\"locationId\": \"${LOCATION_ID}\"}")
  if [[ "$h" -ge 200 && "$h" -lt 300 ]]; then
    echo -e "${GREEN}✅ API reachable (HTTP ${h})${NC}"
  else
    echo -e "${RED}❌ API returned HTTP ${h}${NC}"; exit 1
  fi
}

# ─────────────────────────────────────────────────────────────
# Direct HCP API Tests (no server needed)
# ─────────────────────────────────────────────────────────────

direct_tests() {
  phase_header "D1" "DIRECT HCP API — COMPANY"
  local comp
  comp=$(call_hcp_direct "/company" "GET /company")
  local comp_name
  comp_name=$(echo "$comp" | jq -r '.name // empty' 2>/dev/null)
  assert_not_empty "$comp_name" "D1: Company name"
  echo -e "  ${CYAN}Company: ${comp_name}${NC}"
  local comp_tz
  comp_tz=$(echo "$comp" | jq -r '.time_zone // empty' 2>/dev/null)
  assert_not_empty "$comp_tz" "D1b: Company timezone"
  echo -e "  ${CYAN}Timezone: ${comp_tz}${NC}"

  phase_header "D2" "DIRECT HCP API — SERVICE ZONES"
  local zones
  zones=$(call_hcp_direct "/service_zones" "GET /service_zones" "page_size=50")
  local zone_count
  zone_count=$(echo "$zones" | jq '.service_zones | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Total zones: ${zone_count}${NC}"
  assert_gte "$zone_count" 0 "D2: service_zones array exists"

  if [ "$zone_count" -gt 0 ]; then
    echo -e "  ${CYAN}Zones:${NC}"
    echo "$zones" | jq -r '.service_zones[] | "    - \(.name) (zips: \(.zip_codes | join(", ")), cities: \(.cities | map(.city) | join(", ")))"' 2>/dev/null
  fi

  # Test zip code filter
  echo -e "${YELLOW}── D2b: Filter by zip code 95065 ──${NC}"
  local zones_zip
  zones_zip=$(call_hcp_direct "/service_zones" "GET /service_zones?zip_code=95065" "zip_code=95065")
  local zones_zip_count
  zones_zip_count=$(echo "$zones_zip" | jq '.service_zones | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Zones matching 95065: ${zones_zip_count}${NC}"

  phase_header "D3" "DIRECT HCP API — PRICE BOOK SERVICES"
  local svcs
  svcs=$(call_hcp_direct "/api/price_book/services" "GET /api/price_book/services (page 1)" "page_size=50")
  local svc_count
  svc_count=$(echo "$svcs" | jq '.data | length' 2>/dev/null || echo 0)
  local svc_total
  svc_total=$(echo "$svcs" | jq '.total_count // 0' 2>/dev/null || echo 0)
  local svc_pages
  svc_pages=$(echo "$svcs" | jq '.total_pages_count // 1' 2>/dev/null || echo 1)
  echo -e "  ${CYAN}Page 1: ${svc_count} services (total: ${svc_total}, pages: ${svc_pages})${NC}"
  assert_gte "$svc_count" 1 "D3: Has services"

  # Show first 5 services
  echo -e "  ${CYAN}Sample services:${NC}"
  echo "$svcs" | jq -r '.data[:5][] | "    - \(.name) [$\(.price)] (\(.category.name // "uncategorized"))"' 2>/dev/null

  if [ "$svc_pages" -gt 1 ]; then
    echo -e "${YELLOW}── D3b: Page 2 ──${NC}"
    local svcs2
    svcs2=$(call_hcp_direct "/api/price_book/services" "GET /api/price_book/services (page 2)" "page_size=50&page=2")
    local svc_count2
    svc_count2=$(echo "$svcs2" | jq '.data | length' 2>/dev/null || echo 0)
    echo -e "  ${CYAN}Page 2: ${svc_count2} services${NC}"
    assert_gte "$svc_count2" 1 "D3b: Page 2 has services"
  fi

  phase_header "D4" "DIRECT HCP API — CUSTOMERS"
  local custs
  custs=$(call_hcp_direct "/customers" "GET /customers" "page_size=5")
  local cust_count
  cust_count=$(echo "$custs" | jq '.customers | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Customers (first page): ${cust_count}${NC}"
  if [ "$cust_count" -gt 0 ]; then
    echo "$custs" | jq -r '.customers[:3][] | "    - \(.first_name) \(.last_name) (\(.id))"' 2>/dev/null
  fi

  phase_header "D5" "DIRECT HCP API — JOBS"
  local jobs
  jobs=$(call_hcp_direct "/jobs" "GET /jobs" "page_size=5")
  local job_count
  job_count=$(echo "$jobs" | jq '.jobs | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Jobs (first page): ${job_count}${NC}"
  if [ "$job_count" -gt 0 ]; then
    echo "$jobs" | jq -r '.jobs[:3][] | "    - \(.id): \(.description // "no desc") [\(.work_status // "unknown")]"' 2>/dev/null
  fi

  phase_header "D6" "DIRECT HCP API — LEADS"
  local leads
  leads=$(call_hcp_direct "/leads" "GET /leads" "page_size=5")
  local lead_count
  lead_count=$(echo "$leads" | jq '.leads | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}Leads (first page): ${lead_count}${NC}"

  # Results
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  DIRECT API TEST RESULTS${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
  echo -e "  ${RED}Failed: ${FAILED}${NC}"
  echo ""
}

# ─────────────────────────────────────────────────────────────
# Phase 1: Seed
# ─────────────────────────────────────────────────────────────

seed() {
  phase_header "1" "SEED HCP SANDBOX"
  echo '{}' > "$STATE_FILE"

  # Step 1: Services
  echo -e "${CYAN}── Services ──${NC}"
  local svc_resp
  svc_resp=$(call_api "get-services" "{\"locationId\": \"${LOCATION_ID}\"}" "get-services")
  local svc_count
  svc_count=$(echo "$svc_resp" | jq '.services | length' 2>/dev/null || echo "0")
  echo "  Found ${svc_count} services"

  # Pick some services by name
  local pm_id sv_id
  pm_id=$(echo "$svc_resp" | jq -r '[.services[] | select(.name | test("Preventative Maintenance";"i"))][0].id // empty' 2>/dev/null)
  sv_id=$(echo "$svc_resp" | jq -r '[.services[] | select(.name | test("Service Visit";"i"))][0].id // empty' 2>/dev/null)
  echo "  IDs: pm=${pm_id:-N/A} sv=${sv_id:-N/A}"

  echo "$svc_resp" | jq '.' > /tmp/hcp-services.json 2>/dev/null || true

  jq --arg pm "$pm_id" --arg sv "$sv_id" --argjson count "$svc_count" \
    '. + {services: {preventative_maintenance: $pm, service_visit: $sv, count: $count}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo ""

  # Step 2: Clients
  echo -e "${CYAN}── Clients ──${NC}"
  mk_client() {
    local ph="$1" fn="$2" ln="$3" em="$4"
    local r
    r=$(call_api "create-customer" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${ph}\",\"firstName\":\"${fn}\",\"lastName\":\"${ln}\",\"email\":\"${em}\"}" "Create: ${fn} ${ln}")
    echo "$r" | jq -r '.customer.id // empty'
  }
  local c1 c2 c3 c4
  c1=$(mk_client "$SEED_PHONE_1" "Maria" "Garcia" "maria.hcp@example.com")
  c2=$(mk_client "$SEED_PHONE_2" "James" "Wilson" "james.hcp@example.com")
  c3=$(mk_client "$SEED_PHONE_3" "Sarah" "Chen" "sarah.hcp@example.com")
  c4=$(mk_client "$SEED_PHONE_4" "Robert" "Johnson" "robert.hcp@example.com")
  echo "  IDs: c1=${c1} c2=${c2} c3=${c3} c4=${c4}"
  jq --arg c1 "$c1" --arg c2 "$c2" --arg c3 "$c3" --arg c4 "$c4" \
    '. + {clients: {maria: $c1, james: $c2, sarah: $c3, robert: $c4}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo ""

  # Step 3: Properties
  echo -e "${CYAN}── Properties ──${NC}"
  mk_prop() {
    local ph="$1" cid="$2" st="$3" ci="$4" s="$5" z="$6" lbl="$7"
    local r
    r=$(call_api "create-property" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${ph}\",\"customerId\":\"${cid}\",\"address\":{\"street\":\"${st}\",\"city\":\"${ci}\",\"state\":\"${s}\",\"zip\":\"${z}\"}}" "Property: ${lbl}")
    echo "$r" | jq -r '.property.id // empty'
  }
  local p1 p2 p3 p4
  p1=$(mk_prop "$SEED_PHONE_1" "$c1" "456 Oak Ave" "Santa Cruz" "CA" "95065" "Maria")
  p2=$(mk_prop "$SEED_PHONE_2" "$c2" "789 Pine St" "Santa Cruz" "CA" "95065" "James")
  p3=$(mk_prop "$SEED_PHONE_3" "$c3" "321 Elm Dr" "Capitola" "CA" "95010" "Sarah")
  p4=$(mk_prop "$SEED_PHONE_4" "$c4" "555 Walnut Blvd" "Aptos" "CA" "95003" "Robert")
  jq --arg p1 "$p1" --arg p2 "$p2" --arg p3 "$p3" --arg p4 "$p4" \
    '. + {properties: {maria: $p1, james: $p2, sarah: $p3, robert: $p4}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo ""

  # Step 4: Service Requests (creates leads in HCP)
  # NOTE: Only creating 1 lead (Maria) because leads are very hard to delete in HCP.
  # Customers and properties are easy to delete, but leads persist.
  # The API auto-converts lead → estimate (HCP's equivalent of Jobber Assessment).
  echo -e "${CYAN}── Service Requests (1 lead only — leads are hard to delete in HCP) ──${NC}"
  local sr1_resp
  sr1_resp=$(call_api "create-service-request" \
    "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\",\"description\":\"Kitchen sink leaking\",\"serviceType\":\"Leak Repair\",\"propertyId\":\"${p1}\"${pm_id:+,\"serviceId\":\"${pm_id}\"}}" \
    "Request: Maria/Leak")
  local sr1 est1
  sr1=$(echo "$sr1_resp" | jq -r '.serviceRequest.id // empty')
  est1=$(echo "$sr1_resp" | jq -r '.assessmentId // empty')
  echo "  Lead ID: ${sr1}"
  echo "  Estimate ID (assessment): ${est1:-none}"
  local sr1_addr
  sr1_addr=$(echo "$sr1_resp" | jq -r '.serviceRequest.address.street // "No address"')
  echo "  Lead address: ${sr1_addr}"
  jq --arg sr1 "$sr1" --arg est1 "$est1" \
    '. + {requests: {maria: $sr1}, estimates: {maria: $est1}}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo ""

  echo -e "${GREEN}  SEEDING COMPLETE${NC}"
  echo "  State: ${STATE_FILE}"
  jq . "$STATE_FILE"
  echo ""
  echo -e "  ⏳ Waiting 3s for HCP propagation..."
  sleep 3
}

# ─────────────────────────────────────────────────────────────
# Test Phases 2-10
# ─────────────────────────────────────────────────────────────

run_tests() {
  [ -f "$STATE_FILE" ] || { echo -e "${RED}❌ No state file. Run seed first.${NC}"; exit 1; }

  local c1 c2 c3 c4
  c1=$(jq -r '.clients.maria' "$STATE_FILE")
  c2=$(jq -r '.clients.james' "$STATE_FILE")
  c3=$(jq -r '.clients.sarah' "$STATE_FILE")
  c4=$(jq -r '.clients.robert' "$STATE_FILE")
  local p1 p2 p3 p4
  p1=$(jq -r '.properties.maria' "$STATE_FILE")
  p2=$(jq -r '.properties.james' "$STATE_FILE")
  p3=$(jq -r '.properties.sarah' "$STATE_FILE")
  p4=$(jq -r '.properties.robert' "$STATE_FILE")
  local sr1
  sr1=$(jq -r '.requests.maria' "$STATE_FILE")

  # ═══════════════════════════════════════════════════════════
  # Phase 2: get-services (Price Book)
  # ═══════════════════════════════════════════════════════════
  phase_header "2" "GET-SERVICES (PRICE BOOK)"

  echo -e "${YELLOW}── S1: Returns services ──${NC}"
  local sv
  sv=$(call_api "get-services" "{\"locationId\":\"${LOCATION_ID}\"}" "get-services")
  local sc
  sc=$(echo "$sv" | jq '.services | length' 2>/dev/null || echo 0)
  assert_gte "$sc" 1 "S1: service count >= 1"
  echo -e "  ${CYAN}Found ${sc} services${NC}"

  echo -e "${YELLOW}── S2: All have IDs ──${NC}"
  local si
  si=$(echo "$sv" | jq '[.services[] | select(.id != null and .id != "")] | length' 2>/dev/null || echo 0)
  assert_eq "$si" "$sc" "S2: all services have .id"

  echo -e "${YELLOW}── S3: Services have names ──${NC}"
  local sn
  sn=$(echo "$sv" | jq '[.services[] | select(.name != null and .name != "")] | length' 2>/dev/null || echo 0)
  assert_eq "$sn" "$sc" "S3: all services have .name"

  echo -e "${YELLOW}── S4: Price info ──${NC}"
  local sp
  sp=$(echo "$sv" | jq '[.services[] | select(.price != null)] | length' 2>/dev/null || echo 0)
  echo -e "  ${CYAN}ℹ ${sp}/${sc} services have price${NC}"

  echo -e "${YELLOW}── S5: Category info ──${NC}"
  local categories
  categories=$(echo "$sv" | jq -r '[.services[].category] | unique | join(", ")' 2>/dev/null || echo "none")
  echo -e "  ${CYAN}Categories: ${categories}${NC}"

  # ═══════════════════════════════════════════════════════════
  # Phase 3: check-service-area (zip code)
  # ═══════════════════════════════════════════════════════════
  phase_header "3" "CHECK-SERVICE-AREA (ZIP CODE)"

  echo -e "${YELLOW}── SA1: Known zip code (95065) ──${NC}"
  local sa1
  sa1=$(call_api "check-service-area" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"zipCode\":\"95065\"}" "check-service-area 95065")
  local sa1_serviced
  sa1_serviced=$(echo "$sa1" | jq -r '.isServiced // false' 2>/dev/null)
  assert_eq "$sa1_serviced" "true" "SA1: 95065 is serviced"
  local sa1_zone
  sa1_zone=$(echo "$sa1" | jq -r '.matchedZone // empty' 2>/dev/null)
  echo -e "  ${CYAN}Zone: ${sa1_zone}${NC}"
  echo -e "  ${CYAN}Message: $(echo "$sa1" | jq -r '.message // empty' 2>/dev/null)${NC}"

  echo -e "${YELLOW}── SA2: Unknown zip code (99999) ──${NC}"
  local sa2
  sa2=$(call_api "check-service-area" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"zipCode\":\"99999\"}" "check-service-area 99999")
  local sa2_serviced
  sa2_serviced=$(echo "$sa2" | jq -r '.isServiced // true' 2>/dev/null)
  assert_eq "$sa2_serviced" "false" "SA2: 99999 is NOT serviced"
  echo -e "  ${CYAN}Message: $(echo "$sa2" | jq -r '.message // empty' 2>/dev/null)${NC}"

  # ═══════════════════════════════════════════════════════════
  # Phase 4: get-company-info
  # ═══════════════════════════════════════════════════════════
  phase_header "4" "GET-COMPANY-INFO"

  echo -e "${YELLOW}── CI1: Returns company info ──${NC}"
  local ci
  ci=$(call_api "get-company-info" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\"}" "get-company-info")
  local ci_name
  ci_name=$(echo "$ci" | jq -r '.companyInfo.name // empty' 2>/dev/null)
  assert_not_empty "$ci_name" "CI1: Company name present"
  echo -e "  ${CYAN}Name: ${ci_name}${NC}"
  local ci_phone
  ci_phone=$(echo "$ci" | jq -r '.companyInfo.phone // empty' 2>/dev/null)
  echo -e "  ${CYAN}Phone: ${ci_phone}${NC}"

  # ═══════════════════════════════════════════════════════════
  # Phase 5: Customer CRUD
  # ═══════════════════════════════════════════════════════════
  phase_header "5" "CUSTOMER CRUD"

  echo -e "${YELLOW}── CU1: get-customer-by-phone (existing) ──${NC}"
  local cu1
  cu1=$(call_api "get-customer-by-phone" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\"}" "get-customer Maria")
  local cu1_id
  cu1_id=$(echo "$cu1" | jq -r '.customer.id // empty' 2>/dev/null)
  assert_not_empty "$cu1_id" "CU1: Found Maria by phone"
  local cu1_name
  cu1_name=$(echo "$cu1" | jq -r '.customer.name // empty' 2>/dev/null)
  echo -e "  ${CYAN}Found: ${cu1_name} (${cu1_id})${NC}"

  echo -e "${YELLOW}── CU2: get-customer-by-phone (not found) ──${NC}"
  local cu2
  cu2=$(call_api "get-customer-by-phone" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"+15559999999\"}" "get-customer (not found)")
  local cu2_msg
  cu2_msg=$(echo "$cu2" | jq -r '.message // empty' 2>/dev/null)
  assert_not_empty "$cu2_msg" "CU2: Returns message for unknown phone"
  echo -e "  ${CYAN}Message: ${cu2_msg}${NC}"

  echo -e "${YELLOW}── CU3: update-customer ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local cu3
    cu3=$(call_api "update-customer" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\",\"email\":\"maria.updated@example.com\"}" "update-customer Maria")
    assert_not_empty "$(echo "$cu3" | jq -r '.message // empty')" "CU3: update-customer returns message"
  fi

  # ═══════════════════════════════════════════════════════════
  # Phase 6: Property CRUD
  # ═══════════════════════════════════════════════════════════
  phase_header "6" "PROPERTY CRUD"

  echo -e "${YELLOW}── PR1: list-properties ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local pr1
    pr1=$(call_api "list-properties" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "list-properties Maria")
    local pr1_count
    pr1_count=$(echo "$pr1" | jq '.properties | length' 2>/dev/null || echo 0)
    assert_gte "$pr1_count" 1 "PR1: Maria has >= 1 property"
    echo -e "  ${CYAN}Properties: ${pr1_count}${NC}"
  fi

  # ═══════════════════════════════════════════════════════════
  # Phase 7: Service Request Flow
  # ═══════════════════════════════════════════════════════════
  phase_header "7" "SERVICE REQUEST FLOW"

  echo -e "${YELLOW}── SR1: get-requests (Maria) ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local sr1_resp
    sr1_resp=$(call_api "get-requests" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-requests Maria")
    assert_not_empty "$(echo "$sr1_resp" | jq -r '.message // empty')" "SR1: get-requests returns message"
    echo -e "  ${CYAN}$(echo "$sr1_resp" | jq -r '.message // empty' 2>/dev/null)${NC}"
  fi

  echo -e "${YELLOW}── SR2: get-request (single) ──${NC}"
  if [ -n "$sr1" ] && [ "$sr1" != "null" ]; then
    local sr2_resp
    sr2_resp=$(call_api "get-request" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"requestId\":\"${sr1}\"}" "get-request Maria")
    assert_not_empty "$(echo "$sr2_resp" | jq -r '.message // empty')" "SR2: get-request returns message"
  else
    echo -e "  ${YELLOW}⚠️ Skipping (no request ID)${NC}"
  fi

  # ═══════════════════════════════════════════════════════════
  # Phase 8: Jobs & Appointments
  # ═══════════════════════════════════════════════════════════
  phase_header "8" "JOBS & APPOINTMENTS"

  echo -e "${YELLOW}── JA1: get-jobs (Maria) ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local ja1
    ja1=$(call_api "get-jobs" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-jobs Maria")
    local ja1_msg
    ja1_msg=$(echo "$ja1" | jq -r '.message // empty' 2>/dev/null)
    assert_not_empty "$ja1_msg" "JA1: get-jobs returns message"
    echo -e "  ${CYAN}${ja1_msg}${NC}"
  fi

  echo -e "${YELLOW}── JA2: get-appointments (Maria) ──${NC}"
  if [ -n "$c1" ] && [ "$c1" != "null" ]; then
    local ja2
    ja2=$(call_api "get-appointments" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_1}\",\"customerId\":\"${c1}\"}" "get-appointments Maria")
    local ja2_msg
    ja2_msg=$(echo "$ja2" | jq -r '.message // empty' 2>/dev/null)
    assert_not_empty "$ja2_msg" "JA2: get-appointments returns message"
    echo -e "  ${CYAN}${ja2_msg}${NC}"
  fi

  # ═══════════════════════════════════════════════════════════
  # Phase 9: Submit Lead (E2E new caller)
  # ═══════════════════════════════════════════════════════════
  phase_header "9" "SUBMIT-LEAD (E2E)"

  echo -e "${YELLOW}── SL1: submit-lead ──${NC}"
  local sl1
  sl1=$(call_api "submit-lead" \
    "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"+15559999999\",\"firstName\":\"Test\",\"lastName\":\"Lead\",\"email\":\"test.lead@example.com\",\"address\":{\"street\":\"999 Test Ln\",\"city\":\"Santa Cruz\",\"state\":\"CA\",\"zip\":\"95065\"},\"serviceDescription\":\"Faucet dripping\"}" "submit-lead")
  local sl1_msg
  sl1_msg=$(echo "$sl1" | jq -r '.message // empty' 2>/dev/null)
  assert_not_empty "$sl1_msg" "SL1: submit-lead returns message"
  echo -e "  ${CYAN}${sl1_msg}${NC}"

  # ═══════════════════════════════════════════════════════════
  # Phase 10: get-client-schedule
  # ═══════════════════════════════════════════════════════════
  phase_header "10" "GET-CLIENT-SCHEDULE"

  echo -e "${YELLOW}── CS1: get-client-schedule (James) ──${NC}"
  if [ -n "$c2" ] && [ "$c2" != "null" ]; then
    local cs1
    cs1=$(call_api "get-client-schedule" "{\"locationId\":\"${LOCATION_ID}\",\"callerPhoneNumber\":\"${SEED_PHONE_2}\",\"customerId\":\"${c2}\"}" "get-client-schedule James")
    local cs1_msg
    cs1_msg=$(echo "$cs1" | jq -r '.message // empty' 2>/dev/null)
    assert_not_empty "$cs1_msg" "CS1: get-client-schedule returns message"
    echo -e "  ${CYAN}${cs1_msg}${NC}"
  fi

  # ═══════════════════════════════════════════════════════════
  # Results
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  RESULTS${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
  echo -e "  ${RED}Failed: ${FAILED}${NC}"
  echo -e "  Total:  $((PASSED + FAILED))"
  echo ""
  if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}⚠️  Some tests failed.${NC}"
    exit 1
  else
    echo -e "${GREEN}🎉 All tests passed!${NC}"
  fi
}

# ─────────────────────────────────────────────────────────────
# Voice agent test guide
# ─────────────────────────────────────────────────────────────

guide() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  VOICE AGENT TEST GUIDE (HOUSECALL PRO)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Start voice agent in console mode:"
  echo "  cd ~/callsaver-api/livekit-python"
  echo "  source .venv/bin/activate"
  echo "  API_URL=http://localhost:3002 CONSOLE_TEST_LOCATION_ID=${LOCATION_ID} python server.py console"
  echo ""
  echo "Your phone: ${YOUR_PHONE} (not in HCP = new caller)"
  echo ""
  echo "Scenario A: New caller — report a leak, get service request created"
  echo "  - Give name, address in Santa Cruz (95065 = in service zone)"
  echo "  - Agent should: create customer → create property → check service area → create request"
  echo ""
  echo "Scenario B: Returning caller (${SEED_PHONE_1}) — check request status"
  echo "  - Agent should find Maria Garcia, show her requests"
  echo ""
  echo "Scenario C: New caller from outside service area"
  echo "  - Give address in New York (zip 10001)"
  echo "  - Agent should: check service area → politely decline"
  echo ""
  echo "Scenario D: Ask about services"
  echo "  - 'What services do you offer?'"
  echo "  - Agent should give brief summary, not read all 57 services"
  echo ""
  echo "Scenario E: Returning caller — 'What do I have coming up?'"
  echo "  - Use ${SEED_PHONE_2} (James)"
  echo "  - Agent should call get-client-schedule"
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    seed)    preflight; seed; guide ;;
    test)    run_tests ;;
    all)     preflight; seed; run_tests; guide ;;
    direct)  direct_tests ;;
    guide)   guide ;;
    *)       echo "Usage: $0 {seed|test|all|direct|guide}"; exit 1 ;;
  esac
}

main "$@"
