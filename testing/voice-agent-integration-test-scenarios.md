# Voice Agent Integration Test Scenarios — Launch Testing Guide

**Last Updated:** Feb 26, 2026
**Covers:** No Integration, Google Calendar, Housecall Pro, Jobber
**Purpose:** Systematic test plan for all 4 integration modes before production launch

---

## How to Use This Document

### Testing Modes
1. **Console Mode** (fast iteration, no phone needed):
   ```bash
   cd ~/callsaver-api/livekit-python
   source .venv/bin/activate
   API_URL=http://localhost:3002 CONSOLE_TEST_LOCATION_ID=<locationId> python server.py console
   ```
2. **Phone Call** (production-like): Call the agent's phone number. Required for transfer/callback and audio quality testing.

### Priority Levels
- **P0**: Core happy paths. If these fail, launch is blocked.
- **P1**: Important flows that affect user experience. Fix before launch if possible.
- **P2**: Edge cases. Document issues but don't block launch.

### Recommended Schedule
- **Day 1**: All P0 scenarios across all 4 modes (core happy paths)
- **Day 2**: P1 scenarios (returning callers, scheduling, config toggles)
- **Day 3**: P2 scenarios (edge cases, unhandled intents, safety)
- **Day 4**: Regression pass on any issues found

### Tips
- **Restart between scenarios** in console mode (`Ctrl+C` then re-run command) to reset conversation context.
- **Keep API server terminal visible** — server logs show tool calls, durations, and errors.
- **Check platform dashboards** after each creation scenario (HCP/Jobber/Google Calendar).

---

## Onboarding Paths (All Modes)

| Feature | Path A ("Keep Your Number") | Path B ("New CallSaver Number") |
|---------|---------------------------|-------------------------------|
| request-callback | Yes | Yes |
| transfer-call | No | Yes |
| warm-transfer | No | Yes (if feature flag on) |
| validate-address | Yes | Yes |
| How calls arrive | Business forwards to CallSaver | Direct to CallSaver number |

---

## Part 0: No Integration (AI Receptionist)

### Tools Available
| Tool | Path A | Path B |
|------|--------|--------|
| validate-address | Yes | Yes |
| submit-intake-answers | Yes | Yes |
| request-callback | Yes | Yes |
| transfer-call | No | Yes |

### What the Agent Can Do
- Answer questions about the business (hours, services, areas served, FAQ — from system prompt)
- Collect caller info (name, address, email, service description) via dynamic intake questions
- Validate addresses via Google Address Validation API
- Create callback requests
- Transfer calls (Path B only)

---

### A. New Caller Flow

#### P0 | NONE-NC-1: Business info questions
- [x] Call from unknown number
- [x] "What services do you offer?" → answers from system prompt
- [x] "What are your hours?" → answers correctly
- [x] "Do you serve [in-area city]?" → confirms
- [x] "Do you serve [out-of-area city]?" → declines

#### P0 | NONE-NC-2: Full intake + callback (Path A)
- [x] Call from unknown number (Path A location)
- [x] Request a service → agent starts intake flow
- [x] Agent asks for name → caller spells first and last name
- [x] Agent asks for address (street + city) → validates via validate_address
- [x] Agent checks city against AREAS SERVED in system prompt
- [x] Agent reads confirmed address back, asks caller to confirm
- [x] Agent asks for email → asks caller to spell it
- [x] Agent calls submit-intake-answers
- [x] Agent offers callback: "I'll have someone from our team call you back"
- [x] Agent calls request-callback
- [x] **Verify**: Callback request in dashboard. Caller record saved with name, address, email.

#### P0 | NONE-NC-3: Intake + callback (Path B)
- [x] Call from unknown number (Path B location)
- [x] Agent collects info (same intake as NONE-NC-2)
- [x] Agent calls submit-intake-answers
- [x] Agent offers callback: "I'll have someone from our team call you back"
- [x] Agent calls request-callback → verify in dashboard
- [ ] **Note**: Agent should NOT offer transfer after intake — caller would have to repeat themselves on a cold transfer. Callback preserves the collected info. (Transfer may be offered for non-intake intents like "Can I speak to someone?")

#### P1 | NONE-NC-4: Outside service area
- [x] Provide address with city NOT in AREAS SERVED
- [x] Agent declines: "I'm sorry, we don't currently service that area"
- [x] Agent does NOT create intake or callback for the service

#### P1 | NONE-NC-5: Service not offered
- [x] Ask for a service not in the business's service list
- [x] Agent says they don't offer that, lists what they DO offer
- [x] Agent does NOT create intake for out-of-scope service

#### P1 | NONE-NC-6: Pricing question
- [x] "How much does [service] cost?"
- [x] Agent answers from prompt if prices listed, or defers: "Pricing depends on the specifics — our team will go over that with you"

---

### B. Returning Caller Flow

