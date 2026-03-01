# Google Calendar QA — Phased Implementation Plan

**Date**: March 1, 2026  
**Approach**: One phase at a time. Implement → test manually → add pytest where possible → confirm → move on.

---

## Testing Strategy Overview

### What our pytest framework CAN test
The existing tests (`test_gcal_integration.py`) use LiveKit's `AgentSession` with **mock tools** that return canned responses. They test **LLM behavior**: does the agent call the right tool, say the right thing, follow the right workflow. They do NOT hit any real backend or Google Calendar API.

This means we can test:
- **Prompt-level changes** — does the agent follow new instructions (e.g., not say the year, ask for email before booking, refuse out-of-hours reschedules)?
- **Tool selection** — does the agent call `get_available_slots` vs `check_availability` based on the question?
- **Mock tool error handling** — if a mock tool returns an error message (e.g., "past event"), does the agent relay it correctly?

### What our pytest framework CANNOT test
- **Backend validation logic** (duration caps, past event guards, availability checks on reschedule) — these live in `server.ts`, not in the Python agent
- **Google Calendar API interactions** — freeBusy queries, event CRUD
- **Slot computation algorithms** — the business hours → free windows → bookable slots math

### Strategy per fix type

| Fix Type | Test Approach |
|----------|--------------|
| **Prompt-only** | Pytest: LLM behavior test with mock tools |
| **Backend guard** | Manual QA (call the agent, verify error). Mock tool can return the error message to test agent's handling of it. |
| **New endpoint + tool** | Pytest: mock the new tool, test LLM uses it correctly. Backend logic tested manually or with future TS unit tests. |
| **Contract + Python tool + backend** | Pytest for tool selection. Manual for end-to-end. |

---

## Phase 0 — Prerequisites (do first, test immediately)

### 0a. Fix buffer time dead code (#11b)
**What**: Add `settings: true` and `googlePlaceDetails: true` to `getLocationWithGoogleCalendarConnection` query.  
**Why first**: This is a 1-line fix that unblocks buffer time for ALL existing check-availability calls. It's also prerequisite for Phases 2-3.  
**Risk**: Low — only adds more data to an existing cached query.  
**Files**: `server.ts` (~line 11601, the select clause)  
**Test**: Manual — configure a location with 15-min buffer, book two appointments 10 minutes apart, verify the second is rejected. Check server logs for `Buffer time: 15 minutes` instead of the current silent 0.  
**Pytest**: Not directly testable (backend logic). But confirms the foundation is solid for later phases.

### 0b. Fix past event guard (#10)
**What**: Add date check in `google-calendar-update-event` and `google-calendar-cancel-event` endpoints.  
**Why**: Trivial guard, prevents nonsensical operations. Good warm-up.  
**Risk**: Very low — 5 lines per endpoint.  
**Files**: `server.ts` (two endpoints)  
**Test**: Manual — try to cancel/reschedule a past appointment via the agent.  
**Pytest**: Add mock tool that returns "This appointment has already occurred..." and test agent relays the message gracefully.

```python
# conftest.py — update mock
@function_tool()
async def google_calendar_cancel_event(event_id: str) -> str:
    """Cancel a Google Calendar event."""
    if event_id == "evt_past":
        return "This appointment has already occurred and cannot be cancelled."
    return f"Event {event_id} cancelled."

# test_gcal_integration.py
async def test_cannot_cancel_past_event(self, llm):
    """Agent relays error when trying to cancel a past event."""
    # ... returning caller with past event ID
    result = await session.run(user_input="Cancel my appointment from last week")
    await result.expect.contains_message(role="assistant").judge(
        llm, intent="Informs caller the appointment already occurred and cannot be cancelled"
    )
```

**Estimated time**: 30 min implement + 30 min test

---

## Phase 1 — Prompt Fixes (low risk, high coverage)

### 1a. Year pronunciation (#2)
**What**: Add DATE PRONUNCIATION rule to GCal workflow section in `utils.ts` and test prompt.  
**Files**: `utils.ts` (~line 1928), `tests/prompts.py`  
**Pytest**: 
```python
async def test_no_year_in_appointment_confirmation(self, llm):
    """Agent does not say the year when confirming an appointment date."""
    # Book an appointment, check confirmation doesn't include "2026"
```
**Estimated time**: 15 min implement + 15 min test

