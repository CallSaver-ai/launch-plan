# Voice Agent Test Scenarios — Jobber Integration

## Setup

```bash
cd ~/callsaver-api/livekit-python
source .venv/bin/activate
API_URL=http://localhost:3002 CONSOLE_TEST_LOCATION_ID=cmloxy8vs000ar801ma3wz6s3 python server.py console
```

Your phone: **+18313345344** (Alex Sikand — NOT in Jobber = new caller)

## Current Seeded State (after test run)

| Client | Phone | Request | Assessment |
|--------|-------|---------|------------|
| Maria Garcia | +15551000001 | Leak Repair | Tue Feb 24 @ 11 AM |
| James Wilson | +15551000002 | Drain Cleaning | CANCELLED |
| Sarah Chen | +15551000003 | Water Heater Installation | Mon Feb 23 @ 10 AM |
| Robert Johnson | +15551000004 | Toilet Installation | Sat Feb 21 @ 8-10 AM |

**Calendar:**
- Fri Feb 20: FULLY OPEN
- Sat Feb 21: Robert 8-10 AM → available 10:15 AM - 5:00 PM
- Mon Feb 23: Sarah 10-11 AM → available 8-8:45 AM, 11:15 AM - 6:00 PM
- Tue Feb 24: Maria 11 AM → available 8-10:45 AM, 11:30 AM - 6:00 PM

**Business Hours:** Mon-Fri 8 AM - 6 PM, Sat 8 AM - 5 PM, Sun Closed

---

## Scenario 1: New Caller — Full Lead Flow

**Goal:** Test get-customer-by-phone (not found) → create customer → create property → create service request → check availability → schedule assessment

**You say:**
> "Hi, my kitchen faucet is leaking really badly"

**Expected agent behavior:**
1. Looks up +18313345344 → not found
2. Asks for your name
3. **You:** "Alex Sikand"
4. Asks for your address
5. **You:** "742 Evergreen Terrace, Santa Cruz, California 95060"
6. Creates customer + property
7. Asks about the service needed (may already know from your opening)
8. Creates a service request for Leak Repair (or Faucet Installation)
9. Checks availability and offers windows

**What to verify:**
- [ ] Agent correctly identifies you as a new caller
- [ ] Agent asks for name and address
- [ ] Agent creates customer in Jobber
- [ ] Agent creates property
- [ ] Agent creates service request
- [ ] Agent checks availability and presents windows like "We have availability Friday from 8 AM to 6 PM, Saturday from 10:15 AM to 5 PM..."
- [ ] Agent offers to schedule a consultation

**If agent offers times, you say:**
> "How about Saturday afternoon around 2?"

**Expected:** Agent confirms Saturday Feb 21 at 2:00 PM (within the 10:15 AM - 5 PM window)

---

## Scenario 2: Returning Caller — Check Status

**Setup:** Restart console, test as Maria: change the phone in the console or note that the agent will look up your actual phone.

Since you're calling from +18313345344, after Scenario 1 you ARE in Jobber. Restart console.

**You say:**
> "Hi, I'm calling to check on my request"

**Expected agent behavior:**
1. Looks up +18313345344 → finds Alex Sikand (from Scenario 1)
2. Gets your requests → shows the request you created
3. Shows assessment info if scheduled

**What to verify:**
- [ ] Agent finds you by phone
- [ ] Agent retrieves your request(s)
- [ ] Agent describes the request status and any scheduled consultation

---

## Scenario 3: Returning Caller — "What do I have coming up?"

**You say:**
> "What do I have coming up?"

**Expected agent behavior:**
1. Calls get-client-schedule
2. Lists upcoming consultations/visits

**What to verify:**
- [ ] Agent calls schedule tool
- [ ] Agent lists items with dates and times

---

## Scenario 4: Reschedule Request

**You say:**
> "I need to reschedule my consultation"

**Expected agent behavior:**
1. Gets your schedule → shows current consultation time
2. Asks when you'd like to reschedule
3. **You:** "Can I move it to Monday morning?"
4. Checks availability for Monday Feb 23 → shows windows (8-8:45 AM, 11:15 AM - 6 PM)
5. **You:** "11:30 works"
6. Reschedules assessment to Monday Feb 23 at 11:30 AM

**What to verify:**
- [ ] Agent shows current appointment time
- [ ] Agent checks availability for requested day
- [ ] Agent presents available windows
- [ ] Agent reschedules successfully
- [ ] Agent confirms new time

---

## Scenario 5: Cancel Request