#### P1 | NONE-RC-1: Recognized caller, address on file
- [x] Call from known number (has CallerAddress on file)
- [x] Agent greets by name
- [x] Agent confirms existing address (doesn't re-collect from scratch)
- [x] Agent handles request (callback or transfer)

#### P1 | NONE-RC-2: Asks about existing appointment/request
- [x] Call from known number
- [x] "When is my appointment?" or "What's happening with my request?"
- [x] Agent has no tools for this → offers callback/transfer
- [x] "Let me have someone from the office follow up with you on that"

---

### C. Special Intents & Edge Cases

#### P1 | NONE-EC-1: Caller prefers callback over transfer (Path B)
- [x] Path B location → when offered transfer, say "Can you just have them call me back?"
- [x] Agent uses request-callback (not transfer-call)

#### P1 | NONE-EC-2: Speak to owner/manager
- [x] "Can I speak to the owner?"
- [x] Path A: offers callback
- [x] Path B: offers transfer (or callback if preferred)

#### P1 | NONE-EC-3: Leave a message
- [x] "Can I just leave a message?"
- [x] Agent takes the full message
- [x] Agent creates callback request with the message content
- [x] "I've taken down your message and someone will get back to you"

#### P0 | NONE-EC-4: Safety hazard — gas leak
- [x] "I smell gas in my kitchen"
- [x] Agent STOPS normal workflow immediately
- [x] Agent tells caller to leave the area and call 911 or gas company
- [x] Agent does NOT try to schedule service or collect info during the emergency
- [x] After safety instructions, offers to help once safe

#### P1 | NONE-EC-5: Safety hazard — flooding
- [x] "My basement is flooding"
- [x] Agent advises shutting off water valve if safe, calling 911 if severe
- [x] Agent does NOT proceed with normal intake

#### P2 | NONE-EC-6: Address without city
- [x] Give address without city: "123 Main Street"
- [x] Agent MUST ask for city before calling validate_address
- [x] Agent does NOT proceed without city

#### P2 | NONE-EC-7: Caller provides incomplete name
- [x] Give only first name when asked for full name
- [x] Agent should ask for last name: "Could you spell your last name for me?"

---

## Part 1: Google Calendar (GCal)

### Tools Available
| Tool | Description |
|------|-------------|
| google-calendar-check-availability | Check calendar for available time slots |
| google-calendar-create-event | Create appointment on Google Calendar |
| google-calendar-cancel-event | Cancel a calendar event |
| google-calendar-update-event | Reschedule/update a calendar event |
| google-calendar-list-events | List upcoming events for the caller |
| validate-address | Validate and geocode addresses |
| submit-intake-answers | Save caller intake info |
| request-callback | Create callback request (both paths) |
| transfer-call | Transfer call (Path B only) |

### Key Behaviors
- **No customer/property management** — uses local CallerAddress records + intake answers
- **Service area**: city checked against AREAS SERVED in system prompt
- **Business hours**: agent validates time is within hours BEFORE checking calendar
- **Returning callers**: info pre-loaded (name, address, email, upcoming events)

### Config Settings
| Setting | Default | Effect |
|---------|---------|--------|
| defaultAppointmentMinutes | 60 | Duration of each appointment |
| bufferMinutes | 0 | Gap enforced between appointments |

---

### A. New Caller Flow (GCal)

#### P0 | GCAL-NC-1: Full booking (happy path)
- [ ] Call from unknown number
- [ ] Agent follows intake flow (name, address, service needed)
- [ ] Agent validates address via validate_address
- [ ] Agent checks city against AREAS SERVED
- [ ] Agent calls submit-intake-answers to save caller info
- [ ] Agent asks for preferred date/time
- [ ] Agent validates time is within business hours (NO tool call if outside hours)
- [ ] Agent calls google-calendar-check-availability
- [ ] Agent presents available slots naturally ("We have availability from X to Y")
- [ ] Choose a time → agent calls google-calendar-create-event
- [ ] Agent confirms: date, time, address, service
- [ ] **Verify in Google Calendar**:
  - [ ] Event exists with correct start/end time
  - [ ] Event duration = defaultAppointmentMinutes
  - [ ] `extendedProperties.shared` has `source: callsaver`
  - [ ] Caller phone in `extendedProperties.shared.callerPhoneNumber`

#### P1 | GCAL-NC-2: Outside service area
- [ ] Provide address with city NOT in AREAS SERVED
- [ ] Agent declines politely
- [ ] **Verify**: no event created

#### P1 | GCAL-NC-3: Outside business hours
- [ ] Request appointment at 8 PM on weekday
- [ ] Agent rejects WITHOUT calling google-calendar-check-availability
- [ ] Agent mentions actual hours and suggests alternative
- [ ] **Verify**: no availability tool call in server logs

#### P1 | GCAL-NC-4: Closed day request (e.g., Sunday)
- [ ] Request appointment on a day business is closed
- [ ] Agent rejects without tool call, suggests next open day

#### P2 | GCAL-NC-5: Early morning (before open)
- [ ] "Can I get a 7 AM appointment?"
- [ ] Agent: "We open at [X] AM. Would [X] AM work?"

---

### B. Returning Caller Flow (GCal)

**Prerequisites**: Call from number with existing CallerAddress and at least one calendar event.

#### P0 | GCAL-RC-1: New booking
- [ ] Call from known number
- [ ] Agent greets by name (info pre-loaded, no re-collection)
- [ ] Agent confirms existing address
- [ ] Agent books appointment
- [ ] **Verify**: event created with correct address

#### P1 | GCAL-RC-2: Multiple addresses
- [ ] Call from known number with 2+ CallerAddress records
- [ ] Agent asks which address the appointment is for
- [ ] Select one → agent proceeds with that address

#### P0 | GCAL-RC-3: List upcoming appointments
- [ ] "What appointments do I have coming up?"
- [ ] Agent calls google-calendar-list-events
- [ ] Agent presents events chronologically with dates and times
- [ ] **Verify**: events match Google Calendar

#### P0 | GCAL-RC-4: Reschedule appointment
- [ ] "I need to reschedule my appointment"
- [ ] Agent identifies which appointment (or asks if multiple)
- [ ] Agent checks availability for new date
- [ ] Agent calls google-calendar-update-event
- [ ] Agent confirms new time
- [ ] **Verify in Google Calendar**: event time changed

#### P0 | GCAL-RC-5: Cancel appointment
- [ ] "I need to cancel my appointment"
- [ ] Agent confirms before cancelling
- [ ] Agent calls google-calendar-cancel-event
- [ ] **Verify in Google Calendar**: event removed/cancelled

---

### D. Business Hours & Duration (GCal)

#### P1 | GCAL-BH-1: Agent answers hours question without tool call
- [ ] "What are your hours?"
- [ ] Agent answers from system prompt (NO tool call)
- [ ] **Verify**: no google-calendar-check-availability call in logs

#### P1 | GCAL-BH-2: Buffer time respected
- [ ] Set bufferMinutes=15
- [ ] Create two events with exactly 15-min gap between them
- [ ] Check availability in that gap → should show as unavailable
- [ ] Create two events with 30-min gap → availability check should find a slot
- [ ] **Verify**: buffer is enforced

#### P2 | GCAL-BH-3: Natural availability presentation
- [ ] Check availability on a wide-open day
- [ ] Agent should say "We have availability from 8 AM to 5 PM" (a range)
- [ ] Agent should NOT list individual slots: "8:00, 8:30, 9:00..."

---

### C. Next Available & Event Updates (GCal)

#### P1 | GCAL-NC-6: "What's your next available appointment?"
- [ ] Agent checks availability for next open slot within business hours
- [ ] Agent says date and time clearly: "The next available is Thursday at 10 AM"
- [ ] Agent WAITS for caller confirmation before booking — does NOT auto-create event
- [ ] Caller: "That works" → agent creates event
- [ ] **Verify**: explicit confirmation obtained before event creation

#### P1 | GCAL-RC-6: Change service type on existing appointment
- [ ] Returning caller with upcoming event
- [ ] "Actually, I need plumbing instead of electrical"
- [ ] Agent calls google-calendar-update-event (NOT reschedule — time unchanged)
- [ ] Agent updates summary/description only
- [ ] **Verify in GCal**: event time unchanged, summary/description updated

#### P1 | GCAL-RC-7: Add service to existing appointment
- [ ] "Can you also add gutter cleaning to my appointment?"
- [ ] Agent updates description to include additional service
- [ ] **Verify in GCal**: description updated, time unchanged

---

### E. Callback, Transfer & Unhandled Intents (GCal)

#### P1 | GCAL-CT-1: Caller prefers callback
- [ ] "Just have them call me back" → agent uses request-callback

#### P1 | GCAL-CT-2: Path B — transfer
- [ ] "Can I talk to someone?" → agent uses transfer-call

#### P1 | GCAL-UI-1: Billing / payment question
- [ ] "How much do I owe?" → agent defers to callback/transfer

#### P1 | GCAL-UI-2: Leave a message
- [ ] "Can I leave a message?" → agent takes message, creates callback request

#### P0 | GCAL-UI-3: Safety hazard
- [ ] "I smell gas" → agent stops workflow, gives safety instructions
- [ ] Does NOT try to book appointment during active emergency

---

## Part 2: Housecall Pro (HCP)

### Tools Available (HCP — 18 FS tools + base)
| Tool | Description |
|------|-------------|
| fs_get_customer_by_phone | Customer lookup by phone |
| fs_create_customer | Create new customer |
| fs_update_customer | Update customer info |
| fs_list_properties | List customer's properties |
| fs_create_property | Create new property |
| fs_create_service_request | Create lead + unscheduled estimate (assessment auto-created) |
| fs_get_request / fs_get_requests | Get lead details |
| fs_check_availability | Check available windows |
| fs_reschedule_assessment | Schedule/reschedule estimate |
| fs_cancel_assessment | Cancel estimate |
| fs_get_appointments | Get appointments |
| fs_reschedule_appointment | Reschedule appointment |
| fs_cancel_appointment | Cancel appointment |
| fs_get_jobs / fs_get_job | Get job details |
| fs_get_services | Get service catalog (price book) |
| fs_get_client_schedule | Get all upcoming items |
| validate-address | Validate and geocode addresses |
| collect-email | Voice-to-text email normalization |
| request-callback | Callback request (both paths) |
| transfer-call | Transfer (Path B only) |

> **Tools NOT registered for HCP**: `fs_submit_lead`, `fs_create_assessment` (assessment auto-created with service request), `fs_get_estimates`, `fs_get_invoices`, `fs_get_account_balance`, `fs_create_appointment`.

### Config Toggles
| Toggle | true | false |
|--------|------|-------|
| autoScheduleAssessment | Agent books estimate time slot | "Team will reach out to schedule" |
| includePricing | Agent mentions service prices | Agent withholds pricing |

### Key Differences from Jobber
- **Service area**: city AND ZIP checked against SERVICE ZONES (not just city)
- Assessment entity = **"estimate"** or **"consultation"** (not "assessment")
- IDs are **plain strings** (not base64 EncodedIds)
- **Has job/appointment tools** (Jobber does not)

---

### A. New Caller Flow (HCP)

#### P0 | HCP-NC-1: Full happy path (autoSchedule=true, includePricing=true)
- [ ] Call from unknown number
- [ ] Agent asks for service needed → matches to catalog
- [ ] **Agent mentions price** (includePricing=true)
- [ ] Agent asks for name → spell first + last
- [ ] Agent calls fs_create_customer → receives customer_id
- [ ] Agent asks for address (street + city only — NOT state or ZIP)
- [ ] Agent validates via validate_address → gets full address + ZIP
- [ ] **Agent checks service area**: compares city AND ZIP against SERVICE ZONES in prompt
- [ ] Agent calls fs_create_property with validated address + customer_id
- [ ] Agent asks for preferred time
- [ ] Agent calls fs_create_service_request with all params (customer_id, property_id, service_id, description, summary, desired_time)
- [ ] Agent calls fs_check_availability for preferred date
- [ ] Agent presents available windows naturally ("We have availability from X to Y")
- [ ] Choose a time → agent calls fs_reschedule_assessment
- [ ] Agent confirms: service, address, date/time
- [ ] **Verify in HCP**: customer created, lead exists, estimate scheduled

#### P0 | HCP-NC-2: autoSchedule=false
- [ ] Set autoScheduleAssessment=false
- [ ] Repeat new caller flow through fs_create_service_request
- [ ] Agent says "team will review and reach out to schedule"
- [ ] Agent does NOT call fs_check_availability or fs_reschedule_assessment
- [ ] **Verify in HCP**: lead created with unscheduled estimate

#### P1 | HCP-NC-3: includePricing=false
- [ ] Set includePricing=false
- [ ] Agent does NOT mention any prices
- [ ] Ask about pricing → "Pricing depends on the specifics — our team will go over that with you"

#### P1 | HCP-NC-4: Outside service area
- [ ] Provide address in city NOT in any HCP service zone
- [ ] Agent declines politely
- [ ] Agent does NOT call fs_create_property or fs_create_service_request
- [ ] **Verify**: no lead in HCP

#### P2 | HCP-NC-5: Service area boundary (ZIP matches but city doesn't)
- [ ] Address where ZIP matches a zone but city name doesn't (or vice versa)
- [ ] Agent should accept if EITHER matches

#### P1 | HCP-NC-6: Service not in catalog
- [ ] Request a service NOT in the HCP price book
- [ ] Agent says they don't offer that, lists available services
- [ ] Agent does NOT create a request for an unlisted service

#### P2 | HCP-NC-7: Service out of scope (configured categories)
- [ ] If business has callsaverCategories, request a service outside those categories
- [ ] Agent should decline

---

### B. Returning Caller Flow (HCP)

**Prerequisites**: Known phone with customer record, properties, leads, scheduled estimates, jobs with appointments.

**Key behavior**: Returning callers get a DIFFERENT prompt (no new-caller steps). Agent should NOT ask for name or try to create a customer.

#### P0 | HCP-RC-1: Single property — new service request
- [ ] Call from known number
- [ ] Agent greets by name (no "What's your name?")
- [ ] Agent confirms existing property: "I have your address as [address]. Is this where you need service?"
- [ ] Confirm → agent uses existing property_id
- [ ] Agent creates service request
- [ ] **Verify in HCP**: lead linked to existing customer and property

#### P1 | HCP-RC-2: Multiple properties — select existing
- [ ] Customer has 2+ properties
- [ ] Agent lists: "I see you have [addr 1] and [addr 2]. Which property is this for?"
- [ ] Select one → correct property_id used

#### P1 | HCP-RC-3: Multiple properties — add NEW property
- [ ] "It's for a different address"
- [ ] Agent collects new address → validates → checks service area → fs_create_property
- [ ] Uses new property_id
- [ ] **Verify in HCP**: new address on customer, lead linked to new property

#### P1 | HCP-RC-4: Zero properties
- [ ] Customer exists but no properties
- [ ] Agent collects address from scratch

#### P0 | HCP-RC-5: Check schedule
- [ ] "What do I have coming up?"
- [ ] Agent calls fs_get_client_schedule
- [ ] Lists items with dates, times, types
- [ ] **Verify**: matches HCP dashboard

#### P1 | HCP-RC-6: Check request status
- [ ] "What's the status of my request?"
- [ ] Agent calls fs_get_requests / fs_get_request
- [ ] Reports status

#### P0 | HCP-RC-7: Reschedule estimate
- [ ] "I need to reschedule my estimate"
- [ ] Agent calls fs_check_availability for new date
- [ ] Presents available times
- [ ] Agent calls fs_reschedule_assessment
- [ ] **Verify in HCP**: estimate rescheduled

#### P1 | HCP-RC-8: Cancel estimate
- [ ] "I need to cancel my estimate"
- [ ] Agent confirms → calls fs_cancel_assessment
- [ ] **Verify in HCP**: estimate cancelled

#### P1 | HCP-RC-9: Check job status
- [ ] "What's the status of my job?"
- [ ] Agent calls fs_get_jobs / fs_get_job
- [ ] Reports status, assigned tech, appointments

#### P1 | HCP-RC-10: Reschedule job appointment
- [ ] "I need to reschedule my appointment"
- [ ] Agent calls fs_check_availability → fs_reschedule_appointment
- [ ] **Verify in HCP**: appointment rescheduled

#### P1 | HCP-RC-11: Cancel job appointment
- [ ] Agent confirms → fs_cancel_appointment
- [ ] **Verify in HCP**: appointment removed

#### P2 | HCP-RC-12: Update contact info
- [ ] "I need to update my email"
- [ ] Agent calls fs_update_customer
- [ ] **Verify in HCP**: customer info updated

---

### C. Unhandled Intent Deferral (HCP)

These intents are NOT fully handled. Agent should acknowledge, capture context, and defer via callback or transfer.

#### P1 | HCP-UI-1: Recurring service
- [ ] "Can you set up my monthly lawn maintenance?"
- [ ] Agent creates service request noting it's recurring
- [ ] Does NOT try to create a Job directly

#### P1 | HCP-UI-2: Estimate follow-up
- [ ] "Did you send my estimate yet?"
- [ ] Agent looks up via fs_get_requests
- [ ] Relays info if available, otherwise defers to callback

#### P1 | HCP-UI-3: Approved estimate — wants to schedule work
- [ ] "I approved the estimate, when can you start?"
- [ ] Agent checks fs_get_jobs for created job
- [ ] If job with appointment → provide details
- [ ] If not → "The office will get the work order set up and reach out to schedule"

#### P1 | HCP-UI-4: Warranty / failed repair
- [ ] "The plumber was here last week and the leak came back"
- [ ] Agent creates NEW service request referencing previous work
- [ ] Description notes: "Follow-up/warranty — previous repair did not hold"

#### P1 | HCP-UI-5: Billing question
- [ ] "Can I get a copy of my invoice?" → defers to callback/transfer

#### P1 | HCP-UI-6: Payment
- [ ] "I want to pay my bill" → defers to callback/transfer

#### P1 | HCP-UI-7: Pricing negotiation
- [ ] "The estimate seems too high" → defers: "I'll have someone follow up to discuss"

#### P2 | HCP-UI-8: Specific technician request
- [ ] "Can I get the same tech?" → notes preference in service request

#### P0 | HCP-UI-9: Emergency / urgent
- [ ] "My pipe burst, I need someone NOW"
- [ ] Agent captures urgency in service request (high priority)
- [ ] Path B: offers immediate transfer
- [ ] Path A: creates urgent callback request

#### P0 | HCP-UI-10: Safety hazard
- [ ] "I smell gas" → STOPS workflow, gives safety instructions
- [ ] Does NOT schedule service during active emergency
- [ ] After caller confirms safety, offers to arrange service

#### P1 | HCP-UI-11: Leave a message
- [ ] "Can I just leave a message?"
- [ ] Agent takes full message → creates callback request with content

#### P1 | HCP-UI-12: Technician status / ETA
- [ ] "Where is my technician?" / "Is someone on the way?"
- [ ] Agent looks up via fs_get_client_schedule or fs_get_appointments
- [ ] Shares scheduled time, tech name, visit status if available
- [ ] If can't determine real-time status: "Let me have the office check on that" + callback request

---

### D. Edge Cases (HCP)

#### P2 | HCP-EC-1: Greeting — no duplicate words
- [ ] Call at different times of day
- [ ] "Good morning [Name]" — NOT "Good morning, morning [Name]"

#### P2 | HCP-EC-2: Caller says they're someone else
- [ ] Call from known number → "I'm not [Name], I'm [Other Name]"
- [ ] Agent uses new name, may create new customer profile

---

## Part 3: Jobber

### Tools Available (Jobber — 13 FS tools + base)
| Tool | Description |
|------|-------------|
| fs_get_customer_by_phone | Customer lookup by phone |
| fs_create_customer | Create new client |
| fs_update_customer | Update client info |
| fs_list_properties | List client's properties |
| fs_create_property | Create new property |
| fs_create_service_request | Create request (assessment auto-created) |
| fs_get_request / fs_get_requests | Get request details |
| fs_check_availability | Check available windows |
| fs_reschedule_assessment | Schedule/reschedule assessment |
| fs_cancel_assessment | Cancel assessment |
| fs_get_services | Get service catalog |
| fs_get_client_schedule | Get all upcoming items |
| validate-address | Validate and geocode addresses |
| collect-email | Voice-to-text email normalization |
| request-callback | Callback request (both paths) |
| transfer-call | Transfer (Path B only) |

> **Tools NOT available for Jobber** (vs HCP): `fs_get_jobs`, `fs_get_job`, `fs_get_appointments`, `fs_reschedule_appointment`, `fs_cancel_appointment`. Agent must defer job/appointment intents to callback/transfer.

### Key Differences from HCP
- **Service area**: city only against AREAS SERVED (NOT ZIP-based zones)
- Assessment entity = **"assessment"** (not "estimate/consultation")
- IDs are **Jobber EncodedIds** (base64 strings like `Z2lkOi8v...`) — agent should never expose these
- **No job/appointment tools** — agent must defer those intents to callback/transfer
- Config toggles same: `autoScheduleAssessment`, `includePricing`

---

### A. New Caller Flow (Jobber)

#### P0 | JOB-NC-1: Full happy path (autoSchedule=true, includePricing=true)
- [ ] Call from unknown number
- [ ] Agent matches service to catalog
- [ ] **Agent mentions price** (includePricing=true)
- [ ] Agent collects name → calls fs_create_customer
- [ ] Agent collects address (street + city only) → validates via validate_address
- [ ] **Agent checks service area**: city against AREAS SERVED in system prompt
- [ ] Agent calls fs_create_property → fs_create_service_request → fs_check_availability → fs_reschedule_assessment
- [ ] **Verify in Jobber**: client, property, request, scheduled assessment

#### P0 | JOB-NC-2: autoSchedule=false
- [ ] Agent says "team will review and reach out to schedule"
- [ ] Agent does NOT call fs_check_availability or fs_reschedule_assessment

#### P1 | JOB-NC-3: includePricing=false
- [ ] Agent does NOT mention any prices
- [ ] If asked: "Pricing depends on the specifics"

#### P1 | JOB-NC-4: Outside service area (city check)
- [ ] City NOT in AREAS SERVED → agent declines
- [ ] **Verify**: no request created in Jobber

#### P1 | JOB-NC-5: Service not in catalog
- [ ] Request unlisted service → agent declines, lists available services

---

### B. Returning Caller Flow (Jobber)

#### P0 | JOB-RC-1: Single property — new request
- [ ] Same flow as HCP-RC-1 (greet by name, confirm property, create request)

#### P1 | JOB-RC-2: Multiple properties — select existing
- [ ] Same as HCP-RC-2

#### P1 | JOB-RC-3: Multiple properties — add NEW
- [ ] Same as HCP-RC-3

#### P1 | JOB-RC-4: Zero properties
- [ ] Same as HCP-RC-4

#### P0 | JOB-RC-5: Check schedule
- [ ] "What do I have coming up?"
- [ ] Agent calls fs_get_client_schedule
- [ ] Lists assessments, visits, tasks

#### P1 | JOB-RC-6: Check request status
- [ ] Agent calls fs_get_requests / fs_get_request

#### P0 | JOB-RC-7: Reschedule assessment
- [ ] Same as HCP-RC-7

#### P1 | JOB-RC-8: Cancel assessment
- [ ] Same as HCP-RC-8

#### P2 | JOB-RC-9: Update contact info
- [ ] Same as HCP-RC-12

#### P1 | JOB-RC-10: Asks about jobs/appointments (NO tools available)
- [ ] "Can I reschedule my appointment?" or "What's my job status?"
- [ ] Agent does NOT have job/appointment tools
- [ ] Must defer: "Let me have the office follow up on that for you"

---

### C. Unhandled Intent Deferral (Jobber)

Same as HCP unhandled intents (HCP-UI-1 through HCP-UI-12) with these additions:

#### P1 | JOB-UI-EXTRA-1: Job/appointment questions → defer
- [ ] Any question about jobs, visits, quotes, or appointments beyond the request/assessment level
- [ ] Agent must defer to callback/transfer (no tools for this in Jobber)

---

## Part 4: Cross-Integration Tests

### Safety Hazards (Test in Each Mode)

#### P0 | CROSS-SAFETY-1: Gas leak
Test once per mode (No Integration, GCal, HCP, Jobber):
- [ ] "I smell gas in my kitchen"
- [ ] Agent STOPS workflow, gives safety instructions (leave area, call 911)
- [ ] Does NOT schedule service or collect info during emergency

#### P1 | CROSS-SAFETY-2: Electrical fire
- [ ] "There are sparks coming from my electrical panel"
- [ ] Agent: "Call 911 if flames or smoke. Once safe, call us back."

#### P1 | CROSS-SAFETY-3: Carbon monoxide
- [ ] "My CO alarm is going off"
- [ ] Agent: "Leave immediately, call 911."

---

### Prompt Split Verification

#### P0 | SPLIT-1: New caller gets new-caller workflow (HCP/Jobber)
- [ ] Call from unknown number on FS integration
- [ ] Agent follows step-by-step: service match → name → create customer → address → validate → service area → create property → create request
- [ ] Agent does NOT mention "pre-loaded customer_id" or ask "which property?"

#### P0 | SPLIT-2: Returning caller gets returning-caller workflow (HCP/Jobber)
- [ ] Call from known number with existing customer + properties
- [ ] Agent greets by name, asks how to help
- [ ] Agent does NOT ask for name or try to create customer
- [ ] Agent offers property selection (2+) or confirms (1)

#### P1 | SPLIT-3: GCal returning caller — info pre-loaded
- [ ] Call from known number on GCal
- [ ] Agent greets by name, does NOT re-collect info
- [ ] If upcoming events exist, agent references them

#### P1 | SPLIT-4: GCal new caller — full intake
- [ ] Call from unknown number on GCal
- [ ] Agent follows intake flow (name, address, email, service)

---

### Service Area Comparison

| Test | HCP | Jobber | GCal | No Integration |
|------|-----|--------|------|----------------|
| City matches → accept | Prompt (zones) | Prompt (AREAS SERVED) | Prompt (AREAS SERVED) | Prompt (AREAS SERVED) |
| ZIP matches → accept | Prompt (zones) | N/A (city only) | N/A (city only) | N/A (city only) |
| Neither matches → reject | Yes | Yes | Yes | Yes |

### Pricing Comparison

| Test | HCP | Jobber | GCal | No Integration |
|------|-----|--------|------|----------------|
| includePricing=true | Prices mentioned | Prices mentioned | N/A (catalog) | From prompt |
| includePricing=false | Prices hidden | Prices hidden | N/A | N/A |

### Scheduling Comparison

| Test | HCP | Jobber | GCal | No Integration |
|------|-----|--------|------|----------------|
| autoSchedule=true | Books estimate | Books assessment | Always books | N/A |
| autoSchedule=false | Team handles | Team handles | N/A | N/A |

---

### Agent Identity (Test in Each Mode)

#### P1 | CROSS-IDENTITY-1: "Are you a real person?"
- [ ] Caller: "Are you a real person?" or "Am I talking to a bot?"
- [ ] Agent responds briefly: "I'm a virtual assistant that helps handle calls for our team"
- [ ] Agent does NOT proactively disclose AI status — only admits when directly asked
- [ ] Agent continues helping normally after the response

#### P1 | CROSS-IDENTITY-2: Agent never self-identifies as AI unprompted
- [ ] Complete any normal flow (booking, intake, callback)
- [ ] Verify agent never says "as an AI", "I'm a bot", "I'm an automated system" during the flow
- [ ] Agent should sound natural throughout

#### P1 | CROSS-IDENTITY-3: "I'm not [Name]" — someone else on the phone (all modes)
Test once per mode (No Integration, GCal, HCP, Jobber):
- [ ] Call from known number → agent greets by name
- [ ] "I'm not Alex, I'm Sarah"
- [ ] Agent switches to using "Sarah" for this call
- [ ] Agent does NOT update the stored caller record
- [ ] FS modes: agent may create a new customer if service is requested

---

### Caller Context & Personalization (Returning Callers)

#### P1 | CROSS-CONTEXT-1: GCal returning caller — agent references recent activity
- [ ] Prerequisites: Returning caller with recent call that scheduled an appointment
- [ ] Agent greets by name and references recent activity: "I see we scheduled an appointment for you recently"
- [ ] Agent uses upcoming event context to inform conversation
- [ ] **Verify**: agent does NOT just ignore the pre-loaded context

#### P1 | CROSS-CONTEXT-2: FS returning caller — agent references profile summary
- [ ] Prerequisites: Returning caller with profileSummary populated
- [ ] Agent shows awareness of caller history
- [ ] **Verify**: natural reference, not robotic ("I see you've called us before about...")

---

### Promotions & Discounts (All Modes Where Configured)

**Prerequisites**: Configure at least 2 promotions on the test location (e.g., "10% off first visit", "$50 off water heater install").

#### P1 | CROSS-PROMO-1: Caller asks about deals
- [ ] "Do you have any specials going on?" or "Any discounts?"
- [ ] Agent mentions relevant promotion(s) concisely
- [ ] Agent does NOT read ALL promotions — picks the most relevant one
- [ ] **Verify**: promotion content matches configured data

#### P1 | CROSS-PROMO-2: Agent mentions promotion after booking (proactive)
- [ ] Complete a booking (GCal/HCP/Jobber)
- [ ] Agent asks "anything else?" → during this moment, agent briefly mentions ONE relevant promotion
- [ ] **Verify**: NOT mentioned during intake, only after primary request resolved

#### P1 | CROSS-PROMO-3: Agent does NOT mention promotions when caller is rushed
- [ ] Caller seems impatient: "Just schedule me for the soonest time, I'm in a hurry"
- [ ] Agent completes request efficiently
- [ ] Agent does NOT bring up promotions
- [ ] **Verify**: no promotion mentioned in transcript

---

### FAQ Matching (All Modes Where Configured)

**Prerequisites**: Configure FAQ pairs (e.g., Q: "Do you offer free estimates?" A: "Yes, all our estimates are free with no obligation.").

#### P1 | CROSS-FAQ-1: Caller asks a configured FAQ question
- [ ] Caller: "Do you charge for estimates?"
- [ ] Agent answers from configured FAQ, does NOT say "I'll check with the office"
- [ ] **Verify**: answer matches configured FAQ content

#### P1 | CROSS-FAQ-2: Caller asks question NOT in FAQ
- [ ] "Do you offer 24-hour emergency service?" (not in FAQ)
- [ ] Agent does NOT hallucinate an answer
- [ ] Defers: "I'd want to double-check that for you — let me have someone follow up"

---

### Escalation — Angry/Irate Caller (All Modes)

#### P1 | CROSS-ESCALATION-1: Angry caller demands to speak to someone
- [ ] Caller is visibly frustrated: "This is ridiculous, I need to talk to a real person NOW"
- [ ] Agent immediately offers transfer (Path B) or callback (Path A)
- [ ] Agent does NOT continue intake flow or try to de-escalate extensively
- [ ] **Verify**: agent prioritizes escalation over data collection

#### P1 | CROSS-ESCALATION-2: Caller demands discount/exception
- [ ] "I want a discount" or "You need to make this right"
- [ ] Agent defers to human: "I'll have someone from the team follow up to discuss that with you"
- [ ] Agent does NOT promise a discount or make up a resolution

---

### Commercial vs Residential Triage (HCP / Jobber)

#### P1 | FS-TRIAGE-1: Agent asks commercial or residential when unclear
- [ ] Caller: "I need some plumbing work done at my property"
- [ ] Agent asks: "Is this for a residential home or a commercial property?"
- [ ] Answer included in service request description
- [ ] **Verify in platform**: description mentions "commercial" or "residential"

---

### Service Detail Triage — Probing for Vague Requests (All Modes)

#### P1 | CROSS-TRIAGE-1: Vague request triggers follow-up
- [ ] Caller: "I need some plumbing help"
- [ ] Agent probes: "Can you tell me a bit more about what's going on?"
- [ ] Caller provides detail → agent proceeds
- [ ] **Verify**: agent asked 1-2 follow-up questions before intake

#### P1 | CROSS-TRIAGE-2: Detailed request skips probing
- [ ] Caller: "My kitchen faucet is leaking from the base and there's water pooling under the cabinet"
- [ ] Agent does NOT ask "what's happening?" — moves directly to intake
- [ ] **Verify**: no redundant probing questions

---

### Business Hours — Real-Time Query (All Modes)

#### P1 | CROSS-HOURS-1: "Are you open right now?"
- [ ] Agent compares injected current time against business hours
- [ ] Answers correctly: "Yes, we're open until 5 PM today" or "We're currently closed but open again at 8 AM tomorrow"
- [ ] **Verify**: NO tool call, uses prompt context only

---

### Brands Serviced (All Modes Where Configured)

**Prerequisites**: Configure brands (e.g., "Rheem, Lennox, Carrier, Trane").

#### P1 | CROSS-BRANDS-1: Caller asks about a listed brand
- [ ] "Do you work on Rheem water heaters?"
- [ ] Agent confirms: "Yes, we work with Rheem"

#### P1 | CROSS-BRANDS-2: Caller asks about an unlisted brand
- [ ] "Do you service Noritz tankless heaters?"
- [ ] Agent does NOT say "we don't service that"
- [ ] Instead: "We work with many brands. Let me have our team confirm we can help with Noritz"

---

### Policies — Estimate/Diagnostic Fee/Financing (All Modes Where Configured)

#### P1 | CROSS-POLICY-1: "Do you charge for estimates?"
- [ ] Agent answers from configured estimatePolicyText
- [ ] **Verify**: matches policy, not hallucinated

#### P1 | CROSS-POLICY-2: "Do you offer financing?"
- [ ] Agent answers from configured financing info (if present)
- [ ] If not configured: "Let me have the office follow up with financing details"

---

### Trust & Credentials (All Modes Where Configured)

#### P1 | CROSS-TRUST-1: "Are you licensed and insured?"
- [ ] Agent answers from configured trust_and_guarantees
- [ ] **Verify**: references credentials naturally, not a recitation

---

### Path B Specific Scenarios (All Modes)

#### P1 | CROSS-PATHB-1: Path B — transfer offered for "speak to someone"
- [ ] Path B location, any integration
- [ ] "Can I talk to someone?" → agent uses transfer-call
- [ ] **Verify**: transfer tool called, NOT request-callback

#### P1 | CROSS-PATHB-2: Path B — caller prefers callback over transfer
- [ ] Path B location, any integration
- [ ] "Just have them call me back" → agent uses request-callback (not transfer)
- [ ] **Verify**: callback tool called even though transfer is available

---

### Multiple Services in One Call (HCP / Jobber)

#### P1 | FS-MULTI-1: Caller needs two services in one call
- [ ] "I need a leak repair AND a drain cleaning"
- [ ] Agent creates ONE service request with combined description
- [ ] Agent does NOT call fs_create_service_request twice
- [ ] **Verify in platform**: single request with both services described

---

### County-Based Service Area Matching

#### P1 | CROSS-AREA-1: Caller in city within a listed county
- [ ] Location has "Santa Cruz County" in service areas (which includes Watsonville, Capitola, Scotts Valley, etc.)
- [ ] Caller provides address in "Watsonville"
- [ ] Agent accepts — city is within the expanded county list
- [ ] **Verify**: agent does NOT reject a valid in-county city

---

### P2 Edge Cases & Guardrails

#### P2 | FS-TIME-1: Caller has no time preference (HCP / Jobber)
- [ ] "Whenever works" or "Anytime is fine"
- [ ] Agent passes "No preference - anytime works" as desired_time
- [ ] **Verify in logs**: desired_time field contains fallback text

#### P2 | FS-GUARD-1: Assessment auto-created — no separate tool call (HCP / Jobber)
- [ ] Complete new caller flow through fs_create_service_request
- [ ] **Verify in logs**: NO fs_create_assessment tool call
- [ ] Assessment ID comes from service request response

#### P2 | FS-GUARD-2: Agent does NOT create customer twice (HCP / Jobber)
- [ ] After fs_create_customer returns customer_id
- [ ] Conversation continues with a follow-up that re-enters the flow
- [ ] Agent reuses existing customer_id — does NOT call fs_create_customer again
- [ ] **Verify in logs**: only one fs_create_customer call

#### P2 | CROSS-PAY-1: "What forms of payment do you accept?"
- [ ] Agent answers from Google Place Details payment options
- [ ] "We accept credit cards and debit cards"
- [ ] **Verify**: no hallucinated payment methods

#### P2 | CROSS-VALUE-1: "Why should I choose you over [competitor]?"
- [ ] Agent references value propositions from prompt
- [ ] Natural, not a sales pitch
- [ ] Does NOT badmouth the competitor

#### P2 | CROSS-PROPTYPE-1: "Do you work on commercial properties?"
- [ ] Agent answers based on configured property_types_served
- [ ] If not configured → "Let me have someone from the team confirm that for you"

#### P2 | CROSS-INTAKE-9: Numeric answers submitted correctly
- [ ] Custom intake question: "What is the square footage?"
- [ ] Caller: "about four thousand"
- [ ] Agent submits "4000" (numeric), not "four thousand"
- [ ] **Verify in logs**: submit_intake_answers payload has numeric value

#### P2 | CROSS-WARMXFER-1: Warm transfer when enabled
- [ ] Path B location with warmTransferEnabled=true + org flag on
- [ ] "Can I speak to someone?" → agent uses warm-transfer tool (not transfer-call)
- [ ] **Verify**: warm_transfer tool called

#### P2 | GCAL-EMAIL-1: collect_email tool auto-normalizes
- [ ] GCal location, email required
- [ ] Agent uses collect_email tool (GetEmailTask)
- [ ] Handles "john at gmail dot com" → john@gmail.com
- [ ] Agent then calls submit_intake_answers with normalized email

#### P2 | GCAL-SEC-1: Caller can't cancel someone else's appointment
- [ ] Returning caller asks to cancel an appointment at a time they don't have one
- [ ] System returns error (phone number mismatch)
- [ ] Agent: "I couldn't find an appointment matching that time for this phone number"

#### P2 | FS-DURATION-1: Service-specific duration in availability (HCP)
- [ ] Service has duration: 60 min
- [ ] Agent calls fs_check_availability with duration=60
- [ ] **Verify in logs**: duration parameter passed correctly

#### P2 | FS-DURATION-2: No duration — falls back to default (HCP)
- [ ] Service has no duration defined
- [ ] Agent calls fs_check_availability without duration — server uses default

#### P2 | CROSS-GREET-1: Greeting matches time of day
- [ ] Call at 9 AM → "Good morning"
- [ ] Call at 2 PM → "Good afternoon"
- [ ] Call at 7 PM → "Good evening"
- [ ] **Verify**: no duplicate word ("Good morning, morning Alex")

#### P2 | CROSS-RECORD-1: Recording disclosure in first message
- [ ] Any mode, any caller type
- [ ] First message includes recording disclosure (e.g., "This call may be recorded")
- [ ] **Verify**: present in every call's opening message

---

### EndCallTool — Agent Hang-Up (Test in Each Mode)

The agent should call `EndCallTool` to hang up at the natural end of every conversation. The caller should NOT have to hang up first. Test each trigger across all 4 integration modes.

#### P0 | CROSS-ENDCALL-1: Hang up after booking confirmation (GCal / HCP / Jobber)
Test once per scheduling mode (GCal, HCP autoSchedule=true, Jobber autoSchedule=true):
- [ ] Complete a full booking (new or returning caller)
- [ ] Agent confirms: "Your [appointment/assessment/estimate] is scheduled for [day] at [time] at [address]"
- [ ] Agent asks: "Is there anything else I can help with?"
- [ ] Caller: "No, that's it" / "Nope, thanks"
- [ ] Agent says a natural sign-off: "Great, you're all set. Have a wonderful day!"
- [ ] **Agent calls EndCallTool** — call ends without caller having to hang up
- [ ] **Verify in server logs**: `end_call` tool call appears after final agent utterance

#### P0 | CROSS-ENDCALL-2: Hang up after callback request (all 4 modes)
Test once per mode (No Integration, GCal, HCP, Jobber):
- [ ] Complete intake → agent creates callback request via `request_callback`
- [ ] Agent confirms: "I've requested a callback for you. Someone will reach out shortly."
- [ ] Agent asks if anything else → caller says no
- [ ] Agent says goodbye → **calls EndCallTool**
- [ ] **Verify**: call ends cleanly

#### P0 | CROSS-ENDCALL-3: Hang up after service area rejection (all 4 modes)
Test once per mode:
- [ ] Provide address outside service area
- [ ] Agent declines: "I'm sorry, we don't currently service that area"
- [ ] Agent asks if there's anything else → caller says no
- [ ] Agent says goodbye → **calls EndCallTool**
- [ ] **Verify**: call ends cleanly

#### P1 | CROSS-ENDCALL-4: Hang up after autoSchedule=false confirmation (HCP / Jobber)
- [ ] autoScheduleAssessment=false
- [ ] Complete new caller flow → agent confirms: "Our team will review and reach out to schedule"
- [ ] Agent asks if anything else → caller says no
- [ ] Agent says goodbye → **calls EndCallTool**

#### P1 | CROSS-ENDCALL-5: Hang up after cancel confirmation (GCal / HCP / Jobber)
- [ ] Caller cancels an appointment/assessment/estimate
- [ ] Agent confirms cancellation
- [ ] Agent asks if anything else → caller says no
- [ ] Agent says goodbye → **calls EndCallTool**

#### P1 | CROSS-ENDCALL-6: Hang up after business info only (all 4 modes)
- [ ] Caller only asks about hours/services, does NOT request service
- [ ] Agent answers questions
- [ ] Caller: "That's all I needed, thanks"
- [ ] Agent says goodbye → **calls EndCallTool**

#### P1 | CROSS-ENDCALL-7: Hang up after safety hazard instructions (all 4 modes)
- [ ] Trigger safety hazard ("I smell gas")
- [ ] Agent gives safety instructions
- [ ] Caller: "OK, I'm going outside now"
- [ ] Agent: "Stay safe. Call 911 if needed, and call us back once everything is resolved."
- [ ] Agent says goodbye → **calls EndCallTool**

#### P2 | CROSS-ENDCALL-8: Agent does NOT hang up prematurely
- [ ] Complete a booking, agent asks "anything else?"
- [ ] Caller: "Actually, yes — I have another question about [X]"
- [ ] Agent answers follow-up question
- [ ] Only hangs up after caller confirms they're done

---

### Email Collection (Test in Each Mode)

Email collection behavior differs by integration. The agent should ask the caller to **spell out their email** for accuracy.

#### P0 | CROSS-EMAIL-1: No Integration — email during intake
- [ ] New caller, No Integration location with email in intake questions
- [ ] Agent collects name → address → reaches email step
- [ ] Agent asks for email: "Could I get your email address?"
- [ ] Caller provides email → agent asks to spell it for confirmation
- [ ] Agent calls `submit_intake_answers` with email included
- [ ] **Verify**: Caller record has email saved

#### P0 | CROSS-EMAIL-2: GCal — email required for appointment reminders
- [ ] New caller, GCal location
- [ ] Agent collects name, address, service → reaches email step
- [ ] Agent asks for email (REQUIRED for GCal — needed for appointment reminders)
- [ ] Agent asks caller to spell it
- [ ] Agent calls `submit_intake_answers` with email
- [ ] Agent proceeds to booking
- [ ] **Verify**: Caller record has email, calendar event created

#### P1 | CROSS-EMAIL-3: GCal — caller declines to give email
- [ ] New caller, GCal location
- [ ] Agent asks for email → caller: "I'd rather not give that"
- [ ] Agent should explain email is needed for appointment reminders/confirmation
- [ ] If caller still declines → agent proceeds without email (does not block the call)
- [ ] **Verify**: booking still completes

#### P0 | CROSS-EMAIL-4: HCP — email during customer creation
- [ ] New caller, HCP location
- [ ] Agent collects name → asks for email before or after address
- [ ] Agent asks caller to spell it
- [ ] Agent calls `fs_create_customer` with `email` parameter
- [ ] **Verify in HCP**: customer record has email

#### P0 | CROSS-EMAIL-5: Jobber — email during customer creation
- [ ] New caller, Jobber location
- [ ] Same flow as HCP — email passed to `fs_create_customer`
- [ ] **Verify in Jobber**: client record has email

#### P1 | CROSS-EMAIL-6: Email optional — caller declines (HCP / Jobber)
- [ ] New caller on HCP or Jobber
- [ ] Agent asks for email → caller: "No thanks"
- [ ] Agent proceeds without email (email is optional for FS integrations)
- [ ] Customer created successfully without email
- [ ] **Verify**: no error, customer exists in platform

#### P1 | CROSS-EMAIL-7: Returning caller — email already on file (all modes)
- [ ] Call from known number with email already saved
- [ ] Agent greets by name
- [ ] Agent does NOT re-ask for email
- [ ] **Verify**: no redundant email collection

#### P2 | CROSS-EMAIL-8: Returning caller — email missing, agent collects it
- [ ] Call from known number WITHOUT email on record
- [ ] For FS integrations: agent may ask for email during the flow
- [ ] For GCal: agent should ask for email (needed for reminders)
- [ ] **Verify**: email saved on subsequent calls

---

### Custom Intake Questions (Test in Each Mode)

Custom intake questions are configured per-location (e.g., "How did you hear about us?", "Do you have pets?", "What brand is your equipment?"). They are injected into the system prompt and the agent asks them during intake.

**Prerequisites**: Configure 2-3 custom intake questions on the test location for each mode:
- A **freeform text** question (e.g., "How did you hear about us?")
- A **yes/no** question (e.g., "Do you have pets at the property?")
- A **required** question vs an **optional** question

#### P0 | CROSS-INTAKE-1: No Integration — custom questions asked and saved
- [ ] New caller, No Integration location with custom intake questions configured
- [ ] Agent follows intake flow: name → address → email → custom questions
- [ ] Agent asks each configured question in order
- [ ] Caller answers each question
- [ ] Agent calls `submit_intake_answers` — answers included in payload
- [ ] **Verify in server logs**: `submit_intake_answers` payload contains question labels and answer text
- [ ] **Verify in dashboard**: Caller record shows intake answers

#### P0 | CROSS-INTAKE-2: GCal — custom questions asked and saved
- [ ] New caller, GCal location with custom intake questions configured
- [ ] Agent follows intake flow including custom questions
- [ ] Agent calls `submit_intake_answers` with all answers
- [ ] Agent proceeds to booking
- [ ] **Verify**: intake answers saved, calendar event created

#### P0 | CROSS-INTAKE-3: HCP — custom questions passed via intake_answers
- [ ] New caller, HCP location with custom intake questions configured
- [ ] Agent follows new-caller workflow: service → name → customer → address → property → custom questions
- [ ] Agent asks each configured intake question
- [ ] Agent calls `fs_create_service_request` with `intake_answers` parameter containing question/answer pairs
- [ ] **Verify in HCP**: lead note contains intake answers (HCP stores them in the lead note text)
- [ ] **Verify in server logs**: `create-service-request` request body has `intakeAnswers` field

#### P0 | CROSS-INTAKE-4: Jobber — custom questions passed via intake_answers
- [ ] New caller, Jobber location with custom intake questions configured
- [ ] Same flow as HCP — agent asks custom questions
- [ ] Agent calls `fs_create_service_request` with `intake_answers` parameter
- [ ] **Verify in Jobber**: request has "Intake Answers" section in Request Details form
- [ ] **Verify in server logs**: `create-service-request` request body has `intakeAnswers` field

#### P1 | CROSS-INTAKE-5: Returning caller — skip already-known answers
- [ ] Call from known number on any integration
- [ ] If the custom question's answer can be inferred from existing data (e.g., name already on file), agent should skip it
- [ ] Agent only asks questions that haven't been answered yet
- [ ] **Verify**: agent does not redundantly ask for name/address that's already pre-loaded

#### P1 | CROSS-INTAKE-6: Caller says "I don't know" / "skip" to a custom question
- [ ] New caller on any integration with required + optional custom questions
- [ ] Caller says "I don't know" or "skip" for one question
- [ ] Agent acknowledges and moves on (does NOT loop or insist)
- [ ] Answer recorded as skipped/blank
- [ ] **Verify**: remaining questions still asked, intake completes

#### P1 | CROSS-INTAKE-7: HCP/Jobber — fs_submit_lead includes intake_answers
- [ ] New caller on HCP or Jobber
- [ ] If agent uses `fs_submit_lead` (shortcut tool) instead of step-by-step tools
- [ ] Custom intake answers should still be passed via `intake_answers` parameter
- [ ] **Verify in server logs**: `submit-lead` request body has `intakeAnswers` field

#### P2 | CROSS-INTAKE-8: No custom questions configured — agent skips intake section
- [ ] Location with zero custom intake questions configured
- [ ] Agent still collects standard info (name, address, email) but does NOT ask extra questions
- [ ] No "Intake Answers" section in service request
- [ ] Flow completes normally

---

## Pre-Test Setup Checklist

### Environment
- [ ] API server running: `cd ~/callsaver-api && npm run dev`
- [ ] LiveKit Python agent ready: `cd ~/callsaver-api/livekit-python && source .venv/bin/activate`
- [ ] Console test command template ready (see "How to Use" section)

### No Integration Setup
- [ ] Location with no integrations connected
- [ ] CallerAddress records for returning caller tests
- [ ] Service areas (AREAS SERVED) configured with known in-area and out-of-area cities
- [ ] Business hours configured
- [ ] Services listed
- [ ] FAQ, brands, discounts configured in location
- [ ] Intake questions configured (name, address, email, custom)
- [ ] Path A and Path B locations available

### Google Calendar Setup
- [ ] Location with Google Calendar connected
- [ ] CallerAddress records for returning callers
- [ ] Existing calendar events (for list/reschedule/cancel tests)
- [ ] defaultAppointmentMinutes configured (e.g., 60)
- [ ] bufferMinutes configured (e.g., 15)
- [ ] Business hours in Google Place Details
- [ ] AREAS SERVED configured

### HCP Setup
- [ ] Location with HCP connected
- [ ] Customer records: one with 1 property, one with 2+ properties, one with 0 properties
- [ ] Leads/requests: some with scheduled estimates, some unscheduled
- [ ] Jobs with scheduled appointments
- [ ] Service zones configured with cities AND zip codes
- [ ] Price book populated with services
- [ ] autoScheduleAssessment toggle tested in both states
- [ ] includePricing toggle tested in both states
- [ ] Path A and Path B locations

### Jobber Setup
- [ ] Location with Jobber connected
- [ ] Client records: one with 1 property, one with 2+ properties, one with 0 properties
- [ ] Requests: some with scheduled assessments, some unscheduled
- [ ] Service catalog populated
- [ ] AREAS SERVED list configured
- [ ] Same toggles as HCP

### Phone Numbers
- [ ] Unknown number (new caller) — not in any platform
- [ ] Known number — returning caller with 1 property
- [ ] Known number — returning caller with 2+ properties
- [ ] Known number — returning caller with 0 properties

---

## Verification Checklist (After Each Test)

### Platform Checks
- [ ] Created records appear in platform dashboard (HCP / Jobber / Google Calendar)
- [ ] Callback requests appear in CallSaver dashboard Callback Requests tab
- [ ] CallerAddress synced (from fs_create_property or submit-intake-answers)

### Agent Behavior
- [ ] Greeting correct (no duplicated words, uses name for returning callers)
- [ ] Pricing matches includePricing toggle
- [ ] Scheduling matches autoScheduleAssessment toggle
- [ ] Service area rejection works for out-of-area addresses
- [ ] Business hours enforced (no tool call for out-of-hours requests)
- [ ] Prompt split correct (new caller = new instructions, returning = returning instructions)
- [ ] Unhandled intents gracefully deferred (not ignored or errored)
- [ ] Safety hazards trigger immediate stop + safety instructions

### Server Logs to Watch
```
# Field service instructions injected
✅ Injected field-service instructions (NEW/RETURNING caller, autoScheduleAssessment: true/false)

# Scheduling config
✅ Injected scheduling configuration (duration: Xmin, buffer: Ymin)

# Availability checking
[checkAvailability] duration=Xmin buffer=Ymin items=X/Y

# GCal event creation
[google-calendar-create-event] Created event on [date] from [time] to [time]
```

### GCal-Specific Checks
- [ ] Event `extendedProperties.shared` has `source: callsaver`
- [ ] Event duration = defaultAppointmentMinutes
- [ ] Caller phone in `extendedProperties.shared.callerPhoneNumber`

---

## Test Result Tracking

Copy this table and fill in as you test. Use: **Pass** / **Fail** / **Partial** / **Skip**

### No Integration
| ID | Scenario | Priority | Result | Notes | Date |
|----|----------|----------|--------|-------|------|
| NONE-NC-1 | Business info questions | P0 | **Pass** | Fully successful | 2/25 |
| NONE-NC-2 | Full intake + callback (A) | P0 | **Partial** | 1) Name skip on 1st attempt (intermittent — 2nd attempt OK). 2) No callback request created. 3) CallerAddress not showing in CallerDetailsPage. 4) callerName/First/Last null on CallRecord despite Caller having name. 5) Email not asked — expected (removed from intake). submit_intake_answers tool fired with correct name+address. | 2/25 |
| NONE-NC-3 | Intake + transfer (B) | P0 | | | |
| NONE-NC-4 | Outside service area | P1 | | | |
| NONE-NC-5 | Service not offered | P1 | | | |
| NONE-NC-6 | Pricing question | P1 | | | |
| NONE-RC-1 | Returning — recognized | P1 | | | |
| NONE-RC-2 | Returning — asks about appt | P1 | | | |
| NONE-EC-1 | Prefers callback (B) | P1 | | | |
| NONE-EC-2 | Speak to owner | P1 | | | |
| NONE-EC-3 | Leave a message | P1 | | | |
| NONE-EC-4 | Safety — gas leak | P0 | | | |
| NONE-EC-5 | Safety — flooding | P1 | | | |
| NONE-EC-6 | Address without city | P2 | | | |
| NONE-EC-7 | Incomplete name | P2 | | | |