### 1b. Email enforcement strengthening (#1 — prompt layer)
**What**: Add explicit pre-booking gate in GCal workflow. "You MUST have email before creating event."  
**Files**: `utils.ts` (~line 1861), `tests/prompts.py`  
**Pytest**: Already have `test_email_required_before_booking` — verify it still passes and add a stricter variant where caller refuses email.
```python
async def test_email_refusal_blocks_booking(self, llm):
    """If caller refuses email, agent does NOT create event — offers callback instead."""
```
**Estimated time**: 20 min implement + 20 min test

### 1c. Reschedule must check availability (#3 — prompt layer)
**What**: Add MANDATORY availability check instruction to RESCHEDULING section.  
**Files**: `utils.ts` (~line 1881), `tests/prompts.py`  
**Pytest**:
```python
async def test_reschedule_checks_availability_first(self, llm):
    """Agent calls check_availability before updating event time."""
    # Returning caller asks to reschedule → agent should call check_availability
```
**Estimated time**: 20 min implement + 20 min test

### 1d. Business hours for reschedule (#4 — prompt layer)
**What**: Add business hours rule to RESCHEDULING section.  
**Files**: `utils.ts` (~line 1881), `tests/prompts.py`  
**Pytest**:
```python
async def test_reschedule_rejects_outside_hours(self, llm):
    """Agent refuses to reschedule to Sunday (business closed)."""
```
**Estimated time**: 15 min implement + 15 min test

### 1e. Appointment bleed prevention (#9 — prompt layer)
**What**: Add "entire appointment must fit within hours" rule.  
**Files**: `utils.ts` (~line 1826), `tests/prompts.py`  
**Pytest**:
```python
async def test_no_appointment_past_closing(self, llm):
    """Agent refuses 4pm appointment when duration=90min and closing=5pm."""
```
**Estimated time**: 15 min implement + 15 min test

**Phase 1 total**: ~2 hours. Run full test suite after all 1a-1e to confirm no regressions.

---

## Phase 2 — Backend Guards (medium risk, data integrity)

### 2a. Email enforcement backend (#1 — backend layer)
**What**: In `google-calendar-create-event`, return 400 if `attendeeEmail` is missing.  
**Files**: `server.ts` (~line 11965)  
**Test**: Manual — attempt booking without email via agent. Agent should receive error and go back to collect email.  
**Pytest**: Update mock `google_calendar_create_event` to return error when no email:
```python
@function_tool()
async def google_calendar_create_event(..., attendee_email: str = "") -> str:
    if not attendee_email:
        return "Error: Email address is required for Google Calendar appointments."
    return f"Appointment '{summary}' created..."
```
Then test that the agent handles the error by asking for email.  
**Estimated time**: 30 min implement + 30 min test

### 2b. Duration cap (#5)
**What**: In `google-calendar-create-event`, reject if computed duration > 2x default.  
**Files**: `server.ts` (~after line 12057)  
**Test**: Manual — ask agent to book a 4-hour appointment when default is 90 min.  
**Pytest**: Mock tool returns duration error → agent informs caller of max duration.  
**Estimated time**: 30 min implement + 20 min test

### 2c. Business hours backend guard (#4 + #9 — backend layer)
**What**: In `google-calendar-create-event` and `google-calendar-update-event`, validate start time is within hours and end time doesn't bleed past closing.  
**Files**: `server.ts` (create-event + update-event endpoints)  
**Prerequisite**: Phase 0a (needs `googlePlaceDetails` in the location query)  
**Test**: Manual — attempt booking at 6pm or 90-min at 4:30pm when closing is 5pm.  
**Pytest**: Mock returns hours error → agent suggests alternative.  
**Estimated time**: 1 hour implement + 30 min test

### 2d. Reschedule availability check backend (#3 — backend layer)
**What**: In `google-calendar-update-event`, when time fields are provided, run freeBusy check server-side.  
**Files**: `server.ts` (~line 12769)  
**Test**: Manual — reschedule to a slot that's already booked, verify 409 Conflict.  
**Pytest**: Mock returns conflict error → agent suggests alternatives.  
**Estimated time**: 45 min implement + 30 min test