**You say:**
> "Actually, I need to cancel that consultation"

**Expected agent behavior:**
1. Confirms which consultation
2. Asks for confirmation
3. **You:** "Yes, please cancel it"
4. Cancels the assessment
5. Confirms cancellation

**What to verify:**
- [ ] Agent confirms before cancelling
- [ ] Agent cancels successfully
- [ ] Agent confirms cancellation

---

## Scenario 6: Business Hours Question

**You say:**
> "What are your hours?"

**Expected agent behavior:**
- Agent answers from system prompt (no tool call needed):
  "We're open Monday through Friday 8 AM to 6 PM, Saturday 8 AM to 5 PM, and closed on Sunday."

**What to verify:**
- [ ] Agent answers without calling any tool
- [ ] Hours are correct

---

## Scenario 7: Out-of-Hours Request

**You say:**
> "Can I get someone out here Sunday?"

**Expected agent behavior:**
- Agent says: "I'm sorry, we're closed on Sundays. We're open Monday through Saturday. Would Monday work for you?"

**What to verify:**
- [ ] Agent does NOT call the availability tool
- [ ] Agent correctly identifies Sunday as closed
- [ ] Agent suggests an alternative day

---

## Scenario 8: Services Question

**You say:**
> "What services do you offer?"

**Expected agent behavior:**
- Agent lists services (may call get-services tool or answer from system prompt if services were pre-injected)

**What to verify:**
- [ ] Agent lists services with descriptions
- [ ] Prices shown where available (Water Heater $1200, Drain Cleaning $150)

---

## Scenario 9: Late Afternoon Availability Check

**You say:**
> "Do you have anything available this Friday in the late afternoon?"

**Expected agent behavior:**
1. Checks availability for Friday Feb 20
2. Friday is fully open → "We have availability from 8 AM to 6 PM"
3. **You:** "How about 4:30?"
4. Agent confirms 4:30 PM works

**What to verify:**
- [ ] Agent checks availability
- [ ] Agent presents the full window (not just morning slots)
- [ ] Agent can confirm a specific time within the window

---

## Scenario 10: Multiple Properties (Edge Case)

**You say:**
> "I also have a rental property at 100 Beach Street, Santa Cruz 95060 that needs a toilet installed"

**Expected agent behavior:**
1. Creates new property (100 Beach Street)
2. Creates new service request for Toilet Installation at that address

**What to verify:**
- [ ] Agent creates a second property
- [ ] Agent associates the request with the correct address

---

---

## Scenario 11: Service Duration — Free Assessment (60 min)

**Goal:** Verify agent uses the service-specific duration (60 min for Free Assessment) when checking availability instead of the default 30 min.

**You say:**
> "I'd like to schedule a free assessment"

**Expected agent behavior:**
1. Matches "Free Assessment" from service catalog (duration: 60 min)
2. Checks availability with `duration: 60`
3. Availability windows will be narrower (need 60-min gaps, not 30-min)

**What to verify:**
- [ ] Server log shows `[checkAvailability] duration=60min` (not 30min)
- [ ] Windows account for 60-min appointments
- [ ] Agent doesn't mention the duration mechanics — just offers times naturally

---

## Scenario 12: Service Duration — No Duration Defined (Leak Repair)

**Goal:** Verify agent falls back to default duration (30 min) when the service has no duration.

**You say:**
> "I have a leak under my kitchen sink"

**Expected agent behavior:**
1. Matches "Leak Repair" from service catalog (duration: undefined)
2. Checks availability WITHOUT passing duration → falls back to 30 min default

**What to verify:**
- [ ] Server log shows `[checkAvailability] duration=30min` (location default)
- [ ] Agent offers times normally

---

## Scenario 13: Buffer Time Validation

**Goal:** Verify buffer time (15 min) is respected between appointments.

**Context:** Saturday Feb 21 has Robert's assessment 8-10 AM. With 15-min buffer, first available slot should be 10:15 AM.

**You say:**
> "Do you have anything available this Saturday?"

**Expected agent behavior:**
1. Checks availability for Saturday Feb 21
2. Shows window starting at **10:15 AM** (not 10:00 AM)
3. Says something like "We have availability from 10:15 AM to 5 PM"

**What to verify:**
- [ ] Agent does NOT offer 10:00 AM (buffer respected)
- [ ] Window starts at 10:15 AM (10 AM + 15 min buffer)
- [ ] Server log shows `buffer=15min`