### Google Calendar
| ID | Scenario | Priority | Result | Notes | Date |
|----|----------|----------|--------|-------|------|
| GCAL-NC-1 | Full booking | P0 | | | |
| GCAL-NC-2 | Outside service area | P1 | | | |
| GCAL-NC-3 | Outside business hours | P1 | | | |
| GCAL-NC-4 | Closed day | P1 | | | |
| GCAL-NC-5 | Early morning | P2 | | | |
| GCAL-RC-1 | Returning — new booking | P0 | | | |
| GCAL-RC-2 | Returning — multi address | P1 | | | |
| GCAL-RC-3 | List appointments | P0 | | | |
| GCAL-RC-4 | Reschedule | P0 | | | |
| GCAL-RC-5 | Cancel | P0 | | | |
| GCAL-BH-1 | Hours question (no tool) | P1 | | | |
| GCAL-BH-2 | Buffer time | P1 | | | |
| GCAL-BH-3 | Natural availability | P2 | | | |
| GCAL-CT-1 | Callback | P1 | | | |
| GCAL-CT-2 | Transfer (B) | P1 | | | |
| GCAL-UI-1 | Billing | P1 | | | |
| GCAL-UI-2 | Leave a message | P1 | | | |
| GCAL-UI-3 | Safety hazard | P0 | | | |
| GCAL-NC-6 | Next available appointment | P1 | | | |
| GCAL-RC-6 | Change service type on event | P1 | | | |
| GCAL-RC-7 | Add service to event | P1 | | | |
| GCAL-EMAIL-1 | collect_email normalization | P2 | | | |
| GCAL-SEC-1 | Can't cancel others' events | P2 | | | |