**Phase 2 total**: ~4 hours. Deploy to staging, manual QA each guard.

---

## Phase 3 — Summary/Description Update Bug Fix (#6)

**What**: Add `summary` and `description` params to the update-event contract, backend, and Python tool.  
**Why separate phase**: This touches 3 files across 2 languages and changes a tool's LLM-facing signature.  

**Files**:
1. `contracts/internal-api.contract.ts` — add `summary`, `description` to schema
2. `server.ts` — destructure new fields, apply to `updatedEvent`, track in `changedFields`
3. `livekit-python/tools/google_calendar_update_event.py` — add `summary`, `description` params

**Test**: Manual — ask agent to change service type on existing appointment.  
**Pytest**:
```python
# Update mock to accept summary/description
@function_tool()
async def google_calendar_update_event(
    event_id: str, new_date: str = "", new_start_time: str = "",
    summary: str = "", description: str = "",
) -> str:
    updates = []
    if summary: updates.append(f"summary to '{summary}'")
    if description: updates.append(f"description updated")
    if new_date: updates.append(f"date to {new_date}")
    return f"Event {event_id} updated: {', '.join(updates) or 'no changes'}."

# Test
async def test_update_event_summary(self, llm):
    """Returning caller changes service type → agent updates summary."""
    # "I need to change my plumbing appointment to HVAC instead"
    # Verify google_calendar_update_event is called with summary param
```

**Estimated time**: 1.5 hours implement + 30 min test

---

## Phase 4 — Replace Availability Tool + Add Next Available (#11 + #12)

This is the biggest phase. The old `check_availability` tool (yes/no for a single slot) is **replaced** with a slot-based tool that returns all bookable times for a day. A new `get_next_available` tool is added for "next opening?" questions. Build together since they share infrastructure.

### 4a. Shared infrastructure
- Update `getLocationWithGoogleCalendarConnection` to include `settings` + `googlePlaceDetails` (done in Phase 0a)
- Build `parseBusinessHours(googlePlaceDetails, dayOfWeek)` → returns `{ open: "09:00", close: "17:00" }` or `null` (closed)
- Build `computeAvailableSlots(busyPeriods, openTime, closeTime, durationMin, bufferMin)` → returns slot array
- These are pure functions, easily unit-testable if we add TS tests later

### 4b. Replace `check-availability` endpoint with `get-availability`
**What**: Delete old yes/no endpoint. Create new slot-based endpoint. Rewrite Python tool (keep name, change signature from `(start_date_time, end_date_time)` to `(date)`).

**Files**:
1. `server.ts` — delete `POST /internal/tools/google-calendar-check-availability`, create `POST /internal/tools/google-calendar-get-availability`
2. `livekit-python/tools/google_calendar_check_availability.py` — rewrite with new `(date)` signature pointing to new endpoint
3. `contracts/internal-api.contract.ts` — update schema
4. `utils.ts` — replace AVAILABILITY CHECKING prompt section
5. `tests/prompts.py` — update availability instructions
6. `tests/conftest.py` — update mock tool

**Updated mock** (replaces existing `google_calendar_check_availability` mock in conftest.py):
```python
@function_tool()
async def google_calendar_check_availability(date: str) -> str:
    """Check calendar availability for a specific day. Returns all bookable slots."""
    return f"Available on {date}: 9:00 AM, 11:30 AM, 3:30 PM. Business hours: 8 AM - 5 PM. Appointments are 90 minutes."
```

**Pytest**:
```python
async def test_day_availability_returns_slots(self, llm):
    """'Do you have anything on Monday?' → agent calls check_availability, presents slots."""
    result = await session.run(user_input="Do you have anything available on Monday?")
    result.expect.contains_function_call(name="google_calendar_check_availability")

async def test_specific_time_check(self, llm):
    """'Is 2pm available?' → agent calls check_availability, checks if 2pm is in slots."""
    result = await session.run(user_input="Is 2pm on Monday available?")
    result.expect.contains_function_call(name="google_calendar_check_availability")

async def test_unavailable_offers_alternatives(self, llm):
    """When requested time isn't in slots, agent offers alternatives from the response."""
    # Mock returns slots at 9 AM and 3:30 PM (not 2pm)
    result = await session.run(user_input="Is 2pm on Monday available?")
    await result.expect.contains_message(role="assistant").judge(
        llm, intent="Informs caller that 2pm is not available and suggests alternative times from the available slots"
    )

async def test_presents_slots_naturally(self, llm):
    """Agent presents available slots conversationally."""
    result = await session.run(user_input="What times do you have on Monday?")
    await result.expect.contains_message(role="assistant").judge(
        llm, intent="Presents multiple available time slots in a natural conversational way"
    )
```