**Follow-up — try to book at 10:00 AM:**
> "Can I come at 10?"

**Expected:** Agent should explain that 10:15 is the earliest available, or offer 10:15 instead.

---

## Scenario 14: Business Hours — Sunday Rejection

**Goal:** Verify agent rejects Sunday requests without calling any tool.

**You say:**
> "Can someone come out this Sunday?"

**Expected agent behavior:**
- Agent says: "I'm sorry, we're closed on Sundays. We're open Monday through Saturday. Would another day work?"
- Agent does NOT call fs_check_availability

**What to verify:**
- [ ] No tool call in server logs
- [ ] Agent correctly identifies Sunday as closed
- [ ] Agent suggests alternative days

---

## Scenario 15: Business Hours — Evening Rejection

**Goal:** Verify agent rejects out-of-hours requests.

**You say:**
> "I need someone here at 7 PM tonight"

**Expected agent behavior:**
- Agent says: "I'm sorry, but we close at 6 PM on weekdays. Our hours are 8 AM to 6 PM Monday through Friday. Would tomorrow morning work?"
- Agent does NOT call fs_check_availability

**What to verify:**
- [ ] No availability tool call
- [ ] Agent knows closing time (6 PM weekdays, 5 PM Saturday)
- [ ] Agent suggests a time within business hours

---

## Scenario 16: Business Hours — Early Morning Rejection

**You say:**
> "Can I get a 7 AM appointment?"

**Expected:**
- "We open at 8 AM. Our earliest available time would be 8 AM. Would that work?"

**What to verify:**
- [ ] Agent knows opening time is 8 AM
- [ ] Agent offers 8 AM as alternative

---

## Scenario 17: Availability Windows — Natural Presentation

**Goal:** Verify agent presents availability windows as ranges, not individual slots.

**You say:**
> "What's available this Friday?"

**Expected agent behavior:**
- Agent checks availability for Friday (currently fully open after test mutations)
- Says something like: "Friday is wide open — we have availability from 8 AM to 6 PM. What time works best for you?"
- NOT: "We have a slot at 8:00 AM, 8:30 AM, 9:00 AM..."

**What to verify:**
- [ ] Agent presents windows as ranges ("8 AM to 6 PM")
- [ ] Agent asks for preference within the window
- [ ] Natural conversational tone

---

## Recommended Test Order

**Phase 1 — Core Flow (restart console between each):**
1. **Scenario 1** (New caller flow) — tests the most tools end-to-end
2. **Scenario 8** (Services) — verify clean output, no unitPrice
3. **Scenario 17** (Availability windows) — verify natural range presentation

**Phase 2 — Business Hours (restart console between each):**
4. **Scenario 6** (What are your hours?) — no tool call
5. **Scenario 14** (Sunday rejection) — no tool call
6. **Scenario 15** (Evening rejection) — no tool call
7. **Scenario 16** (Early morning rejection) — no tool call

**Phase 3 — Duration & Buffer (restart console between each):**
8. **Scenario 11** (Free Assessment 60-min duration) — check server log
9. **Scenario 12** (Leak Repair default duration) — check server log
10. **Scenario 13** (Buffer time on Saturday) — verify 10:15 AM start

**Phase 4 — Returning Caller Flows (restart console between each):**
11. **Scenario 2** (Check status as returning caller)
12. **Scenario 3** (What do I have coming up?)
13. **Scenario 4** (Reschedule)
14. **Scenario 5** (Cancel)
15. **Scenario 9** (Late afternoon availability)
16. **Scenario 10** (Multiple properties)

Run each scenario in a fresh console session (restart `python server.py console` between scenarios to reset conversation context).

---

## Server Logs to Watch

Keep the API server terminal visible. Key log lines:

```
✅ Injected scheduling configuration (duration: 30min, buffer: 15min, 6 business hour periods)
🔍 searchTerm matched with format: "+18313345344"
✅ Found customer via searchTerm (efficient!)
[checkAvailability] duration=30min buffer=15min items=X/Y
[checkAvailability] day=2026-02-20 dow=5 period=...
```

**Duration checks:**
- Free Assessment → `duration=60min`
- Leak Repair (no duration) → `duration=30min` (location default)
- Buffer always → `buffer=15min`

**Business hours checks:**
- Sunday/evening/early morning requests → NO `[checkAvailability]` log (agent should reject without tool call)

If you see `⚠️ searchTerm returned no results, using fallback method...` on the FIRST call for a phone number, that's the findCustomerByPhone issue we still need to investigate.