### Housecall Pro
| ID | Scenario | Priority | Result | Notes | Date |
|----|----------|----------|--------|-------|------|
| HCP-NC-1 | Full happy path | P0 | | | |
| HCP-NC-2 | autoSchedule=false | P0 | | | |
| HCP-NC-3 | includePricing=false | P1 | | | |
| HCP-NC-4 | Outside service area | P1 | | | |
| HCP-NC-5 | Service area boundary | P2 | | | |
| HCP-NC-6 | Service not in catalog | P1 | | | |
| HCP-NC-7 | Out of scope (categories) | P2 | | | |
| HCP-RC-1 | Single property — request | P0 | | | |
| HCP-RC-2 | Multi property — select | P1 | | | |
| HCP-RC-3 | Multi property — add new | P1 | | | |
| HCP-RC-4 | Zero properties | P1 | | | |
| HCP-RC-5 | Check schedule | P0 | | | |
| HCP-RC-6 | Check request status | P1 | | | |
| HCP-RC-7 | Reschedule estimate | P0 | | | |
| HCP-RC-8 | Cancel estimate | P1 | | | |
| HCP-RC-9 | Check job status | P1 | | | |
| HCP-RC-10 | Reschedule appointment | P1 | | | |
| HCP-RC-11 | Cancel appointment | P1 | | | |
| HCP-RC-12 | Update contact info | P2 | | | |
| HCP-UI-1 | Recurring service | P1 | | | |
| HCP-UI-2 | Estimate follow-up | P1 | | | |
| HCP-UI-3 | Approved estimate | P1 | | | |
| HCP-UI-4 | Warranty / failed repair | P1 | | | |
| HCP-UI-5 | Billing question | P1 | | | |
| HCP-UI-6 | Payment | P1 | | | |
| HCP-UI-7 | Pricing negotiation | P1 | | | |
| HCP-UI-8 | Specific tech request | P2 | | | |
| HCP-UI-9 | Emergency / urgent | P0 | | | |
| HCP-UI-10 | Safety hazard | P0 | | | |
| HCP-UI-11 | Leave a message | P1 | | | |
| HCP-UI-12 | Technician status | P1 | | | |
| HCP-EC-1 | Greeting duplication | P2 | | | |
| HCP-EC-2 | Caller is someone else | P2 | | | |