### 4c. `get-next-available` endpoint + tool (NEW)
**Files**:
1. `server.ts` — new `POST /internal/tools/google-calendar-get-next-available` endpoint
2. `livekit-python/tools/google_calendar_get_next_available.py` — new tool
3. `livekit-python/tools/__init__.py` — register tool
4. `server.ts` — register tool in `getLiveKitToolsForLocation`
5. `utils.ts` — add NEXT/FIRST AVAILABLE prompt section
6. `tests/prompts.py` — add to test prompt
7. `tests/conftest.py` — add mock tool

**Mock tool**:
```python
@function_tool()
async def google_calendar_get_next_available(starting_from: str = "") -> str:
    """Find the next available appointment slot."""
    return "Next available: Monday, March 3rd at 9:00 AM (90-minute appointment)."
```

**Pytest**:
```python
async def test_next_available_uses_dedicated_tool(self, llm):
    """'When's the next opening?' → agent uses get_next_available."""
    result = await session.run(user_input="When's the next available appointment?")
    result.expect.contains_function_call(name="google_calendar_get_next_available")

async def test_next_available_waits_for_confirmation(self, llm):
    """Agent presents the slot and waits for confirmation before booking."""
    result = await session.run(user_input="I want the next available appointment")
    await result.expect.contains_message(role="assistant").judge(
        llm, intent="Presents a specific date and time and asks for confirmation before booking"
    )
```

**Estimated time**: 4-5 hours implement + 2 hours test

---

## Phase 5 — Booking Limits (#8)

**What**: Per-caller limits (max 3 future appointments, max 1 per day).  
**Files**: `server.ts` (create-event endpoint)  
**Test**: Manual — book 4 appointments as same caller, verify 4th is rejected.  
**Pytest**: Mock tool returns limit error → agent informs caller.  
**Estimated time**: 1 hour implement + 30 min test

---

## Phase 6 — Nice-to-Haves

### 6a. Store intake on GCal events (#7)
**What**: Add intake answers to `extendedProperties.shared` on created events.  
**Files**: `server.ts` (create-event endpoint, after event creation)  
**Test**: Manual — create appointment, check event in Google Calendar for extended properties.  
**Pytest**: N/A (backend-only, no LLM behavior change)  
**Estimated time**: 45 min

---

## Summary Timeline

| Phase | Items | Effort | Cumulative |
|-------|-------|--------|------------|
| **0** | Location query fix + past event guard | 1 hour | 1 hour |
| **1** | All prompt fixes (year, email, reschedule, hours, bleed) | 2 hours | 3 hours |
| **2** | All backend guards (email, duration, hours, reschedule) | 4 hours | 7 hours |
| **3** | Summary/description update bug | 2 hours | 9 hours |
| **4** | Replace availability tool + add next-available | 6-7 hours | 15-16 hours |
| **5** | Booking limits | 1.5 hours | 17 hours |
| **6** | Intake on events | 45 min | ~18 hours |

### Deploy cadence
- **After Phase 0**: Deploy to staging, verify past event guard works
- **After Phase 1**: Deploy, run full pytest suite + manual spot checks
- **After Phase 2**: Deploy, thorough manual QA of all guards
- **After Phase 3**: Deploy, test update flows
- **After Phase 4**: Deploy, this is the big one — test both availability tools end-to-end
- **After Phase 5-6**: Deploy, final polish

### Pytest test count estimate
- Phase 0: +1 test
- Phase 1: +5 tests  
- Phase 2: +4 tests (mock error handling)
- Phase 3: +2 tests
- Phase 4: +6 tests (4 for check_availability replacement, 2 for get_next_available)
- Phase 5: +1 test
- **Total: ~19 new tests** added to `test_gcal_integration.py`
