#!/bin/bash
# =============================================================================
# GOOGLE CALENDAR AVAILABILITY DEBUG SCRIPT
# =============================================================================
#
# Calls the /internal/tools/google-calendar-get-availability endpoint directly
# and prints the raw response: busy periods, individual slots, and collapsed
# windows. This lets us see exactly what the backend computes before the LLM
# ever touches the data.
#
# Usage:
#   chmod +x testing/test-gcal-availability.sh
#   ./testing/test-gcal-availability.sh                    # Default: 2026-03-02
#   ./testing/test-gcal-availability.sh 2026-03-05         # Custom date
#   ./testing/test-gcal-availability.sh 2026-03-02 --raw   # Print full JSON
#
# Prerequisites:
#   - Local API server running on port 3000
#   - Google Calendar connected for the test location
#   - jq installed
#
# =============================================================================

set -euo pipefail

# ── Configuration ──
BASE_URL="http://localhost:3000/internal/tools"
API_KEY="ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7"
LOCATION_ID="cmm36ubye002bpw01y51nc0ln"
TIMEZONE="America/Los_Angeles"
DATE="${1:-2026-03-02}"
RAW=false

for arg in "$@"; do
  case "$arg" in
    --raw) RAW=true ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Preflight ──
if ! command -v jq &> /dev/null; then
  echo -e "${RED}❌ jq required. Install: sudo apt install jq${NC}"
  exit 1