### Jobber
| ID | Scenario | Priority | Result | Notes | Date |
|----|----------|----------|--------|-------|------|
| JOB-NC-1 | Full happy path | P0 | | | |
| JOB-NC-2 | autoSchedule=false | P0 | | | |
| JOB-NC-3 | includePricing=false | P1 | | | |
| JOB-NC-4 | Outside service area | P1 | | | |
| JOB-NC-5 | Service not in catalog | P1 | | | |
| JOB-RC-1 | Single property | P0 | | | |
| JOB-RC-2 | Multi property — select | P1 | | | |
| JOB-RC-3 | Multi property — add new | P1 | | | |
| JOB-RC-4 | Zero properties | P1 | | | |
| JOB-RC-5 | Check schedule | P0 | | | |
| JOB-RC-6 | Check request status | P1 | | | |
| JOB-RC-7 | Reschedule assessment | P0 | | | |
| JOB-RC-8 | Cancel assessment | P1 | | | |
| JOB-RC-9 | Update contact info | P2 | | | |
| JOB-RC-10 | Job/appointment (no tools) | P1 | | | |

### Cross-Integration
| ID | Scenario | Priority | Result | Notes | Date |
|----|----------|----------|--------|-------|------|
| CROSS-SAFETY-1 | Gas leak (each mode) | P0 | | | |
| CROSS-SAFETY-2 | Electrical fire | P1 | | | |
| CROSS-SAFETY-3 | CO alarm | P1 | | | |
| SPLIT-1 | New caller workflow | P0 | | | |
| SPLIT-2 | Returning caller workflow | P0 | | | |
| SPLIT-3 | GCal returning pre-loaded | P1 | | | |
| SPLIT-4 | GCal new caller intake | P1 | | | |
| CROSS-ENDCALL-1 | Hang up after booking | P0 | | | |
| CROSS-ENDCALL-2 | Hang up after callback | P0 | | | |
| CROSS-ENDCALL-3 | Hang up after area reject | P0 | | | |
| CROSS-ENDCALL-4 | Hang up after autoSched=false | P1 | | | |
| CROSS-ENDCALL-5 | Hang up after cancel | P1 | | | |
| CROSS-ENDCALL-6 | Hang up after info only | P1 | | | |
| CROSS-ENDCALL-7 | Hang up after safety | P1 | | | |
| CROSS-ENDCALL-8 | No premature hang up | P2 | | | |
| CROSS-EMAIL-1 | No Integration — email | P0 | | | |
| CROSS-EMAIL-2 | GCal — email required | P0 | | | |
| CROSS-EMAIL-3 | GCal — email declined | P1 | | | |
| CROSS-EMAIL-4 | HCP — email on create | P0 | | | |
| CROSS-EMAIL-5 | Jobber — email on create | P0 | | | |
| CROSS-EMAIL-6 | Email optional — declined | P1 | | | |
| CROSS-EMAIL-7 | Returning — email on file | P1 | | | |
| CROSS-EMAIL-8 | Returning — email missing | P2 | | | |
| CROSS-INTAKE-1 | No Integration — custom Q | P0 | | | |
| CROSS-INTAKE-2 | GCal — custom Q | P0 | | | |
| CROSS-INTAKE-3 | HCP — intake_answers | P0 | | | |
| CROSS-INTAKE-4 | Jobber — intake_answers | P0 | | | |
| CROSS-INTAKE-5 | Returning — skip known | P1 | | | |
| CROSS-INTAKE-6 | Skip / don't know | P1 | | | |
| CROSS-INTAKE-7 | fs_submit_lead + intake | P1 | | | |
| CROSS-INTAKE-8 | No custom Q configured | P2 | | | |
| CROSS-INTAKE-9 | Numeric answers format | P2 | | | |
| CROSS-IDENTITY-1 | "Are you a real person?" | P1 | | | |
| CROSS-IDENTITY-2 | No unprompted AI disclosure | P1 | | | |
| CROSS-IDENTITY-3 | "I'm not [Name]" | P1 | | | |
| CROSS-CONTEXT-1 | GCal returning — recent activity | P1 | | | |
| CROSS-CONTEXT-2 | FS returning — profile summary | P1 | | | |
| CROSS-PROMO-1 | Caller asks about deals | P1 | | | |
| CROSS-PROMO-2 | Promo after booking | P1 | | | |
| CROSS-PROMO-3 | No promo when rushed | P1 | | | |
| CROSS-FAQ-1 | Configured FAQ answered | P1 | | | |
| CROSS-FAQ-2 | Non-FAQ question deferred | P1 | | | |
| CROSS-ESCALATION-1 | Angry caller → escalate | P1 | | | |
| CROSS-ESCALATION-2 | Demands discount → defer | P1 | | | |
| FS-TRIAGE-1 | Commercial vs residential | P1 | | | |
| CROSS-TRIAGE-1 | Vague request → probe | P1 | | | |
| CROSS-TRIAGE-2 | Detailed request → no probe | P1 | | | |
| CROSS-HOURS-1 | "Are you open right now?" | P1 | | | |
| CROSS-BRANDS-1 | Listed brand confirmed | P1 | | | |
| CROSS-BRANDS-2 | Unlisted brand → defer | P1 | | | |
| CROSS-POLICY-1 | Estimate policy | P1 | | | |
| CROSS-POLICY-2 | Financing question | P1 | | | |
| CROSS-TRUST-1 | Licensed and insured | P1 | | | |
| CROSS-PATHB-1 | Path B transfer | P1 | | | |
| CROSS-PATHB-2 | Path B prefers callback | P1 | | | |
| FS-MULTI-1 | Two services one request | P1 | | | |
| CROSS-AREA-1 | County-based city match | P1 | | | |
| FS-TIME-1 | No time preference | P2 | | | |
| FS-GUARD-1 | No separate create_assessment | P2 | | | |
| FS-GUARD-2 | No duplicate customer | P2 | | | |
| CROSS-PAY-1 | Payment methods | P2 | | | |
| CROSS-VALUE-1 | Why choose us | P2 | | | |
| CROSS-PROPTYPE-1 | Commercial properties | P2 | | | |
| CROSS-WARMXFER-1 | Warm transfer | P2 | | | |
| FS-DURATION-1 | Service duration in avail | P2 | | | |
| FS-DURATION-2 | Default duration fallback | P2 | | | |
| CROSS-GREET-1 | Time-of-day greeting | P2 | | | |
| CROSS-RECORD-1 | Recording disclosure | P2 | | | |

---

## P0 Quick Reference (Day 1 Testing)

All P0 scenarios in one list — these must pass before launch:

**Core Happy Paths**
1. **NONE-NC-1** — No Integration: business info questions
2. **NONE-NC-2** — No Integration: full intake + callback
3. **NONE-NC-3** — No Integration: intake + transfer
4. **NONE-EC-4** — No Integration: safety hazard (gas leak)
5. **GCAL-NC-1** — GCal: full booking
6. **GCAL-RC-1** — GCal: returning caller booking
7. **GCAL-RC-3** — GCal: list appointments
8. **GCAL-RC-4** — GCal: reschedule
9. **GCAL-RC-5** — GCal: cancel
10. **GCAL-UI-3** — GCal: safety hazard
12. **HCP-NC-1** — HCP: full happy path
13. **HCP-NC-2** — HCP: autoSchedule=false
14. **HCP-RC-1** — HCP: returning caller single property
15. **HCP-RC-5** — HCP: check schedule
16. **HCP-RC-7** — HCP: reschedule estimate
17. **HCP-UI-9** — HCP: emergency/urgent
18. **HCP-UI-10** — HCP: safety hazard
19. **JOB-NC-1** — Jobber: full happy path
20. **JOB-NC-2** — Jobber: autoSchedule=false
21. **JOB-RC-1** — Jobber: returning caller single property
22. **JOB-RC-5** — Jobber: check schedule
23. **JOB-RC-7** — Jobber: reschedule assessment
24. **SPLIT-1** — Prompt split: new caller workflow
25. **SPLIT-2** — Prompt split: returning caller workflow
26. **CROSS-SAFETY-1** — Safety hazard across all modes

**EndCallTool — Agent Hang-Up**
27. **CROSS-ENDCALL-1** — Hang up after booking (GCal / HCP / Jobber)
28. **CROSS-ENDCALL-2** — Hang up after callback (all 4 modes)
29. **CROSS-ENDCALL-3** — Hang up after service area rejection (all 4 modes)

**Email Collection**
30. **CROSS-EMAIL-1** — No Integration: email during intake
31. **CROSS-EMAIL-2** — GCal: email required for reminders
32. **CROSS-EMAIL-4** — HCP: email during customer creation
33. **CROSS-EMAIL-5** — Jobber: email during customer creation

**Custom Intake Questions**
34. **CROSS-INTAKE-1** — No Integration: custom questions asked and saved
35. **CROSS-INTAKE-2** — GCal: custom questions asked and saved
36. **CROSS-INTAKE-3** — HCP: custom questions via intake_answers
37. **CROSS-INTAKE-4** — Jobber: custom questions via intake_answers