fi

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  GOOGLE CALENDAR AVAILABILITY DEBUG${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Date:${NC}       ${DATE}"
echo -e "  ${CYAN}Location:${NC}   ${LOCATION_ID}"
echo -e "  ${CYAN}Timezone:${NC}   ${TIMEZONE}"
echo -e "  ${CYAN}API:${NC}        ${BASE_URL}"
echo ""

# ── Step 1: Call get-availability ──
echo -e "${BLUE}── Calling google-calendar-get-availability ──${NC}"
echo ""

RESPONSE=$(curl -s -w "\n---HTTP_CODE:%{http_code}---" \
  -X POST "${BASE_URL}/google-calendar-get-availability" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"locationId\": \"${LOCATION_ID}\",
    \"date\": \"${DATE}\",
    \"timeZone\": \"${TIMEZONE}\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/---HTTP_CODE:/d')

if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${RED}❌ API returned HTTP ${HTTP_CODE}${NC}"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi

echo -e "${GREEN}✅ API returned HTTP ${HTTP_CODE}${NC}"
echo ""

# ── Step 1b: Display freeBusy query range and raw busy periods ──
FB_START=$(echo "$BODY" | jq -r '.freeBusyQueryRange.start // empty')
FB_END=$(echo "$BODY" | jq -r '.freeBusyQueryRange.end // empty')
BUSY_COUNT=$(echo "$BODY" | jq '.busyPeriods | length // 0')

if [ -n "$FB_START" ]; then
  echo -e "${BLUE}── FreeBusy Query Range ──${NC}"
  echo ""
  echo -e "  ${CYAN}Query start (UTC):${NC}  ${FB_START}"
  echo -e "  ${CYAN}Query end (UTC):${NC}    ${FB_END}"
  echo ""
fi

if [ "$BUSY_COUNT" -gt 0 ]; then
  echo -e "${BLUE}── Raw Busy Periods (from Google Calendar) ──${NC}"
  echo ""
  echo "$BODY" | jq -r '.busyPeriods[] | .start + "|" + .end' | while IFS='|' read -r UTC_START UTC_END; do
    LOCAL_START=$(TZ="${TIMEZONE}" date -d "$UTC_START" "+%-I:%M %p" 2>/dev/null || echo "?")
    LOCAL_END=$(TZ="${TIMEZONE}" date -d "$UTC_END" "+%-I:%M %p" 2>/dev/null || echo "?")
    echo -e "  ${RED}BUSY:${NC} ${LOCAL_START} to ${LOCAL_END}  (UTC: ${UTC_START} to ${UTC_END})"
  done
  echo ""
else
  echo -e "${BLUE}── Raw Busy Periods ──${NC}"
  echo ""
  echo -e "  ${GREEN}No busy periods returned by Google Calendar${NC}"
  echo ""
fi

# ── Step 2: Print raw JSON if --raw ──
if [ "$RAW" = true ]; then
  echo -e "${BLUE}── Raw JSON Response ──${NC}"
  echo "$BODY" | jq .
  echo ""
fi

# ── Step 3: Parse and display results ──
SLOT_COUNT=$(echo "$BODY" | jq '.slots | length')
WINDOW_COUNT=$(echo "$BODY" | jq '.windows | length')
DURATION=$(echo "$BODY" | jq '.appointmentDurationMinutes')
TZ_RESP=$(echo "$BODY" | jq -r '.timezone')
MESSAGE=$(echo "$BODY" | jq -r '.message')

echo -e "${BLUE}── Summary ──${NC}"
echo ""
echo -e "  ${CYAN}Timezone:${NC}             ${TZ_RESP}"
echo -e "  ${CYAN}Appointment duration:${NC}  ${DURATION} minutes"
echo -e "  ${CYAN}Total slots:${NC}          ${SLOT_COUNT}"
echo -e "  ${CYAN}Windows:${NC}              ${WINDOW_COUNT}"
echo -e "  ${CYAN}Message:${NC}              ${MESSAGE}"
echo ""

# ── Step 4: Display windows ──
if [ "$WINDOW_COUNT" -gt 0 ]; then
  echo -e "${BLUE}── Availability Windows (what the LLM sees) ──${NC}"
  echo ""
  echo "$BODY" | jq -r '.windows[] | "  \(.start)  →  \(.end)"'
  echo ""
  
  echo -e "  ${CYAN}ℹ  Window start/end = first/last valid appointment START time in each block${NC}"
  echo ""
fi

# ── Step 5: Display all individual slots ──
if [ "$SLOT_COUNT" -gt 0 ]; then
  echo -e "${BLUE}── Individual Slots (all valid appointment start times) ──${NC}"
  echo ""
  
  # Format slots as a compact grid (4 per line)
  SLOTS=$(echo "$BODY" | jq -r '.slots[]')
  COUNT=0
  LINE=""
  while IFS= read -r slot; do
    # Extract just the time portion (HH:MM) from the ISO string
    TIME=$(echo "$slot" | sed 's/.*T\([0-9][0-9]:[0-9][0-9]\).*/\1/')
    # Convert to 12-hour format
    HOUR=$(echo "$TIME" | cut -d: -f1 | sed 's/^0//')
    MIN=$(echo "$TIME" | cut -d: -f2)
    if [ "$HOUR" -ge 12 ]; then
      AMPM="PM"
      [ "$HOUR" -gt 12 ] && HOUR=$((HOUR - 12))
    else
      AMPM="AM"
      [ "$HOUR" -eq 0 ] && HOUR=12
    fi
    DISPLAY=$(printf "%2d:%s %s" "$HOUR" "$MIN" "$AMPM")
    
    LINE="${LINE}  ${DISPLAY}"
    COUNT=$((COUNT + 1))
    if [ $((COUNT % 6)) -eq 0 ]; then
      echo "$LINE"
      LINE=""
    fi
  done <<< "$SLOTS"
  [ -n "$LINE" ] && echo "$LINE"
  
  echo ""
  echo -e "  ${CYAN}First slot:${NC}  $(echo "$BODY" | jq -r '.slots[0]')"
  echo -e "  ${CYAN}Last slot:${NC}   $(echo "$BODY" | jq -r '.slots[-1]')"
  echo ""
  
  # ── Step 6: Identify gaps (where contiguous slots break) ──
  echo -e "${BLUE}── Slot Gaps (busy periods detected) ──${NC}"
  echo ""
  
  PREV_EPOCH=""
  PREV_TIME=""
  GAP_COUNT=0
  while IFS= read -r slot; do
    CUR_EPOCH=$(date -d "$slot" +%s 2>/dev/null || echo "0")
    if [ -n "$PREV_EPOCH" ] && [ "$CUR_EPOCH" != "0" ] && [ "$PREV_EPOCH" != "0" ]; then
      DIFF=$(( (CUR_EPOCH - PREV_EPOCH) / 60 ))
      if [ "$DIFF" -gt 15 ]; then
        # There's a gap — a busy period lives here
        # The gap is from (prev_slot + duration) to current_slot
        PREV_END_EPOCH=$((PREV_EPOCH + DURATION * 60))
        PREV_END=$(date -d "@$PREV_END_EPOCH" "+%-I:%M %p" 2>/dev/null || echo "?")
        CUR_TIME=$(date -d "$slot" "+%-I:%M %p" 2>/dev/null || echo "?")
        PREV_DISP=$(date -d "@$PREV_EPOCH" "+%-I:%M %p" 2>/dev/null || echo "?")
        echo -e "  ${RED}GAP:${NC} Last slot before gap: ${PREV_DISP} (appt ends ${PREV_END})"
        echo -e "       First slot after gap: ${CUR_TIME}"
        echo -e "       → Busy period approx: ${PREV_END} to ${CUR_TIME} (${DIFF} min gap between slot starts)"
        echo ""
        GAP_COUNT=$((GAP_COUNT + 1))
      fi
    fi
    PREV_EPOCH="$CUR_EPOCH"
    PREV_TIME="$slot"
  done <<< "$SLOTS"
  
  if [ "$GAP_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}No gaps — entire day is one contiguous block${NC}"
    echo ""
  fi
fi

# ── Step 7: Expected vs Actual analysis ──
echo -e "${BLUE}── Analysis ──${NC}"
echo ""

# Known facts for March 2nd
echo -e "  ${BOLD}Known facts:${NC}"
echo -e "    Business hours (Google Place Details): 8:00 AM - 6:00 PM"
echo -e "    Test event on calendar:                12:00 PM - 2:00 PM"
echo -e "    Appointment duration:                  ${DURATION} minutes"
echo -e "    Buffer time:                           0 minutes"
echo ""

echo -e "  ${BOLD}Expected (valid START time windows):${NC}"
echo -e "    ${GREEN}Window 1: 8:00 AM to 10:30 AM${NC}  (last start 10:30, ends 12:00 = event start)"
echo -e "    ${GREEN}Window 2: 2:00 PM to 4:30 PM${NC}  (last start 4:30, ends 6:00 = closing)"
echo ""

echo -e "  ${BOLD}Actual windows returned:${NC}"
if [ "$WINDOW_COUNT" -gt 0 ]; then
  echo "$BODY" | jq -r '.windows[] | "    \(.start) to \(.end)"'
else
  echo "    (none)"
fi
echo ""

# ── Step 8: Also test get-next-available ──
echo -e "${BLUE}── Bonus: get-next-available (starting from ${DATE}) ──${NC}"
echo ""

NEXT_RESPONSE=$(curl -s \
  -X POST "${BASE_URL}/google-calendar-get-next-available" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"locationId\": \"${LOCATION_ID}\",
    \"timeZone\": \"${TIMEZONE}\"
  }")

NEXT_SLOT=$(echo "$NEXT_RESPONSE" | jq -r '.slot // "none"')
NEXT_MSG=$(echo "$NEXT_RESPONSE" | jq -r '.message // "no response"')
echo -e "  ${CYAN}Next available:${NC}  ${NEXT_SLOT}"
echo -e "  ${CYAN}Message:${NC}         ${NEXT_MSG}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Done.${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
